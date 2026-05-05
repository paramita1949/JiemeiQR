import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qrscan_flutter/data/app_database.dart';

class AttendanceDao {
  AttendanceDao(this._db);

  final AppDatabase _db;

  Future<AttendanceRule> getRule() async {
    final existing = await (_db.select(
      _db.attendanceRules,
    )..limit(1)).getSingleOrNull();
    if (existing != null) return existing;
    await _db
        .into(_db.attendanceRules)
        .insert(const AttendanceRulesCompanion());
    return (_db.select(_db.attendanceRules)..limit(1)).getSingle();
  }

  Future<void> saveRule(AttendanceRulesCompanion companion) async {
    final rule = await getRule();
    await (_db.update(_db.attendanceRules)..where((t) => t.id.equals(rule.id)))
        .write(
          companion.copyWith(updatedAt: Value(DateTime.now())),
        );
  }

  Future<void> checkInOrOut({DateTime? now}) async {
    final ts = now ?? DateTime.now();
    final day = DateTime(ts.year, ts.month, ts.day);
    final existing = await (_db.select(_db.attendanceRecords)
          ..where((t) => t.day.equals(day)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.attendanceRecords).insert(
            AttendanceRecordsCompanion.insert(
              day: day,
              checkInAt: Value(ts),
              updatedAt: Value(ts),
            ),
          );
      return;
    }
    if (existing.checkOutAt != null) return;

    final rule = await getRule();
    final end = _mergeDayTime(day, rule.workEndTime);
    final rawMinutes = ts.isAfter(end) ? ts.difference(end).inMinutes : 0;
    final roundedHours = (rawMinutes ~/ rule.overtimeRoundingMinutes) * 0.5;

    final updated = existing.copyWith(
      checkOutAt: Value(ts),
      overtimeMinutesRaw: rawMinutes,
      overtimeHoursRounded: roundedHours,
      isLate: existing.checkInAt != null &&
          existing.checkInAt!.isAfter(
            _mergeDayTime(day, rule.workStartTime).add(
              Duration(minutes: rule.lateGraceMinutes),
            ),
          ),
      isEarlyLeave: ts.isBefore(end),
      updatedAt: ts,
    );
    await _saveNormalizedRecord(updated, rule: rule);
  }

