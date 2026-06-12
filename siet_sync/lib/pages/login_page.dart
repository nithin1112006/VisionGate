import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/college_ip_config.dart';
import '../services/session_service.dart';
import '../utils/validators.dart';
import '../utils/vpn_check.dart';
import '../utils/api_response_utils.dart';
import 'admin_panel.dart';
import 'hod_panel.dart';
import 'staff_panel.dart';
import 'other_staff_login.dart';
import '../widgets/face_registration_widget.dart';

String get API_URL => CollegeIPConfig.apiBaseURL;

class AppColors {
  static const Color orange = Color(0xFF6366F1); // Modernized Indigo
  static const Color orangePaleDark = Color(0xFF1E1B4B); // Deep Indigo
  static const Color orangeLight = Color(0xFF818CF8);
  static const Color orangePale = Color(0xFFEEF2F6);
  static const Color yellow = Color(0xFFEC4899); // Modernized Pink/Magenta
  static const Color yellowPaleDark = Color(0xFF3B0764); // Deep Purple
  static const Color yellowLight = Color(0xFFF472B6);
  static const Color yellowPale = Color(0xFFFDF2F8);
  static const Color green = Color(0xFF10B981); // Emerald Green
  static const Color greenLight = Color(0xFF34D399);
  static const Color greenPale = Color(0xFFECFDF5);
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMedium = Color(0xFF475569);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkGrey = Color(0xFF94A3B8);
}

