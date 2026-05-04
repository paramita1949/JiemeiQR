import 'package:flutter/services.dart';

class AttendanceGeofenceBridge {
  AttendanceGeofenceBridge._();

  static const MethodChannel _channel = MethodChannel('com.jiemei.hualushui/geofence');

  static Future<void> syncGeofence({
    required bool enabled,
    required double? lat,
    required double? lng,
    required int radius,
  }) async {
    if (!enabled || lat == null || lng == null) {
      await _channel.invokeMethod<String>('unregisterGeofence');
      return;
    }
    await _channel.invokeMethod<String>('registerGeofence', {
      'lat': lat,
      'lng': lng,
      'radius': radius.toDouble(),
    });
  }

  static Future<String> providerSummary() async {
    final value = await _channel.invokeMethod<String>('getLocationProviderSummary');
    return value ?? '系统融合定位（GPS/北斗/网络）';
  }
}
