import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_geofence_bridge.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

class AttendanceGeofenceReminderService {
  AttendanceGeofenceReminderService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> checkAndMaybeNotify({
    required AppDatabase database,
    String accountKey = 'local',
  }) async {
    final dao = AttendanceDao(database, accountKey: accountKey);
    final rule = await dao.getRule();
    if (!rule.geofenceEnabled ||
        rule.officeLat == null ||
        rule.officeLng == null) {
      return;
    }

    await _initNotification();

    final permissionState =
        await ensureSystemPermissions(requestIfNeeded: true);
    final serviceEnabled = permissionState.locationServiceEnabled;
    if (!serviceEnabled) return;

    final permission = permissionState.locationPermission;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    DebugEventLog.add('GEOFENCE_AUTO', 'foreground locate start');
    final location = await _locateForAttendance();
    if (location == null) {
      DebugEventLog.add('GEOFENCE_AUTO', 'position null');
      return;
    }

    final distance = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      rule.officeLat!,
      rule.officeLng!,
    );
    final isInsideNow = distance <= rule.officeRadiusMeters;
    DebugEventLog.add(
      'GEOFENCE_AUTO',
      'current=${location.latitude.toStringAsFixed(6)},${location.longitude.toStringAsFixed(6)} '
          'center=${rule.officeLat!.toStringAsFixed(6)},${rule.officeLng!.toStringAsFixed(6)} '
          'distance=${distance.toStringAsFixed(1)} radius=${rule.officeRadiusMeters} inside=$isInsideNow',
    );
    final decision =
        await dao.handleGeofenceTransition(isInsideNow: isInsideNow);
    DebugEventLog.add('GEOFENCE_AUTO', 'decision=${decision.reason}');
    if (!decision.triggered) return;

    await showAutoCheckinNotification();
  }

  static Future<_AttendanceLocation?> _locateForAttendance() async {
    final amap = await AttendanceGeofenceBridge.amapCurrentLocation();
    if (amap != null) {
      DebugEventLog.add(
        'GEOFENCE_AUTO',
        'amap lat=${amap.latitude} lng=${amap.longitude} acc=${amap.accuracy} type=${amap.locationType}',
      );
      return _AttendanceLocation(
        latitude: amap.latitude,
        longitude: amap.longitude,
      );
    }
    DebugEventLog.add('GEOFENCE_AUTO', 'amap location unavailable');
    return null;
  }

  static Future<void> showAutoCheckinNotification() async {
    await _initNotification();
    const android = AndroidNotificationDetails(
      'attendance_checkin_channel',
      '考勤自动签到',
      channelDescription: '打开APP进入公司围栏后的自动签到反馈',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.status,
    );
    const details = NotificationDetails(android: android);
    await _notifications.show(
      20260504,
      '已自动上班签到',
      '已在公司范围内完成上班签到',
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

  static Future<void> showCheckinReminderNotification() async {
    await _initNotification();
    const android = AndroidNotificationDetails(
      'attendance_checkin_channel',
      '考勤自动签到',
      channelDescription: '打开APP进入公司围栏后的自动签到反馈',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
    );
    const details = NotificationDetails(android: android);
    await _notifications.show(
      202605052,
      '围栏测试',
      '当前位置在公司范围内，正式使用时会自动上班签到',
      details,
    );
  }

  static Future<void> showPrecheckinNotification() async {
    await _initNotification();
    const android = AndroidNotificationDetails(
      'attendance_precheckin_channel',
      '上班临近提醒',
      channelDescription: '上班前3分钟未签到提醒',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );
    const details = NotificationDetails(android: android);
    await _notifications.show(
      202605041,
      '上班临近提醒',
      '距离上班时间不足3分钟，且你还未签到',
      details,
    );
  }

  static Future<AttendancePermissionState> ensureSystemPermissions({
    bool requestIfNeeded = true,
  }) async {
    await _initNotification();
    DebugEventLog.add(
        'PERMISSION', 'ensureSystemPermissions request=$requestIfNeeded');
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    var locationPermission = await Geolocator.checkPermission();
    if (requestIfNeeded && locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }

    bool? notificationGranted;
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      notificationGranted = await androidPlugin.areNotificationsEnabled();
      if (requestIfNeeded && notificationGranted != true) {
        notificationGranted =
            await androidPlugin.requestNotificationsPermission();
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

class _AttendanceLocation {
  const _AttendanceLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
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