class FloatingParticle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  Color color;

  FloatingParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.color,
  });
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool isLoading = true;
  String errorMsg = '';
  bool rememberMe = false;
  late AnimationController _fadeController;
  late AnimationController _particleController;
  late Animation<double> _fadeAnimation;
  List<FloatingParticle> _particles = [];
  final Random _random = Random();

  List<Map<String, String>> get servers =>
      CollegeIPConfig.getServersForDropdown();

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
    _checkVpnStatus();
  }

  Future<void> _checkVpnStatus() async {
    final vpnError = await VpnChecker.validateVpnStatus();
    if (vpnError != null && mounted) {
      setState(() => errorMsg = vpnError);
    }
  }

  Future<void> _checkExistingSession() async {
    final session = await sessionService.getSession();
    if (session != null) {
      _navigateToDashboard(session.token, session.user, session.role);
    } else {
      setState(() => isLoading = false);
      _initAnimations();
    }
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..addListener(_updateParticles);

    _initParticles();
    _particleController.repeat();
  }

  void _initParticles() {
    _particles = List.generate(25, (index) {
      final colorChoice = _random.nextInt(3);
      Color particleColor;
      switch (colorChoice) {
        case 0:
          particleColor = AppColors.orange;
          break;
        case 1:
          particleColor = const Color.fromARGB(255, 200, 182, 19);
          break;
        default:
          particleColor = AppColors.green;
      }

      return FloatingParticle(
        x: _random.nextDouble() * 500,
        y: _random.nextDouble() * 800,
        size: _random.nextDouble() * 8 + 4,
        speedX: (_random.nextDouble() - 0.5) * 1.5,
        speedY: (_random.nextDouble() - 0.5) * 1.5,
        color: particleColor.withOpacity(_random.nextDouble() * 0.3 + 0.15),
      );
    });
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (var particle in _particles) {
        particle.x += particle.speedX;
        particle.y += particle.speedY;
        if (particle.x < 0 || particle.x > 500) particle.speedX *= -1;
        if (particle.y < 0 || particle.y > 800) particle.speedY *= -1;
      }
    });
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    _fadeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final usernameError = Validators.validateUsername(usernameCtrl.text);
    if (usernameError != null) {
      setState(() => errorMsg = usernameError);
      return;
    }

    final passwordError = Validators.validatePassword(passwordCtrl.text);
    if (passwordError != null) {
      setState(() => errorMsg = passwordError);
      return;
    }

    // Check for VPN
    final vpnError = await VpnChecker.validateVpnStatus();
    if (vpnError != null) {
      setState(() => errorMsg = vpnError);
      return;
    }

    setState(() {
      isLoading = true;
      errorMsg = '';
    });

    try {
      final deviceSessionId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
      final response = await http.post(
        Uri.parse('$API_URL/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameCtrl.text,
          'password': passwordCtrl.text,
          'device_id': deviceSessionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = ApiResponseUtils.tryParseJson(response.body);
        if (data == null) {
          setState(
            () => errorMsg =
                'Login failed: invalid server response. Please verify backend URL/server status.',
          );
          return;
        }
        final user = data['user'];
        final role = user['role']?.toString().toLowerCase() ?? '';

        await sessionService.saveSession(
          SessionData(
            token: data['token'],
            user: user,
            role: role,
            loginTime: DateTime.now(),
            deviceSessionId: deviceSessionId,
          ),
        );

        _navigateToDashboard(data['token'], user, role);
      } else {
        final parsed = ApiResponseUtils.tryParseJson(response.body);
        final serverMessage =
            parsed?['detail'] ??
            parsed?['message'] ??
            parsed?['error'] ??
            ApiResponseUtils.nonJsonErrorMessage(
              response.statusCode,
              response.body,
            );
        setState(() => errorMsg = serverMessage ?? 'Login failed');
      }
    } catch (e) {
      setState(() => errorMsg = 'Connection error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _navigateToDashboard(
    String token,
    Map<String, dynamic> user,
    String role,
  ) {
    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AdminDashboardPage(token: token, user: user),
        ),
      );
    } else if (role == 'hod') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HODDashboardPage(token: token, user: user),
        ),
      );
    } else if (role == 'staff') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StaffDashboardPage(token: token, user: user),
        ),
      );
    } else if ([
      'principal',
      'placement_staff',
      'placement',
      'lab_technician',
      'lab_tech',
      'labtech',
      'system_admin',
      'systemadmin',
      'office_staff',
      'vice_chancellor',
      'director',
      'dean',
    ].contains(role)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              OtherStaffDashboardPage(token: token, user: user),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              GeneralUserDashboardPage(token: token, user: user),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.textDarkGrey : AppColors.textDark;
    final textSecondaryColor = isDark
        ? AppColors.textDarkGrey
        : AppColors.textMedium;
    final paleColor1 = isDark ? AppColors.orangePaleDark : AppColors.orangePale;
    final paleColor2 = isDark ? AppColors.yellowPaleDark : AppColors.yellowPale;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: bgColor),
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _GridPatternPainter(color: borderColor),
            ),
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) => CustomPaint(
                size: Size.infinite,
                painter: _LightParticlePainter(particles: _particles),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    paleColor1.withOpacity(0.3),
                    paleColor2.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            _LightAnimatedGlow(
              color: AppColors.orange,
              initialPosition: const Offset(80, 80),
              duration: const Duration(seconds: 8),
            ),
            _LightAnimatedGlow(
              color: AppColors.yellow,
              initialPosition: Offset(size.width - 180, size.height * 0.25),
              duration: const Duration(seconds: 10),
            ),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 420,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.orange.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 80,
                              width: 80,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.orange,
                                        AppColors.yellow,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.orange, AppColors.green],
                          ).createShader(bounds),
                          child: Text(
                            'Faculty Sphere',
                            style: TextStyle(
                              fontSize: isMobile ? 28 : 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Smart Attendance System',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Welcome Back',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to continue',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondaryColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: usernameCtrl,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(
                                    Validators.maxUsernameLength,
                                  ),
                                  FilteringTextInputFormatter.deny(
                                    RegExp(r'\s'),
                                  ),
                                ],
                                onChanged: (value) {
                                  final trimmed = value.trimRight();
                                  if (value != trimmed) {
                                    usernameCtrl.text = trimmed;
                                    usernameCtrl.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(offset: trimmed.length),
                                        );
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'Username / Reg No',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: textSecondaryColor,
                                  ),
                                  filled: true,
                                  fillColor: bgColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.orange,
                                      width: 2,
                                    ),
                                  ),
                                  labelStyle: TextStyle(
                                    color: textSecondaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: passwordCtrl,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(
                                    Validators.maxPasswordLength,
                                  ),
                                ],
                                onChanged: (value) {
                                  final trimmed = value.trimRight();
                                  if (value != trimmed) {
                                    passwordCtrl.text = trimmed;
                                    passwordCtrl.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(offset: trimmed.length),
                                        );
                                  }
                                },
                                onFieldSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: textSecondaryColor,
                                  ),
                                  filled: true,
                                  fillColor: bgColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.orange,
                                      width: 2,
                                    ),
                                  ),
                                  labelStyle: TextStyle(
                                    color: textSecondaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (errorMsg.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          errorMsg,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  final Color color;
  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += spacing)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _GridPatternPainter oldDelegate) => false;
}

class _LightParticlePainter extends CustomPainter {
  final List<FloatingParticle> particles;
  _LightParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(particle.x, particle.y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightParticlePainter oldDelegate) => true;
}

class _LightAnimatedGlow extends StatefulWidget {
  final Color color;
  final Offset initialPosition;
  final Duration duration;

  const _LightAnimatedGlow({
    required this.color,
    required this.initialPosition,
    required this.duration,
  });

  @override
  State<_LightAnimatedGlow> createState() => _LightAnimatedGlowState();
}

