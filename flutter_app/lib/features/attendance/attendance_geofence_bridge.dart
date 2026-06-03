import 'package:flutter/services.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

class AttendanceGeofenceBridge {
  AttendanceGeofenceBridge._();

  static const MethodChannel _channel = MethodChannel('com.jiemei.hualushui/geofence');

  /// Foreground-only auto check-in keeps office coordinates in Drift and uses
  /// one-shot AMap location when the app is open. Native background geofences
  /// are intentionally cleared here for older installs.
  static Future<void> syncGeofence({
    required bool enabled,
    required double? lat,
    required double? lng,
    required int radius,
  }) async {
    DebugEventLog.add(
      'GEOFENCE_NATIVE',
      'clear native background geofence enabled=$enabled lat=$lat lng=$lng radius=$radius',
    );
    await _channel.invokeMethod<String>('unregisterGeofence');
  }

  static Future<String> providerSummary() async {
    final value = await _channel.invokeMethod<String>('getLocationProviderSummary');
    return value ?? '系统融合定位（GPS/北斗/网络）';
  }

  static Future<String> nativeLogs() async {
    final value = await _channel.invokeMethod<String>('getNativeGeofenceLogs');
    return value ?? '';
  }

  static Future<AmapLocationSnapshot?> amapCurrentLocation() async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>(
        'getAmapCurrentLocation',
      );
      if (value == null) return null;
      final latitude = (value['latitude'] as num?)?.toDouble();
      final longitude = (value['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) return null;
      return AmapLocationSnapshot(
        latitude: latitude,
        longitude: longitude,
        accuracy: (value['accuracy'] as num?)?.toDouble(),
        address: value['address'] as String?,
        locationType: (value['locationType'] as num?)?.toInt(),
      );
    } on PlatformException catch (e) {
      DebugEventLog.add('AMAP_LOCATE', 'failed ${e.code}: ${e.message}');
      return null;
    }
  }
}

class AmapLocationSnapshot {
  const AmapLocationSnapshot({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.address,
    this.locationType,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? address;
  final int? locationType;
}
