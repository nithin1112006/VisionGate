import 'package:flutter/services.dart';

/// Manage background location updates when app is closed and phone is locked using native Android services.
class BackgroundLocationService {
  static const MethodChannel _channel = MethodChannel('attendance');

  static Future<void> initialize() async {
    // Native service handles its own initialization on the native side.
  }

  /// Start the background service with server connection and geofence coordinates
  static Future<void> start({
    required String baseUrl,
    required double geofenceLat,
    required double geofenceLng,
    required double geofenceRadius,
    required String token,
    required String regNo,
    required String deviceSessionId,
  }) async {
    try {
      await _channel.invokeMethod('startService', {
        'baseUrl': baseUrl,
        'geofenceLat': geofenceLat,
        'geofenceLng': geofenceLng,
        'geofenceRadius': geofenceRadius,
        'token': token,
        'regNo': regNo,
        'deviceSessionId': deviceSessionId,
      });
    } catch (_) {}
  }

  /// Stop the background service
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopService');
    } catch (_) {}
  }

  /// Update the notification on Android (handled internally by native service now)
  static void updateNotification({required bool isTracking, String? customContent}) {
    // Internal native handling, no-op in Dart
  }
}
