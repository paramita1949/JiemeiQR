import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

class AttendanceGeofenceReminderService {
  AttendanceGeofenceReminderService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> checkAndMaybeNotify({
    required AppDatabase database,
  }) async {
    final dao = AttendanceDao(database);
    final rule = await dao.getRule();
    if (!rule.geofenceEnabled || rule.officeLat == null || rule.officeLng == null) {
      return;
    }

    await _initNotification();

    final permissionState = await ensureSystemPermissions(requestIfNeeded: true);
    final serviceEnabled = permissionState.locationServiceEnabled;
    if (!serviceEnabled) return;

    final permission = permissionState.locationPermission;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      rule.officeLat!,
      rule.officeLng!,
    );
    final isInsideNow = distance <= rule.officeRadiusMeters;
    final decision = await dao.handleGeofenceTransition(isInsideNow: isInsideNow);
    if (!decision.triggered) return;

    const android = AndroidNotificationDetails(
      'attendance_checkin_channel',
      '考勤签到提醒',
      channelDescription: '进入公司围栏后的签到提醒',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    );
    const details = NotificationDetails(android: android);
    await _notifications.show(
      20260504,
      '签到提醒',
      '你已进入公司范围，请完成上班签到',
      details,
    );
  }

  static Future<void> _initNotification() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
    _initialized = true;
  }

  static Future<void> showDebugNotification() async {
    await _initNotification();
    const android = AndroidNotificationDetails(
      'attendance_checkin_channel',
      '考勤签到提醒',
      channelDescription: '进入公司围栏后的签到提醒',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
    );
    const details = NotificationDetails(android: android);
    await _notifications.show(
      20260506,
      '调试通知',
      '如果你看到这条，说明通知链路可用',
      details,
    );
  }

  static Future<AttendancePermissionState> ensureSystemPermissions({
    bool requestIfNeeded = true,
  }) async {
    await _initNotification();
    DebugEventLog.add('PERMISSION', 'ensureSystemPermissions request=$requestIfNeeded');
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    var locationPermission = await Geolocator.checkPermission();
    if (requestIfNeeded && locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }

    bool? notificationGranted;
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      notificationGranted = await androidPlugin.areNotificationsEnabled();
      if (requestIfNeeded && notificationGranted != true) {
        notificationGranted = await androidPlugin.requestNotificationsPermission();
      }
    }
    DebugEventLog.add(
      'PERMISSION',
      'result service=$locationServiceEnabled location=${locationPermission.name} notification=${notificationGranted ?? true}',
    );

    return AttendancePermissionState(
      locationServiceEnabled: locationServiceEnabled,
      locationPermission: locationPermission,
      notificationGranted: notificationGranted ?? true,
    );
  }
}

class AttendancePermissionState {
  const AttendancePermissionState({
    required this.locationServiceEnabled,
    required this.locationPermission,
    required this.notificationGranted,
  });

  final bool locationServiceEnabled;
  final LocationPermission locationPermission;
  final bool notificationGranted;

  bool get ready =>
      locationServiceEnabled &&
      notificationGranted &&
      locationPermission != LocationPermission.denied &&
      locationPermission != LocationPermission.deniedForever;
}
