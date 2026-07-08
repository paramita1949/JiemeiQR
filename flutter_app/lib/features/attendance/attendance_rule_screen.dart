import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_geofence_bridge.dart';
import 'package:qrscan_flutter/features/attendance/attendance_geofence_reminder_service.dart';
import 'package:qrscan_flutter/features/transfer/cloud_backup_service.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';
import 'package:share_plus/share_plus.dart';

const _defaultOfficeRadiusMeters = 500;
const _defaultProviderSummary = '系统融合定位（GPS/北斗/网络）';

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
  final _autoCheckinPopupTextController = TextEditingController();

  bool _geofenceEnabled = false;
  bool _showBackupRecords = false;
  String _weekendType = 'double';
  String _providerSummary = _defaultProviderSummary;
  List<AttendanceBackupSnapshot> _backups = const [];
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
    _autoCheckinPopupTextController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rule = await _dao.getRule();
    _startController.text = rule.workStartTime;
    _endController.text = rule.workEndTime;
    _lateController.text = '${rule.lateGraceMinutes}';
    _latController.text = rule.officeLat?.toString() ?? '';
    _lngController.text = rule.officeLng?.toString() ?? '';
    _autoCheckinPopupTextController.text = rule.autoCheckinPopupText ?? '';
    _geofenceEnabled = rule.geofenceEnabled;
    _weekendType = rule.weekendType;

    if (!mounted) return;
    setState(() => _loading = false);

    try {
      _backups = await _dao.listAttendanceBackups();
    } catch (e) {
      DebugEventLog.add('ATTENDANCE_RULE_LOAD', 'list backups failed: $e');
      _backups = const [];
    }
    try {
      _todayGeofenceState = await _dao.getTodayGeofenceState();
    } catch (e) {
      DebugEventLog.add('ATTENDANCE_RULE_LOAD', 'load today state failed: $e');
      _todayGeofenceState = null;
    }
    try {
      _providerSummary = await AttendanceGeofenceBridge.providerSummary();
    } catch (e) {
      DebugEventLog.add('ATTENDANCE_RULE_LOAD', 'provider summary failed: $e');
      _providerSummary = _defaultProviderSummary;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _save() async {
    await _dao.saveRule(
      AttendanceRulesCompanion(
        workStartTime: Value(_startController.text.trim()),
        workEndTime: Value(_endController.text.trim()),
        lateGraceMinutes: Value(int.tryParse(_lateController.text.trim()) ?? 0),
        weekendType: Value(_weekendType),
        officeLat: Value(double.tryParse(_latController.text.trim())),
        officeLng: Value(double.tryParse(_lngController.text.trim())),
        officeRadiusMeters: const Value(_defaultOfficeRadiusMeters),
        geofenceEnabled: Value(_geofenceEnabled),
        checkinReminderEnabled: const Value(true),
        checkoutReminderEnabled: const Value(false),
        autoCheckinPopupText:
            Value(_normalizedPopupText(_autoCheckinPopupTextController.text)),
      ),
    );
    try {
      await AttendanceGeofenceBridge.syncGeofence(
        enabled: _geofenceEnabled,
        lat: double.tryParse(_latController.text.trim()),
        lng: double.tryParse(_lngController.text.trim()),
        radius: _defaultOfficeRadiusMeters,
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
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    DebugEventLog.add(
      'GEOFENCE_SAVE',
      'start enabled=$_geofenceEnabled lat=$lat lng=$lng radius=$_defaultOfficeRadiusMeters',
    );
    await _dao.saveRule(
      AttendanceRulesCompanion(
        officeLat: Value(lat),
        officeLng: Value(lng),
        officeRadiusMeters: const Value(_defaultOfficeRadiusMeters),
        geofenceEnabled: Value(_geofenceEnabled),
        checkinReminderEnabled: const Value(true),
        checkoutReminderEnabled: const Value(false),
        autoCheckinPopupText:
            Value(_normalizedPopupText(_autoCheckinPopupTextController.text)),
      ),
    );

    try {
      await AttendanceGeofenceBridge.syncGeofence(
        enabled: _geofenceEnabled,
        lat: lat,
        lng: lng,
        radius: _defaultOfficeRadiusMeters,
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

  String? _normalizedPopupText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
            '已使用${resolved.provider}定位更新公司范围',
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

  Future<void> _exportAttendanceBackup() async {
    final file = await _dao.createAttendanceBackup();
    _backups = await _dao.listAttendanceBackups();
    if (!mounted) return;
    setState(() {});
    await SharePlus.instance.share(
      ShareParams(
        text: '考勤备份',
        files: [XFile(file.filePath)],
      ),
    );
  }

  Future<void> _deleteBackup(AttendanceBackupSnapshot row) async {
    await _dao.deleteAttendanceBackup(row.filePath);
    _backups = await _dao.listAttendanceBackups();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _shareBackup(AttendanceBackupSnapshot row) async {
    await SharePlus.instance.share(
      ShareParams(
        text: '考勤备份',
        files: [XFile(row.filePath)],
      ),
    );
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
    const bg = Color(0xFFF5F7FB);
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
          _workRuleCard(),
          const SizedBox(height: 12),
          _autoCheckInCard(),
          const SizedBox(height: 12),
          _dataBackupCard(),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _save,
            child: const Text('保存设置'),
          ),
        ],
      ),
    );
  }

  Widget _workRuleCard() {
    return _settingsCard(
      title: '班次规则',
      icon: Icons.schedule_rounded,
      trailing: Text(
        _weekendType == 'double' ? '双休' : '单休',
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Column(
        children: [
          _rowField('上班时间', _startController),
          _rowField('下班时间', _endController),
          _rowField(
            '迟到宽限(分钟)',
            _lateController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              segments: const [
                ButtonSegment(value: 'single', label: Text('单休')),
                ButtonSegment(value: 'double', label: Text('双休')),
              ],
              selected: {_weekendType},
              onSelectionChanged: (v) => setState(() => _weekendType = v.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoCheckInCard() {
    return _settingsCard(
      title: '签到',
      icon: Icons.location_on_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '自动签到',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          Switch(
            value: _geofenceEnabled,
            activeThumbColor: const Color(0xFF1D4ED8),
            onChanged: (v) async {
              setState(() => _geofenceEnabled = v);
              await _saveGeofenceOnly();
            },
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusStrip(
            icon: Icons.radar_rounded,
            text: _todayGeofenceState == null
                ? '打开APP定位到公司范围后自动记录上班，并系统通知反馈'
                : '今日：${_todayGeofenceState!.wasInside ? '范围内' : '范围外'} · 已触发${_todayGeofenceState!.triggeredCount}次 · 打开APP后系统通知反馈',
          ),
          const SizedBox(height: 10),
          _rowField(
            '自动签到通知内容',
            _autoCheckinPopupTextController,
            key: const Key('autoCheckinPopupTextField'),
          ),
          Row(
            children: [
              Expanded(
                child: _compactOutlineButton(
                  icon: Icons.my_location_rounded,
                  label: '当前位置',
                  onPressed: _useCurrentLocation,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _compactOutlineButton(
                  icon: Icons.verified_user_outlined,
                  label: '系统权限',
                  onPressed: _checkSystemPermissions,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _statusStrip(
            icon: Icons.sensors_rounded,
            text: _providerSummary,
            muted: true,
          ),
        ],
      ),
    );
  }

  Widget _dataBackupCard() {
    final latestBackup = _backups.isEmpty ? null : _backups.first;
    return _settingsCard(
      title: '数据备份',
      icon: Icons.inventory_2_rounded,
      trailing: Text(
        widget.accountKey,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusStrip(
            icon: Icons.folder_copy_rounded,
            text: latestBackup == null
                ? '最近暂无本地备份'
                : '最近备份：${latestBackup.fileName}',
            muted: true,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F63F2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: _exportAttendanceBackup,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text(
                '生成并分享备份',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _compactOutlineButton(
                  icon: Icons.cloud_upload_outlined,
                  label: '上传云端',
                  onPressed: _cloudBusy ? null : _uploadAttendanceToCloud,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _compactOutlineButton(
                  icon: Icons.cloud_download_outlined,
                  label: '云端恢复',
                  onPressed: _cloudBusy ? null : _downloadAttendanceFromCloud,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () =>
                setState(() => _showBackupRecords = !_showBackupRecords),
            icon: Icon(
              _showBackupRecords
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            label: const Text('备份记录'),
          ),
          if (_cloudBusy) ...[
            const SizedBox(height: 4),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (_showBackupRecords) ...[
            const SizedBox(height: 4),
            if (_backups.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '暂无本地备份记录',
                  style: TextStyle(color: Color(0xFF74819E)),
                ),
              )
            else
              ..._backups.map(_backupTile),
          ],
        ],
      ),
    );
  }

  Future<void> _checkSystemPermissions() async {
    final messenger = ScaffoldMessenger.of(context);
    final state =
        await AttendanceGeofenceReminderService.ensureSystemPermissions(
      requestIfNeeded: true,
    );
    if (!mounted) return;
    final msg = state.ready ? '权限已就绪（定位/通知）' : '权限未完全开启：请检查定位服务、定位权限、通知权限';
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _settingsCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0C235A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1F63F2), size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _statusStrip({
    required IconData icon,
    required String text,
    bool muted = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF8FAFC) : const Color(0xFFF1F6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: muted ? const Color(0xFFE8EDF5) : const Color(0xFFDCE8FF),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: muted ? const Color(0xFF64748B) : const Color(0xFF1F63F2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    muted ? const Color(0xFF64748B) : const Color(0xFF334155),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactOutlineButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1F63F2),
        side: const BorderSide(color: Color(0xFFC7D8FF)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _backupTile(AttendanceBackupSnapshot b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${b.createdAt.toLocal()} · ${b.sizeBytes}B',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF74819E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _shareBackup(b),
            icon: const Icon(Icons.share_rounded),
            tooltip: '分享',
          ),
          IconButton(
            onPressed: () => _deleteBackup(b),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: '删除',
          ),
        ],
      ),
    );
  }

  Widget _rowField(
    String label,
    TextEditingController controller, {
    Key? key,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        key: key,
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
