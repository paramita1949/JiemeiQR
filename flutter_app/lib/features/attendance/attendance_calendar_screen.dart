import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_record_edit_screen.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({
    super.key,
    required this.database,
    required this.initialMonth,
  });

  final AppDatabase database;
  final DateTime initialMonth;

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  late final AttendanceDao _dao;
  late DateTime _month;
  late int _selectedDay;
  Set<int> _recordedDays = <int>{};
  Set<int> _lateDays = <int>{};
  Set<int> _absentDays = <int>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _dao = AttendanceDao(widget.database);
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
    final now = DateTime.now();
    _selectedDay =
        (now.year == _month.year && now.month == _month.month) ? now.day : 1;
    unawaited(_reloadMonth());
  }

  Future<void> _reloadMonth() async {
    setState(() => _loading = true);
    final rows = await _dao.recordsByMonth(_month);
    final days = rows
        .where((r) => r.checkInAt != null || r.checkOutAt != null)
        .map((r) => r.day.day)
        .toSet();
    final lateDays = rows.where((r) => r.isLate).map((r) => r.day.day).toSet();
    final absentDays =
        rows.where((r) => r.isAbsent).map((r) => r.day.day).toSet();
    if (!mounted) return;
    setState(() {
      _recordedDays = days;
      _lateDays = lateDays;
      _absentDays = absentDays;
      _loading = false;
    });
  }

  Future<void> _openDay(DateTime day) async {
    final row = await _dao.getOrCreateRecordByDay(day);
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AttendanceRecordEditScreen(dao: _dao, record: row),
      ),
    );
    if (changed == true) {
      await _reloadMonth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final yearMonth = '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final today = DateTime.now();
    const weekTitles = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final selectedDay = _selectedDay > daysInMonth ? daysInMonth : _selectedDay;
    final selectedDate = DateTime(_month.year, _month.month, selectedDay);
    final selectedWeek = weekTitles[selectedDate.weekday - 1];
    final cells = <Widget>[];

    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final hasRecord = _recordedDays.contains(day);
      final isLate = _lateDays.contains(day);
      final isAbsent = _absentDays.contains(day);
      final date = DateTime(_month.year, _month.month, day);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      cells.add(
        InkWell(
          onTap: () {
            setState(() => _selectedDay = day);
            _openDay(date);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: day == selectedDay
                  ? const Color(0xFF1D4ED8)
                  : (hasRecord ? const Color(0xFFEFF6FF) : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: day == selectedDay
                    ? const Color(0xFF1D4ED8)
                    : (isToday
                        ? const Color(0xFF60A5FA)
                        : (hasRecord
                            ? const Color(0xFFBFDBFE)
                            : const Color(0xFFE2E8F0))),
              ),
            ),
            child: Stack(
              children: [
                if (isLate || isAbsent)
                  Positioned(
                    left: 6,
                    right: 6,
                    top: 6,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isAbsent
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: day == selectedDay
                          ? Colors.white
                          : (hasRecord
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF334155)),
                    ),
                  ),
                ),
                if (hasRecord)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: day == selectedDay ? Colors.white : const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          setState(() {
                            _month = DateTime(_month.year, _month.month - 1, 1);
                            _selectedDay = 1;
                          });
                          await _reloadMonth();
                        },
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF334155)),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            yearMonth,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          setState(() {
                            _month = DateTime(_month.year, _month.month + 1, 1);
                            _selectedDay = 1;
                          });
                          await _reloadMonth();
                        },
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${selectedDate.month}月${selectedDate.day}日  $selectedWeek',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '点日期可补录',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: weekTitles
                      .map(
                        (w) => Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: TextStyle(
                                color: w == '周六' || w == '周日'
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 7,
                    childAspectRatio: 0.95,
                    children: cells,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF2563EB)),
                    SizedBox(width: 6),
                    Text(
                      '有记录',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    SizedBox(width: 14),
                    Icon(Icons.remove, size: 12, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text(
                      '迟到',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    SizedBox(width: 14),
                    Icon(Icons.remove, size: 12, color: Color(0xFFDC2626)),
                    SizedBox(width: 4),
                    Text(
                      '请假',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
