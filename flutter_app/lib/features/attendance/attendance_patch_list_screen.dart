import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_record_edit_screen.dart';

class AttendancePatchListScreen extends StatefulWidget {
  const AttendancePatchListScreen({
    super.key,
    required this.database,
    this.accountKey = 'local',
  });

  final AppDatabase database;
  final String accountKey;

  @override
  State<AttendancePatchListScreen> createState() =>
      _AttendancePatchListScreenState();
}

class _AttendancePatchListScreenState extends State<AttendancePatchListScreen> {
  late final AttendanceDao _dao;
  List<AttendanceRecord> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _dao = AttendanceDao(widget.database, accountKey: widget.accountKey);
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final month = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final rows = await _dao.recordsByMonth(month);
    if (!mounted) return;
    setState(() {
      _rows = rows.where((r) => r.needsPatch).toList();
      _loading = false;
    });
  }

  Future<void> _openEdit(AttendanceRecord row) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AttendanceRecordEditScreen(dao: _dao, record: row),
      ),
    );
    if (changed == true) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('未完成记录')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('暂无未完成记录'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rows.length,
                  itemBuilder: (_, i) {
                    final row = _rows[i];
                    return Card(
                      child: ListTile(
                        title: Text(_md(row.day)),
                        subtitle: Text(
                            '${row.checkInAt == null ? '--:--' : _hhmm(row.checkInAt!)} / ${row.checkOutAt == null ? '--:--' : _hhmm(row.checkOutAt!)}'),
                        trailing: const Text('编辑'),
                        onTap: () => _openEdit(row),
                      ),
                    );
                  },
                ),
    );
  }
}

String _md(DateTime day) =>
    '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

String _hhmm(DateTime ts) =>
    '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
