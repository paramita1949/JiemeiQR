import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_account_resolver.dart';
import 'package:qrscan_flutter/features/attendance/attendance_geofence_reminder_service.dart';
import 'package:qrscan_flutter/features/attendance/attendance_record_edit_screen.dart';
import 'package:qrscan_flutter/features/attendance/attendance_rule_screen.dart';
import 'package:qrscan_flutter/features/attendance/attendance_stats_screen.dart';

enum _StatusFilter { all, late, absent, holiday }

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.database,
    this.initialImportPath,
  });

  final AppDatabase database;
  final String? initialImportPath;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late AttendanceDao _dao;
  String _accountKey = AttendanceAccountResolver.localAccountKey;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  MonthAttendanceStats? _stats;
  List<AttendanceRecord> _rows = const [];
  bool _loading = true;
  _StatusFilter _filter = _StatusFilter.all;
  DateTime _lastRefreshDay = DateTime.now();
  bool _crossDayRefreshQueued = false;

  @override
  void initState() {
    super.initState();
    _dao = AttendanceDao(widget.database, accountKey: _accountKey);
    unawaited(_loadAccountAndStart());
  }

  Future<void> _loadAccountAndStart() async {
    final accountKey = await const AttendanceAccountResolver().resolve();
    if (!mounted) return;
    _accountKey = accountKey;
    _dao = AttendanceDao(widget.database, accountKey: accountKey);
    await _dao.adoptLegacyLocalDataIfAccountEmpty();
    await _reload();
    unawaited(_runForegroundAutoCheckIn());
    unawaited(_consumeInitialImport());
  }

  Future<void> _runForegroundAutoCheckIn() async {
    try {
      await AttendanceGeofenceReminderService.checkAndMaybeNotify(
        database: widget.database,
        accountKey: _accountKey,
      );
      await _reload();
    } catch (_) {
      // Location failures must not block normal manual attendance.
    }
  }

  Future<void> _consumeInitialImport() async {
    final path = widget.initialImportPath;
    if (path == null || path.isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    try {
      await _dao.importAttendanceFromFilePath(path, overwrite: true);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('签到备份已恢复')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _reload() async {
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    setState(() => _loading = true);
    final stats = await _dao.monthStats(_month);
    final rows = await _dao.recordsByMonth(_month);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _rows = rows;
      _loading = false;
      _lastRefreshDay = now;
    });
  }

  Future<void> _checkIn() async {
    await _dao.checkInOrOut();
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('签到已记录')),
    );
  }

  Future<void> _openRules() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceRuleScreen(
          database: widget.database,
          accountKey: _accountKey,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openStats() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceStatsScreen(
          database: widget.database,
          initialMonth: _month,
          accountKey: _accountKey,
        ),
      ),
    );
    await _reload();
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

  List<AttendanceRecord> get _filteredRows {
    switch (_filter) {
      case _StatusFilter.all:
        return _rows;
      case _StatusFilter.late:
        return _rows.where((r) => r.isLate).toList();
      case _StatusFilter.absent:
        return _rows.where((r) => r.isAbsent).toList();
      case _StatusFilter.holiday:
        return _rows.where((r) => r.isHoliday).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final monthLabel = '${_month.month}月';
    final now = DateTime.now();
    final today = now;
    final crossDay = now.year != _lastRefreshDay.year ||
        now.month != _lastRefreshDay.month ||
        now.day != _lastRefreshDay.day;
    if (crossDay && !_crossDayRefreshQueued) {
      _crossDayRefreshQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _reload();
        _crossDayRefreshQueued = false;
      });
    }
    final todayRow = _findTodayRow(_rows, today);
    final todayCompleted = !crossDay &&
        todayRow?.checkInAt != null &&
        todayRow?.checkOutAt != null;
    final heroStatus = crossDay ? '未签到' : _heroStatusText(_rows);
    final heroAction = crossDay ? '上班签到' : _heroActionText(_rows);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '签到',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Row(
                    children: [
                      _HeaderIconButton(
                        icon: Icons.tune_rounded,
                        label: '规则',
                        onPressed: _openRules,
                      ),
                      const SizedBox(width: 8),
                      _HeaderIconButton(
                        icon: Icons.bar_chart_rounded,
                        label: '统计',
                        onPressed: _openStats,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _HeroCheckInCard(
                nowText: _hhmm(DateTime.now()),
                statusText: heroStatus,
                actionText: heroAction,
                onCheckIn: todayCompleted ? null : _checkIn,
              ),
              const SizedBox(height: 10),
              _MonthSummaryCard(
                monthLabel: monthLabel,
                stats: stats,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D0F172A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '签到明细',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          monthLabel,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _filterChip('全部', _StatusFilter.all),
                        _filterChip('迟到', _StatusFilter.late),
                        _filterChip('请假', _StatusFilter.absent),
                        _filterChip('假期', _StatusFilter.holiday),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_filteredRows.isEmpty)
                      const _EmptyState(text: '暂无记录')
                    else
                      ..._filteredRows.map(
                        (r) => _DetailCard(
                          row: r,
                          onTap: () => _openEdit(r),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String text, _StatusFilter filter) {
    final selected = _filter == filter;
    Color bg;
    Color fg;
    if (selected) {
      bg = const Color(0xFF1D4ED8);
      fg = Colors.white;
    } else {
      switch (filter) {
        case _StatusFilter.late:
          bg = const Color(0xFFEDE9FE);
          fg = const Color(0xFF4338CA);
          break;
        case _StatusFilter.absent:
          bg = const Color(0xFFFEF3C7);
          fg = const Color(0xFF92400E);
          break;
        case _StatusFilter.holiday:
          bg = const Color(0xFFE0ECFF);
          fg = const Color(0xFF1D4ED8);
          break;
        case _StatusFilter.all:
          bg = const Color(0xFFE2E8F0);
          fg = const Color(0xFF334155);
          break;
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
      ),
    );
  }

  String _heroStatusText(List<AttendanceRecord> rows) {
    final today = DateTime.now();
    final todayRow = _findTodayRow(rows, today);
    if (todayRow == null || todayRow.checkInAt == null) return '未签到';
    if (todayRow.checkOutAt == null) return '上班已签到';
    return '下班已签到';
  }

  String _heroActionText(List<AttendanceRecord> rows) {
    final today = DateTime.now();
    final todayRow = _findTodayRow(rows, today);
    if (todayRow == null || todayRow.checkInAt == null) return '上班签到';
    if (todayRow.checkOutAt == null) return '下班签到';
    return '今日已完成';
  }

  AttendanceRecord? _findTodayRow(List<AttendanceRecord> rows, DateTime today) {
    for (final row in rows) {
      if (row.day.year == today.year &&
          row.day.month == today.month &&
          row.day.day == today.day) {
        return row;
      }
    }
    return null;
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1F63F2),
          side: const BorderSide(color: Color(0xFFC7D8FF)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(68, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _HeroCheckInCard extends StatelessWidget {
  const _HeroCheckInCard({
    required this.nowText,
    required this.statusText,
    required this.actionText,
    required this.onCheckIn,
  });

  final String nowText;
  final String statusText;
  final String actionText;
  final Future<void> Function()? onCheckIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                nowText,
                style: const TextStyle(
                  color: Color(0xFFE0F2FE),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2A4FD0),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: onCheckIn,
              child: Text(actionText,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.monthLabel,
    required this.stats,
  });

  final String monthLabel;
  final MonthAttendanceStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _SummaryMetric(
            label: monthLabel,
            value: s == null ? '--' : '${s.presentDays}天',
            color: const Color(0xFF1D4ED8),
          ),
          _SummaryMetric(
            label: '迟到',
            value: s == null ? '--' : '${s.lateCount}',
            color: const Color(0xFF7C3AED),
          ),
          _SummaryMetric(
            label: '加班',
            value: s == null ? '--' : '${s.overtimeHours.toStringAsFixed(1)}h',
            color: const Color(0xFF0F766E),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.row,
    required this.onTap,
  });

  final AttendanceRecord row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _status(row);
    final isLate = status == '迟到';
    final isAbsent = status == '请假';
    final isHoliday = row.isHoliday;
    final isPending = status == '未完成' || status == '待下班';
    final bg = isAbsent
        ? const Color(0xFFFEF2F2)
        : isHoliday
            ? const Color(0xFFEFF6FF)
            : isLate
                ? const Color(0xFFFFF7ED)
                : const Color(0xFFF8FAFC);
    final fg = isAbsent
        ? const Color(0xFF991B1B)
        : isHoliday
            ? const Color(0xFF1D4ED8)
            : isLate
                ? const Color(0xFF9A3412)
                : const Color(0xFF334155);
    final overtimeText = row.overtimeHoursRounded > 0
        ? '+${row.overtimeHoursRounded.toStringAsFixed(1)}h'
        : '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_md(row.day)}  ${_timeRange(row)}',
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            if (overtimeText.isNotEmpty)
              Text(overtimeText,
                  style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            if (overtimeText.isEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isAbsent
                      ? const Color(0xFFDC2626)
                      : isLate
                          ? const Color(0xFFF59E0B)
                          : isPending
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(status,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }

  String _status(AttendanceRecord r) {
    final now = DateTime.now();
    final isToday = r.day.year == now.year &&
        r.day.month == now.month &&
        r.day.day == now.day;
    final hasCheckIn = r.checkInAt != null;
    final hasCheckOut = r.checkOutAt != null;
    if (r.isLeave) return '请假';
    if (r.isAbsent) return '请假';
    if (r.isLate) return '迟到';
    if (isToday && hasCheckIn && !hasCheckOut) return '待下班';
    if (hasCheckIn ^ hasCheckOut) return '未完成';
    if (hasCheckIn && hasCheckOut && r.checkOutAt!.isBefore(r.checkInAt!)) {
      return '异常';
    }
    if (hasCheckIn && hasCheckOut) return '正常';
    if (r.isException) return '异常';
    return '无记录';
  }

  String _timeRange(AttendanceRecord r) {
    final a = r.checkInAt == null ? '--:--' : _hhmm(r.checkInAt!);
    final b = r.checkOutAt == null ? '--:--' : _hhmm(r.checkOutAt!);
    return '$a / $b';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
          child: Text(text, style: const TextStyle(color: Color(0xFF64748B)))),
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
