import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';

class AttendanceRecordEditScreen extends StatefulWidget {
  const AttendanceRecordEditScreen({
    super.key,
    required this.dao,
    required this.record,
  });

  final AttendanceDao dao;
  final AttendanceRecord record;

  @override
  State<AttendanceRecordEditScreen> createState() => _AttendanceRecordEditScreenState();
}

class _AttendanceRecordEditScreenState extends State<AttendanceRecordEditScreen> {
  late bool _absent;
  late bool _leave;
  late bool _holiday;
  DateTime? _checkIn;
  DateTime? _checkOut;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _absent = r.isAbsent;
    _leave = r.isLeave;
    _holiday = r.isHoliday;
    _checkIn = r.checkInAt;
    _checkOut = r.checkOutAt;
    _noteController.text = r.note ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isCheckIn}) async {
    final initial = isCheckIn
        ? (_checkIn ?? DateTime(widget.record.day.year, widget.record.day.month, widget.record.day.day, 8, 0))
        : (_checkOut ?? DateTime(widget.record.day.year, widget.record.day.month, widget.record.day.day, 17, 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null) return;
    final value = DateTime(
      widget.record.day.year,
      widget.record.day.month,
      widget.record.day.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (isCheckIn) {
        _checkIn = value;
      } else {
        _checkOut = value;
      }
    });
  }

  Future<void> _save() async {
    await widget.dao.updateRecordManual(
      recordId: widget.record.id,
      checkInAt: _checkIn,
      checkOutAt: _checkOut,
      isAbsent: _absent,
      isLeave: _leave,
      isHoliday: _holiday,
      note: _noteController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除当天记录'),
        content: Text('确认删除 ${_md(widget.record.day)} 的签到记录吗？删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.dao.deleteRecordById(widget.record.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('编辑 ${_md(widget.record.day)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('上班时间'),
            subtitle: Text(_checkIn == null ? '--:--' : _hhmm(_checkIn!)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _pickTime(isCheckIn: true),
          ),
          ListTile(
            title: const Text('下班时间'),
            subtitle: Text(_checkOut == null ? '--:--' : _hhmm(_checkOut!)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _pickTime(isCheckIn: false),
          ),
          SwitchListTile(
            title: const Text('假期'),
            subtitle: const Text('标记后按假期加班日计算'),
            value: _holiday,
            onChanged: (v) => setState(() {
              _holiday = v;
              if (v) {
                _leave = false;
                _absent = false;
              }
            }),
          ),
          SwitchListTile(
            title: const Text('请假'),
            value: _leave,
            onChanged: _holiday ? null : (v) => setState(() => _leave = v),
          ),
          SwitchListTile(
            title: const Text('旷工'),
            value: _absent,
            onChanged: _holiday ? null : (v) => setState(() => _absent = v),
          ),
          if (_holiday)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                '保存后将按上班到下班的实际时长计算加班。',
                style: TextStyle(color: Color(0xFF475569)),
              ),
            ),
          if (_leave)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                '保存后将按规则上班时间到打卡上班时间自动计算请假时长。',
                style: TextStyle(color: Color(0xFF475569)),
              ),
            ),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '备注',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          const Text(
            '单独缺少上班或下班时间时，状态显示为未完成。',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
              ),
              onPressed: _deleteRecord,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('彻底删除当天记录'),
            ),
          ),
        ],
      ),
    );
  }

}

String _md(DateTime day) =>
    '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

String _hhmm(DateTime ts) =>
    '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
