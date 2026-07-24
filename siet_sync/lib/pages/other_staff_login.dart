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
import '../widgets/quick_access_stat_card.dart';
import '../widgets/face_registration_widget.dart';
import '../widgets/attendance_pie_chart.dart';
import '../widgets/user_settings_tab.dart';
import '../widgets/leave_request_widget.dart';
import '../widgets/location_permission_enforcer.dart';
import '../utils/responsive.dart';
import '../utils/api_response_utils.dart';
import '../services/leave_balance_notifier.dart';
import '../services/pre_verification_service.dart';
import 'attendance_log_page.dart';


String get API_URL => CollegeIPConfig.defaultURL;

class OtherStaffLoginPage extends StatefulWidget {
  const OtherStaffLoginPage({super.key});

  @override
  State<OtherStaffLoginPage> createState() => _OtherStaffLoginPageState();
}

class _OtherStaffLoginPageState extends State<OtherStaffLoginPage> {
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
      final deviceSessionId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
      final response = await http.post(
        Uri.parse('$API_URL/other_staff/login'),
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtherStaffDashboardPage(
              token: data['token'],
              user: data['user'],
            ),
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
    final panelAccent = const Color(0xFF007AFF);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF000000), const Color(0xFF1C1C1E)]
                : [panelAccent, const Color(0xFF5AC8FA)],
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: panelAccent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: panelAccent.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Other Staff Portal',
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
                        'Principal / Placement / Lab Tech / Admin Login',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey[600],
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
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
                              color: panelAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.person_outline,
                              color: panelAccent,
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
                            borderSide: BorderSide(
                              color: panelAccent,
                              width: 2,
                            ),
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
                              color: panelAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.lock_outline,
                              color: panelAccent,
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
                            borderSide: BorderSide(
                              color: panelAccent,
                              width: 2,
                            ),
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
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: panelAccent,
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
                              : const Text(
                                  'Login as Other Staff',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Back to Home',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
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

class OtherStaffDashboardPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const OtherStaffDashboardPage({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<OtherStaffDashboardPage> createState() =>
      _OtherStaffDashboardPageState();
}

class _OtherStaffDashboardPageState extends State<OtherStaffDashboardPage> {
  int _selectedIndex = 0;
  StreamSubscription<String>? _warningSub;
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;
  int presentDays = 0;
  int absentDays = 0;

  final List<Widget> _pages = [];
  final List<String> _titles = [
    'Dashboard',
    'Mark Attendance',
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
    final accent = roleAccentColor;
    _pages.addAll([
      OtherStaffDashboardTab(
        token: widget.token,
        user: widget.user,
        onTabSelected: _onTabSelected,
        accentColor: accent,
      ),
      OtherStaffMarkAttendanceTab(
        token: widget.token,
        user: widget.user,
        accentColor: accent,
      ),
      OtherStaffFaceRegisterTab(
        token: widget.token,
        user: widget.user,
        accentColor: accent,
      ),
      StaffLeaveRequestTab(token: widget.token, accentColor: accent),
      AttendanceLogTab(token: widget.token, user: widget.user),
      UserSettingsTab(
        title: 'Settings',
        token: widget.token,
        accentColor: accent,
      ),
    ]);
    _loadDashboard();
  }

  void _loadDashboard() {
    // Dashboard loaded
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

  String get userRole => widget.user['role'] ?? 'Unknown';

  Color get roleAccentColor {
    switch (userRole.toLowerCase()) {
      case 'principal':
        return const Color(0xFF6A1B9A);
      case 'placement_staff':
      case 'placement':
        return const Color(0xFF00838F);
      case 'lab_technician':
      case 'lab_tech':
      case 'labtech':
        return const Color(0xFFE65100);
      case 'system_admin':
      case 'systemadmin':
        return const Color(0xFF1565C0);
      case 'office_staff':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF007AFF);
    }
  }

  String get roleDisplayName {
    switch (userRole.toLowerCase()) {
      case 'principal':
        return 'Principal';
      case 'placement_staff':
      case 'placement':
        return 'Placement Staff';
      case 'lab_technician':
      case 'lab_tech':
      case 'labtech':
        return 'Lab Technician';
      case 'system_admin':
      case 'systemadmin':
        return 'System Admin';
      case 'office_staff':
        return 'Office Staff';
      default:
        return userRole;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = roleAccentColor;
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
      destinations: const [
        NavDestination(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Dashboard',
        ),
        NavDestination(
          icon: Icons.assignment_turned_in_outlined,
          selectedIcon: Icons.assignment_turned_in_rounded,
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
      ],
      accentColor: accentColor,
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
                  OtherStaffDashboardTab(
                    token: widget.token,
                    user: widget.user,
                    onTabSelected: _onTabSelected,
                    accentColor: accentColor,
                  ),
                  OtherStaffMarkAttendanceTab(
                    token: widget.token,
                    user: widget.user,
                    accentColor: accentColor,
                  ),
                  OtherStaffFaceRegisterTab(
                    token: widget.token,
                    user: widget.user,
                    accentColor: accentColor,
                  ),
                  StaffLeaveRequestTab(
                    token: widget.token,
                    accentColor: accentColor,
                  ),
                  AttendanceLogTab(token: widget.token, user: widget.user),
                  UserSettingsTab(
                    title: 'Settings',
                    token: widget.token,
                    accentColor: accentColor,
                  ),
                ]);
              });
              await Future.delayed(const Duration(milliseconds: 100));
            },
            color: accentColor,
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );

    return kIsWeb ? scaffold : LocationPermissionEnforcer(child: scaffold);
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = roleAccentColor;

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
                      : [accent, accent.withValues(alpha: 0.7)],
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
                      Icons.person,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Other Staff Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user['name'] ?? 'Staff',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        roleDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
              Icons.assignment_turned_in_rounded,
              'Mark Attendance',
              Icons.assignment_turned_in_outlined,
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
    final accent = roleAccentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected ? accent.withValues(alpha: 0.12) : Colors.transparent,
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
                        ? accent
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
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? accent
                          : (isDark ? Colors.white : Colors.grey.shade700),
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.chevron_right, color: accent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Other Staff Dashboard Tab
class OtherStaffDashboardTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final Function(int)? onTabSelected;
  final Color accentColor;

  const OtherStaffDashboardTab({
    super.key,
    required this.token,
    required this.user,
    this.onTabSelected,
    this.accentColor = const Color(0xFF007AFF),
  });

  @override
  State<OtherStaffDashboardTab> createState() => _OtherStaffDashboardTabState();
}

