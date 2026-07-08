import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/college_ip_config.dart';
import '../services/api_client.dart';
import '../services/location_tracking_service.dart';
import '../services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/responsive.dart';
import '../utils/api_response_utils.dart';
import '../widgets/advanced_stat_card.dart';
import '../widgets/quick_access_stat_card.dart';
import '../widgets/face_registration_widget.dart';
import '../widgets/user_settings_tab.dart';
import '../widgets/leave_request_widget.dart';
import '../widgets/location_permission_enforcer.dart';
import '../services/leave_balance_notifier.dart';
import '../services/pre_verification_service.dart';
import 'attendance_log_page.dart';


String get API_URL => CollegeIPConfig.defaultURL;

int javaScriptRandomInt() {
  return Random().nextInt(999999);
}

class StaffLoginPage extends StatefulWidget {
  const StaffLoginPage({super.key});

  @override
  State<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool isLoading = false;
  String errorMsg = '';

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      setState(() => errorMsg = 'Please enter username and password');
      return;
    }

    setState(() {
      isLoading = true;
      errorMsg = '';
    });

    try {
      final deviceSessionId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${javaScriptRandomInt()}';
      final response = await http.post(
        Uri.parse('$API_URL/staff/login'),
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
        await sessionService.saveSession(
          SessionData(
            token: data['token'],
            user: data['user'],
            role: 'staff',
            loginTime: DateTime.now(),
            deviceSessionId: deviceSessionId,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StaffDashboardPage(token: data['token'], user: data['user']),
          ),
        );
      } else {
        final data = ApiResponseUtils.tryParseJson(response.body);
        setState(() {
          errorMsg =
              data?['detail'] ??
              data?['message'] ??
              data?['error'] ??
              ApiResponseUtils.nonJsonErrorMessage(
                response.statusCode,
                response.body,
              );
          passwordCtrl.clear();
        });
      }
    } catch (e) {
      setState(() => errorMsg = ApiResponseUtils.sanitize(e));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iOSBlue = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF000000), const Color(0xFF1C1C1E)]
                : [iOSBlue, const Color(0xFF5AC8FA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 20 : 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 420,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.5 : 0.15,
                        ),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isMobile ? 24 : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // iOS-style logo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: iOSBlue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: iOSBlue.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Staff Portal',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Faculty/Staff Login',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey[600],
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // iOS-style text fields
                      TextField(
                        controller: usernameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iOSBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.person_outline,
                              color: iOSBlue,
                              size: 22,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF2F2F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: iOSBlue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 16,
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iOSBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.lock_outline,
                              color: iOSBlue,
                              size: 22,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF2F2F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: iOSBlue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 16,
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (errorMsg.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3D1A1A)
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF5D2A2A)
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade400,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  errorMsg,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.red.shade300
                                        : Colors.red.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      // iOS-style button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: iOSBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      'Login as Staff',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 18, color: iOSBlue),
                            const SizedBox(width: 6),
                            Text(
                              'Back to Home',
                              style: TextStyle(color: iOSBlue, fontSize: 15),
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
        ),
      ),
    );
  }
}

class StaffDashboardPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const StaffDashboardPage({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  int _selectedIndex = 0;
  StreamSubscription<String>? _warningSub;

  final List<Widget> _pages = [];
  final List<String> _titles = [
    'Dashboard',
    'Mark My Attendance',
    'My Face',
    'Leave Requests',
    'Attendance Log',
    'Settings',
  ];

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 3) {
      LeaveBalanceNotifier.instance.notifyBalanceChanged();
    }
  }

  void _checkOfflineViolations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool('offline_rules_violated') == true) {
      final msg = prefs.getString('offline_violation_message') ?? 'Rule violation detected during offline tracking. You have been marked absent.';
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 10),
                Text('Rule Violation Warning'),
              ],
            ),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await prefs.remove('offline_rules_violated');
                  await prefs.remove('offline_violation_message');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkOfflineViolations();
    if (!kIsWeb) {
      LocationTrackingService.instance.startTracking(
        token: widget.token,
        user: widget.user,
      );
      _warningSub = LocationTrackingService.instance.warningStream.listen((warning) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _BoundaryBreachDialog(message: warning),
          );
        }
      });
    }
    _pages.addAll([
      StaffDashboardTab(
        token: widget.token,
        user: widget.user,
        onTabSelected: _onTabSelected,
      ),
      StaffMarkAttendanceTab(token: widget.token, user: widget.user),
      StaffFaceRegisterTab(token: widget.token, user: widget.user),
      StaffLeaveRequestTab(token: widget.token),
      AttendanceLogTab(token: widget.token, user: widget.user),
      UserSettingsTab(title: 'Staff Settings', token: widget.token),
    ]);
  }

  void _logout() async {
    if (!kIsWeb) {
      await _warningSub?.cancel();
      await LocationTrackingService.instance.stopTracking();
    }
    await sessionService.clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _warningSub?.cancel();
      LocationTrackingService.instance.stopTracking();
    }
    super.dispose();
  }

  static const List<NavDestination> _navDestinations = [
    NavDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    NavDestination(
      icon: Icons.qr_code_scanner_outlined,
      selectedIcon: Icons.qr_code_scanner_rounded,
      label: 'Attend',
    ),
    NavDestination(
      icon: Icons.face_outlined,
      selectedIcon: Icons.face_rounded,
      label: 'My Face',
    ),
    NavDestination(
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
      label: 'Leave',
    ),
    NavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final iOSBlue = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaffold = AdaptiveScaffold(
      title: _titles[_selectedIndex],
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
        if (index == 3) {
          LeaveBalanceNotifier.instance.notifyBalanceChanged();
        }
      },
      destinations: _navDestinations,
      accentColor: iOSBlue,
      drawer: _buildDrawer(context),
      onLogout: _logout,
      body: Stack(
        children: [
          if (!kIsWeb) ...[
            Positioned(
              top: -120,
              left: -120,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: isDark ? 0.22 : 0.12),
                      const Color(0xFF6366F1).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 50,
              right: -150,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFEC4899).withValues(alpha: isDark ? 0.18 : 0.08),
                      const Color(0xFFEC4899).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 300,
              right: 120,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.05),
                      const Color(0xFF10B981).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: 100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.15 : 0.06),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
          RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _pages.clear();
                _pages.addAll([
                  StaffDashboardTab(
                    token: widget.token,
                    user: widget.user,
                    onTabSelected: _onTabSelected,
                  ),
                  StaffMarkAttendanceTab(token: widget.token, user: widget.user),
                  StaffFaceRegisterTab(token: widget.token, user: widget.user),
                  StaffLeaveRequestTab(token: widget.token),
                  AttendanceLogTab(token: widget.token, user: widget.user),
                  UserSettingsTab(title: 'Staff Settings', token: widget.token),
                ]);
              });
              await Future.delayed(const Duration(milliseconds: 100));
            },
            color: iOSBlue,
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );

    return kIsWeb ? scaffold : LocationPermissionEnforcer(child: scaffold);
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iOSBlue = Theme.of(context).colorScheme.primary;

    return Drawer(
      child: Container(
        color: isDark ? const Color(0xFF000000) : Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // iOS-style Drawer Header
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
                      : [iOSBlue, const Color(0xFF5AC8FA)],
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
                    'Staff Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user['name'] ?? 'Staff',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.user['dept']?.toUpperCase() ?? 'FACULTY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildDrawerItem(
              0,
              Icons.dashboard_rounded,
              'Dashboard',
              Icons.dashboard_outlined,
            ),
            _buildDrawerItem(
              1,
              Icons.qr_code_scanner_rounded,
              'Mark Attendance',
              Icons.qr_code_scanner_outlined,
            ),
            _buildDrawerItem(
              2,
              Icons.face_rounded,
              'My Face',
              Icons.face_outlined,
            ),
            _buildDrawerItem(
              3,
              Icons.event_note_rounded,
              'Leave Requests',
              Icons.event_note_outlined,
            ),
            _buildDrawerItem(
              4,
              Icons.history_edu_rounded,
              'Attendance Log',
              Icons.history_edu_outlined,
            ),
            _buildDrawerItem(
              5,
              Icons.settings_rounded,
              'Settings',
              Icons.settings_outlined,
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

  Widget _buildDrawerItem(
    int index,
    IconData selectedIcon,
    String title,
    IconData unselectedIcon,
  ) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iOSBlue = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected
            ? iOSBlue.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedIndex = index);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? iOSBlue
                        : (isDark
                              ? const Color(0xFF1C1C1E)
                              : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSelected ? selectedIcon : unselectedIcon,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white60 : Colors.grey.shade600),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? iOSBlue
                        : (isDark ? Colors.white : Colors.grey.shade700),
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.chevron_right, color: iOSBlue, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StaffDashboardTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final Function(int)? onTabSelected;

  const StaffDashboardTab({
    super.key,
    required this.token,
    required this.user,
    this.onTabSelected,
  });

  @override
  State<StaffDashboardTab> createState() => _StaffDashboardTabState();
}

class _StaffDashboardTabState extends State<StaffDashboardTab> {
  Map<String, dynamic>? data;
  bool isLoading = true;
  int presentDays = 0;
  int absentDays = 0;
  List<dynamic> myAttendance = [];
  int? _quickAccessIndex;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadQuickAccessIndex();
    fetchDashboard();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchMyAttendance();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _formatTimestamp(dynamic raw) {
    final ts = raw?.toString().trim() ?? '';
    if (ts.isEmpty) return '';
    if (ts.contains('T')) {
      final parts = ts.split('T');
      final date = parts[0];
      final time = parts[1].split('.').first;
      return '$date $time';
    }
    return ts;
  }

  // Available drawer items for quick access
  final List<DrawerItem> _drawerItems = const [
    DrawerItem(
      index: 1,
      icon: Icons.qr_code_scanner_rounded,
      title: 'Mark Attendance',
    ),
    DrawerItem(index: 2, icon: Icons.face_rounded, title: 'My Face'),
    DrawerItem(
      index: 3,
      icon: Icons.event_note_rounded,
      title: 'Leave Requests',
    ),
    DrawerItem(index: 4, icon: Icons.settings_rounded, title: 'Settings'),
  ];

  // Handle quick access widget tap - navigate to the selected tab
  void _onQuickAccessWidgetTap(int index) {
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
    }
  }

  // Load persisted quick access index from storage
  Future<void> _loadQuickAccessIndex() async {
    final storedIndex = await sessionService.getQuickAccessIndex();
    if (storedIndex != null && mounted) {
      setState(() {
        _quickAccessIndex = storedIndex;
      });
    }
  }

  // Save quick access index to storage
  Future<void> _saveQuickAccessIndex(int index) async {
    await sessionService.saveQuickAccessIndex(index);
  }

  Future<void> fetchDashboard() async {
    setState(() => isLoading = true);
    try {
      final role = (widget.user['role'] ?? '').toString().toLowerCase();
      final isHod = role == 'hod';
      final endpoint = isHod ? 'hod' : 'staff';
      // Dashboard with caching (15 minutes for slow networks)
      final response = await apiClient.get(
        '$API_URL/$endpoint/dashboard',
        token: widget.token,
        cacheKey: '${endpoint}_dashboard_${widget.token.hashCode}',
        cacheDuration: const Duration(minutes: 15),
      );
      if (response.statusCode == 200) {
        setState(() => data = jsonDecode(response.body));
      }

      // Fetch personal attendance stats (with caching - 10 minutes for slow networks)
      await fetchMyAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ApiResponseUtils.sanitize(e)}')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchMyAttendance() async {
    try {
      final regNo = widget.user['regNo'];
      final response = await apiClient.get(
        '$API_URL/staff/attendance/$regNo',
        token: widget.token,
        cacheKey: 'staff_attendance_${widget.token.hashCode}_$regNo',
        cacheDuration: const Duration(minutes: 10),
      );
      if (response.statusCode == 200) {
        final attendanceData = jsonDecode(response.body);
        final records = attendanceData['attendance'] ?? [];

        int? newPresent = attendanceData['present_days'];
        int? newAbsent = attendanceData['absent_days'];

        if (newPresent == null || newAbsent == null) {
          // Fallback: count unique days present from records
          final Set<String> uniqueDates = {};
          for (var record in records) {
            final timestamp = record['timestamp']?.toString() ?? '';
            if (timestamp.isNotEmpty) {
              final date = timestamp.contains(' ')
                  ? timestamp.split(' ')[0]
                  : (timestamp.contains('T')
                        ? timestamp.split('T')[0]
                        : timestamp);
              uniqueDates.add(date);
            }
          }
          final now = DateTime.now();
          newPresent = uniqueDates.length;
          newAbsent = (now.day - newPresent).clamp(0, 30);
        }

        if (mounted) {
          setState(() {
            myAttendance = records;
            presentDays = newPresent ?? 0;
            absentDays = newAbsent ?? 0;
          });
        }
      }
    } catch (e) {
      // Silently fail for attendance stats
    }
  }

  void _showMyAttendanceDetails() {
    showDialog(
      context: context,
      builder: (context) => _MyAttendanceDialog(
        token: widget.token,
        name: widget.user['name'] ?? 'Staff',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iOSBlue = Theme.of(context).colorScheme.primary;

    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: iOSBlue));
    }

    final recentAttendance = data?['recent_attendance'] ?? [];
    final pagePadding = Breakpoints.pagePadding(screenWidth);
    final isWide = screenWidth >= 900;
    final gridSpacing = Breakpoints.gridSpacing(screenWidth);

    // A beautiful Glass Bento Card helper
    Widget bentoCard({
      required Widget child,
      Color? accentColor,
      double? height,
      VoidCallback? onTap,
    }) {
      final accent = accentColor ?? iOSBlue;
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.08 : 0.01),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.09),
                              Colors.white.withValues(alpha: 0.02),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.7),
                              Colors.white.withValues(alpha: 0.3),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget welcomeCard() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1C1C1E), const Color(0xFF2C2C2E)]
                : [iOSBlue, const Color(0xFF5AC8FA)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: iOSBlue.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.waving_hand,
                    color: Colors.white,
                    size: 28,
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
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        widget.user['name'] ?? 'Staff',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Department: ${widget.user['dept']?.toUpperCase() ?? 'FACULTY'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
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
      );
    }

    Widget dynamicProgressBento() {
      final double presentRatio = (presentDays + absentDays) > 0
          ? presentDays / (presentDays + absentDays)
          : 1.0;
      return bentoCard(
        accentColor: Colors.teal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Health',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: presentRatio,
                      strokeWidth: 10,
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(presentRatio * 100).toInt()}%',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Present',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black45,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Present: $presentDays d',
                  style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Absent: $absentDays d',
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget recentAttendancePanel() {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Attendance Logs',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: iOSBlue),
                    onPressed: fetchDashboard,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            recentAttendance.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 40, color: isDark ? Colors.white30 : Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No logs registered recently',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentAttendance.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final record = recentAttendance[index];
                      final when = _formatTimestamp(record['timestamp']);
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.green, Colors.teal],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          record['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          record['reg_no'] ?? '',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1D3D1D) : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            when,
                            style: TextStyle(
                              color: Colors.green.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      );
    }

    Widget bentoGrid() {
      if (isWide) {
        // Desktop / Wide Tablet Mosaic Grid
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 220,
                    child: welcomeCard(),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 220,
                    child: dynamicProgressBento(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 180,
                    child: bentoCard(
                      accentColor: Colors.green,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 36),
                          const Spacer(),
                          Text(
                            'Present Days',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                          ),
                          Text(
                            presentDays.toString(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 180,
                    child: bentoCard(
                      accentColor: Colors.red,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cancel_rounded, color: Colors.red, size: 36),
                          const Spacer(),
                          Text(
                            'Absent Days',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                          ),
                          Text(
                            absentDays.toString(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 180,
                    child: bentoCard(
                      accentColor: iOSBlue,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_rounded, color: iOSBlue, size: 36),
                          const Spacer(),
                          Text(
                            'Total Cycles',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                          ),
                          Text(
                            (presentDays + absentDays).toString(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 180,
                    child: QuickAccessStatCard(
                      availableItems: _drawerItems,
                      selectedIndex: _quickAccessIndex,
                      onItemSelected: (index) {
                        setState(() => _quickAccessIndex = index);
                        _saveQuickAccessIndex(index);
                      },
                      onRemove: () {
                        setState(() => _quickAccessIndex = null);
                        sessionService.clearQuickAccessIndex();
                      },
                      onWidgetTap: _onQuickAccessWidgetTap,
                      accentColor: iOSBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      } else {
        // Mobile layout
        return Column(
          children: [
            welcomeCard(),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: dynamicProgressBento(),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: gridSpacing,
              mainAxisSpacing: gridSpacing,
              childAspectRatio: 1.15,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                bentoCard(
                  accentColor: Colors.green,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                      const Spacer(),
                      Text(
                        'Present',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11),
                      ),
                      Text(
                        presentDays.toString(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                bentoCard(
                  accentColor: Colors.red,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cancel_rounded, color: Colors.red, size: 28),
                      const Spacer(),
                      Text(
                        'Absent',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11),
                      ),
                      Text(
                        absentDays.toString(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                bentoCard(
                  accentColor: iOSBlue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_rounded, color: iOSBlue, size: 28),
                      const Spacer(),
                      Text(
                        'Total Days',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11),
                      ),
                      Text(
                        (presentDays + absentDays).toString(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                QuickAccessStatCard(
                  availableItems: _drawerItems,
                  selectedIndex: _quickAccessIndex,
                  onItemSelected: (index) {
                    setState(() => _quickAccessIndex = index);
                    _saveQuickAccessIndex(index);
                  },
                  onRemove: () {
                    setState(() => _quickAccessIndex = null);
                    sessionService.clearQuickAccessIndex();
                  },
                  onWidgetTap: _onQuickAccessWidgetTap,
                  accentColor: iOSBlue,
                ),
              ],
            ),
          ],
        );
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(pagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Breakpoints.contentMaxWidth(screenWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bentoGrid(),
              const SizedBox(height: 20),
              // View detailed attendance button - iOS style
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: iOSBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: iOSBlue.withValues(alpha: 0.3)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showMyAttendanceDetails,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iOSBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.calendar_month,
                              color: iOSBlue,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'View Detailed Attendance',
                            style: TextStyle(
                              color: iOSBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: iOSBlue,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              recentAttendancePanel(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern responsive stat card with gradient accent and glass effect
class ModernStaffStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final bool isSmallScreen;

  const ModernStaffStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconSize = isSmallScreen ? 18.0 : (isMobile ? 20.0 : 22.0);
    final titleSize = isSmallScreen ? 13.0 : 14.0;
    final valueSize = isSmallScreen ? 26.0 : 28.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: color.withOpacity(0.8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleSize,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: valueSize,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick select chip widget
class _QuickSelectChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _QuickSelectChip({
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// My Attendance Dialog Widget
class _MyAttendanceDialog extends StatefulWidget {
  final String token;
  final String name;

  const _MyAttendanceDialog({required this.token, required this.name});

  @override
  State<_MyAttendanceDialog> createState() => _MyAttendanceDialogState();
}

class _MyAttendanceDialogState extends State<_MyAttendanceDialog> {
  List<dynamic> attendanceRecords = [];
  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;
  int presentDays = 0;
  int absentDays = 0;

  @override
  void initState() {
    super.initState();
    _loadDefaultDates();
  }

  Future<void> _loadDefaultDates() async {
    try {
      final response = await http.get(Uri.parse('$API_URL/academics/current'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawRanges = data['academic_ranges'] as List? ?? [];
        if (rawRanges.isNotEmpty && rawRanges[0]['start'] != null && mounted) {
          setState(() {
            startDate = DateTime.parse(rawRanges[0]['start']);
            endDate = DateTime.parse(rawRanges.last['end']);
          });
          fetchAttendance();
          return;
        }
        // Fallback to single range
        if (data['academic_year_start'] != null && mounted) {
          setState(() {
            startDate = DateTime.parse(data['academic_year_start']);
            endDate = DateTime.parse(data['academic_year_end']);
          });
          fetchAttendance();
          return;
        }
      }
    } catch (_) {}
    final now = DateTime.now();
    setState(() {
      startDate = DateTime(now.year, now.month, 1);
      endDate = now;
    });
    fetchAttendance();
  }

  // Quick select methods for common date ranges
  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      startDate = now;
      endDate = now;
    });
    fetchAttendance();
  }

  void _selectThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      startDate = startOfWeek;
      endDate = now;
    });
    fetchAttendance();
  }

  void _selectThisMonth() {
    final now = DateTime.now();
    setState(() {
      startDate = DateTime(now.year, now.month, 1);
      endDate = now;
    });
    fetchAttendance();
  }

  void _selectLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
    setState(() {
      startDate = lastMonth;
      endDate = lastDayOfLastMonth;
    });
    fetchAttendance();
  }

  void _selectLast7Days() {
    final now = DateTime.now();
    setState(() {
      startDate = now.subtract(const Duration(days: 6));
      endDate = now;
    });
    fetchAttendance();
  }

  void _selectLast30Days() {
    final now = DateTime.now();
    setState(() {
      startDate = now.subtract(const Duration(days: 29));
      endDate = now;
    });
    fetchAttendance();
  }

  // Week navigation methods
  void _goToPreviousWeek() {
    if (startDate != null && endDate != null) {
      setState(() {
        startDate = startDate!.subtract(const Duration(days: 7));
        endDate = endDate!.subtract(const Duration(days: 7));
      });
      fetchAttendance();
    }
  }

  void _goToNextWeek() {
    final now = DateTime.now();
    if (startDate != null && endDate != null) {
      // Don't go beyond today
      final newEndDate = endDate!.add(const Duration(days: 7));
      if (newEndDate.isAfter(now)) {
        return;
      }
      setState(() {
        startDate = startDate!.add(const Duration(days: 7));
        endDate = newEndDate;
      });
      fetchAttendance();
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();

    // Load academic range bounds
    DateTime firstDate = DateTime(2024);
    DateTime lastDate = now;
    try {
      final acadResp = await http.get(Uri.parse('$API_URL/academics/current'));
      if (acadResp.statusCode == 200) {
        final acadData = jsonDecode(acadResp.body);
        final rawRanges = acadData['academic_ranges'] as List? ?? [];
        if (rawRanges.isNotEmpty) {
          final parsedStarts = <DateTime>[];
          final parsedEnds = <DateTime>[];
          for (final r in rawRanges) {
            final s = DateTime.tryParse(r['start']?.toString() ?? '');
            final e = DateTime.tryParse(r['end']?.toString() ?? '');
            if (s != null && e != null) {
              parsedStarts.add(s);
              parsedEnds.add(e);
            }
          }
          if (parsedStarts.isNotEmpty) {
            firstDate = parsedStarts.reduce((a, b) => a.isBefore(b) ? a : b);
            lastDate = parsedEnds.reduce((a, b) => a.isAfter(b) ? a : b);
          }
        }
      }
    } catch (_) {}
    if (lastDate.isAfter(now)) lastDate = now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : DateTimeRange(start: startDate ?? DateTime(now.year, now.month, 1), end: endDate ?? now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF007AFF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            textTheme: Theme.of(context).textTheme.copyWith(
              headlineSmall: TextStyle(
                color: const Color(0xFF007AFF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Validate date range
      if (picked.start.isAfter(picked.end)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Start date cannot be after end date'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate not future dates
      if (picked.end.isAfter(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot select future dates'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      fetchAttendance();
    }
  }

  String _formatDate(DateTime date) {
    // For display in UI - dd/mm/yy format
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
  }

  // Format date for API - yyyy-mm-dd format (required by backend)
  String _formatDateForAPI(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> fetchAttendance() async {
    if (startDate == null || endDate == null) return;

    setState(() => isLoading = true);
    try {
      final url =
          '$API_URL/staff/attendance?start_date=${_formatDateForAPI(startDate!)}&end_date=${_formatDateForAPI(endDate!)}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final records = data['attendance'] ?? [];

        // Count unique days
        final Set<String> uniqueDates = {};
        for (var record in records) {
          final timestamp = record['timestamp']?.toString() ?? '';
          if (timestamp.isNotEmpty) {
            // Handle both "2024-03-11 07:04:29" and "2024-03-11T07:04:29" formats
            final date = timestamp.contains(' ')
                ? timestamp.split(' ')[0]
                : (timestamp.contains('T')
                      ? timestamp.split('T')[0]
                      : timestamp);
            uniqueDates.add(date);
          }
        }

        presentDays = data['present_days'] as int? ?? uniqueDates.length;
        final dataAbsentDays = data['absent_days'] as int?;
        if (dataAbsentDays != null) {
          absentDays = dataAbsentDays;
        } else {
          final totalDays = endDate!.difference(startDate!).inDays + 1;
          absentDays = (totalDays - presentDays).clamp(0, totalDays);
        }

        setState(() => attendanceRecords = records);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Attendance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Date range filter - Improved styling
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Previous week button
                  IconButton(
                    onPressed: _goToPreviousWeek,
                    icon: const Icon(Icons.chevron_left),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF007AFF,
                      ).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF007AFF),
                    ),
                    tooltip: 'Previous Week',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      child: Material(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _selectDateRange,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: const Color(0xFF007AFF),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Select Date Range',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        startDate != null && endDate != null
                                            ? '${_formatDate(startDate!)} - ${_formatDate(endDate!)}'
                                            : 'Tap to select dates',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF007AFF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: const Color(0xFF007AFF),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Next week button
                  IconButton(
                    onPressed: _goToNextWeek,
                    icon: const Icon(Icons.chevron_right),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF007AFF,
                      ).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF007AFF),
                    ),
                    tooltip: 'Next Week',
                  ),
                ],
              ),
            ),

            // Quick select buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Select',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickSelectChip(
                          label: 'Today',
                          onTap: _selectToday,
                          color: const Color(0xFF007AFF),
                        ),
                        const SizedBox(width: 8),
                        _QuickSelectChip(
                          label: 'This Week',
                          onTap: _selectThisWeek,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _QuickSelectChip(
                          label: 'This Month',
                          onTap: _selectThisMonth,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _QuickSelectChip(
                          label: 'Last Month',
                          onTap: _selectLastMonth,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _QuickSelectChip(
                          label: 'Last 7 Days',
                          onTap: _selectLast7Days,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 8),
                        _QuickSelectChip(
                          label: 'Last 30 Days',
                          onTap: _selectLast30Days,
                          color: Colors.indigo,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats cards with improved styling
            if (!isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedStatCard(
                        icon: Icons.check_circle,
                        title: 'Present',
                        value: presentDays.toString(),
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedStatCard(
                        icon: Icons.cancel,
                        title: 'Absent',
                        value: absentDays.toString(),
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedStatCard(
                        icon: Icons.calendar_month,
                        title: 'Total',
                        value: (presentDays + absentDays).toString(),
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Attendance list
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : attendanceRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No attendance records found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: attendanceRecords.length,
                      itemBuilder: (context, index) {
                        final record = attendanceRecords[index];
                        final timestamp = record['timestamp']?.toString() ?? '';
                        // Handle both "2024-03-11 07:04:29" and "2024-03-11T07:04:29" formats
                        final datePart = timestamp.contains(' ')
                            ? timestamp.split(' ')[0]
                            : (timestamp.contains('T')
                                  ? timestamp.split('T')[0]
                                  : '');
                        final timePart = timestamp.contains(' ')
                            ? (timestamp.split(' ').length > 1
                                  ? timestamp.split(' ')[1]
                                  : '')
                            : (timestamp.contains('T')
                                  ? timestamp.split('T')[1]
                                  : '');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withValues(
                                alpha: 0.1,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                            ),
                            title: Text(datePart),
                            subtitle: Text('Time: $timePart'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Present',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaffStudentsTab extends StatefulWidget {
  final String token;
  final String dept;

  const StaffStudentsTab({super.key, required this.token, required this.dept});

  @override
  State<StaffStudentsTab> createState() => _StaffStudentsTabState();
}

class _StaffStudentsTabState extends State<StaffStudentsTab> {
  List<dynamic> students = [];
  bool isLoading = true;
  final _formKey = GlobalKey<FormState>();

  final regNoCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final classDivCtrl = TextEditingController();

  @override
  void dispose() {
    regNoCtrl.dispose();
    nameCtrl.dispose();
    classDivCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future<void> fetchStudents() async {
    setState(() => isLoading = true);
    try {
      // Students with caching (10 minutes for slow networks)
      final response = await apiClient.get(
        '$API_URL/staff/students',
        token: widget.token,
        cacheKey: 'staff_students_${widget.token.hashCode}',
        cacheDuration: const Duration(minutes: 10),
      );
      if (response.statusCode == 200) {
        setState(() => students = jsonDecode(response.body)['students']);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> createStudent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final response = await http.post(
        Uri.parse('$API_URL/staff/students/create'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reg_no': regNoCtrl.text,
          'name': nameCtrl.text,
          'class_div': classDivCtrl.text,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student created successfully')),
        );
        fetchStudents();
        _clearForm();
        Navigator.pop(context);
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['detail'] ?? 'Failed to create student')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _clearForm() {
    regNoCtrl.clear();
    nameCtrl.clear();
    classDivCtrl.clear();
  }

  void _showCreateStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Student to ${widget.dept}'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: regNoCtrl,
                  decoration: InputDecoration(
                    labelText: 'Registration Number',
                    prefixIcon: const Icon(Icons.badge),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: classDivCtrl,
                  decoration: InputDecoration(
                    labelText: 'Class/Division (e.g., CSE-A)',
                    prefixIcon: const Icon(Icons.class_),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Student will be added to ${widget.dept}',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: createStudent,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
            ),
            child: const Text('Create Student'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteStudent(String regNo, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete $name ($regNo)? This will also remove their face data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$API_URL/staff/students/$regNo'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted successfully')),
        );
        fetchStudents();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete student')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.dept.toUpperCase()} Students',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total: ${students.length}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: _showCreateStudentDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Student'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: fetchStudents,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No students in ${widget.dept}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _showCreateStudentDialog,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Student'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFF57C00),
                          child: const Icon(
                            Icons.person,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text(student['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student['reg_no'] ?? ''),
                            if (student['class_div'] != null &&
                                student['class_div'].isNotEmpty)
                              Text(
                                'Class: ${student['class_div']}',
                                style: const TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteStudent(
                            student['reg_no'] ?? '',
                            student['name'] ?? '',
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class StaffAttendanceTab extends StatefulWidget {
  final String token;
  final String dept;

  const StaffAttendanceTab({
    super.key,
    required this.token,
    required this.dept,
  });

  @override
  State<StaffAttendanceTab> createState() => _StaffAttendanceTabState();
}

class _StaffAttendanceTabState extends State<StaffAttendanceTab> {
  List<dynamic> attendance = [];
  bool isLoading = true;
  String? selectedDate;

  @override
  void initState() {
    super.initState();
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    setState(() => isLoading = true);
    try {
      final url = selectedDate != null
          ? Uri.parse('$API_URL/staff/attendance?date=$selectedDate')
          : Uri.parse('$API_URL/staff/attendance');
      // Attendance with caching (5 minutes for slow networks)
      final response = await apiClient.get(
        url.toString(),
        token: widget.token,
        cacheKey: 'staff_attendance',
        cacheDuration: const Duration(minutes: 5),
      );
      if (response.statusCode == 200) {
        setState(() => attendance = jsonDecode(response.body)['attendance']);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate != null ? DateTime.parse(selectedDate!) : now,
      firstDate: DateTime(2024),
      lastDate: now,
    );
    if (date != null) {
      setState(() {
        selectedDate =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      });
      fetchAttendance();
    }
  }

  // Week navigation for single date
  void _goToPreviousDay() {
    if (selectedDate != null) {
      final current = DateTime.parse(selectedDate!);
      final previous = current.subtract(const Duration(days: 1));
      setState(() {
        selectedDate =
            '${previous.year}-${previous.month.toString().padLeft(2, '0')}-${previous.day.toString().padLeft(2, '0')}';
      });
      fetchAttendance();
    }
  }

  void _goToNextDay() {
    final now = DateTime.now();
    if (selectedDate != null) {
      final current = DateTime.parse(selectedDate!);
      final next = current.add(const Duration(days: 1));
      // Don't go beyond today
      if (next.isAfter(now)) return;
      setState(() {
        selectedDate =
            '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
      });
      fetchAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${widget.dept.toUpperCase()} Attendance (${attendance.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Previous day button
                      IconButton(
                        onPressed: selectedDate != null
                            ? _goToPreviousDay
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          foregroundColor: Colors.orange,
                        ),
                        tooltip: 'Previous Day',
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _selectDate,
                        style: FilledButton.styleFrom(
                          backgroundColor: selectedDate != null
                              ? Colors.orange
                              : Colors.grey,
                        ),
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          selectedDate ?? 'Filter Date',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () {
                            setState(() => selectedDate = null);
                            fetchAttendance();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      // Next day button
                      IconButton(
                        onPressed: selectedDate != null ? _goToNextDay : null,
                        icon: const Icon(Icons.chevron_right),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          foregroundColor: Colors.orange,
                        ),
                        tooltip: 'Next Day',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : attendance.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        selectedDate != null
                            ? 'No records for $selectedDate'
                            : 'No attendance records',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: attendance.length,
                  itemBuilder: (context, index) {
                    final record = attendance[index];
                    final timestamp = record['timestamp']?.toString() ?? '';
                    // Handle both "2024-03-11 07:04:29" and "2024-03-11T07:04:29" formats
                    final datePart = timestamp.contains(' ')
                        ? timestamp.split(' ')[0]
                        : (timestamp.contains('T')
                              ? timestamp.split('T')[0]
                              : 'N/A');
                    final timePart = timestamp.contains(' ')
                        ? timestamp.split(' ')[1]
                        : (timestamp.contains('T')
                              ? timestamp.split('T')[1]
                              : 'N/A');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(
                            0xFF007AFF,
                          ).withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.access_time,
                            color: const Color(0xFF007AFF),
                            size: 20,
                          ),
                        ),
                        title: Text(record['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(record['reg_no'] ?? ''),
                            if (record['class_div'] != null &&
                                record['class_div'].isNotEmpty)
                              Text(
                                'Class: ${record['class_div']}',
                                style: const TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              timePart,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              datePart,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Staff Mark Attendance Tab - Staff can mark their own attendance via face verification
class StaffMarkAttendanceTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const StaffMarkAttendanceTab({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<StaffMarkAttendanceTab> createState() => _StaffMarkAttendanceTabState();
}

class _StaffMarkAttendanceTabState extends State<StaffMarkAttendanceTab> {
  bool _isRegistered = false;
  bool _isLoading = true;
  String _message = '';

  bool _isWindowAllowed = false;
  String _activeSlotType = 'check_in';
  bool _alreadyMarkedCurrentSlot = false;

  @override
  void initState() {
    super.initState();
    _checkFaceStatus();
    _checkTodayAttendance();
    PreVerificationService.instance.forceRefresh();
  }

  Future<void> _checkFaceStatus() async {
    try {
      final response = await http.get(
        Uri.parse("$API_URL/face/status/${widget.user['regNo']}"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isRegistered = data['face_registered'] ?? false;
        });
      }
    } catch (e) {
      setState(() {
        _message = "Error checking face status: ${ApiResponseUtils.sanitize(e)}";
      });
    }
  }

  Future<void> _checkTodayAttendance() async {
    try {
      final slotResponse = await http.get(
        Uri.parse("$API_URL/admin/attendance/duration/check"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      
      bool allowed = false;
      String slotType = 'check_in';
      
      if (slotResponse.statusCode == 200) {
        final slotData = jsonDecode(slotResponse.body);
        allowed = slotData['allowed'] ?? false;
        slotType = slotData['slot_type'] ?? 'check_in';
      }

      final today = DateTime.now().toString().split(' ')[0];
      final response = await http.get(
        Uri.parse("$API_URL/staff/attendance?date=$today"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      bool alreadyMarked = false;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final attendance = data['attendance'] as List? ?? [];
        final regNo = widget.user['regNo'] ?? widget.user['reg_no'] ?? '';
        
        final userRecords = attendance.where(
          (record) => record['reg_no'] == regNo
        ).toList();
        
        if (userRecords.isNotEmpty) {
          alreadyMarked = userRecords.any(
            (record) => record['status'] == slotType
          );
        }
      }

      setState(() {
        _isWindowAllowed = allowed;
        _activeSlotType = slotType;
        _alreadyMarkedCurrentSlot = alreadyMarked;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToMarkAttendance() {
    if (!_isRegistered) {
      setState(
        () => _message =
            "Please register your face first before marking attendance.",
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceVerificationWidget(
          token: widget.token,
          regNo: widget.user['regNo'],
          name: widget.user['name'],
          dept: widget.user['dept'],
          onVerified: () {
            // Immediately trigger location tracking resume (check-in) or suspend (check-out)
            LocationTrackingService.instance.onAttendanceMarked();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attendance marked successfully!')),
            );
            _checkTodayAttendance();
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateToFaceRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRegistrationWidget(
          token: widget.token,
          role: 'staff',
          initialRegNo: widget.user['regNo'],
          initialName: widget.user['name'],
          initialDept: widget.user['dept'],
          registerEndpoint: '/staff/face/register',
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Face registered successfully!')),
            );
            _checkFaceStatus();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final infoBg = isDark ? const Color(0xFF2A2A30) : const Color(0xFFF8F5FF);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF007AFF)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFF5AC8FA)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mark Your Attendance',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            Text(
                              !_isWindowAllowed
                                  ? "Outside active attendance window"
                                  : (_alreadyMarkedCurrentSlot
                                      ? "Already marked ${_activeSlotType == 'check_in' ? 'Check-In' : 'Check-Out'} today"
                                      : "Active Slot: ${_activeSlotType == 'check_in' ? 'Check-In' : 'Check-Out'} (Verification Required)"),
                              style: TextStyle(
                                fontSize: 14,
                                color: !_isWindowAllowed
                                    ? Colors.red[700]
                                    : (_alreadyMarkedCurrentSlot ? Colors.green[700] : Colors.orange[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: infoBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.person_outline, "Name", widget.user['name'] ?? 'N/A'),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.badge_outlined, "ID", widget.user['regNo'] ?? 'N/A'),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.school_outlined, "Department", widget.user['dept'] ?? 'N/A'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_isRegistered && _isWindowAllowed && !_alreadyMarkedCurrentSlot)
                          ? _navigateToMarkAttendance
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 8,
                        shadowColor: const Color(0xFF007AFF).withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(
                        !_isWindowAllowed
                            ? "Outside Window"
                            : (_alreadyMarkedCurrentSlot
                                ? "Already ${_activeSlotType == 'check_in' ? 'Checked-In' : 'Checked-Out'}"
                                : "Mark ${_activeSlotType == 'check_in' ? 'Check-In' : 'Check-Out'}"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_isRegistered) ...[
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.orange.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Face Not Registered',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You need to register your face before you can mark attendance.',
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _navigateToFaceRegistration,
                        icon: const Icon(Icons.face, size: 22),
                        label: const Text("Register Face Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 6,
                          shadowColor: Colors.orange.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            color: cardBg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  _buildInstructionTile(Icons.person, 'Ensure your face is visible and well-lit'),
                  _buildInstructionTile(Icons.camera_alt, 'Position your face in the camera frame'),
                  _buildInstructionTile(Icons.check_circle, 'Tap capture when ready'),
                  _buildInstructionTile(Icons.access_time, 'Attendance is marked once verified'),
                ],
              ),
            ),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_message, style: const TextStyle(color: Colors.red, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionTile(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF007AFF)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF007AFF)),
        const SizedBox(width: 12),
        Text("$label: ", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A2E), fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// Staff Face Registration Tab - Only for self-registration
class StaffFaceRegisterTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const StaffFaceRegisterTab({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<StaffFaceRegisterTab> createState() => _StaffFaceRegisterTabState();
}

class _StaffFaceRegisterTabState extends State<StaffFaceRegisterTab> {
  bool _isRegistered = false;
  bool _isLoading = true;
  bool _hasPendingRequest = false;
  bool _canReregister = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _checkFaceStatus();
  }

  Future<void> _checkFaceStatus() async {
    try {
      final response = await http.get(
        Uri.parse("$API_URL/face/status/${widget.user['regNo']}"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isRegistered = data['face_registered'] ?? false;
          _hasPendingRequest = data['has_pending_request'] ?? false;
          _canReregister = data['can_reregister'] ?? false;
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

  Future<void> _requestReregister() async {
    try {
      final response = await http.post(
        Uri.parse("$API_URL/staff/face/reregister/request"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request submitted! Waiting for HOD and Admin approval.',
            ),
            backgroundColor: Color(0xFF8BC34A),
          ),
        );
        _checkFaceStatus();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Failed to submit request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildActionButton() {
    // Case 1: Not registered yet - can register directly
    if (!_isRegistered) {
      return ElevatedButton.icon(
        onPressed: _navigateToFaceRegistration,
        icon: const Icon(Icons.face),
        label: const Text("Register Face"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }

    // Case 2: Already registered and has permission to re-register
    if (_canReregister) {
      return ElevatedButton.icon(
        onPressed: _navigateToFaceRegistration,
        icon: const Icon(Icons.refresh),
        label: const Text("Re-register Face"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
      );
    }

    // Case 3: Already registered but has pending request
    if (_hasPendingRequest) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_empty),
        label: const Text("Request Pending"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
        ),
      );
    }

    // Case 4: Already registered, no permission, no pending request - need to request
    return ElevatedButton.icon(
      onPressed: _requestReregister,
      icon: const Icon(Icons.request_page),
      label: const Text("Request Re-registration"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _navigateToFaceRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRegistrationWidget(
          token: widget.token,
          role: 'staff',
          initialRegNo: widget.user['regNo'],
          initialName: widget.user['name'],
          initialDept: widget.user['dept'],
          registerEndpoint: '/staff/face/register',
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Face registered successfully!')),
            );
            _checkFaceStatus();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: cardBg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isRegistered ? Icons.check_circle : Icons.warning,
                        color: _isRegistered ? Colors.green : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Face Registration',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            Text(
                              _isRegistered ? "Your face is registered" : "Face not registered yet",
                              style: TextStyle(fontSize: 14, color: _isRegistered ? Colors.green[700] : Colors.orange[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Name: ${widget.user['name']}", style: TextStyle(fontSize: 14, color: textColor)),
                        Text("ID: ${widget.user['regNo']}", style: TextStyle(fontSize: 14, color: textColor)),
                        Text("Dept: ${widget.user['dept']}", style: TextStyle(fontSize: 14, color: textColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, height: 50, child: _buildActionButton()),
                  if (_hasPendingRequest) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_empty, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your re-registration request is pending approval from HOD and Admin.',
                              style: TextStyle(color: Colors.blue[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: cardBg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  _buildInstructionTile(Icons.person, 'This section is for registering YOUR own face only'),
                  _buildInstructionTile(Icons.camera_alt, 'Position your face in the camera frame'),
                  _buildInstructionTile(Icons.check_circle, 'Tap capture when face is detected'),
                  _buildInstructionTile(Icons.save, 'Confirm registration'),
                ],
              ),
            ),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_message, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionTile(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: isDark ? Colors.white70 : null))),
        ],
      ),
    );
  }
}

// HOD Face Re-registration Requests Tab
class HODReRegisterRequestsTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const HODReRegisterRequestsTab({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<HODReRegisterRequestsTab> createState() =>
      _HODReRegisterRequestsTabState();
}

class _HODReRegisterRequestsTabState extends State<HODReRegisterRequestsTab> {
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final response = await http.get(
        Uri.parse("$API_URL/hod/face/reregister/requests"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _requests = data['requests'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveRequest(String staffRegNo) async {
    try {
      final response = await http.post(
        Uri.parse("$API_URL/hod/face/reregister/approve/$staffRegNo"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchRequests();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _denyRequest(String staffRegNo) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for denial',
            hintText: 'Enter reason...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse("$API_URL/hod/face/reregister/deny/$staffRegNo"),
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: 'reason=${Uri.encodeComponent(result)}',
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request denied!'),
              backgroundColor: Colors.red,
            ),
          );
          _fetchRequests();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No pending requests', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req['staff_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'ID: ${req['staff_reg_no']}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Department: ${req['dept']}'),
                  Text('Requested: ${req['request_date']}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!req['hod_approved'])
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _approveRequest(req['staff_reg_no']),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        )
                      else
                        const Chip(
                          label: Text('HOD Approved'),
                          backgroundColor: Color(0xFF4CAF50),
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                      const SizedBox(width: 8),
                      if (!req['hod_approved'])
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _denyRequest(req['staff_reg_no']),
                            icon: const Icon(Icons.close),
                            label: const Text('Deny'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (req['admin_approved'])
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Chip(
                        label: Text('Admin Approved'),
                        backgroundColor: Color(0xFF8BC34A),
                        labelStyle: TextStyle(color: Colors.white),
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

// Admin Face Re-registration Requests Tab
class AdminReRegisterRequestsTab extends StatefulWidget {
  final String token;

  const AdminReRegisterRequestsTab({super.key, required this.token});

  @override
  State<AdminReRegisterRequestsTab> createState() =>
      _AdminReRegisterRequestsTabState();
}

class _AdminReRegisterRequestsTabState
    extends State<AdminReRegisterRequestsTab> {
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final response = await http.get(
        Uri.parse("$API_URL/admin/face/reregister/requests"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _requests = data['requests'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveRequest(String staffRegNo) async {
    try {
      final response = await http.post(
        Uri.parse("$API_URL/admin/face/reregister/approve/$staffRegNo"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchRequests();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _denyRequest(String staffRegNo) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for denial',
            hintText: 'Enter reason...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse("$API_URL/admin/face/reregister/deny/$staffRegNo"),
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: 'reason=${Uri.encodeComponent(result)}',
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request denied!'),
              backgroundColor: Colors.red,
            ),
          );
          _fetchRequests();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No pending requests', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req['staff_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'ID: ${req['staff_reg_no']}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Department: ${req['dept']}'),
                  Text('Requested: ${req['request_date']}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (req['hod_approved'])
                        const Chip(
                          label: Text('HOD Approved'),
                          backgroundColor: Color(0xFF4CAF50),
                          labelStyle: TextStyle(color: Colors.white),
                        )
                      else
                        const Chip(
                          label: Text('HOD Pending'),
                          backgroundColor: const Color(0xFF007AFF),
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                      const SizedBox(width: 8),
                      if (!req['admin_approved'])
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _approveRequest(req['staff_reg_no']),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        )
                      else
                        const Chip(
                          label: Text('Admin Approved'),
                          backgroundColor: Color(0xFF8BC34A),
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                      if (!req['admin_approved']) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _denyRequest(req['staff_reg_no']),
                            icon: const Icon(Icons.close),
                            label: const Text('Deny'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
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

// ─── Boundary Breach Alert Dialog ───────────────────────────────────────────
class _BoundaryBreachDialog extends StatefulWidget {
  final String message;
  const _BoundaryBreachDialog({required this.message});

  @override
  State<_BoundaryBreachDialog> createState() => _BoundaryBreachDialogState();
}

class _BoundaryBreachDialogState extends State<_BoundaryBreachDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0000), Color(0xFF3D0000)],
            ),
            border: Border.all(color: const Color(0xFFFF3333), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3333).withValues(alpha: 0.45),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing alert icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF3333).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFFFF3333), width: 2),
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  color: Color(0xFFFF3333),
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '⚠ Boundary Breach Detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF6666),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3333).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF3333).withValues(alpha: 0.4)),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your attendance may be affected. Please return to the designated area immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text(
                    'I Understand',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3333),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