  Future<GeofenceDecision> handleGeofenceTransition({
    required bool isInsideNow,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final day = DateTime(ts.year, ts.month, ts.day);
    final rule = await getRule();
    if (!rule.geofenceEnabled) {
      return const GeofenceDecision(triggered: false, reason: '围栏未启用');
    }

    final daily = await (_db.select(_db.geofenceDailyStates)
          ..where((t) => t.day.equals(day)))
        .getSingleOrNull();
    final wasInside = daily?.wasInside ?? false;
    final hasTriggered = daily?.triggered ?? false;

    final todayRecord = await (_db.select(_db.attendanceRecords)
          ..where((t) => t.day.equals(day)))
        .getSingleOrNull();
    final alreadyCheckedIn = todayRecord?.checkInAt != null;

    final enteredFence = !wasInside && isInsideNow;
    final shouldTrigger =
        enteredFence && !hasTriggered && !alreadyCheckedIn && rule.checkinReminderEnabled;

    if (daily == null) {
      await _db.into(_db.geofenceDailyStates).insert(
            GeofenceDailyStatesCompanion.insert(
              day: day,
              wasInside: Value(isInsideNow),
              triggered: Value(shouldTrigger),
              triggeredCount: Value(shouldTrigger ? 1 : 0),
              lastTriggeredAt: Value(shouldTrigger ? ts : null),
              updatedAt: Value(ts),
            ),
          );
    } else {
      await (_db.update(_db.geofenceDailyStates)..where((t) => t.id.equals(daily.id)))
          .write(
        GeofenceDailyStatesCompanion(
          wasInside: Value(isInsideNow),
          triggered: Value(hasTriggered || shouldTrigger),
          triggeredCount: Value(
            daily.triggeredCount + (shouldTrigger ? 1 : 0),
          ),
          lastTriggeredAt: Value(
            shouldTrigger ? ts : daily.lastTriggeredAt,
          ),
          updatedAt: Value(ts),
        ),
      );
    }

    if (!enteredFence) {
      return const GeofenceDecision(triggered: false, reason: '未发生进围栏事件');
    }
    if (alreadyCheckedIn) {
      return const GeofenceDecision(triggered: false, reason: '今日已签到');
    }
    if (hasTriggered) {
      return const GeofenceDecision(triggered: false, reason: '今日已触发过提醒');
    }
    if (!rule.checkinReminderEnabled) {
      return const GeofenceDecision(triggered: false, reason: '上班提醒未启用');
    }
    return const GeofenceDecision(triggered: true, reason: '进入围栏，触发签到提醒');
  }

  Future<GeofenceDailyState?> getTodayGeofenceState({DateTime? now}) async {
    final ts = now ?? DateTime.now();
    final day = DateTime(ts.year, ts.month, ts.day);
    return (_db.select(_db.geofenceDailyStates)..where((t) => t.day.equals(day)))
        .getSingleOrNull();
  }

  Future<List<AttendanceRecord>> recordsByMonth(DateTime month) async {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 1);
    final rows = await (_db.select(_db.attendanceRecords)
          ..where((t) => t.day.isBiggerOrEqualValue(from) & t.day.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.day)]))
        .get();
    return _applyWeekendOvertime(rows);
  }

  List<AttendanceRecord> _applyWeekendOvertime(List<AttendanceRecord> rows) {
    if (rows.isEmpty) return rows;
    final byDay = <String, AttendanceRecord>{};
    for (final row in rows) {
      byDay[_dayKey(row.day)] = row;
    }

    final result = <AttendanceRecord>[];
    for (final row in rows) {
      final normalized = DateTime(row.day.year, row.day.month, row.day.day);
      if (normalized.weekday != DateTime.sunday ||
          row.checkInAt == null ||
          row.checkOutAt == null) {
        result.add(row);
        continue;
      }
      final sat = normalized.subtract(const Duration(days: 1));
      final satRow = byDay[_dayKey(sat)];
      final bothWeekendWorked = satRow != null &&
          satRow.checkInAt != null &&
          satRow.checkOutAt != null;
      if (!bothWeekendWorked) {
        result.add(row);
        continue;
      }

      final workedMinutes = row.checkOutAt!.isAfter(row.checkInAt!)
          ? row.checkOutAt!.difference(row.checkInAt!).inMinutes
          : 0;
      final weekendOvertimeHours = (workedMinutes ~/ 30) * 0.5;
      if (weekendOvertimeHours <= row.overtimeHoursRounded) {
        result.add(row);
        continue;
      }

      result.add(
        row.copyWith(
          overtimeMinutesRaw: workedMinutes,
          overtimeHoursRounded: weekendOvertimeHours,
        ),
      );
    }
    return result;
  }

  String _dayKey(DateTime day) => '${day.year}-${day.month}-${day.day}';

  Future<List<DateTime>> recordedMonths() async {
    final rows = await _db.select(_db.attendanceRecords).get();
    final keys = <String, DateTime>{};
    for (final row in rows) {
      final month = DateTime(row.day.year, row.day.month, 1);
      keys['${month.year}-${month.month}'] = month;
    }
    final months = keys.values.toList()..sort((a, b) => a.compareTo(b));
    return months;
  }

  Future<MonthAttendanceStats> monthStats(DateTime month) async {
    final rule = await getRule();
    final rows = await recordsByMonth(month);
    final totalWorkdays = _countWorkdaysInMonth(month, rule.weekendType);
    var present = 0;
    var late = 0;
    var absent = 0;
    var leave = 0;
    var pendingPatch = 0;
    var patched = 0;
    var overtime = 0.0;
    var leaveMinutes = 0;
    for (final row in rows) {
      if (row.checkInAt != null || row.checkOutAt != null) present += 1;
      if (row.isLate) late += 1;
      if (row.isAbsent) absent += 1;
      if (row.isLeave) leave += 1;
      if (row.needsPatch) pendingPatch += 1;
      if (row.patched) patched += 1;
      overtime += row.overtimeHoursRounded;
      leaveMinutes += row.leaveMinutes;
    }
    final hasRecords = rows.isNotEmpty;
    final fullAttendance = hasRecords && absent == 0 && leave == 0 && late == 0 && pendingPatch == 0;
    return MonthAttendanceStats(
      presentDays: present,
      lateCount: late,
      absentDays: absent,
      leaveDays: leave,
      pendingPatchCount: pendingPatch,
      patchedCount: patched,
      overtimeHours: overtime,
      leaveMinutes: leaveMinutes,
      fullAttendance: fullAttendance,
      hasRecords: hasRecords,
      workdayCount: totalWorkdays,
    );
  }

  Future<String> exportAttendanceJson() async {
    final rules = await _db.select(_db.attendanceRules).get();
    final records = await _db.select(_db.attendanceRecords).get();
    final requests = await _db.select(_db.patchRequests).get();
    return jsonEncode({
      'type': 'attendance-backup',
      'version': 2,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'rules': rules.map((e) => e.toJson()).toList(),
      'records': records.map((e) => e.toJson()).toList(),
      'patchRequests': requests.map((e) => e.toJson()).toList(),
    });
  }

  Future<AttendanceBackupSnapshot> createAttendanceBackup() async {
    final json = await exportAttendanceJson();
    final dir = await _attendanceBackupDir();
    final stamp = _fileStamp(DateTime.now());
    final file = File(p.join(dir.path, 'attendance-backup-$stamp.attendance.json'));
    await file.writeAsString(json);
    return AttendanceBackupSnapshot(
      fileName: p.basename(file.path),
      filePath: file.path,
      createdAt: await file.lastModified(),
      sizeBytes: await file.length(),
    );
  }

  Future<List<AttendanceBackupSnapshot>> listAttendanceBackups() async {
    final dir = await _attendanceBackupDir();
    final files = await dir
        .list()
        .where((e) => e is File)
        .cast<File>()
        .where((f) => f.path.toLowerCase().endsWith('.attendance.json'))
        .toList();
    final snapshots = <AttendanceBackupSnapshot>[];
    for (final file in files) {
      snapshots.add(
        AttendanceBackupSnapshot(
          fileName: p.basename(file.path),
          filePath: file.path,
          createdAt: await file.lastModified(),
          sizeBytes: await file.length(),
        ),
      );
    }
    snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return snapshots;
  }

  Future<void> deleteAttendanceBackup(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> importAttendanceFromFilePath(
    String path, {
    required bool overwrite,
  }) async {
    final text = await File(path).readAsString();
    await importAttendanceJson(text, overwrite: overwrite);
  }

  Future<void> updateRecordManual({
    required int recordId,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    bool? isAbsent,
    bool? isLeave,
    bool? isHoliday,
    String? note,
  }) async {
    final row = await (_db.select(_db.attendanceRecords)
          ..where((t) => t.id.equals(recordId)))
        .getSingle();
    final rule = await getRule();
    final updated = row.copyWith(
      checkInAt: Value(checkInAt),
      checkOutAt: Value(checkOutAt),
      isAbsent: isHoliday == true ? false : (isAbsent ?? row.isAbsent),
      isLeave: isHoliday == true ? false : (isLeave ?? row.isLeave),
      isHoliday: isHoliday ?? row.isHoliday,
      note: Value(note ?? row.note),
      updatedAt: DateTime.now(),
    );
    await _saveNormalizedRecord(updated, rule: rule);
  }

  Future<void> deleteRecordById(int recordId) async {
    await (_db.delete(_db.attendanceRecords)..where((t) => t.id.equals(recordId))).go();
  }

  Future<AttendanceRecord> getOrCreateRecordByDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    final existing = await (_db.select(_db.attendanceRecords)
          ..where((t) => t.day.equals(normalized)))
        .getSingleOrNull();
    if (existing != null) return existing;
    final id = await _db.into(_db.attendanceRecords).insert(
          AttendanceRecordsCompanion.insert(day: normalized),
        );
    return (_db.select(_db.attendanceRecords)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> importAttendanceJson(
    String jsonText, {
    required bool overwrite,
  }) async {
    final map = jsonDecode(jsonText) as Map<String, dynamic>;
    final type = map['type'] as String?;
    if (type != 'attendance-backup') {
      throw const FormatException('不是考勤备份文件');
    }
    final rules = (map['rules'] as List<dynamic>? ?? const []);
    final records = (map['records'] as List<dynamic>? ?? const []);
    final requests = (map['patchRequests'] as List<dynamic>? ?? const []);

    await _db.transaction(() async {
      if (overwrite) {
        await _db.delete(_db.patchRequests).go();
        await _db.delete(_db.attendanceRecords).go();
        await _db.delete(_db.attendanceRules).go();
      }

      for (final raw in rules) {
        final row = AttendanceRule.fromJson(raw as Map<String, dynamic>);
        if (overwrite) {
          await _db.into(_db.attendanceRules).insert(
                AttendanceRulesCompanion.insert(
                  workStartTime: Value(row.workStartTime),
                  workEndTime: Value(row.workEndTime),
                  lateGraceMinutes: Value(row.lateGraceMinutes),
                  weekendType: Value(row.weekendType),
                  overtimeRoundingMinutes: Value(row.overtimeRoundingMinutes),
                  officeLat: Value(row.officeLat),
                  officeLng: Value(row.officeLng),
                  officeRadiusMeters: Value(row.officeRadiusMeters),
                  geofenceEnabled: Value(row.geofenceEnabled),
                  checkinReminderEnabled: Value(row.checkinReminderEnabled),
                  checkoutReminderEnabled: Value(row.checkoutReminderEnabled),
                  updatedAt: Value(row.updatedAt),
                ),
              );
        } else {
          final existing = await (_db.select(_db.attendanceRules)..limit(1))
              .getSingleOrNull();
          if (existing == null) {
            await _db.into(_db.attendanceRules).insert(
                  AttendanceRulesCompanion.insert(
                    workStartTime: Value(row.workStartTime),
                    workEndTime: Value(row.workEndTime),
                    lateGraceMinutes: Value(row.lateGraceMinutes),
                    weekendType: Value(row.weekendType),
                    overtimeRoundingMinutes: Value(row.overtimeRoundingMinutes),
                    officeLat: Value(row.officeLat),
                    officeLng: Value(row.officeLng),
                    officeRadiusMeters: Value(row.officeRadiusMeters),
                    geofenceEnabled: Value(row.geofenceEnabled),
                    checkinReminderEnabled: Value(row.checkinReminderEnabled),
                    checkoutReminderEnabled: Value(row.checkoutReminderEnabled),
                    updatedAt: Value(row.updatedAt),
                  ),
                );
          }
        }
      }

      for (final raw in records) {
        final rawMap = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        rawMap.putIfAbsent('isHoliday', () => false);
        final row = AttendanceRecord.fromJson(rawMap);
        final sameDay = await (_db.select(_db.attendanceRecords)
              ..where((t) => t.day.equals(row.day)))
            .getSingleOrNull();
        if (sameDay == null || overwrite) {
          await _db.into(_db.attendanceRecords).insert(
                AttendanceRecordsCompanion.insert(
                  day: row.day,
                  checkInAt: Value(row.checkInAt),
                  checkOutAt: Value(row.checkOutAt),
                  isWorkday: Value(row.isWorkday),
                  isLate: Value(row.isLate),
                  isEarlyLeave: Value(row.isEarlyLeave),
                  isAbsent: Value(row.isAbsent),
                  isLeave: Value(row.isLeave),
                  isHoliday: Value(row.isHoliday),
                  isException: Value(row.isException),
                  needsPatch: Value(row.needsPatch),
                  patched: Value(row.patched),
                  overtimeMinutesRaw: Value(row.overtimeMinutesRaw),
                  leaveMinutes: Value(row.leaveMinutes),
                  overtimeHoursRounded: Value(row.overtimeHoursRounded),
                  source: Value(row.source),
                  note: Value(row.note),
                  createdAt: Value(row.createdAt),
                  updatedAt: Value(row.updatedAt),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      }

      for (final raw in requests) {
        final row = PatchRequest.fromJson(raw as Map<String, dynamic>);
        await _db.into(_db.patchRequests).insert(
              PatchRequestsCompanion.insert(
                day: row.day,
                patchType: row.patchType,
                requestedCheckInAt: Value(row.requestedCheckInAt),
                requestedCheckOutAt: Value(row.requestedCheckOutAt),
                reason: Value(row.reason),
                status: Value(row.status),
                createdAt: Value(row.createdAt),
                reviewedAt: Value(row.reviewedAt),
              ),
              mode: overwrite ? InsertMode.insertOrReplace : InsertMode.insert,
            );
      }
    });
  }

  DateTime _mergeDayTime(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  Future<Directory> _attendanceBackupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'attendance_backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileStamp(DateTime ts) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${ts.year}${two(ts.month)}${two(ts.day)}-${two(ts.hour)}${two(ts.minute)}${two(ts.second)}';
  }

  int _countWorkdaysInMonth(DateTime month, String weekendType) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    var count = 0;
    for (var i = 0; i < daysInMonth; i++) {
      final day = first.add(Duration(days: i));
      if (_isWorkday(day, weekendType)) {
        count += 1;
      }
    }
    return count;
  }

  bool _isWorkday(DateTime day, String weekendType) {
    if (weekendType == 'single') {
      return day.weekday != DateTime.sunday;
    }
    return day.weekday != DateTime.saturday && day.weekday != DateTime.sunday;
  }

  Future<void> _saveNormalizedRecord(
    AttendanceRecord row, {
    required AttendanceRule rule,
  }) async {
    final day = DateTime(row.day.year, row.day.month, row.day.day);
    final workStartBase = _mergeDayTime(day, rule.workStartTime);
    final workStart = workStartBase.add(
      Duration(minutes: rule.lateGraceMinutes),
    );
    final workEnd = _mergeDayTime(day, rule.workEndTime);

    final checkIn = row.checkInAt;
    final checkOut = row.checkOutAt;
    final hasCheckIn = checkIn != null;
    final hasCheckOut = checkOut != null;
    final exception = (hasCheckIn ^ hasCheckOut) ||
        (checkIn != null && checkOut != null && checkOut.isBefore(checkIn));
    final needsPatch = exception || (row.isAbsent && !row.isLeave && !row.isHoliday);
    final patched = row.patched || (row.needsPatch && !needsPatch);
    final late = row.isLeave || row.isHoliday
        ? false
        : (checkIn != null ? checkIn.isAfter(workStart) : false);
    final early = row.isHoliday ? false : (checkOut != null ? checkOut.isBefore(workEnd) : false);
    final leaveMinutes = row.isLeave && !row.isHoliday && checkIn != null && checkIn.isAfter(workStartBase)
        ? checkIn.difference(workStartBase).inMinutes
        : 0;
    final rawMinutes = row.isHoliday
        ? checkIn != null && checkOut != null && checkOut.isAfter(checkIn)
            ? checkOut.difference(checkIn).inMinutes
            : 0
        : checkOut != null && checkOut.isAfter(workEnd)
            ? checkOut.difference(workEnd).inMinutes
            : 0;
    final roundedHours = (rawMinutes ~/ rule.overtimeRoundingMinutes) * 0.5;

    await (_db.update(_db.attendanceRecords)..where((t) => t.id.equals(row.id))).write(
      AttendanceRecordsCompanion(
        checkInAt: Value(checkIn),
        checkOutAt: Value(checkOut),
        isLate: Value(late),
        isEarlyLeave: Value(early),
        isException: Value(exception),
        needsPatch: Value(needsPatch),
        overtimeMinutesRaw: Value(rawMinutes),
        leaveMinutes: Value(leaveMinutes),
        overtimeHoursRounded: Value(roundedHours),
        isAbsent: Value(row.isHoliday ? false : row.isAbsent),
        isLeave: Value(row.isHoliday ? false : row.isLeave),
        isHoliday: Value(row.isHoliday),
        patched: Value(patched),
        note: Value(row.note),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

class MonthAttendanceStats {
  const MonthAttendanceStats({
    required this.presentDays,
    required this.lateCount,
    required this.absentDays,
    required this.leaveDays,
    required this.pendingPatchCount,
    required this.patchedCount,
    required this.overtimeHours,
    required this.leaveMinutes,
    required this.fullAttendance,
    required this.hasRecords,
    required this.workdayCount,
  });

  final int presentDays;
  final int lateCount;
  final int absentDays;
  final int leaveDays;
  final int pendingPatchCount;
  final int patchedCount;
  final double overtimeHours;
  final int leaveMinutes;
  final bool fullAttendance;
  final bool hasRecords;
  final int workdayCount;
}

class GeofenceDecision {
  const GeofenceDecision({
    required this.triggered,
    required this.reason,
  });

  final bool triggered;
  final String reason;
}

class AttendanceBackupSnapshot {
  const AttendanceBackupSnapshot({
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String fileName;
  final String filePath;
  final DateTime createdAt;
  final int sizeBytes;
}
