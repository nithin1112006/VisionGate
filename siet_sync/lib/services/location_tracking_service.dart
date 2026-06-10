import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../config/college_ip_config.dart';
import 'api_client.dart';
import 'session_service.dart';

class LocationTrackingService {
  LocationTrackingService._() {
    _initLocalNotifications();
  }
  static final LocationTrackingService instance = LocationTrackingService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  bool _running = false;
  String? _activeToken;
  Map<String, dynamic>? _activeUser;
  final List<Map<String, dynamic>> _pending = [];
  bool _flushing = false;
  
  // Tracking window status variables
  bool _trackingSuspended = false;
  final _warningController = StreamController<String>.broadcast();
  
  /// Stream emitting warnings (e.g. boundary breach warnings) to be consumed by UI pages
  Stream<String> get warningStream => _warningController.stream;

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(initSettings);
  }

  Future<void> _showBreachNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'geofence_breach_channel',
      'Geofence Alerts',
      channelDescription: 'Alerts when moving out of geofence boundaries',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    await _localNotifications.show(
      1001,
      'Geofence Boundary Breach!',
      message,
      details,
    );
  }

  String? _deviceSessionId;

  Future<bool> startTracking({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    if (kIsWeb) return false;
    if (_running && _activeToken == token) {
      return true;
    }

    await stopTracking();
    _activeToken = token;
    _activeUser = user;

    try {
      final session = await sessionService.getSession();
      _deviceSessionId = session?.deviceSessionId;
    } catch (_) {}

    final permissionGranted = await _ensureLocationPermission();
    if (!permissionGranted) {
      await stopTracking();
      return false;
    }

    _running = true;
    _trackingSuspended = false;

    // Check if tracking should be active dynamically
    final active = await checkTrackingActive();
    if (!active) {
      _trackingSuspended = true;
    } else {
      await _captureAndQueue(source: 'startup');
      _startStream();
    }
    _startHeartbeat();
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
      service.invoke('startTracking');
    } catch (_) {}
    return true;
  }



  Future<void> stopTracking() async {
    if (kIsWeb) return;
    _running = false;
    try {
      await _positionSub?.cancel();
    } catch (_) {}
    _positionSub = null;
    
    try {
      _heartbeatTimer?.cancel();
    } catch (_) {}
    _heartbeatTimer = null;
    
    _activeToken = null;
    _activeUser = null;
    _deviceSessionId = null;
    _pending.clear();
    _trackingSuspended = false;
    
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke('stopService');
      }
    } catch (_) {}
  }

  /// Called immediately after attendance is marked (check-in or check-out).
  /// Re-checks tracking status and resumes or suspends location sharing accordingly.
  /// This eliminates the delay for start/stop of tracking.
  Future<void> onAttendanceMarked() async {
    if (!_running || _activeToken == null) return;
    final active = await checkTrackingActive();
    if (active) {
      if (_trackingSuspended) {
        _trackingSuspended = false;
        _startStream();
        await _captureAndQueue(source: 'attendance_mark');
        await _flushPending();
      }
    } else {
      if (!_trackingSuspended) {
        _trackingSuspended = true;
        await _positionSub?.cancel();
        _positionSub = null;
      }
      // Flush any remaining pending positions before fully suspending
      await _flushPending();
    }
  }

  Future<bool> checkTrackingActive() async {
    if (_activeToken == null) return false;
    try {
      final queryParam = _deviceSessionId != null ? '?device_id=$_deviceSessionId' : '';
      final response = await apiClient.get(
        '${CollegeIPConfig.defaultURL}/staff/tracking-status$queryParam',
        token: _activeToken,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['reason'] == 'device_mismatch') {
          // A new device has logged in, stop tracking on this device immediately
          await stopTracking();
          return false;
        }
        return body['tracking_active'] == true;
      } else if (response.statusCode == 403) {
        await stopTracking();
        return false;
      }
    } catch (_) {}
    return false;
  }

  void _startStream() {
    if (_trackingSuspended) return;
    
    final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(minutes: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Running in the background to verify location attendance.",
          notificationTitle: "Attenda Location Sync",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

    _positionSub =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            _queuePosition(position, source: 'stream');
          },
          onError: (_) {},
        );
  }

  void _startHeartbeat() {
    // Poll tracking status and flush positions every 1 minute for dynamic updates
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!_running) return;
      
      final active = await checkTrackingActive();
      if (active) {
        if (_trackingSuspended) {
          _trackingSuspended = false;
          _startStream();
          await _captureAndQueue(source: 'startup');
        }
        await _captureAndQueue(source: 'heartbeat');
        await _flushPending();
      } else {
        if (!_trackingSuspended) {
          _trackingSuspended = true;
          await _positionSub?.cancel();
          _positionSub = null;
        }
      }
    });
  }

  Future<void> _captureAndQueue({required String source}) async {
    if (_trackingSuspended) return;
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

    if (position != null) {
      _queuePosition(position, source: source);
    }
  }


  void _queuePosition(Position position, {required String source}) {
    if (!_running || _trackingSuspended || _activeToken == null || _activeUser == null) return;
    
    // Ignore noisy location updates with error margin > 50 meters
    if (position.accuracy > 50.0) return;

    final regNo = _activeUser!.containsKey('regNo')
        ? _activeUser!['regNo'].toString()
        : (_activeUser!['reg_no']?.toString() ?? '');

    final payload = <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy_meters': position.accuracy,
      'speed_mps': position.speed,
      'heading_deg': position.heading,
      'altitude_m': position.altitude,
      'is_mocked': position.isMocked,
      'source': source,
      'app_state': 'active',
      'captured_at': position.timestamp.toUtc().toIso8601String(),
      'device_id': _deviceSessionId ?? 'app_$regNo',
    };

    _pending.add(payload);
    if (_pending.length > 300) {
      _pending.removeRange(0, _pending.length - 300);
    }
    _flushPending();
  }

  Future<void> _flushPending() async {
    if (_flushing || _activeToken == null || _pending.isEmpty) return;
    _flushing = true;
    try {
      int retries = 0;
      while (_pending.isNotEmpty && _activeToken != null && retries < 3) {
        final current = _pending.first;
        try {
          final response = await apiClient.post(
            '${CollegeIPConfig.defaultURL}/location/update',
            token: _activeToken,
            body: jsonEncode(current),
          );
          if (response.statusCode >= 200 && response.statusCode < 300) {
            _pending.removeAt(0);
            retries = 0; // reset retry count on success
            
            // Extract warning payloads if any
            final data = jsonDecode(response.body);
            if (data['boundary_warning'] == true && data['warning'] != null) {
              _warningController.add(data['warning'].toString());
              _showBreachNotification(data['warning'].toString());
            }
          } else if (response.statusCode == 403 || response.statusCode == 401) {
            // Device mismatch or unauthorized - stop trying
            break;
          } else {
            // Server error - retry up to 3 times
            retries++;
            if (retries < 3) {
              await Future.delayed(const Duration(seconds: 2));
            } else {
              break;
            }
          }
        } catch (_) {
          retries++;
          if (retries < 3) {
            await Future.delayed(const Duration(seconds: 2));
          } else {
            break;
          }
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (permission == LocationPermission.whileInUse) {
      final status = await Permission.locationAlways.request();
      if (!status.isGranted) {
        return false; // ENFORCE COMPULSORY BACKGROUND PERMISSION
      }
    }

    // Ensure notification permission is also granted (required for foreground notifications on Android 13+)
    if (await Permission.notification.status.isDenied) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        return false;
      }
    }

    return true;
  }
}
