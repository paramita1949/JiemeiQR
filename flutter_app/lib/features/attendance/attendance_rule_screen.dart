import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceRuleScreen extends StatefulWidget {
  const AttendanceRuleScreen({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  State<AttendanceRuleScreen> createState() => _AttendanceRuleScreenState();
}

class _AttendanceRuleScreenState extends State<AttendanceRuleScreen> {
  late final AttendanceDao _dao;
  bool _loading = true;
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
  List<AttendanceBackupSnapshot> _backups = const [];
  GeofenceDailyState? _todayGeofenceState;

  @override
  void initState() {
    super.initState();
    _dao = AttendanceDao(widget.database);
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
    _backups = await _dao.listAttendanceBackups();
    _todayGeofenceState = await _dao.getTodayGeofenceState();
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('规则已保存')),
    );
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

  Future<void> _importAttendanceBackup({required bool overwrite}) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    await _dao.importAttendanceFromFilePath(path, overwrite: overwrite);
    _backups = await _dao.listAttendanceBackups();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(overwrite ? '考勤备份已覆盖导入' : '考勤备份已合并导入')),
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
                _rowField('迟到宽限(分钟)', _lateController, keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<String>(
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
          ),
          const SizedBox(height: 14),
          _glassCard(
            title: '围栏提醒',
            icon: Icons.location_on_rounded,
            child: Column(
              children: [
                _switchTile('启用围栏提醒', _geofenceEnabled, (v) => setState(() => _geofenceEnabled = v)),
                _rowField('纬度', _latController, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _rowField('经度', _lngController, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _rowField('范围半径(m)', _radiusController, keyboardType: TextInputType.number),
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
                _switchTile('上班提醒', _checkInRemindEnabled, (v) => setState(() => _checkInRemindEnabled = v)),
                _switchTile('下班提醒', _checkOutRemindEnabled, (v) => setState(() => _checkOutRemindEnabled = v)),
                if (_todayGeofenceState != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.radar_rounded, size: 18, color: Color(0xFF4664C6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '今日：${_todayGeofenceState!.wasInside ? '围栏内' : '围栏外'} · 已触发${_todayGeofenceState!.triggeredCount}次',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF4B587C)),
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
            title: '考勤备份',
            icon: Icons.inventory_2_rounded,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1F63F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _exportAttendanceBackup,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('生成并分享备份', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1F63F2),
                          side: const BorderSide(color: Color(0xFFBFD1FF)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _importAttendanceBackup(overwrite: true),
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('导入覆盖', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1F63F2),
                          side: const BorderSide(color: Color(0xFFBFD1FF)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _importAttendanceBackup(overwrite: false),
                        icon: const Icon(Icons.merge_type_rounded, size: 18),
                        label: const Text('导入合并', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_backups.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('暂无备份记录', style: TextStyle(color: Color(0xFF74819E))),
                  )
                else
                  ..._backups.map(_backupTile),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _save,
            child: const Text('保存设置'),
          ),
        ],
      ),
    );
  }

  Widget _backupTile(AttendanceBackupSnapshot b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FE),
        borderRadius: BorderRadius.circular(12),
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${b.createdAt.toLocal()} · ${b.sizeBytes}B',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF74819E)),
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
        onChanged: onChanged,
      ),
    );
  }

  Widget _quickRadius(int radius) {
    final selected = _radiusController.text.trim() == '$radius';
    return ChoiceChip(
      label: Text('${radius}m'),
      selected: selected,
      onSelected: (_) => setState(() => _radiusController.text = '$radius'),
      side: BorderSide(color: selected ? const Color(0xFF8DB0FF) : const Color(0xFFD7DDF0)),
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

  Widget _glassCard({required String title, required IconData icon, required Widget child}) {
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
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
