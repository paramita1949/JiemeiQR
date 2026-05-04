import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/attendance_dao.dart';

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

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
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
      importance: Importance.high,
      priority: Priority.high,
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
}