class _OtherStaffDashboardTabState extends State<OtherStaffDashboardTab> {
  Map<String, dynamic>? data;
  bool isLoading = true;
  double presentDays = 0.0;
  double absentDays = 0.0;
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
      icon: Icons.assignment_turned_in_rounded,
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
      final response = await apiClient.get(
        '$API_URL/other_staff/dashboard',
        token: widget.token,
        cacheKey: 'other_staff_dashboard_${widget.token.hashCode}',
        cacheDuration: const Duration(minutes: 1),
      );
      if (response.statusCode == 200) {
        setState(() => data = jsonDecode(response.body));
      }

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
      final response = await apiClient.get(
        '$API_URL/other_staff/attendance',
        token: widget.token,
        cacheKey: 'other_staff_attendance_${widget.token.hashCode}',
        cacheDuration: const Duration(minutes: 10),
      );
      if (response.statusCode == 200) {
        final attendanceData = jsonDecode(response.body);
        final records = attendanceData['attendance'] ?? [];

        double? newPresent = attendanceData['present_days'] != null ? (attendanceData['present_days'] as num).toDouble() : null;
        double? newAbsent = attendanceData['absent_days'] != null ? (attendanceData['absent_days'] as num).toDouble() : null;

        if (newPresent == null || newAbsent == null) {
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
          newPresent = uniqueDates.length.toDouble();
          newAbsent = (now.day - newPresent).clamp(0, 30).toDouble();
        }

        if (mounted) {
          setState(() {
            presentDays = newPresent ?? 0.0;
            absentDays = newAbsent ?? 0.0;
          });
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  String get roleDisplayName {
    final role = widget.user['role']?.toString() ?? 'Unknown';
    switch (role.toLowerCase()) {
      case 'principal':
        return 'Principal';
      case 'placement_staff':
      case 'placement':
        return 'Placement Staff';
      case 'lab_technician':
      case 'lab_tech':
      case 'labtech':
        return 'Lab Technician';
      case 'system_admin':
      case 'systemadmin':
        return 'System Admin';
      case 'office_staff':
        return 'Office Staff';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor;

    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    final stats = data?['stats'] ?? {};
    final recentAttendance = data?['recent_attendance'] ?? [];

    final pagePadding = Breakpoints.pagePadding(screenWidth);
    final gridSpacing = Breakpoints.gridSpacing(screenWidth);
    final isWide = screenWidth >= 900;

    // Bento glass card helper
    Widget bentoCard({
      required Widget child,
      Color? accentColor,
      double? height,
      VoidCallback? onTap,
    }) {
      final cardAccent = accentColor ?? accent;
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
              color: cardAccent.withValues(alpha: isDark ? 0.08 : 0.01),
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
                              Colors.white.withValues(alpha: 0.75),
                              Colors.white.withValues(alpha: 0.35),
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
                : [accent, const Color(0xFF7986CB)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.3),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
                        Icons.badge,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Role: $roleDisplayName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.user['regNo'] != null)
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
                          Icons.perm_identity,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ID: ${widget.user['regNo']}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    Widget attendanceProgressBento() {
      // Use historical breakdown from daily_attendance_status for pie chart
      final double fullDay = (stats['hist_full_day_count'] as num? ?? presentDays).toDouble();
      final double halfDay = (stats['hist_half_day_count'] as num? ?? 0.0).toDouble();
      final double absent  = (stats['hist_absent_count']   as num? ?? absentDays).toDouble();
      final double onLeave = (stats['hist_leave_count']    as num? ?? 0.0).toDouble();

      // Today's status from server
      final String? todayStatus      = stats['today_status'] as String?;
      final String? todayFirstHalf   = stats['today_first_half'] as String?;
      final String? todaySecondHalf  = stats['today_second_half'] as String?;

      Color _statusColor(String? s) {
        switch (s) {
          case 'Present': return const Color(0xFF10B981);
          case 'Absent':  return const Color(0xFFEF4444);
          case 'Leave':   return const Color(0xFF8B5CF6);
          default:        return Colors.grey;
        }
      }

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
            // Today's half-day status pills
            if (todayFirstHalf != null || todaySecondHalf != null) ...[  
              const SizedBox(height: 6),
              Row(
                children: [
                  if (todayFirstHalf != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(todayFirstHalf).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _statusColor(todayFirstHalf), width: 0.8),
                      ),
                      child: Text(
                        '1st: $todayFirstHalf',
                        style: TextStyle(
                          color: _statusColor(todayFirstHalf),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (todaySecondHalf != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(todaySecondHalf).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _statusColor(todaySecondHalf), width: 0.8),
                      ),
                      child: Text(
                        '2nd: $todaySecondHalf',
                        style: TextStyle(
                          color: _statusColor(todaySecondHalf),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: AttendancePieChart(
                  fullDay: fullDay.toInt(),
                  halfDay: halfDay.toInt(),
                  absent: absent.toInt(),
                  onLeave: onLeave.toInt(),
                  centerLabel: 'Days',
                  centerSpaceRadius: 36,
                ),
              ),
            ),
            if (todayStatus != null) ...[  
              const SizedBox(height: 4),
              Text(
                'Today: $todayStatus',
                style: TextStyle(
                  color: _statusColor(todayStatus),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
                    'Activity Beacons',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: accent),
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
                            'No logs recorded recently',
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
                      final avatarRadius = isSmallScreen ? 14.0 : 18.0;
                      final avatarIconSize = isSmallScreen ? 14.0 : 18.0;
                      final titleSize = isSmallScreen ? 13.0 : 14.0;
                      final subtitleSize = isSmallScreen ? 11.0 : 12.0;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: accent.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.person,
                            size: avatarIconSize,
                            color: accent,
                          ),
                        ),
                        title: Text(
                          record['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          record['reg_no'] ?? '',
                          style: TextStyle(
                            fontSize: subtitleSize,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        trailing: Text(
                          _formatTimestamp(record['timestamp']),
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontSize: 12,
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
        // Desktop Bento Grid
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 225,
                    child: welcomeCard(),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 270,
                    child: attendanceProgressBento(),
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
                            'Present Cycles',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                          ),
                          Text(
                            presentDays % 1 == 0 ? presentDays.toInt().toString() : presentDays.toString(),
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
                            'Absent Cycles',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                          ),
                          Text(
                            absentDays % 1 == 0 ? absentDays.toInt().toString() : absentDays.toString(),
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
                      accentColor: accent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_rounded, color: accent, size: 36),
                          const Spacer(),
                          Text(
                            'Aggregated Shifts',
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
                      accentColor: accent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      } else {
        // Mobile Bento Grid
        return Column(
          children: [
            welcomeCard(),
            const SizedBox(height: 16),
            SizedBox(
              height: 270,
              child: attendanceProgressBento(),
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
                  accentColor: accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_rounded, color: accent, size: 28),
                      const Spacer(),
                      Text(
                        'Total Shifts',
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
                  accentColor: accent,
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
class ModernOtherStaffStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const ModernOtherStaffStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
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

// Other Staff Mark Attendance Tab
class OtherStaffMarkAttendanceTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final Color accentColor;

  const OtherStaffMarkAttendanceTab({
    super.key,
    required this.token,
    required this.user,
    this.accentColor = const Color(0xFF007AFF),
  });

  @override
  State<OtherStaffMarkAttendanceTab> createState() =>
      _OtherStaffMarkAttendanceTabState();
}

class _OtherStaffMarkAttendanceTabState
    extends State<OtherStaffMarkAttendanceTab> {
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
        Uri.parse("$API_URL/other_staff/face/status"),
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
        Uri.parse("$API_URL/other_staff/attendance?date=$today"),
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

    final regNo = widget.user['regNo'] ?? widget.user['reg_no'] ?? '';
    final name = widget.user['name'] ?? '';
    final dept =
        widget.user['dept'] ??
        widget.user['department'] ??
        widget.user['dept_name'] ??
        '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceVerificationWidget(
          token: widget.token,
          regNo: regNo,
          name: name,
          dept: dept,
          onVerified: () {
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
    final regNo = widget.user['regNo'] ?? widget.user['reg_no'] ?? '';
    final name = widget.user['name'] ?? '';
    final dept =
        widget.user['dept'] ??
        widget.user['department'] ??
        widget.user['dept_name'] ??
        '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRegistrationWidget(
          token: widget.token,
          role: widget.user['role'] ?? 'other_staff',
          initialRegNo: regNo,
          initialName: name,
          initialDept: dept,
          registerEndpoint: '/other_staff/face/register',
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

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: const Color(0xFF007AFF)));
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
                BoxShadow(color: widget.accentColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
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
                          gradient: const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF5AC8FA)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mark Your Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                            Text(
                              !_isWindowAllowed
                                  ? "Outside active attendance window"
                                  : (_alreadyMarkedCurrentSlot
                                      ? "Already marked ${_activeSlotType == 'check_in' ? 'Check-In' : 'Check-Out'} today"
                                      : "Active Slot: ${_activeSlotType == 'check_in' ? 'Check-In' : 'Check-Out'} (Verification Required)"),
                              style: TextStyle(fontSize: 14, color: !_isWindowAllowed ? Colors.red[700] : (_alreadyMarkedCurrentSlot ? Colors.green[700] : Colors.orange[700])),
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
                      color: isDark ? const Color(0xFF2A2A30) : const Color(0xFFF8F5FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.person_outline, "Name", widget.user['name'] ?? 'N/A'),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.badge_outlined, "ID", widget.user['regNo'] ?? widget.user['reg_no'] ?? 'N/A'),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.school_outlined, "Department", widget.user['dept'] ?? widget.user['department'] ?? widget.user['dept_name'] ?? 'N/A'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_isRegistered && _isWindowAllowed && !_alreadyMarkedCurrentSlot) ? _navigateToMarkAttendance : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 8, shadowColor: const Color(0xFF007AFF).withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(!_isWindowAllowed ? "Outside Window" : (_alreadyMarkedCurrentSlot ? "Already ${_activeSlotType == 'check_in' ? 'Checked-In' : 'Checked-Out'}" : "Mark ${_activeSlotType == 'check_in' ? 'Check-In' : 'Check-Out'}")),
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
                boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
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
                        Expanded(child: Text('Face Not Registered', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))),
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
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Please register your face to enable attendance marking.', style: TextStyle(fontSize: 14, color: Colors.orange.shade800))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _navigateToFaceRegistration,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 6, shadowColor: Colors.orange.withValues(alpha: 0.4)),
                        icon: const Icon(Icons.face), label: const Text("Register Face"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))]),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.info_outline, color: widget.accentColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionTile(Icons.person_outline, 'Ensure your face is visible and well-lit'),
                  _buildInstructionTile(Icons.camera_alt_outlined, 'Position your face in the camera frame'),
                  _buildInstructionTile(Icons.check_circle_outline, 'Tap capture when ready'),
                  _buildInstructionTile(Icons.access_time_outlined, 'Attendance is marked once verified'),
                ],
              ),
            ),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_message, style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: widget.accentColor),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : const Color(0xFF666666), fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : null), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildInstructionTile(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: widget.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF333333), height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

// Other Staff Face Registration Tab
class OtherStaffFaceRegisterTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final Color accentColor;

  const OtherStaffFaceRegisterTab({
    super.key,
    required this.token,
    required this.user,
    this.accentColor = const Color(0xFF007AFF),
  });

  @override
  State<OtherStaffFaceRegisterTab> createState() =>
      _OtherStaffFaceRegisterTabState();
}

class _OtherStaffFaceRegisterTabState extends State<OtherStaffFaceRegisterTab> {
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
        Uri.parse("$API_URL/other_staff/face/status"),
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
        _message = "Error checking face status: ${ApiResponseUtils.sanitize(e)}";
        _isLoading = false;
      });
    }
  }

