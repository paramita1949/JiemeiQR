import 'package:flutter/services.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

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
      DebugEventLog.add('GEOFENCE_NATIVE', 'unregisterGeofence enabled=$enabled lat=$lat lng=$lng');
      await _channel.invokeMethod<String>('unregisterGeofence');
      return;
    }
    DebugEventLog.add('GEOFENCE_NATIVE', 'registerGeofence lat=$lat lng=$lng radius=$radius');
    await _channel.invokeMethod<String>('registerGeofence', {
      'lat': lat,
      'lng': lng,
      'radius': radius.toDouble(),
    });
    DebugEventLog.add('GEOFENCE_NATIVE', 'registerGeofence done');
  }

  static Future<String> providerSummary() async {
    final value = await _channel.invokeMethod<String>('getLocationProviderSummary');
    return value ?? '系统融合定位（GPS/北斗/网络）';
  }

  static Future<String> nativeLogs() async {
    final value = await _channel.invokeMethod<String>('getNativeGeofenceLogs');
    return value ?? '';
  }
}