class _LightAnimatedGlowState extends State<_LightAnimatedGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.1,
      end: 0.25,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          left: widget.initialPosition.dx,
          top: widget.initialPosition.dy,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color.withOpacity(_animation.value),
                  widget.color.withOpacity(_animation.value * 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GeneralUserDashboardPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const GeneralUserDashboardPage({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<GeneralUserDashboardPage> createState() =>
      _GeneralUserDashboardPageState();
}

class _GeneralUserDashboardPageState extends State<GeneralUserDashboardPage> {
  int _selectedIndex = 0;
  bool _isRegistered = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFaceStatus();
  }

  Future<void> _checkFaceStatus() async {
    final role = widget.user['role']?.toString() ?? '';
    final isOtherStaff = [
      'principal',
      'placement_staff',
      'lab_technician',
      'system_admin',
      'office_staff',
    ].contains(role.toLowerCase());

    try {
      final url = isOtherStaff
          ? "$API_URL/other_staff/face/status"
          : "$API_URL/face/status/${widget.user['regNo']}";
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isRegistered = data['face_registered'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _logout() {
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role']?.toString() ?? 'User';
    final displayRole = role
        .replaceAll('custom_', '')
        .replaceAll('_', ' ')
        .toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAccent = Colors.teal;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$displayRole Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark
            ? const Color(0xFF000000)
            : const Color(0xFFF2F2F7),
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        leading: Builder(
          builder: (context) => Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                Icons.menu,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                Icons.logout,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: _logout,
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF2F2F7),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: userAccent))
          : _selectedIndex == 0
          ? _buildDashboard()
          : _buildFaceRegistration(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        indicatorColor: userAccent.withValues(alpha: 0.2),
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
              color: isDark ? Colors.white : Colors.black,
            ),
            selectedIcon: Icon(Icons.dashboard, color: userAccent),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.face_outlined,
              color: isDark ? Colors.white : Colors.black,
            ),
            selectedIcon: Icon(Icons.face, color: userAccent),
            label: 'My Face',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = widget.user['role']?.toString() ?? 'User';
    final displayRole = role
        .replaceAll('custom_', '')
        .replaceAll('_', ' ')
        .toUpperCase();

    return Drawer(
      child: Container(
        color: isDark ? const Color(0xFF000000) : Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 24,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1C1C1E), const Color(0xFF2C2C2E)]
                      : [Colors.teal, const Color(0xFF26A69A)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayRole,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user['name'] ?? 'User',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.dashboard,
                  color: Colors.teal,
                  size: 22,
                ),
              ),
              title: Text(
                'Dashboard',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey.shade700,
                ),
              ),
              selected: _selectedIndex == 0,
              selectedTileColor: Colors.teal.withValues(alpha: 0.1),
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isRegistered ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isRegistered ? Icons.check_circle : Icons.face,
                  color: _isRegistered ? Colors.green : Colors.orange,
                  size: 22,
                ),
              ),
              title: Text(
                _isRegistered ? 'Face Registered' : 'Register Face',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey.shade700,
                ),
              ),
              selected: _selectedIndex == 1,
              selectedTileColor: Colors.teal.withValues(alpha: 0.1),
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3D1A1A)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red.shade400,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: _logout,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = widget.user['role']?.toString() ?? 'User';
    final displayRole = role
        .replaceAll('custom_', '')
        .replaceAll('_', ' ')
        .toUpperCase();
    final userAccent = Colors.teal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1C1C1E), const Color(0xFF2C2C2E)]
                    : [userAccent, const Color(0xFF26A69A)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: userAccent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.waving_hand,
                        color: Colors.white,
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                          Text(
                            widget.user['name'] ?? 'User',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.badge,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: isSmallScreen ? 16 : 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          displayRole,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: isSmallScreen ? 11 : 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: userAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: userAccent,
                  size: isSmallScreen ? 18 : 22,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxGridWidth = isSmallScreen ? double.infinity : 520.0;
              return Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: min(constraints.maxWidth, maxGridWidth),
                  ),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isSmallScreen ? 1.15 : 1.1,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildActionCard(
                        icon: _isRegistered ? Icons.check_circle : Icons.face,
                        title: _isRegistered
                            ? 'Face Registered'
                            : 'Register Face',
                        color: _isRegistered ? Colors.green : Colors.orange,
                        onTap: () => setState(() => _selectedIndex = 1),
                      ),
                      _buildActionCard(
                        icon: Icons.logout,
                        title: 'Logout',
                        color: Colors.red,
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: userAccent.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: userAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: userAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.info,
                        color: userAccent,
                        size: isSmallScreen ? 18 : 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Important Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: userAccent,
                          fontSize: isSmallScreen ? 13 : 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Register your face to mark attendance\n• Make sure you are in good lighting\n• Look at the camera when marking attendance',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[700],
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w500, color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaceRegistration() {
    final role = widget.user['role']?.toString() ?? '';
    final isOtherStaff = [
      'principal',
      'placement_staff',
      'lab_technician',
      'system_admin',
      'office_staff',
    ].contains(role.toLowerCase());
    final registerEndpoint = isOtherStaff
        ? '/other_staff/face/register'
        : '/admin/face/register';

    return SingleChildScrollView(
      child: FaceRegistrationWidget(
        token: widget.token,
        role: widget.user['role'] ?? 'staff',
        initialRegNo: widget.user['regNo'],
        initialName: widget.user['name'],
        initialDept: widget.user['dept'],
        registerEndpoint: registerEndpoint,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face registered successfully!')),
          );
          _checkFaceStatus();
        },
      ),
    );
  }
}
