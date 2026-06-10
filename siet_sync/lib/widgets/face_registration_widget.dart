import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../config/college_ip_config.dart';
import '../utils/wifi_check.dart';
import '../utils/vpn_check.dart';
import '../utils/geofence_check.dart';

String get API_URL => CollegeIPConfig.defaultURL;

class FaceRegistrationWidget extends StatefulWidget {
  final String token;
  final String role;
  final String? initialRegNo;
  final String? initialName;
  final String? initialDept;
  final String registerEndpoint;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const FaceRegistrationWidget({
    super.key,
    required this.token,
    required this.role,
    this.initialRegNo,
    this.initialName,
    this.initialDept,
    required this.registerEndpoint,
    this.onSuccess,
    this.onCancel,
  });

  @override
  State<FaceRegistrationWidget> createState() => _FaceRegistrationWidgetState();
}

class _FaceRegistrationWidgetState extends State<FaceRegistrationWidget> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String _statusMessage = "Position your face in the frame";
  XFile? _capturedImage;
  bool _hasFace = false;

  bool _isRegistering = false;
  bool _isRegistrationSuccess = false;
  bool _isRegistrationError = false;
  String _registrationErrorMessage = '';

  final regNoCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final deptCtrl = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    regNoCtrl.text = widget.initialRegNo ?? '';
    nameCtrl.text = widget.initialName ?? '';
    deptCtrl.text = widget.initialDept ?? '';
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _animationController.dispose();
    regNoCtrl.dispose();
    nameCtrl.dispose();
    deptCtrl.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      _controller = CameraController(
        _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        ),
        kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      setState(() => _statusMessage = "Camera error: $e");
    }
  }

  Future<void> _captureFrame() async {
    if (_isCapturing || !_isInitialized) return;

    setState(() => _isCapturing = true);
    _statusMessage = "Capturing face...";

    try {
      final XFile imageFile = await _controller!.takePicture();

      // Backend will detect and process the face
      setState(() {
        _capturedImage = imageFile;
        _hasFace = true;
        _statusMessage = "Face captured! Tap Register to confirm.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Capture failed: $e";
      });
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _registerFace() async {
    if (_capturedImage == null) {
      setState(() => _statusMessage = "Please capture your face first");
      return;
    }

    if (nameCtrl.text.isEmpty) {
      setState(() => _statusMessage = "Please fill in your name");
      return;
    }

    setState(() {
      _isRegistering = true;
      _isRegistrationSuccess = false;
      _isRegistrationError = false;
      _registrationErrorMessage = '';
      _statusMessage = "Registering face...";
    });

    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("${API_URL}${widget.registerEndpoint}"),
      );

      final clientPlatform = kIsWeb ? 'web' : 'app';
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.headers['X-Client-Platform'] = clientPlatform;
      request.fields['name'] = nameCtrl.text;
      request.fields['reg_no'] = regNoCtrl.text;
      request.fields['dept'] = deptCtrl.text;
      request.fields['role'] = widget.role;
      final bytes = await _capturedImage!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          bytes,
          filename: "face_capture.jpg",
        ),
      );

      var response = await request.send();
      var body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(body);
        setState(() {
          _isRegistering = false;
          _isRegistrationSuccess = true;
          _statusMessage = "✅ ${json['message']}";
        });
        widget.onSuccess?.call();
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) Navigator.pop(context);
      } else {
        final errorJson = jsonDecode(body);
        setState(() {
          _isRegistering = false;
          _isRegistrationError = true;
          _registrationErrorMessage =
              errorJson['detail'] ?? 'Registration failed';
          _statusMessage = "❌ ${_registrationErrorMessage}";
        });
      }
    } catch (e) {
      setState(() {
        _isRegistering = false;
        _isRegistrationError = true;
        _registrationErrorMessage = "Error: $e";
        _statusMessage = "❌ $_registrationErrorMessage";
      });
    }
  }

  void _retryRegistration() {
    setState(() {
      _isRegistrationError = false;
      _registrationErrorMessage = '';
    });
    _registerFace();
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: Colors.deepPurpleAccent.shade200,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Registering Face...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Please keep still",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withValues(alpha: 0.2),
                      border: Border.all(
                        color: Colors.green,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.green,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage.replaceAll("✅ ", ""),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Redirecting...",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.red, width: 3),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage.replaceAll("❌ ", ""),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _retryRegistration,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Try Again"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
      );
    }

    return GestureDetector(
      onTap: (_isRegistering || _isRegistrationSuccess) ? null : _captureFrame,
      child: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(_controller!)),
          // Transparent overlay to capture taps on web (video element blocks gestures)
          if (!_isRegistering && !_isRegistrationSuccess)
            Positioned.fill(
              child: GestureDetector(
                onTap: _captureFrame,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
          
          // Animated Scanning Mask
          if (!_isRegistering && !_isRegistrationSuccess)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: FaceScannerMaskPainter(
                      scanProgress: _animationController.value,
                      faceDetected: _hasFace,
                      faceQuality: _hasFace ? 1.0 : 0.0,
                    ),
                  );
                },
              ),
            ),

          if (_isCapturing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
                ),
              ),
            ),

          if (_isRegistering)
            Positioned.fill(child: _buildLoadingOverlay()),

          if (_isRegistrationSuccess)
            Positioned.fill(child: _buildSuccessOverlay()),

          if (_isRegistrationError)
            Positioned.fill(child: _buildErrorOverlay()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBar = Container(
      padding: const EdgeInsets.all(16),
      color: _hasFace
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.grey[100]!,
      child: Row(
        children: [
          Icon(
            _hasFace ? Icons.check_circle : Icons.info,
            color: _hasFace ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: _hasFace ? Colors.green[700] : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    Widget buildForm(EdgeInsetsGeometry padding) {
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          children: [
            TextField(
              controller: regNoCtrl,
              decoration: InputDecoration(
                labelText: "Registration Number",
                prefixIcon: const Icon(Icons.badge),
                filled: true,
                fillColor: Colors.grey[100]!,
                enabled: false,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Full Name",
                prefixIcon: const Icon(Icons.person),
                filled: true,
                fillColor: Colors.grey[100]!,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deptCtrl,
              decoration: InputDecoration(
                labelText: "Department",
                prefixIcon: const Icon(Icons.school),
                filled: true,
                fillColor: Colors.grey[100]!,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_hasFace && !_isRegistering && !_isRegistrationSuccess) ? _registerFace : null,
                icon: const Icon(Icons.face),
                label: Text(_isRegistering ? "Registering..." : _isRegistrationSuccess ? "Success!" : "Register Face"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRegistrationSuccess ? Colors.green : Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (!_hasFace) ...[
              const SizedBox(height: 16),
              Text(
                "Tap the camera to capture your face",
                style: TextStyle(color: Colors.grey[600]!, fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Registration"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (!isWide) {
            return Column(
              children: [
                Expanded(flex: 3, child: _buildCameraPreview()),
                statusBar,
                Expanded(flex: 2, child: buildForm(const EdgeInsets.all(16))),
              ],
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: Colors.black,
                              child: _buildCameraPreview(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        statusBar,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: buildForm(const EdgeInsets.all(20)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Staff Face Registration Widget (with permission check)
class StaffFaceRegistrationWidget extends StatefulWidget {
  final String token;
  final String regNo;
  final String name;
  final String dept;

  const StaffFaceRegistrationWidget({
    super.key,
    required this.token,
    required this.regNo,
    required this.name,
    required this.dept,
  });

  @override
  State<StaffFaceRegistrationWidget> createState() =>
      _StaffFaceRegistrationWidgetState();
}

class _StaffFaceRegistrationWidgetState
    extends State<StaffFaceRegistrationWidget> {
  bool _isRegistered = false;
  bool _hasPermission = false;
  bool _isLoading = true;
  String _message = "";

  @override
  void initState() {
    super.initState();
    _checkFaceStatus();
  }

  Future<void> _checkFaceStatus() async {
    try {
      final response = await http.get(
        Uri.parse("${API_URL}/face/status/${widget.regNo}"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isRegistered = data['face_registered'] ?? false;
          _hasPermission = data['can_reregister'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = "Error checking status: $e";
        _isLoading = false;
      });
    }
  }

  void _navigateToRegistration() {
    if (_isRegistered && !_hasPermission) {
      // Staff users need to contact HOD for permission
      setState(
        () =>
            _message = "Please contact your HOD for permission to re-register.",
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRegistrationWidget(
          token: widget.token,
          role: 'staff',
          initialRegNo: widget.regNo,
          initialName: widget.name,
          initialDept: widget.dept,
          registerEndpoint: '/staff/face/register',
          onSuccess: () => _checkFaceStatus(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isRegistered ? Icons.check_circle : Icons.warning,
                  color: _isRegistered ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Face Registration",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _isRegistered
                            ? "Your face is registered"
                            : "Face not registered yet",
                        style: TextStyle(
                          fontSize: 12,
                          color: _isRegistered
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _navigateToRegistration,
                  icon: Icon(_isRegistered ? Icons.refresh : Icons.add),
                  label: Text(_isRegistered ? "Re-register" : "Register"),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isRegistered
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ],
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
            if (_isRegistered && _hasPermission) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You have permission to re-register your face",
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Face Verification Widget for attendance marking
class FaceVerificationWidget extends StatefulWidget {
  final String token;
  final String regNo;
  final String name;
  final String dept;
  final VoidCallback? onVerified;
  final VoidCallback? onCancel;

  const FaceVerificationWidget({
    super.key,
    required this.token,
    required this.regNo,
    required this.name,
    required this.dept,
    this.onVerified,
    this.onCancel,
  });

  @override
  State<FaceVerificationWidget> createState() => _FaceVerificationWidgetState();
}

class _FaceVerificationWidgetState extends State<FaceVerificationWidget> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isVerifying = false;
  String _statusMessage = "Position your face in the frame";
  bool _hasFace = false;
  bool _isVerified = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      _controller = CameraController(
        _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        ),
        kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      setState(() => _statusMessage = "Camera error: $e");
    }
  }

  Future<void> _verifyFace() async {
    if (_isVerifying || !_isInitialized) return;

    setState(() {
      _isVerifying = true;
      _statusMessage = "Verifying...";
    });

    try {
      // VPN Check (runs on ALL platforms including web)
      await AppSettings.refreshSettings();
      final vpnError = await VpnChecker.validateVpnStatus();
      if (vpnError != null) {
        setState(() {
          _statusMessage = "Error: $vpnError";
        });
        return;
      }

      // Check geofence before marking attendance
      final geoDecision = await GeoFenceChecker.checkAttendanceFence();
      if (geoDecision.error != null) {
        setState(() {
          _statusMessage = "Error: ${geoDecision.error}";
        });
        _showGeofenceWarningDialog(geoDecision.error!);
        return;
      }

      // Check WiFi connection before marking attendance - web completely skips WiFi checks
      if (!kIsWeb &&
          CollegeIPConfig.isWifiCheckEnabled &&
          !AppSettings.allowAnyNetwork) {
        final wifiError = await WifiChecker.validateCollegeWifi();
        if (wifiError != null) {
          setState(() {
            _statusMessage = "Error: $wifiError";
          });
          
          if (wifiError.contains("SSID") || wifiError.contains("location") || wifiError.contains("Location")) {
            _showGeofenceWarningDialog("To verify WiFi connection, please turn on Location Services (GPS) and grant permission.");
          }
          return;
        }
      }

      setState(() => _statusMessage = "Verifying face...");

      final XFile imageFile = await _controller!.takePicture();

      // Send to backend for verification
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("${API_URL}/mark_attendance"),
      );

      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['reg_no'] = widget.regNo;

      // Attach client location for server-side geofence enforcement.
      // For APP: GeoFenceChecker.lastFetchedPosition is always set when geofence
      // check passed (inside fence). For WEB: also try fetching fresh if needed.
      Position? position = GeoFenceChecker.lastFetchedPosition;

      // For web: if no cached position and geofence is enforced, fetch fresh position
      if (position == null && kIsWeb && geoDecision.enforced) {
        late final Position pos;
        int retries = 5;
        
        for (int i = 0; i < retries; i++) {
          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 20),
            );
            break;
          } catch (e) {
            // Try last known position
            try {
              final lastPos = await Geolocator.getLastKnownPosition();
              if (lastPos != null) {
                pos = lastPos;
                break;
              }
            } catch (_) {}
            
            if (i < 2) {
              try {
                pos = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.reduced,
                  timeLimit: const Duration(seconds: 10),
                );
                break;
              } catch (_) {}
            }
            
            if (i == retries - 1) {
              setState(() {
                _statusMessage =
                    "Error: Unable to get your location. Please:\n1. Refresh the page\n2. Click location icon in browser address bar\n3. Select \"Allow\" for this site\n4. Ensure you are on HTTPS";
              });
              return;
            }
            
            await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
          }
        }
        position = pos;
      }

      // If geofence is enforced but no position is resolved, block as a safety net
      // on both web and app platforms.
      if (geoDecision.enforced && position == null) {
        setState(() {
          _statusMessage = "Error: Unable to verify your location. Please try again.";
        });
        _showGeofenceWarningDialog("Unable to verify your location. Please enable GPS/location services and try again.");
        return;
      }

      // Always send client platform — backend relies on this to distinguish web vs app
      final clientPlatform = kIsWeb ? 'web' : 'app';
      request.fields['client_platform'] = clientPlatform;
      request.headers['X-Client-Platform'] = clientPlatform;

      // ALWAYS send coordinates when geofencing is enforced — backend uses
      // these as second-layer verification even after client-side geofence passed.
      if (geoDecision.enforced && position != null) {
        request.fields['client_lat'] = position.latitude.toString();
        request.fields['client_lng'] = position.longitude.toString();
      }

      final bytes = await imageFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          bytes,
          filename: "face_verify.jpg",
        ),
      );

      var response = await request.send();
      var body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(body);
        setState(() {
          _hasFace = true;
          _isVerified = true;
          _statusMessage =
              "✅ ${json['message'] ?? 'Attendance marked successfully!'}";
        });
        widget.onVerified?.call();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      } else {
        // Handle both 'error' (new format) and 'detail' (legacy format)
        String errorMsg = 'Verification failed';
        try {
          final errorJson = jsonDecode(body);
          errorMsg =
              errorJson['error'] ??
              errorJson['detail'] ??
              'Verification failed';
        } catch (e) {
          // If JSON parsing fails, use a generic message
          errorMsg = response.statusCode == 500
              ? "Server error. Please try again."
              : "Verification failed";
        }
        setState(() {
          _hasFace = true;
          _statusMessage = "❌ $errorMsg";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
      });
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _showGeofenceWarningDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              "Geofence Warning",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Attendance Denied",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Please ensure you are physically present inside the designated college campus boundaries.",
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
      );
    }

    return GestureDetector(
      onTap: _isVerifying ? null : _verifyFace,
      child: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(_controller!)),
          // Transparent overlay to capture taps on web (video element blocks gestures)
          Positioned.fill(
            child: GestureDetector(
              onTap: _isVerifying ? null : _verifyFace,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // Animated Scanning Mask
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: FaceScannerMaskPainter(
                    scanProgress: _animationController.value,
                    faceDetected: _hasFace,
                    faceQuality: _isVerified ? 1.0 : (_hasFace ? 0.75 : 0.0),
                  ),
                );
              },
            ),
          ),

          if (_isVerifying)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.deepPurpleAccent),
                      const SizedBox(height: 16),
                      Text(
                        "Verifying...",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = Container(
      padding: const EdgeInsets.all(16),
      color: Colors.deepPurple.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${widget.regNo} â€¢ ${widget.dept}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final statusBar = Container(
      padding: const EdgeInsets.all(16),
      color: _isVerified
          ? Colors.green.withValues(alpha: 0.1)
          : _hasFace
          ? Colors.blue.withValues(alpha: 0.1)
          : Colors.grey[100]!,
      child: Row(
        children: [
          Icon(
            _isVerified
                ? Icons.check_circle
                : _hasFace
                ? Icons.face
                : Icons.info,
            color: _isVerified
                ? Colors.green
                : _hasFace
                ? Colors.blue
                : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: _isVerified
                    ? Colors.green[700]
                    : _hasFace
                    ? Colors.blue[700]
                    : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    final instructions = Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100]!,
      child: Column(
        children: [
          Text(
            "Tap the camera to verify your face for attendance",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepIcon(1, "Position Face", Icons.face),
              _buildStepIcon(2, "Tap to Capture", Icons.touch_app),
              _buildStepIcon(3, "Verify", Icons.check_circle),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Verification"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (!isWide) {
            return Column(
              children: [
                userInfo,
                Expanded(flex: 3, child: _buildCameraPreview()),
                statusBar,
                instructions,
              ],
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: Colors.black,
                              child: _buildCameraPreview(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        statusBar,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        userInfo,
                        const SizedBox(height: 12),
                        instructions,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepIcon(int step, String label, IconData icon) {
    final isActive = _isVerified ? step <= 3 : step == 1;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.deepPurple : Colors.grey[300],
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.grey[500],
            size: 16,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? Colors.deepPurple : Colors.grey[400],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (step < 3) const SizedBox(width: 16),
      ],
    );
  }
}

/// Custom painter for futuristic scanning HUD with oval mask
class FaceScannerMaskPainter extends CustomPainter {
  final double scanProgress;
  final bool faceDetected;
  final double faceQuality;

  FaceScannerMaskPainter({
    required this.scanProgress,
    required this.faceDetected,
    required this.faceQuality,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maskPaint = Paint()
      ..color = Colors.black.withOpacity(0.70)
      ..style = PaintingStyle.fill;

    // Dimensions of the viewport scanning oval
    final ovalWidth = size.width * 0.68;
    final ovalHeight = ovalWidth * 1.28;
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final rect = Rect.fromCenter(center: center, width: ovalWidth, height: ovalHeight);

    // Screen backdrop mask
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addOval(rect);
    final maskPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(maskPath, maskPaint);

    // Dynamic scanning ring colors
    final Color ringColor = faceDetected
        ? (faceQuality > 0.75 ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
        : const Color(0xFF6366F1); // Green, Orange, Indigo

    // Draw scanning border ring
    final borderPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawOval(rect, borderPaint);

    // Draw futuristic corner brackets around the scanner
    final cornerPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // Top-Left corner bracket
    canvas.drawArc(Rect.fromLTWH(rect.left - 10, rect.top - 10, 40, 40), 3.14, 1.57, false, cornerPaint);
    // Top-Right corner bracket
    canvas.drawArc(Rect.fromLTWH(rect.right - 30, rect.top - 10, 40, 40), 4.71, 1.57, false, cornerPaint);
    // Bottom-Left corner bracket
    canvas.drawArc(Rect.fromLTWH(rect.left - 10, rect.bottom - 30, 40, 40), 1.57, 1.57, false, cornerPaint);
    // Bottom-Right corner bracket
    canvas.drawArc(Rect.fromLTWH(rect.right - 30, rect.bottom - 30, 40, 40), 0.0, 1.57, false, cornerPaint);

    // Draw active scanning line moving down the oval viewport
    if (faceDetected) {
      final double laserY = rect.top + (rect.height * scanProgress);

      // Verify that coordinates lie within the oval curve bound width
      final double distFromCenterY = (laserY - center.dy).abs();
      final double ratioY = distFromCenterY / (ovalHeight / 2);
      if (ratioY < 1.0) {
        final double factorX = math.sqrt(1.0 - ratioY * ratioY);
        final double boundX = (ovalWidth / 2) * factorX;
        final double actualX1 = center.dx - (boundX * 0.85);
        final double actualX2 = center.dx + (boundX * 0.85);

        final laserPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              ringColor.withOpacity(0.0),
              ringColor.withOpacity(0.85),
              ringColor.withOpacity(0.0),
            ],
          ).createShader(Rect.fromLTRB(actualX1, laserY - 2, actualX2, laserY + 2))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5;

        canvas.drawLine(Offset(actualX1, laserY), Offset(actualX2, laserY), laserPaint);

        // Scan reflection glow
        final glowPaint = Paint()
          ..color = ringColor.withOpacity(0.12)
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(center.dx, laserY), width: (actualX2 - actualX1), height: 16),
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaceScannerMaskPainter oldDelegate) {
    return oldDelegate.scanProgress != scanProgress ||
        oldDelegate.faceDetected != faceDetected ||
        oldDelegate.faceQuality != faceQuality;
  }
}

