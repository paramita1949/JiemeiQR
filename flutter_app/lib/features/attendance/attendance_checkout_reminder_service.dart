import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_account_resolver.dart';
import 'package:qrscan_flutter/shared/utils/attendance_notification_log.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';
import 'package:timezone/timezone.dart' as tz;

const checkoutNotificationId = 20261120;
const checkoutActionId = 'attendance_checkout_now';
const checkoutTestActionId = 'attendance_checkout_test_ack';
const checkoutTestNotificationId = checkoutNotificationId + 2;
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
    await AttendanceNotificationLog.write(
        'action_ignored', {'reason': 'not_checkout_action'});
    return false;
  }
  final payload = CheckoutReminderPayload.decode(response.payload);
  if (payload == null ||
      payload.accountKey !=
          AttendanceAccountResolver.normalize(activeAccount)) {
    await AttendanceNotificationLog.write('action_rejected',
        {'reason': payload == null ? 'invalid_payload' : 'account_changed'});
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
  String? _lastDecision;

  Future<void> _decision(String reason, Map<String, Object?> data) async {
    final signature = jsonEncode({'reason': reason, ...data});
    if (signature == _lastDecision) return;
    _lastDecision = signature;
    await AttendanceNotificationLog.write(
        'schedule_decision', {'reason': reason, ...data});
    if (reason == 'cached_schedule_unchanged' ||
        reason == 'keep_delivered_reminder') {
      await captureSystemState('cached_schedule_check');
    }
  }

  /// 采集实际系统权限、渠道及通知队列，不把API调用成功当作弹窗已展示。
  Future<Map<String, Object?>> captureSystemState(String stage) async {
    final result = <String, Object?>{
      'stage': stage,
      'os': Platform.operatingSystemVersion,
      'offsetMinutes': DateTime.now().timeZoneOffset.inMinutes
    };
    Future<void> query(String key, Future<Object?> Function() read) async {
      try {
        result[key] = await read();
      } catch (error) {
        result[key] = 'query_failed: $error';
      }
    }

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await query('permission', android.areNotificationsEnabled);
      await query('exactAlarmAllowed', android.canScheduleExactNotifications);
      await query(
          'channels',
          () async => (await android.getNotificationChannels())
              ?.where((c) => c.id == 'attendance_checkout_channel')
              .map((c) => {
                    'id': c.id,
                    'importance': c.importance.value,
                    'sound': c.playSound,
                    'vibration': c.enableVibration
                  })
              .toList());
    }
    await query(
        'pending',
        () async => (await _notifications.pendingNotificationRequests())
            .map((n) => {
                  'id': n.id,
                  'due': CheckoutReminderPayload.decode(n.payload)
                      ?.reminderAt
                      .toIso8601String()
                })
            .toList());
    await query(
        'active',
        () async => (await _notifications.getActiveNotifications())
            .map((n) => {'id': n.id, 'channel': n.channelId})
            .toList());
    await query('appVersion', () async {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    });
    await AttendanceNotificationLog.write('system_state', result);
    return result;
  }

  /// 立即测试相同渠道与通知动作，不改真实排期、不写签到记录。
  Future<String> sendTestNotification() async {
    await AttendanceNotificationLog.write(
        'test_begin', {'notificationId': checkoutTestNotificationId});
    if (defaultTargetPlatform != TargetPlatform.android) {
      await AttendanceNotificationLog.write(
          'test_skipped', {'reason': 'not_android'});
      return '通知测试仅支持Android。';
    }
    try {
      await initializeNotifications();
      final before = await captureSystemState('test_before');
      if (before['permission'] == false &&
          !await requestNotificationPermission()) {
        await AttendanceNotificationLog.write(
            'test_blocked', {'reason': 'notification_permission_denied'});
        return '通知权限未开启，请在系统设置中允许通知后重试。';
      }
      await _notifications.show(
          checkoutTestNotificationId,
          '下班通知测试',
          '这是系统通知测试。按钮仅测试回调，不会下班签到。',
          const NotificationDetails(
              android: AndroidNotificationDetails(
            'attendance_checkout_channel',
            '下班签到提醒',
            channelDescription: '到下班时间提醒，可在通知栏直接下班签到',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            actions: [
              AndroidNotificationAction(checkoutTestActionId, '测试签到按钮（不签到）',
                  showsUserInterface: false, cancelNotification: false)
            ],
          )),
          payload: '{"type":"attendance_checkout_test"}');
      await AttendanceNotificationLog.write('test_show_returned', {
        'notificationId': checkoutTestNotificationId,
        'meaning': 'API accepted; banner visibility not confirmed'
      });
      final after = await captureSystemState('test_after');
      final channels = after['channels'];
      if (channels is List &&
          channels.any((c) =>
              c is Map &&
              c['importance'] is int &&
              (c['importance'] as int) < Importance.high.value)) {
        return '已提交测试通知，但渠道重要性较低，请在系统通知设置中开启横幅/声音。';
      }
      return '已提交测试通知，请检查通知栏和横幅；未出现时复制通知日志。测试不签到。';
    } catch (error, stack) {
      await AttendanceNotificationLog.write(
          'test_failed', {'error': '$error', 'stack': '$stack'});
      return '测试通知发送失败：$error。请查看通知日志。';
    }
  }

  Future<File> _stateFile() async => File(
      '${(await getApplicationDocumentsDirectory()).path}/attendance_checkout_schedule.json');

  static Future<void> initializeNotifications() =>
      _initialization ??= _initialize();

  static Future<void> _initialize() async {
    try {
      await AttendanceNotificationLog.write('initialize_begin');
      final initialized = await notificationClient.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (response) =>
            unawaited(processResponse(response)),
        onDidReceiveBackgroundNotificationResponse:
            checkoutNotificationBackground,
      );
      await AttendanceNotificationLog.write(
          'initialize_returned', {'initialized': initialized});
    } catch (error, stack) {
      await AttendanceNotificationLog.write(
          'initialize_failed', {'error': '$error', 'stack': '$stack'});
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
    await AttendanceNotificationLog.write('response_received', {
      'id': response.id,
      'action': response.actionId,
      'responseType': response.notificationResponseType.name
    });
    if (response.actionId == checkoutTestActionId &&
        response.notificationResponseType ==
            NotificationResponseType.selectedNotificationAction) {
      await AttendanceNotificationLog.write(
          'test_action_received', {'attendanceChanged': false});
      try {
        await initializeNotifications();
        await notificationClient.show(
            checkoutTestNotificationId + 1,
            '测试按钮已响应',
            '仅测试通知回调，未执行下班签到。',
            const NotificationDetails(
                android: AndroidNotificationDetails(
                    'attendance_checkout_channel', '下班签到提醒',
                    importance: Importance.max, priority: Priority.high)));
      } catch (error, stack) {
        await AttendanceNotificationLog.write(
            'test_action_failed', {'error': '$error', 'stack': '$stack'});
      }
      return;
    }
    if (response.actionId != checkoutActionId ||
        CheckoutReminderPayload.decode(response.payload) == null) {
      await AttendanceNotificationLog.write(
          'response_ignored', {'reason': 'ordinary_tap_or_invalid_payload'});
      return;
    }
    AppDatabase? db;
    try {
      final account =
          await (resolveAccount ?? const AttendanceAccountResolver().resolve)();
      db = database ?? AppDatabase.forNotificationAction();
      final changed = await handleCheckoutNotificationAction(response,
          database: db, activeAccount: account, now: now);
      await AttendanceNotificationLog.write(
          'checkout_result', {'changed': changed});
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
    } catch (error, stack) {
      await AttendanceNotificationLog.write(
          'action_failed', {'error': '$error', 'stack': '$stack'});
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
        final context = <String, Object?>{
          'accountId': AttendanceNotificationLog.accountId(account),
          'enabled': rule.checkoutReminderEnabled,
          'workStart': rule.workStartTime,
          'workEnd': rule.workEndTime,
          'openRecordCount': rows.length
        };
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
        if (encoded != null && encoded == _scheduled) {
          await _decision('cached_schedule_unchanged',
              {...context, 'due': next!.reminderAt.toIso8601String()});
          return;
        }
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
          await _decision('keep_delivered_reminder', context);
          return;
        }
        await _decision(
            next == null
                ? (!rule.checkoutReminderEnabled
                    ? 'reminder_disabled'
                    : rows.isEmpty
                        ? 'no_open_record'
                        : 'outside_future_window_or_past_due')
                : 'schedule_required',
            context);
        await AttendanceNotificationLog.write('schedule_input', {
          'now': now.toIso8601String(),
          'due': next?.reminderAt.toIso8601String(),
          'recordId': next?.recordId
        });
        await initializeNotifications();
        await captureSystemState('schedule_before');
        await _notifications.cancel(checkoutNotificationId);
        await AttendanceNotificationLog.write(
            'cancel_returned', {'notificationId': checkoutNotificationId});
        _scheduled = null;
        final file = await _stateFile();
        if (await file.exists()) await file.delete();
        if (next == null || _disposed) return;
        final android = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final exact = await android?.canScheduleExactNotifications() == true;
        await AttendanceNotificationLog.write('schedule_begin', {
          'notificationId': checkoutNotificationId,
          'due': next.reminderAt.toIso8601String(),
          'epoch': next.reminderAt.millisecondsSinceEpoch,
          'mode': exact ? 'exactAllowWhileIdle' : 'inexactAllowWhileIdle'
        });
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
        await AttendanceNotificationLog.write(
            'schedule_returned', {'notificationId': checkoutNotificationId});
        _scheduled = encoded;
        await file.writeAsString(encoded!, flush: true);
        await captureSystemState('schedule_after');
      } catch (error, stack) {
        await AttendanceNotificationLog.write(
            'schedule_failed', {'error': '$error', 'stack': '$stack'});
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