  Future<void> _requestReregister() async {
    try {
      final response = await http.post(
        Uri.parse("$API_URL/other_staff/face/reregister/request"),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted! Waiting for Admin approval.'),
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
    if (!_isRegistered) {
      return ElevatedButton.icon(
        onPressed: _navigateToFaceRegistration,
        icon: const Icon(Icons.face),
        label: const Text("Register Face"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 56),
        ),
      );
    }

    if (_canReregister) {
      return ElevatedButton.icon(
        onPressed: _navigateToFaceRegistration,
        icon: const Icon(Icons.refresh),
        label: const Text("Re-register Face"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 56),
        ),
      );
    }

    if (_hasPendingRequest) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_empty),
        label: const Text("Request Pending"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 56),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _requestReregister,
      icon: const Icon(Icons.request_page),
      label: const Text("Request Re-registration"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 56),
      ),
    );
  }

  void _navigateToFaceRegistration() {
    final regNo =
        widget.user['regNo'] ??
        widget.user['reg_no'] ??
        widget.user['registration_no'] ??
        '';
    final name = widget.user['name'] ?? '';
    final dept =
        widget.user['dept'] ??
        widget.user['department'] ??
        widget.user['dept_name'] ??
        widget.user['department_name'] ??
        '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRegistrationWidget(
          token: widget.token,
          role: widget.user['role'] ?? 'other_staff',
          initialRegNo: regNo,
          initialName: name,
          initialDept: dept,
          registerEndpoint: '/other_staff/face/register',
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
      return Center(child: CircularProgressIndicator(color: const Color(0xFF007AFF)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: widget.accentColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))]),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(_isRegistered ? Icons.check_circle : Icons.warning_amber_rounded, color: _isRegistered ? Colors.green : Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  Text('Your Face Registration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(_isRegistered ? 'Your face is registered' : 'Face not registered yet', style: TextStyle(fontSize: 14, color: _isRegistered ? Colors.green[700] : Colors.orange[700]), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2A30) : const Color(0xFFF8F5FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.accentColor.withValues(alpha: 0.2))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.person_outline, 'Name', widget.user['name'] ?? 'N/A'),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.badge_outlined, 'ID', widget.user['regNo'] ?? widget.user['reg_no'] ?? 'N/A'),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.school_outlined, 'Department', widget.user['dept'] ?? widget.user['department'] ?? widget.user['dept_name'] ?? 'N/A'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 56, child: _buildActionButton()),
                  if (_hasPendingRequest) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue)),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_empty, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Your re-registration request is pending approval from Admin.', style: TextStyle(color: Colors.blue[700]))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))]),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.info_outline, color: widget.accentColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionTile(Icons.person_outline, 'This section is for registering YOUR own face only'),
                  _buildInstructionTile(Icons.camera_alt_outlined, 'Position your face in the camera frame'),
                  _buildInstructionTile(Icons.check_circle_outline, 'Tap capture when face is detected'),
                  _buildInstructionTile(Icons.save_outlined, 'Confirm registration'),
                ],
              ),
            ),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_message, style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: widget.accentColor),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : const Color(0xFF666666), fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : null), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildInstructionTile(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: widget.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF333333), height: 1.4)),
            ),
          ),
        ],
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
