import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/college_ip_config.dart';

/// Manage background location updates when app is closed and phone is locked
class BackgroundLocationService {
  static const String _notificationChannelId = 'background_location_channel';
  
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId, // id
      'Attenda Location Sync', // title
      description: 'Running in the background to verify location attendance.', // description
      importance: Importance.low, // importance must be low for persistent service
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'Attenda Location Sync',
        initialNotificationContent: 'Waiting for check-in to start location sharing...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only initialized inside isolate context
    DartPluginRegistrant.ensureInitialized();

    // Keep track of periodic execution timer
    Timer? trackingTimer;

    // Run execution loop
    void runLocationUpdateCycle() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final sessionStr = prefs.getString('user_session');
        if (sessionStr == null) {
          // No active logged in session
          if (service is AndroidServiceInstance) {
            await service.setAsBackgroundService();
          }
          return;
        }

        final session = jsonDecode(sessionStr);
        final token = session['token'] as String?;
        final user = session['user'] as Map<String, dynamic>?;
        final deviceSessionId = session['deviceSessionId'] as String?;

        if (token == null || user == null) return;

        // Check if tracking should be active dynamically
        final active = await _checkTrackingActive(token, deviceSessionId, service);
        if (!active) {
          // Update notification to show tracking is paused when attendance is not active
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Attenda Location Sync",
              content: "Location sharing paused (outside attendance window)",
            );
          }
          return;
        }

        // Fetch user location with a robust fallback strategy
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 7),
          );
        } catch (_) {
          try {
            position = await Geolocator.getLastKnownPosition();
          } catch (_) {}
        }

        if (position == null) {
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 5),
            );
          } catch (_) {}
        }

        if (position == null) return;

        // Upload to server
        final regNo = user['regNo'] ?? user['reg_no'] ?? '';
        final baseUrl = CollegeIPConfig.defaultURL;
        
        final payload = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy_meters': position.accuracy,
          'speed_mps': position.speed,
          'heading_deg': position.heading,
          'altitude_m': position.altitude,
          'is_mocked': position.isMocked,
          'source': 'background_isolate',
          'app_state': 'background',
          'captured_at': position.timestamp.toUtc().toIso8601String(),
          'device_id': deviceSessionId ?? 'app_$regNo',
        };

        final response = await http.post(
          Uri.parse('$baseUrl/location/update'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 403 || response.statusCode == 401) {
          // Device mismatch or unauthorized: stop self
          trackingTimer?.cancel();
          service.stopSelf();
          return;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          final String content = data['boundary_warning'] == true
              ? (data['warning'] ?? 'Warning: Movement outside boundary detected!')
              : 'Location synchronized successfully.';

          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Attenda Location Sync",
              content: content,
            );
          }

          // Trigger a popup heads-up notification when boundary breach is detected in background
          if (data['boundary_warning'] == true && data['warning'] != null) {
            try {
              final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
                  FlutterLocalNotificationsPlugin();
              const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
                'geofence_breach_channel',
                'Geofence Alerts',
                channelDescription: 'Alerts when moving out of geofence boundaries',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              );
              const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
                presentBadge: true,
              );
              const NotificationDetails details =
                  NotificationDetails(android: androidDetails, iOS: iosDetails);

              await flutterLocalNotificationsPlugin.show(
                1001,
                'Geofence Boundary Breach!',
                data['warning'].toString(),
                details,
              );
            } catch (_) {}
          }
        }
      } catch (_) {
        // Suppress background network/GPS errors to keep service alive
      }
    }

    // Initialize triggers for service interaction
    service.on('stopService').listen((event) {
      trackingTimer?.cancel();
      service.stopSelf();
    });

    service.on('startTracking').listen((event) {
      trackingTimer?.cancel();
      runLocationUpdateCycle(); // Run immediately
      trackingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        runLocationUpdateCycle();
      });
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
      }
    });

    service.on('stopTracking').listen((event) async {
      trackingTimer?.cancel();
      if (service is AndroidServiceInstance) {
        await service.setAsBackgroundService();
      }
    });

    service.on('updateNotification').listen((event) async {
      if (service is AndroidServiceInstance) {
        final data = event;
        service.setForegroundNotificationInfo(
          title: data?['title'] as String? ?? 'Attenda Location Sync',
          content: data?['content'] as String? ?? 'Location synchronized successfully.',
        );
      }
    });

    // Check on startup if tracking is already enabled (e.g. on boot)
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('user_session') != null) {
      runLocationUpdateCycle();
      trackingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        runLocationUpdateCycle();
      });
    }
  }

  static Future<bool> _checkTrackingActive(String token, String? deviceSessionId, ServiceInstance service) async {
    try {
      final baseUrl = CollegeIPConfig.defaultURL;
      final queryParam = deviceSessionId != null ? '?device_id=$deviceSessionId' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/staff/tracking-status$queryParam'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final prefs = await SharedPreferences.getInstance();
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['reason'] == 'device_mismatch') {
          service.stopSelf();
          await prefs.setBool('last_tracking_active', false);
          return false;
        }
        final isActive = body['tracking_active'] == true;
        await prefs.setBool('last_tracking_active', isActive);
        return isActive;
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        service.stopSelf();
        await prefs.setBool('last_tracking_active', false);
        return false;
      }
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool('last_tracking_active') ?? true;
      } catch (_) {}
    }
    return false;
  }

  /// Update the persistent notification in the background service.
  /// Called from the main isolate to reflect current tracking state.
  static void updateNotification({required bool isTracking, String? customContent}) {
    try {
      final service = FlutterBackgroundService();
      if (isTracking) {
        service.invoke('updateNotification', {
          'title': 'Attenda Location Sync',
          'content': customContent ?? 'Location synchronized successfully.',
        });
      } else {
        service.invoke('updateNotification', {
          'title': 'Attenda Location Sync',
          'content': customContent ?? 'Location sharing paused (outside attendance window)',
        });
      }
    } catch (_) {}
  }
}
