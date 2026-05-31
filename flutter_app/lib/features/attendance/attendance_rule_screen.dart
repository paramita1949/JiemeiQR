import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_geofence_bridge.dart';
import 'package:qrscan_flutter/features/attendance/attendance_geofence_reminder_service.dart';
import 'package:qrscan_flutter/features/transfer/cloud_backup_service.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

class AttendanceRuleScreen extends StatefulWidget {
  const AttendanceRuleScreen({
    super.key,
    required this.database,
    this.accountKey = 'local',
  });

  final AppDatabase database;
  final String accountKey;

  @override
  State<AttendanceRuleScreen> createState() => _AttendanceRuleScreenState();
}

class _AttendanceRuleScreenState extends State<AttendanceRuleScreen> {
  late final AttendanceDao _dao;
  final _cloudBackupService = CloudBackupService(api: SupabaseCloudBackupApi());
  bool _loading = true;
  bool _cloudBusy = false;
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _lateController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();

  bool _geofenceEnabled = false;
  bool _checkInRemindEnabled = true;
  bool _checkOutRemindEnabled = false;
  String _weekendType = 'double';
  String _providerSummary = '系统融合定位（GPS/北斗/网络）';
  GeofenceDailyState? _todayGeofenceState;

  Future<({double lat, double lng, String provider, double? accuracy})?>
      _resolveFenceLocation() async {
    final amap = await AttendanceGeofenceBridge.amapCurrentLocation();
    if (amap != null) {
      return (
        lat: amap.latitude,
        lng: amap.longitude,
        provider: '高德',
        accuracy: amap.accuracy,
      );
    }
    DebugEventLog.add('GEOFENCE_LOCATE', 'amap location unavailable');
    return null;
  }

  @override
  void initState() {
    super.initState();
    _dao = AttendanceDao(widget.database, accountKey: widget.accountKey);
    _load();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _lateController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rule = await _dao.getRule();
    _startController.text = rule.workStartTime;
    _endController.text = rule.workEndTime;
    _lateController.text = '${rule.lateGraceMinutes}';
    _latController.text = rule.officeLat?.toString() ?? '';
    _lngController.text = rule.officeLng?.toString() ?? '';
    _radiusController.text = '${rule.officeRadiusMeters}';
    _geofenceEnabled = rule.geofenceEnabled;
    _checkInRemindEnabled = rule.checkinReminderEnabled;
    _checkOutRemindEnabled = rule.checkoutReminderEnabled;
    _weekendType = rule.weekendType;
    _todayGeofenceState = await _dao.getTodayGeofenceState();
    _providerSummary = await AttendanceGeofenceBridge.providerSummary();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final radius = int.tryParse(_radiusController.text.trim()) ?? 300;
    final normalizedRadius = radius.clamp(50, 2000);
    await _dao.saveRule(
      AttendanceRulesCompanion(
        workStartTime: Value(_startController.text.trim()),
        workEndTime: Value(_endController.text.trim()),
        lateGraceMinutes: Value(int.tryParse(_lateController.text.trim()) ?? 0),
        weekendType: Value(_weekendType),
        officeLat: Value(double.tryParse(_latController.text.trim())),
        officeLng: Value(double.tryParse(_lngController.text.trim())),
        officeRadiusMeters: Value(normalizedRadius),
        geofenceEnabled: Value(_geofenceEnabled),
        checkinReminderEnabled: Value(_checkInRemindEnabled),
        checkoutReminderEnabled: Value(_checkOutRemindEnabled),
      ),
    );
    try {
      await AttendanceGeofenceBridge.syncGeofence(
        enabled: _geofenceEnabled,
        lat: double.tryParse(_latController.text.trim()),
        lng: double.tryParse(_lngController.text.trim()),
        radius: normalizedRadius,
      );
    } catch (_) {
      // Keep rule saving resilient when geofence registration fails on device.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('规则已保存')),
    );
  }

