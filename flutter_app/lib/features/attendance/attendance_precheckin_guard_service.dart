import 'package:drift/drift.dart';
import 'package:qrscan_flutter/data/attendance_workday_policy.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

class AttendancePrecheckinGuardService {
  AttendancePrecheckinGuardService._();

  static final Set<String> _dialogTriggeredDays = <String>{};
  static final Set<String> _notificationTriggeredDays = <String>{};

  static Future<PrecheckinDecision> evaluate({
    required AppDatabase database,
    String accountKey = 'local',
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final dao = AttendanceDao(database, accountKey: accountKey);
    final rule = await dao.getRule();
    final day = DateTime(ts.year, ts.month, ts.day);
    final dayKey = '${day.year}-${day.month}-${day.day}';

    if (isAttendanceDefinitelyRestDay(day, rule.weekendType)) {
      return PrecheckinDecision.none(dayKey);
    }

    final today = await (database.select(database.attendanceRecords)
          ..where(
            (t) => t.accountKey.equals(dao.accountKey) & t.day.equals(day),
          ))
        .getSingleOrNull();
    if (today?.checkInAt != null) {
      return PrecheckinDecision.none(dayKey);
    }

    final workStart = _mergeDayTime(day, rule.workStartTime);
    final remindFrom = workStart.subtract(const Duration(minutes: 3));
    final remindTo = workStart.add(const Duration(minutes: 3));
    final inWindow = !ts.isBefore(remindFrom) && !ts.isAfter(remindTo);
    if (!inWindow) {
      return PrecheckinDecision.none(dayKey);
    }

    DebugEventLog.add(
      'PRECHECKIN',
      'inWindow day=$dayKey now=$ts workStart=${rule.workStartTime} checkIn=null',
    );
    return PrecheckinDecision.remind(dayKey);
  }

  static bool shouldShowDialog(String dayKey) {
    if (_dialogTriggeredDays.contains(dayKey)) return false;
    _dialogTriggeredDays.add(dayKey);
    return true;
  }

  static bool shouldSendNotification(String dayKey) {
    if (_notificationTriggeredDays.contains(dayKey)) return false;
    _notificationTriggeredDays.add(dayKey);
    return true;
  }

  static DateTime _mergeDayTime(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}

class PrecheckinDecision {
  const PrecheckinDecision({
    required this.dayKey,
    required this.shouldRemind,
  });

  factory PrecheckinDecision.none(String dayKey) =>
      PrecheckinDecision(dayKey: dayKey, shouldRemind: false);
  factory PrecheckinDecision.remind(String dayKey) =>
      PrecheckinDecision(dayKey: dayKey, shouldRemind: true);

  final String dayKey;
  final bool shouldRemind;
}
