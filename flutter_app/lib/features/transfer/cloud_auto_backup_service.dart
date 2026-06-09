import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_account_resolver.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/cloud_backup_service.dart';

typedef CloudAutoBackupNowProvider = DateTime Function();

class CloudAutoBackupService {
  const CloudAutoBackupService({
    required this.database,
    BackupService? backupService,
    CloudBackupService? cloudBackupService,
    AttendanceAccountResolver? attendanceAccountResolver,
    Future<Directory> Function()? documentsDirectoryProvider,
    CloudAutoBackupNowProvider? nowProvider,
  })  : _backupService = backupService,
        _cloudBackupService = cloudBackupService,
        _attendanceAccountResolver = attendanceAccountResolver,
        _documentsDirectoryProvider = documentsDirectoryProvider,
        _nowProvider = nowProvider;

  final AppDatabase database;
  final BackupService? _backupService;
  final CloudBackupService? _cloudBackupService;
  final AttendanceAccountResolver? _attendanceAccountResolver;
  final Future<Directory> Function()? _documentsDirectoryProvider;
  final CloudAutoBackupNowProvider? _nowProvider;

  static const _settingsFileName = 'cloud_auto_backup_state.json';

  Future<CloudAutoBackupResult> runIfDue() async {
    final now = (_nowProvider ?? DateTime.now)();
    if (now.hour != 0) {
      return const CloudAutoBackupResult.skipped('not_midnight_hour');
    }

    final dayKey = _dayKey(now);
    final state = await _readState();
    if (state.lastBusinessRunDay == dayKey &&
        state.lastAttendanceRunDay == dayKey) {
      return const CloudAutoBackupResult.skipped('already_ran_today');
    }

    final cloudService = _cloudBackupService ??
        CloudBackupService(api: SupabaseCloudBackupApi());
    final session = await cloudService.loadSavedSession();
    if (session == null) {
      return const CloudAutoBackupResult.skipped('no_cloud_session');
    }

    var businessUploaded = false;
    var attendanceUploaded = false;
    final errors = <String>[];

    if (session.canUpload && state.lastBusinessRunDay != dayKey) {
      try {
        final backupService = _backupService ??
            BackupService(
              databaseFileName: 'jiemei.sqlite',
              nowProvider: _nowProvider,
            );
        final package = await backupService.createSharePackage();
        await cloudService.uploadPackage(
          session: session,
          packageFile: File(package.filePath),
        );
        businessUploaded = true;
      } catch (error) {
        errors.add('business: $error');
      }
    }

    if (state.lastAttendanceRunDay != dayKey) {
      try {
        final accountKey = await (_attendanceAccountResolver ??
                const AttendanceAccountResolver())
            .resolve();
        final dao = AttendanceDao(database, accountKey: accountKey);
        final jsonText = await dao.exportAttendanceJson();
        await cloudService.uploadAttendanceBackup(
          session: session,
          accountKey: accountKey,
          jsonText: jsonText,
        );
        attendanceUploaded = true;
      } catch (error) {
        errors.add('attendance: $error');
      }
    }

    if (businessUploaded || attendanceUploaded) {
      await _writeState(
        _CloudAutoBackupState(
          lastBusinessRunDay:
              businessUploaded ? dayKey : state.lastBusinessRunDay,
          lastAttendanceRunDay:
              attendanceUploaded ? dayKey : state.lastAttendanceRunDay,
        ),
      );
    }

    return CloudAutoBackupResult(
      ran: businessUploaded || attendanceUploaded,
      businessUploaded: businessUploaded,
      attendanceUploaded: attendanceUploaded,
      errors: errors,
    );
  }

  Future<_CloudAutoBackupState> _readState() async {
    final file = await _settingsFile();
    if (!await file.exists()) {
      return const _CloudAutoBackupState();
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return _CloudAutoBackupState(
          lastBusinessRunDay: decoded['lastBusinessRunDay']?.toString() ??
              decoded['lastRunDay']?.toString(),
          lastAttendanceRunDay: decoded['lastAttendanceRunDay']?.toString() ??
              decoded['lastRunDay']?.toString(),
        );
      }
    } catch (_) {}
    return const _CloudAutoBackupState();
  }

  Future<void> _writeState(_CloudAutoBackupState state) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'lastBusinessRunDay': state.lastBusinessRunDay,
      'lastAttendanceRunDay': state.lastAttendanceRunDay,
    }));
  }

  Future<File> _settingsFile() async {
    final docs = await (_documentsDirectoryProvider ??
        getApplicationDocumentsDirectory)();
    return File(p.join(docs.path, _settingsFileName));
  }

  static String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class CloudAutoBackupResult {
  const CloudAutoBackupResult({
    required this.ran,
    required this.businessUploaded,
    required this.attendanceUploaded,
    this.errors = const [],
  });

  const CloudAutoBackupResult.skipped(String reason)
      : ran = false,
        businessUploaded = false,
        attendanceUploaded = false,
        errors = const [];

  final bool ran;
  final bool businessUploaded;
  final bool attendanceUploaded;
  final List<String> errors;
}

class _CloudAutoBackupState {
  const _CloudAutoBackupState({
    this.lastBusinessRunDay,
    this.lastAttendanceRunDay,
  });

  final String? lastBusinessRunDay;
  final String? lastAttendanceRunDay;
}
