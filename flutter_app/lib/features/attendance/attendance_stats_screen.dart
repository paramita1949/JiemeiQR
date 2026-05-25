import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_calendar_screen.dart';

class AttendanceStatsScreen extends StatefulWidget {
  const AttendanceStatsScreen({
    super.key,
    required this.database,
    required this.initialMonth,
  });

  final AppDatabase database;
  final DateTime initialMonth;

  @override
  State<AttendanceStatsScreen> createState() => _AttendanceStatsScreenState();
}

class _AttendanceStatsScreenState extends State<AttendanceStatsScreen> {
  late final AttendanceDao _dao;
  late DateTime _month;
  List<DateTime> _months = const [];
  AttendanceRule? _rule;
  MonthAttendanceStats? _stats;
  List<AttendanceRecord> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _dao = AttendanceDao(widget.database);
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final allMonths = await _dao.recordedMonths();
    var effectiveMonth = _month;
    if (allMonths.isNotEmpty && !_containsMonth(allMonths, _month)) {
      effectiveMonth = allMonths.last;
    }
    final rule = await _dao.getRule();
    final stats = await _dao.monthStats(effectiveMonth);
    final rows = await _dao.recordsByMonth(effectiveMonth);
    if (!mounted) return;
    setState(() {
      _months = allMonths;
      _month = effectiveMonth;
      _rule = rule;
      _stats = stats;
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthChips = _months.isEmpty
        ? [DateTime(_month.year, _month.month, 1)]
        : _months.reversed.toList();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '统计',
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AttendanceCalendarScreen(
                                database: widget.database,
                                initialMonth: _month,
                              ),
                            ),
                          );
                          await _reload();
                        },
                        child: const Text('日历'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('回签到'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < 80) return;
                  if (velocity < 0) {
                    _switchMonth(step: 1);
                  } else {
                    _switchMonth(step: -1);
                  }
                },
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: monthChips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => _monthChip(monthChips[index]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Overview(stats: _stats, month: _month),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniMetric(
                    '加班',
                    _stats == null
                        ? '--'
                        : '${_stats!.overtimeHours.toStringAsFixed(1)}h',
                  ),
                  const SizedBox(width: 8),
                  _miniMetric(
                    '请假时长',
                    _stats == null
                        ? '--'
                        : _leaveDuration(_stats!.leaveMinutes),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TableCard(
                title: '上下班明细',
                headers: const ['日期', '上班/下班', '状态'],
                rows: _rows.map((r) {
                  final hasBoth = r.checkInAt != null && r.checkOutAt != null;
                  final status = (!_isWorkdayByRule(r.day) && hasBoth)
                      ? '休息日'
                      : r.isHoliday
                          ? '假期'
                          : r.isLeave
                              ? '请假'
                              : r.isAbsent
                                  ? '请假'
                                  : r.isLate
                                      ? '迟到'
                                      : ((r.checkInAt != null) ^
                                              (r.checkOutAt != null))
                                          ? '未完成'
                                          : (r.checkInAt != null &&
                                                  r.checkOutAt != null
                                              ? '正常'
                                              : '无记录');
                  return [
                    _md(r.day),
                    '${r.checkInAt == null ? '--:--' : _hhmm(r.checkInAt!)} / ${r.checkOutAt == null ? '--:--' : _hhmm(r.checkOutAt!)}',
                    status,
                  ];
                }).toList(),
                loading: _loading,
              ),
              const SizedBox(height: 12),
              _TableCard(
                title: '加班明细',
                headers: const ['日期', '时间段', '小时'],
                rows: _rows
                    .where((r) => r.overtimeHoursRounded > 0)
                    .map((r) => [
                          _md(r.day),
                          (!_isWorkdayByRule(r.day) || r.isHoliday)
                              ? '${r.checkInAt == null ? '--:--' : _hhmm(r.checkInAt!)}-${r.checkOutAt == null ? '--:--' : _hhmm(r.checkOutAt!)}'
                              : '17:00-${r.checkOutAt == null ? '--:--' : _hhmm(r.checkOutAt!)}',
                          r.overtimeHoursRounded.toStringAsFixed(1),
                        ])
                    .toList(),
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthChip(DateTime month) {
    final selected = month.year == _month.year && month.month == _month.month;
    return InkWell(
      onTap: () {
        setState(() => _month = month);
        unawaited(_reload());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${month.year}-${month.month.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _miniMetric(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 28)),
          ],
        ),
      ),
    );
  }

  String _leaveDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m分钟';
    if (m == 0) return '$h小时';
    return '$h小时$m分';
  }

  bool _containsMonth(List<DateTime> months, DateTime month) {
    for (final m in months) {
      if (m.year == month.year && m.month == month.month) return true;
    }
    return false;
  }

  void _switchMonth({required int step}) {
    if (_months.isEmpty) return;
    final asc = _months;
    final current =
        asc.indexWhere((m) => m.year == _month.year && m.month == _month.month);
    if (current < 0) return;
    final next = (current + step).clamp(0, asc.length - 1);
    if (next == current) return;
    setState(() => _month = asc[next]);
    unawaited(_reload());
  }

  bool _isWorkdayByRule(DateTime day) {
    final weekendType = _rule?.weekendType ?? 'double';
    if (weekendType == 'single') {
      return day.weekday != DateTime.sunday;
    }
    return day.weekday != DateTime.saturday && day.weekday != DateTime.sunday;
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.stats,
    required this.month,
  });

  final MonthAttendanceStats? stats;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B153A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${month.month}月概览',
              style: const TextStyle(
                  color: Color(0xFF93C5FD), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            s == null
                ? '--'
                : '出勤${s.presentDays}  请假${s.leaveDays}  迟到${s.lateCount}',
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.title,
    required this.headers,
    required this.rows,
    required this.loading,
  });

  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: headers
                  .map((h) => Expanded(
                        child: Text(h,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155))),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('暂无数据')),
            )
          else
            ...rows.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: r
                      .map(
                        (c) => Expanded(
                          child: Text(
                            c,
                            style: TextStyle(
                              fontWeight: c == '正常' ||
                                      c == '迟到' ||
                                      c == '请假' ||
                                      c == '假期'
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: c == '正常'
                                  ? const Color(0xFF16A34A)
                                  : c == '迟到'
                                      ? const Color(0xFFD97706)
                                      : c == '请假'
                                          ? const Color(0xFFDC2626)
                                          : c == '假期'
                                              ? const Color(0xFF1D4ED8)
                                              : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _md(DateTime day) =>
    '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')} ${_weekLabel(day)}';

String _weekLabel(DateTime day) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return names[day.weekday - 1];
}

String _hhmm(DateTime ts) =>
    '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
