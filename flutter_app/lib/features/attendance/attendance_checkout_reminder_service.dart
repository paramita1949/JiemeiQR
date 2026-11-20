import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_account_resolver.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';
import 'package:timezone/timezone.dart' as tz;

const checkoutNotificationId = 20261120;
const checkoutActionId = 'attendance_checkout_now';
const checkoutNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'attendance_checkout_channel',
    '下班签到提醒',
    channelDescription: '到下班时间提醒，可在通知栏直接下班签到',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    actions: [
      AndroidNotificationAction(checkoutActionId, '下班签到',
          showsUserInterface: false, cancelNotification: false)
    ],
  ),
);

class CheckoutReminderPayload {
  const CheckoutReminderPayload(
      {required this.accountKey,
      required this.recordId,
      required this.checkInAt,
      required this.reminderAt});

  final String accountKey;
  final int recordId;
  final DateTime checkInAt;
  final DateTime reminderAt;

  String encode() => jsonEncode({
        'type': 'attendance_checkout',
        'account': accountKey,
        'record': recordId,
        'checkIn': checkInAt.millisecondsSinceEpoch,
        'due': reminderAt.millisecondsSinceEpoch,
      });

  static CheckoutReminderPayload? decode(String? text) {
    try {
      final data = jsonDecode(text ?? '') as Map<String, dynamic>;
      if (data['type'] != 'attendance_checkout' ||
          data['account'] is! String ||
          data['record'] is! int ||
          data['checkIn'] is! int ||
          data['due'] is! int) {
        return null;
      }
      return CheckoutReminderPayload(
        accountKey:
            AttendanceAccountResolver.normalize(data['account'] as String),
        recordId: data['record'] as int,
        checkInAt: DateTime.fromMillisecondsSinceEpoch(data['checkIn'] as int),
        reminderAt: DateTime.fromMillisecondsSinceEpoch(data['due'] as int),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Only an explicit action can write attendance; an ordinary notification tap cannot.
Future<bool> handleCheckoutNotificationAction(
  NotificationResponse response, {
  required AppDatabase database,
  required String activeAccount,
  DateTime? now,
}) async {
  if (response.actionId != checkoutActionId ||
      response.notificationResponseType !=
          NotificationResponseType.selectedNotificationAction) {
    return false;
  }
  final payload = CheckoutReminderPayload.decode(response.payload);
  if (payload == null ||
      payload.accountKey !=
          AttendanceAccountResolver.normalize(activeAccount)) {
    return false;
  }
  return AttendanceDao(database, accountKey: payload.accountKey)
      .checkoutFromReminder(
    recordId: payload.recordId,
    expectedCheckInAt: payload.checkInAt,
    reminderAt: payload.reminderAt,
    now: now,
  );
}

@pragma('vm:entry-point')
void checkoutNotificationBackground(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  unawaited(AttendanceCheckoutReminderService.processResponse(response));
}

class AttendanceCheckoutReminderService {
  AttendanceCheckoutReminderService(
    this.database, {
    Future<String> Function()? resolveAccount,
    FlutterLocalNotificationsPlugin? notifications,
    DateTime Function()? clock,
  })  : _resolveAccount =
            resolveAccount ?? const AttendanceAccountResolver().resolve,
        _notifications = notifications ?? notificationClient,
        _clock = clock ?? DateTime.now;

  final AppDatabase database;
  final Future<String> Function() _resolveAccount;
  final FlutterLocalNotificationsPlugin _notifications;
  final DateTime Function() _clock;
  static final notificationClient = FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;
  StreamSubscription? _updates;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  bool _loaded = false;
  String? _scheduled;

  Future<File> _stateFile() async => File(
      '${(await getApplicationDocumentsDirectory()).path}/attendance_checkout_schedule.json');

  static Future<void> initializeNotifications() =>
      _initialization ??= _initialize();

  static Future<void> _initialize() async {
    try {
      await notificationClient.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (response) =>
            unawaited(processResponse(response)),
        onDidReceiveBackgroundNotificationResponse:
            checkoutNotificationBackground,
      );
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    await initializeNotifications();
    final android = notificationClient.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.areNotificationsEnabled() == true ||
        await android.requestNotificationsPermission() == true;
  }

  static Future<void> processResponse(
    NotificationResponse response, {
    AppDatabase? database,
    Future<String> Function()? resolveAccount,
    DateTime? now,
  }) async {
    if (response.actionId != checkoutActionId ||
        CheckoutReminderPayload.decode(response.payload) == null) {
      return;
    }
    AppDatabase? db;
    try {
      final account =
          await (resolveAccount ?? const AttendanceAccountResolver().resolve)();
      db = database ?? AppDatabase.forNotificationAction();
      final changed = await handleCheckoutNotificationAction(response,
          database: db, activeAccount: account, now: now);
      if (!changed) return;
      await initializeNotifications();
      // A separate confirmation ID cannot be erased by the record-change cancellation.
      await notificationClient.cancel(checkoutNotificationId);
      await notificationClient.show(
          checkoutNotificationId + 1,
          '已下班签到',
          '已按点击时间记录下班签到，可打开APP查看工时。',
          const NotificationDetails(
              android: AndroidNotificationDetails(
            'attendance_checkout_channel',
            '下班签到提醒',
            importance: Importance.max,
            priority: Priority.high,
          )));
    } catch (error) {
      DebugEventLog.add('CHECKOUT_ACTION', 'failed: $error');
      // Do not remove the action notification when a database write fails.
    } finally {
      if (database == null) await db?.close();
    }
  }

  void start() {
    if (_disposed || _updates != null) return;
    _updates = database
        .tableUpdates(TableUpdateQuery.onAllTables([
          database.attendanceRules,
          database.attendanceRecords,
        ]))
        .listen((_) => unawaited(refresh()));
    unawaited(refresh());
  }

  Future<void> refresh() {
    _pending = _pending.then((_) async {
      if (_disposed || defaultTargetPlatform != TargetPlatform.android) return;
      try {
        if (!_loaded) {
          final file = await _stateFile();
          if (await file.exists()) _scheduled = await file.readAsString();
          _loaded = true;
        }
        final account =
            AttendanceAccountResolver.normalize(await _resolveAccount());
        final rule =
            await AttendanceDao(database, accountKey: account).getRule();
        final now = _clock();
        final rows = await (database.select(database.attendanceRecords)
              ..where((t) =>
                  t.accountKey.equals(account) &
                  t.checkInAt.isNotNull() &
                  t.checkOutAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.day)]))
            .get();
        CheckoutReminderPayload? next;
        if (rule.checkoutReminderEnabled) {
          for (final row in rows) {
            final due = AttendanceDao.checkoutReminderTime(row.day, rule);
            // No repeated/retroactive reminder after the configured time has passed.
            if (due.isAfter(now) &&
                !due.isAfter(now.add(const Duration(days: 1))) &&
                !row.checkInAt!.isAfter(due)) {
              next = CheckoutReminderPayload(
                  accountKey: account,
                  recordId: row.id,
                  checkInAt: row.checkInAt!,
                  reminderAt: due);
              break;
            }
          }
        }
        if (_disposed) return;
        final encoded = next?.encode();
        if (encoded != null && encoded == _scheduled) return;
        // Leave an already-delivered reminder actionable until checkout or expiry.
        final old = CheckoutReminderPayload.decode(_scheduled);
        if (next == null &&
            old != null &&
            old.accountKey == account &&
            rule.checkoutReminderEnabled &&
            rows.any((row) =>
                row.id == old.recordId &&
                row.checkInAt == old.checkInAt &&
                AttendanceDao.checkoutReminderTime(row.day, rule) ==
                    old.reminderAt) &&
            now.isBefore(old.reminderAt.add(const Duration(hours: 12)))) {
          return;
        }
        await initializeNotifications();
        await _notifications.cancel(checkoutNotificationId);
        _scheduled = null;
        final file = await _stateFile();
        if (await file.exists()) await file.delete();
        if (next == null || _disposed) return;
        final android = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final exact = await android?.canScheduleExactNotifications() == true;
        await _notifications.zonedSchedule(
            checkoutNotificationId,
            '该下班签到啦',
            '已到下班时间，请在通知栏点击“下班签到”。',
            tz.TZDateTime.from(next.reminderAt, tz.UTC),
            checkoutNotificationDetails,
            androidScheduleMode: exact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: encoded);
        _scheduled = encoded;
        await file.writeAsString(encoded!, flush: true);
      } catch (error) {
        DebugEventLog.add('CHECKOUT_REMINDER', 'refresh failed: $error');
      }
    });
    return _pending;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _updates?.cancel();
    await _pending;
    // Keep the system schedule when the app closes.
  }
}
