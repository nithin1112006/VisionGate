import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import '../config/college_ip_config.dart';
import '../utils/geofence_check.dart';
import '../utils/wifi_check.dart';
import '../utils/api_response_utils.dart';
import 'pre_verification_service.dart';

/// Secure face verification service with liveness detection and audit logging
class FaceVerificationService {
  static String get API_URL => CollegeIPConfig.defaultURL;

  // Verification state
  static int _failedAttempts = 0;
  static DateTime? _lockoutEndTime;
  static const int _maxFailedAttempts = 20;
  static const Duration _lockoutDuration = Duration(minutes: 5);

  /// Check if user is locked out
  static bool isLockedOut() {
    if (_lockoutEndTime == null) return false;
    if (DateTime.now().isAfter(_lockoutEndTime!)) {
      // Lockout expired
      _lockoutEndTime = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  /// Get remaining lockout time in seconds
  static int? getRemainingLockoutSeconds() {
    if (_lockoutEndTime == null) return null;
    if (DateTime.now().isAfter(_lockoutEndTime!)) return null;
    return _lockoutEndTime!.difference(DateTime.now()).inSeconds;
  }

  /// Get verification status
  static Future<Map<String, dynamic>> getVerificationStatus(
    String regNo,
  ) async {
    try {
      final response = await http.get(
        Uri.parse("$API_URL/audit/status/$regNo"),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'is_locked': isLockedOut(), 'failed_attempts': _failedAttempts};
    } catch (e) {
      return {
        'is_locked': isLockedOut(),
        'failed_attempts': _failedAttempts,
        'error': e.toString(),
      };
    }
  }

  /// Get security configuration from server
  static Future<Map<String, dynamic>> getConfig() async {
    try {
      final response = await http.get(Uri.parse("$API_URL/config"));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Capture face with liveness detection
  static Future<XFile?> captureFaceWithLiveness(
    CameraController controller, {
    int framesForLiveness = 3,
    bool requireMovement = true,
  }) async {
    try {
      final capturedFrames = <XFile>[];
      final frameInterval = const Duration(milliseconds: 300);

      for (int i = 0; i < framesForLiveness; i++) {
        final image = await controller.takePicture();
        capturedFrames.add(image);

        if (i < framesForLiveness - 1) {
          await Future.delayed(frameInterval);
        }
      }

      if (capturedFrames.isEmpty) {
        return null;
      }

      // Return the last captured frame (server will do quality check)
      return capturedFrames.last;
    } catch (e) {
      debugPrint("Face capture error: $e");
      return null;
    }
  }

  /// Secure face verification with user identity binding
  static Future<Map<String, dynamic>> verifyAndMarkAttendance({
    required String regNo,
    required XFile imageFile,
    VoidCallback? onVerificationComplete,
    VoidCallback? onVerificationFailed,
    Function(String)? onError,
  }) async {
    // Check lockout
    if (isLockedOut()) {
      final remaining = getRemainingLockoutSeconds();
      final errorMsg =
          "Account locked. Try again in ${remaining ?? _lockoutDuration.inSeconds} seconds.";
      onError?.call(errorMsg);
      return {
        'success': false,
        'error': errorMsg,
        'locked_out': true,
        'remaining_seconds': remaining,
      };
    }

    // ── Use pre-verified background cache (VPN + WiFi + Geofence) ────────────
    // getOrRefresh() returns the cached status if it is fresh (< 90 s old).
    // If the cache is stale it runs a synchronous re-check before continuing.
    final preVerif = await PreVerificationService.instance.getOrRefresh();

    // 1. VPN Check
    if (preVerif.vpnError != null) {
      onError?.call(preVerif.vpnError!);
      return {'success': false, 'error': preVerif.vpnError, 'vpn_blocked': true};
    }

    // 2. WiFi/Network check (app only)
    if (!kIsWeb && !AppSettings.allowAnyNetwork && preVerif.wifiError != null) {
      onError?.call(preVerif.wifiError!);
      return {'success': false, 'error': preVerif.wifiError, 'wifi_blocked': true};
    }

    // 3. Geofence check
    final geoDecision = preVerif.geoDecision;
    if (geoDecision != null && geoDecision.error != null) {
      onError?.call(geoDecision.error!);
      return {'success': false, 'error': geoDecision.error, 'geo_blocked': true};
    }

    // Resolve the effective geo decision — use cached one from the service.
    // If no geo decision is cached (geofence disabled), create a no-enforce sentinel.
    final effectiveGeoDecision = geoDecision ??
        const GeoFenceDecision(
          enforced: false,
          insideOuter: null,
          insideInner: null,
          error: null,
        );

    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Build multipart request
      final clientPlatform = kIsWeb ? 'web' : 'app';
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          "$API_URL/mark_attendance?reg_no=$regNo",
        ), // Also add as query param
      );

      // Add reg_no as a field (form data)
      request.fields['reg_no'] = regNo;

      // Always send client platform — backend check_wifi and _enforce_web_geofence
      // both rely on this to distinguish web vs app requests
      request.fields['client_platform'] = clientPlatform;
      request.headers['X-Client-Platform'] = clientPlatform;

      // Send location coordinates when geofence was enforced and position was fetched.
      // Use the position cached by PreVerificationService, falling back to the
      // static GeoFenceChecker cache if needed.
      final position = preVerif.position ?? GeoFenceChecker.lastFetchedPosition;
      if (effectiveGeoDecision.enforced) {
        if (position == null) {
          final errorMsg = "Unable to verify your location. Please enable GPS/location services and try again.";
          onError?.call(errorMsg);
          return {'success': false, 'error': errorMsg, 'geo_blocked': true};
        }
        request.fields['client_lat'] = position.latitude.toString();
        request.fields['client_lng'] = position.longitude.toString();
      }


      // Add image as multipart file
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print("DEBUG: Mark attendance response status: ${response.statusCode}");
      print("DEBUG: Mark attendance response body: $responseBody");

      // Parse JSON response - handle case where response is not JSON
      Map<String, dynamic> result;
      try {
        result = jsonDecode(responseBody);
      } catch (e) {
        // Server returned non-JSON response (likely HTML error page)
        // Use the response body as the error message
        final errorMsg = _statusDefaultMessage(response.statusCode);
        onError?.call(errorMsg);
        return {'success': false, 'error': errorMsg};
      }

      if (response.statusCode == 200) {
        // Success
        _failedAttempts = 0;
        _lockoutEndTime = null;
        onVerificationComplete?.call();

        return {
          'success': true,
          'message': result['message'] ?? 'Attendance marked successfully',
          'data': result,
        };
      } else if (response.statusCode == 401) {
        // Verification failed
        _failedAttempts++;
        onVerificationFailed?.call();

        // Check if locked out
        if (_failedAttempts >= _maxFailedAttempts) {
          _lockoutEndTime = DateTime.now().add(_lockoutDuration);
        }

        // Handle both 'error' (new format) and 'detail' (legacy format)
        final rawError = (result['error'] ?? result['detail'] ?? '').toString();
        final errorMsg = _friendlyAttendanceError(
          statusCode: response.statusCode,
          rawError: rawError,
        );
        onError?.call(errorMsg);

        return {
          'success': false,
          'error': errorMsg,
          'failed_attempts': _failedAttempts,
          'max_attempts': _maxFailedAttempts,
          'locked_out': _failedAttempts >= _maxFailedAttempts,
          'remaining_seconds': _failedAttempts >= _maxFailedAttempts
              ? _lockoutDuration.inSeconds
              : null,
        };
      } else if (response.statusCode == 423) {
        // Locked out
        final remaining = result['remaining_seconds'] ?? 300;
        _lockoutEndTime = DateTime.now().add(Duration(seconds: remaining));

        final rawError = (result['error'] ?? result['detail'] ?? '').toString();
        final errorMsg = _friendlyAttendanceError(
          statusCode: response.statusCode,
          rawError: rawError,
        );
        onError?.call(errorMsg);

        return {
          'success': false,
          'error': errorMsg,
          'locked_out': true,
          'remaining_seconds': remaining,
        };
      } else {
        // Other error - handle both 'error' (new format) and 'detail' (legacy)
        final rawError = (result['error'] ?? result['detail'] ?? '').toString();
        final errorMsg = _friendlyAttendanceError(
          statusCode: response.statusCode,
          rawError: rawError,
        );
        onError?.call(errorMsg);

        final isGeoBlocked = errorMsg.contains('outside') ||
            errorMsg.contains('geofence') ||
            errorMsg.contains('campus') ||
            errorMsg.contains('location');

        return {
          'success': false,
          'error': errorMsg,
          'geo_blocked': isGeoBlocked,
        };
      }
    } catch (e) {
      final errorMsg = ApiResponseUtils.sanitize(e);
      onError?.call(errorMsg);

      return {'success': false, 'error': errorMsg};
    }
  }

  static String _statusDefaultMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid capture input. Please retake your photo clearly.';
      case 401:
        return 'Face does not match. Please try again.';
      case 403:
        return 'Action blocked by policy (VPN, WiFi, geofence, or time window).';
      case 404:
        return 'User not found. Please check your registration number.';
      case 423:
        return 'Account locked due to multiple failed attempts.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'Verification failed (HTTP $statusCode). Please try again.';
    }
  }

  static String _friendlyAttendanceError({
    required int statusCode,
    required String rawError,
  }) {
    final msg = rawError.toLowerCase();

    if (msg.contains('blurry') || msg.contains('hold camera steady')) {
      return 'Image is blurry. Hold your phone steady and keep your face inside the frame.';
    }
    if (msg.contains('dim') || msg.contains('lighting')) {
      return 'Lighting is too low. Move to a brighter place and try again.';
    }
    if (msg.contains('too bright') || msg.contains('overexposed')) {
      return 'Image is too bright. Avoid strong backlight and try again.';
    }
    if (msg.contains('no face') || msg.contains('unable to detect')) {
      return 'No face detected. Center your face in the camera and try again.';
    }
    if (msg.contains('multiple faces')) {
      return 'Multiple faces detected. Make sure only your face is visible.';
    }
    if (msg.contains('does not match') || statusCode == 401) {
      return 'Face verification failed. Your face does not match the registered profile.';
    }
    if (msg.contains('face not registered')) {
      return 'Face not registered. Please register your face before marking attendance.';
    }
    if (msg.contains('liveness')) {
      return 'Liveness check failed. Use a live camera view (not photo/screen replay).';
    }
    if (statusCode == 423 || msg.contains('locked')) {
      return 'Too many failed attempts. Account is temporarily locked. Try again later.';
    }
    if (msg.contains('outside') || msg.contains('fence') || msg.contains('allowed location') || msg.contains('wifi') || msg.contains('wi-fi')) {
      return 'You are outside the allowed geofence area. Please move inside the campus to mark your attendance.';
    }
    if (msg.contains('vpn') || msg.contains('proxy')) {
      return 'VPN/proxy detected. Turn it off and try again.';
    }
    if (msg.contains('not allowed at this time') ||
        msg.contains('available slots')) {
      return 'Attendance is not allowed at this time. Please mark attendance during your allowed slot.';
    }
    if (msg.contains('empty image')) {
      return 'No image received. Please capture your face again.';
    }

    if (rawError.trim().isNotEmpty) return rawError;
    return _statusDefaultMessage(statusCode);
  }

  /// Legacy attendance marking (without identity binding - less secure)
  static Future<Map<String, dynamic>> markAttendanceLegacy({
    required XFile imageFile,
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$API_URL/mark_attendance_legacy"),
      );
      request.files.add(multipartFile);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      // Parse JSON response - handle case where response is not JSON
      Map<String, dynamic> result;
      try {
        result = jsonDecode(responseBody);
      } catch (e) {
        final errorMsg = response.statusCode == 500
            ? "Server error. Please try again later."
            : "Unexpected response from server";
        onError?.call(errorMsg);
        return {'success': false, 'error': errorMsg};
      }

      if (response.statusCode == 200) {
        onSuccess?.call();
        return {
          'success': true,
          'message': result['message'] ?? 'Attendance marked',
          'data': result,
          'warning': result['warning'] ?? 'Legacy mode - identity not verified',
        };
      } else {
        // Handle both 'error' (new format) and 'detail' (legacy format)
        final errorMsg =
            result['error'] ?? result['detail'] ?? 'Attendance marking failed';
        onError?.call(errorMsg);
        return {'success': false, 'error': errorMsg};
      }
    } catch (e) {
      final errorMsg = ApiResponseUtils.sanitize(e);
      onError?.call(errorMsg);
      return {'success': false, 'error': errorMsg};
    }
  }

  /// Get audit logs
  static Future<Map<String, dynamic>> getAuditLogs({
    String? regNo,
    int limit = 100,
  }) async {
    try {
      final url = regNo != null
          ? "$API_URL/audit/logs?reg_no=$regNo&limit=$limit"
          : "$API_URL/audit/logs?limit=$limit";

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'logs': [], 'count': 0};
    } catch (e) {
      return {'logs': [], 'count': 0, 'error': e.toString()};
    }
  }

  /// Reset failed attempts (for testing or admin use)
  static void resetFailedAttempts() {
    _failedAttempts = 0;
    _lockoutEndTime = null;
  }

  /// Verify admin face specifically for settings verification (no checks for wifi/gps/etc)
  static Future<Map<String, dynamic>> verifyAdminExclusive({
    required XFile image,
    required String token,
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$API_URL/admin/face/verify-own-exclusive'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      final fileBytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          fileBytes,
          filename: 'admin_verify.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        onSuccess?.call();
        return {
          'success': true,
          'message': result['message'] ?? 'Admin verified successfully',
        };
      } else {
        final data = jsonDecode(response.body);
        final errorMsg = data['detail'] ?? data['error'] ?? 'Face verification failed';
        onError?.call(errorMsg);
        return {'success': false, 'error': errorMsg};
      }
    } catch (e) {
      final errorMsg = ApiResponseUtils.sanitize(e);
      onError?.call(errorMsg);
      return {'success': false, 'error': errorMsg};
    }
  }
}

/// Verification result model
class VerificationResult {
  final bool success;
  final String? message;
  final String? error;
  final Map<String, dynamic>? data;
  final bool lockedOut;
  final int? remainingSeconds;
  final int failedAttempts;

  VerificationResult({
    required this.success,
    this.message,
    this.error,
    this.data,
    this.lockedOut = false,
    this.remainingSeconds,
    this.failedAttempts = 0,
  });

  factory VerificationResult.fromMap(Map<String, dynamic> map) {
    return VerificationResult(
      success: map['success'] ?? false,
      message: map['message'],
      error: map['error'],
      data: map['data'],
      lockedOut: map['locked_out'] ?? false,
      remainingSeconds: map['remaining_seconds'],
      failedAttempts: map['failed_attempts'] ?? 0,
    );
  }
}