  Future<void> _saveGeofenceOnly({bool silent = true}) async {
    final radius = int.tryParse(_radiusController.text.trim()) ?? 300;
    final normalizedRadius = radius.clamp(50, 2000);
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    DebugEventLog.add(
      'GEOFENCE_SAVE',
      'start enabled=$_geofenceEnabled lat=$lat lng=$lng radius=$normalizedRadius',
    );
    await _dao.saveRule(
      AttendanceRulesCompanion(
        officeLat: Value(lat),
        officeLng: Value(lng),
        officeRadiusMeters: Value(normalizedRadius),
        geofenceEnabled: Value(_geofenceEnabled),
        checkinReminderEnabled: Value(_checkInRemindEnabled),
        checkoutReminderEnabled: Value(_checkOutRemindEnabled),
      ),
    );

    try {
      await AttendanceGeofenceBridge.syncGeofence(
        enabled: _geofenceEnabled,
        lat: lat,
        lng: lng,
        radius: normalizedRadius,
      );
      DebugEventLog.add('GEOFENCE_SAVE', 'syncGeofence success');
    } catch (e) {
      DebugEventLog.add('GEOFENCE_SAVE', 'syncGeofence failed: $e');
    }

    if (!mounted || silent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('围栏设置已保存')),
    );
  }

  Future<void> _useCurrentLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    DebugEventLog.add('GEOFENCE_LOCATE', 'tap 获取当前位置');
    final state =
        await AttendanceGeofenceReminderService.ensureSystemPermissions(
      requestIfNeeded: true,
    );
    DebugEventLog.add(
      'GEOFENCE_LOCATE',
      'permission service=${state.locationServiceEnabled} location=${state.locationPermission.name} notification=${state.notificationGranted}',
    );
    if (!state.locationServiceEnabled ||
        state.locationPermission == LocationPermission.denied ||
        state.locationPermission == LocationPermission.deniedForever) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('定位不可用，请先开启定位服务与定位权限')),
      );
      return;
    }

    try {
      DebugEventLog.add('GEOFENCE_LOCATE', 'begin resolve fence location');
      final resolved = await _resolveFenceLocation();
      if (resolved == null) {
        DebugEventLog.add('GEOFENCE_LOCATE', 'resolved location is null');
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('高德定位失败：请检查网络/GPS后重试')),
        );
        return;
      }
      DebugEventLog.add(
        'GEOFENCE_LOCATE',
        'position provider=${resolved.provider} lat=${resolved.lat} lng=${resolved.lng} accuracy=${resolved.accuracy}',
      );
      if (!mounted) return;
      setState(() {
        _latController.text = resolved.lat.toStringAsFixed(6);
        _lngController.text = resolved.lng.toStringAsFixed(6);
      });
      await _saveGeofenceOnly(silent: true);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '已使用${resolved.provider}定位更新围栏中心：${_latController.text}, ${_lngController.text}',
          ),
        ),
      );
    } catch (e) {
      DebugEventLog.add('GEOFENCE_LOCATE', 'get location failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('获取当前位置失败：$e')),
      );
    }
  }

  Future<void> _uploadAttendanceToCloud() async {
    await _runCloudAttendanceAction(() async {
      final session = await _cloudBackupService.loadSavedSession();
      if (session == null) {
        throw const _AttendanceCloudLoginRequiredException();
      }
      final jsonText = await _dao.exportAttendanceJson();
      await _cloudBackupService.uploadAttendanceBackup(
        session: session,
        accountKey: widget.accountKey,
        jsonText: jsonText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('签到数据已上传云端')),
      );
    });
  }

  Future<void> _downloadAttendanceFromCloud() async {
    await _runCloudAttendanceAction(() async {
      final session = await _cloudBackupService.loadSavedSession();
      if (session == null) {
        throw const _AttendanceCloudLoginRequiredException();
      }
      final jsonText = await _cloudBackupService.downloadAttendanceBackup(
        session: session,
        accountKey: widget.accountKey,
      );
      await _dao.importAttendanceJson(jsonText, overwrite: true);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('云端签到数据已恢复')),
      );
    });
  }

  Future<void> _runCloudAttendanceAction(Future<void> Function() action) async {
    if (_cloudBusy) return;
    setState(() => _cloudBusy = true);
    try {
      await action();
    } on _AttendanceCloudLoginRequiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在数据备份里登录云账号')),
      );
    } on CloudBackupRequestException catch (e) {
      if (!mounted) return;
      final notFound = e.statusCode == 404;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notFound ? '云端还没有这个账号的签到备份' : '云同步失败：${e.debugMessage}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('云同步失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _cloudBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF3F6FC);
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('规则设置'),
        elevation: 0,
        backgroundColor: bg,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          _glassCard(
            title: '班次规则',
            icon: Icons.schedule_rounded,
            child: Column(
              children: [
                _rowField('上班时间', _startController),
                _rowField('下班时间', _endController),
                _rowField('迟到宽限(分钟)', _lateController,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'single', label: Text('单休')),
                      ButtonSegment(value: 'double', label: Text('双休')),
                    ],
                    selected: {_weekendType},
                    onSelectionChanged: (v) =>
                        setState(() => _weekendType = v.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _glassCard(
            title: '到公司自动签到',
            icon: Icons.location_on_rounded,
            child: Column(
              children: [
                _switchTile('到公司自动签到', _geofenceEnabled,
                    (v) => setState(() => _geofenceEnabled = v)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _useCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('获取当前位置'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final state = await AttendanceGeofenceReminderService
                          .ensureSystemPermissions(
                        requestIfNeeded: true,
                      );
                      if (!mounted) return;
                      final msg = state.ready
                          ? '权限已就绪（定位/通知）'
                          : '权限未完全开启：请检查定位服务、定位权限、通知权限（VIVO 还需自启动与后台高耗电白名单）';
                      messenger.showSnackBar(SnackBar(content: Text(msg)));
                    },
                    icon: const Icon(Icons.verified_user_outlined, size: 18),
                    label: const Text('检测并开启系统权限'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _providerSummary,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
                _rowField('纬度', _latController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
                _rowField('经度', _lngController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
                _rowField('范围半径(m)', _radiusController,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  children: [
                    _quickRadius(100),
                    _quickRadius(200),
                    _quickRadius(300),
                    _quickRadius(500),
                  ],
                ),
                const SizedBox(height: 10),
                _switchTile('上班前通知', _checkInRemindEnabled,
                    (v) => setState(() => _checkInRemindEnabled = v)),
                _switchTile('下班通知', _checkOutRemindEnabled,
                    (v) => setState(() => _checkOutRemindEnabled = v)),
                if (_todayGeofenceState != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.radar_rounded,
                            size: 18, color: Color(0xFF4664C6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '今日：${_todayGeofenceState!.wasInside ? '围栏内' : '围栏外'} · 已触发${_todayGeofenceState!.triggeredCount}次',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF4B587C)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _glassCard(
            title: '考勤云备份',
            icon: Icons.cloud_done_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前账号：${widget.accountKey}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _cloudActionButton(
                        icon: Icons.cloud_upload_outlined,
                        label: '上传云端',
                        filled: true,
                        onPressed: _cloudBusy ? null : _uploadAttendanceToCloud,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _cloudActionButton(
                        icon: Icons.cloud_download_outlined,
                        label: '云端恢复',
                        filled: false,
                        onPressed:
                            _cloudBusy ? null : _downloadAttendanceFromCloud,
                      ),
                    ),
                  ],
                ),
                if (_cloudBusy) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _save,
            child: const Text('保存设置'),
          ),
        ],
      ),
    );
  }

  Widget _cloudActionButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback? onPressed,
  }) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    if (filled) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1F63F2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: shape,
          elevation: 0,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F766E),
        side: const BorderSide(color: Color(0xFF99F6E4)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: shape,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeThumbColor: const Color(0xFF1D4ED8),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        value: value,
        onChanged: (v) async {
          onChanged(v);
          if (title == '到公司自动签到' || title == '上班前通知' || title == '下班通知') {
            await _saveGeofenceOnly();
          }
        },
      ),
    );
  }

  Widget _quickRadius(int radius) {
    final selected = _radiusController.text.trim() == '$radius';
    return ChoiceChip(
      label: Text('${radius}m'),
      selected: selected,
      onSelected: (_) => setState(() => _radiusController.text = '$radius'),
      side: BorderSide(
          color: selected ? const Color(0xFF8DB0FF) : const Color(0xFFD7DDF0)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      selectedColor: const Color(0xFFDDE8FF),
      backgroundColor: Colors.white,
      elevation: selected ? 0 : 0,
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF224FD4) : const Color(0xFF45506A),
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  Widget _glassCard(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140C235A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F57E8), Color(0xFF1D9DE8)],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _rowField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF7F9FE),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E1F3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E1F3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A59E8), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _AttendanceCloudLoginRequiredException implements Exception {
  const _AttendanceCloudLoginRequiredException();
}
