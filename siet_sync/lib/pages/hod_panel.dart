import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
import '../widgets/attendance_pie_chart.dart';
import '../widgets/user_settings_tab.dart';
import '../widgets/leave_request_widget.dart';
import '../widgets/location_permission_enforcer.dart';
import '../services/pre_verification_service.dart';
import '../services/leave_balance_notifier.dart';
import 'attendance_log_page.dart';


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

String get API_URL => CollegeIPConfig.defaultURL;

// Helper function to format date for display - dd/mm/yy format
String _formatDateForDisplay(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      // yyyy-mm-dd -> dd/mm/yy
      return '${parts[2]}/${parts[1]}/${parts[0].substring(2)}';
    }
    return dateStr;
  } catch (e) {
    return dateStr;
  }
}

class HODLoginPage extends StatefulWidget {
  const HODLoginPage({super.key});

  @override
  State<HODLoginPage> createState() => _HODLoginPageState();
}

class _HODLoginPageState extends State<HODLoginPage> {
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
      final response = await http.post(
        Uri.parse('$API_URL/hod/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameCtrl.text,
          'password': passwordCtrl.text,
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HODDashboardPage(token: data['token'], user: data['user']),
          ),
        );
      } else {
        final data = ApiResponseUtils.tryParseJson(response.body);
        setState(
          () =>
              errorMsg =
                  data?['detail'] ??
                  data?['message'] ??
                  data?['error'] ??
                  ApiResponseUtils.nonJsonErrorMessage(
                    response.statusCode,
                    response.body,
                  ),
        );
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
    final hodAccent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF000000), const Color(0xFF1C1C1E)]
                : [hodAccent, const Color(0xFF26A69A)],
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
                          color: hodAccent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: hodAccent.withValues(alpha: 0.4),
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
                        'HOD Portal',
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
                        'Head of Department Login',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey[600],
                          fontSize: 15,
                        ),
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
                              color: hodAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.person_outline,
                              color: hodAccent,
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
                            borderSide: BorderSide(color: hodAccent, width: 2),
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
                              color: hodAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.lock_outline,
                              color: hodAccent,
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
                            borderSide: BorderSide(color: hodAccent, width: 2),
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
                            backgroundColor: hodAccent,
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
                                  'Login as HOD',
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

class HODDashboardPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const HODDashboardPage({super.key, required this.token, required this.user});

  @override
  State<HODDashboardPage> createState() => _HODDashboardPageState();
}

class _HODDashboardPageState extends State<HODDashboardPage> {
  int _selectedIndex = 0;
  StreamSubscription<String>? _warningSub;

  final List<Widget> _pages = [];
  final List<String> _titles = [
    'Dashboard',
    'Staff',
    'Mark Attend',
    'Leave Requests',
    'Analytics',
    'My Face',
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
      HODDashboardTab(
        token: widget.token,
        user: widget.user,
        onTabSelected: _onTabSelected,
      ),
      HODStaffTab(token: widget.token, dept: widget.user['dept']),
      HODMarkAttendanceTab(token: widget.token, user: widget.user),
      StaffLeaveRequestTab(token: widget.token),
      HODMergedAnalyticsTab(
        token: widget.token,
        user: widget.user,
        dept: widget.user['dept'],
      ),
      HODFaceRegisterTab(token: widget.token, user: widget.user),
      AttendanceLogTab(token: widget.token, user: widget.user),
      UserSettingsTab(title: 'HOD Settings', token: widget.token),
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
      icon: Icons.people_outline,
      selectedIcon: Icons.people_rounded,
      label: 'Staff',
    ),
    NavDestination(
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge_rounded,
      label: 'Mark Attend',
    ),
    NavDestination(
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
      label: 'Leave',
    ),
    NavDestination(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics_rounded,
      label: 'Analytics',
    ),
    NavDestination(
      icon: Icons.face_outlined,
      selectedIcon: Icons.face_rounded,
      label: 'My Face',
    ),
    NavDestination(
      icon: Icons.history_edu_outlined,
      selectedIcon: Icons.history_edu_rounded,
      label: 'Log',
    ),
    NavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final hodAccent = Theme.of(context).colorScheme.primary;

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
      accentColor: hodAccent,
      drawer: _buildDrawer(context),
      onLogout: _logout,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _pages.clear();
            _pages.addAll([
              HODDashboardTab(
                token: widget.token,
                user: widget.user,
                onTabSelected: _onTabSelected,
              ),
              HODStaffTab(token: widget.token, dept: widget.user['dept']),
              HODMarkAttendanceTab(token: widget.token, user: widget.user),
              StaffLeaveRequestTab(token: widget.token),
              HODMergedAnalyticsTab(
                token: widget.token,
                user: widget.user,
                dept: widget.user['dept'],
              ),
              HODFaceRegisterTab(token: widget.token, user: widget.user),
              AttendanceLogTab(token: widget.token, user: widget.user),
              UserSettingsTab(title: 'HOD Settings', token: widget.token),
            ]);
          });
          await Future.delayed(const Duration(milliseconds: 100));
        },
        color: hodAccent,
        child: _pages[_selectedIndex],
      ),
    );

    return kIsWeb ? scaffold : LocationPermissionEnforcer(child: scaffold);
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      : [
                          const Color(0xFF00695C),
                          const Color(0xFF00897B),
                          const Color(0xFF26A69A),
                        ],
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
                  const Text(
                    'HOD Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user['name'] ?? 'HOD',
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
                        (widget.user['dept'] ?? '').toString().toUpperCase(),
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
              Icons.people_rounded,
              'Staff',
              Icons.people_outline,
            ),
            _buildDrawerItem(
              2,
              Icons.badge_rounded,
              'Mark Attendance',
              Icons.badge_outlined,
            ),
            _buildDrawerItem(
              3,
              Icons.event_note_rounded,
              'Leave Requests',
              Icons.event_note_outlined,
            ),
            _buildDrawerItem(
              4,
              Icons.analytics_rounded,
              'Analytics',
              Icons.analytics_outlined,
            ),
            _buildDrawerItem(
              5,
              Icons.face_rounded,
              'My Face',
              Icons.face_outlined,
            ),
            _buildDrawerItem(
              6,
              Icons.history_edu_rounded,
              'Attendance Log',
              Icons.history_edu_outlined,
            ),
            _buildDrawerItem(
              7,
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
    final hodAccent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected
            ? hodAccent.withValues(alpha: 0.12)
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
                        ? hodAccent
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
                          ? hodAccent
                          : (isDark ? Colors.white : Colors.grey.shade700),
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.chevron_right, color: hodAccent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HODDashboardTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final Function(int)? onTabSelected;

  const HODDashboardTab({
    super.key,
    required this.token,
    required this.user,
    this.onTabSelected,
  });

  @override
  State<HODDashboardTab> createState() => _HODDashboardTabState();
}

class _HODDashboardTabState extends State<HODDashboardTab> {
  Map<String, dynamic>? data;
  bool isLoading = true;
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
      _fetchRecentAttendance();
    });
  }

  Future<void> _fetchRecentAttendance() async {
    try {
      final response = await http.get(
        Uri.parse('$API_URL/hod/recent-attendance?dept=${widget.user['dept']}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final newData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            data?['recent_attendance'] = newData['recent_attendance'] ?? [];
            final existingStats =
                data?['stats'] as Map<String, dynamic>? ?? <String, dynamic>{};
            final newStats =
                newData['stats'] as Map<String, dynamic>? ??
                <String, dynamic>{};
            data?['stats'] = <String, dynamic>{...existingStats, ...newStats};
          });
        }
      }
    } catch (_) {}
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
    DrawerItem(index: 1, icon: Icons.people_rounded, title: 'Staff'),
    DrawerItem(index: 2, icon: Icons.badge_rounded, title: 'Mark Attendance'),
    DrawerItem(
      index: 3,
      icon: Icons.event_note_rounded,
      title: 'Leave Requests',
    ),
    DrawerItem(index: 4, icon: Icons.analytics_rounded, title: 'Analytics'),
    DrawerItem(index: 5, icon: Icons.face_rounded, title: 'My Face'),
    DrawerItem(index: 6, icon: Icons.settings_rounded, title: 'Settings'),
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
    try {
      final response = await apiClient.get(
        '$API_URL/hod/dashboard',
        token: widget.token,
        cacheKey: 'hod_dashboard_${widget.token.hashCode}',
        cacheDuration: const Duration(minutes: 1),
      );
      if (response.statusCode == 200) {
        setState(() => data = jsonDecode(response.body));
      }
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hodAccent = Theme.of(context).colorScheme.primary;

    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: hodAccent));
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
      final accent = accentColor ?? hodAccent;
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
                : [hodAccent, const Color(0xFF26A69A)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: hodAccent.withValues(alpha: 0.3),
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
                        widget.user['name'] ?? 'HOD',
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
                  Text(
                    'Department: ${widget.user['dept']?.toUpperCase() ?? 'HOD'}',
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
      );
    }

    Widget deptAttendanceProgress() {
      // Pull pie-chart fields from the enriched dashboard response
      final int fullDay  = (stats['today_full_day']  as num? ?? 0).toInt();
      final int halfDay  = (stats['today_half_day']  as num? ?? 0).toInt();
      final int absent   = (stats['today_absent']    as num? ?? 0).toInt();
      final int onLeave  = (stats['today_leave']     as num? ?? 0).toInt();
      final int total    = (stats['total_staff']     as num? ?? 0).toInt();

      return bentoCard(
        accentColor: Colors.green,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Attendance',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AttendancePieChart(
                  fullDay: fullDay,
                  halfDay: halfDay,
                  absent: absent,
                  onLeave: onLeave,
                  centerLabel: 'Staff',
                  centerSpaceRadius: 38,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${fullDay + halfDay + absent + onLeave} / $total',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 10,
              ),
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
                    'Departmental Activity Logs',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: hodAccent),
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
                            'No HOD logs registered recently',
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
                          backgroundColor: hodAccent.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.person,
                            size: avatarIconSize,
                            color: hodAccent,
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
        // Desktop / Wide Tablet Mosaic Grid
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
                    child: deptAttendanceProgress(),
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
                      accentColor: Colors.orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_rounded, color: Colors.orange, size: 36),
                          const Spacer(),
                          Text(
                            'Departmental Faculty',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                          ),
                          Text(
                            stats['total_staff']?.toString() ?? '0',
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
                      accentColor: Colors.purple,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_rounded, color: Colors.purple, size: 36),
                          const Spacer(),
                          Text(
                            'Cumulative Logs',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                          ),
                          Text(
                            stats['total_attendance']?.toString() ?? '0',
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
                      accentColor: Colors.green,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.today_rounded, color: Colors.green, size: 36),
                          const Spacer(),
                          Text(
                            'Active Beacons Today',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                          ),
                          Text(
                            stats['today_attendance']?.toString() ?? '0',
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
                      accentColor: hodAccent,
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
              height: 270,
              child: deptAttendanceProgress(),
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
                  accentColor: Colors.orange,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_rounded, color: Colors.orange, size: 28),
                      const Spacer(),
                      Text(
                        'Faculty Staff',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11),
                      ),
                      Text(
                        stats['total_staff']?.toString() ?? '0',
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
                  accentColor: Colors.purple,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_rounded, color: Colors.purple, size: 28),
                      const Spacer(),
                      Text(
                        'Total Logs',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11),
                      ),
                      Text(
                        stats['total_attendance']?.toString() ?? '0',
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
                  accentColor: Colors.green,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.today_rounded, color: Colors.green, size: 28),
                      const Spacer(),
                      Text(
                        'Today Logs',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11),
                      ),
                      Text(
                        stats['today_attendance']?.toString() ?? '0',
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
                  accentColor: hodAccent,
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
class ModernHODStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const ModernHODStatCard({
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
    final hodAccent = Theme.of(context).colorScheme.primary;

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
                  color: (color == Colors.orange ? hodAccent : color)
                      .withOpacity(0.8),
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

class HODStudentsTab extends StatefulWidget {
  final String token;
  final String dept;

  const HODStudentsTab({super.key, required this.token, required this.dept});

  @override
  State<HODStudentsTab> createState() => _HODStudentsTabState();
}

class _HODStudentsTabState extends State<HODStudentsTab> {
  List<dynamic> students = [];
  bool isLoading = true;

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
        '$API_URL/hod/students',
        token: widget.token,
        cacheKey: 'hod_students_${widget.dept}',
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
        Uri.parse('$API_URL/hod/students/$regNo'),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.dept.toUpperCase()} Students (${students.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: fetchStudents,
                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
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
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.person,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text(student['name'] ?? 'Unknown'),
                        subtitle: Text(
                          student['reg_no'] ?? '',
                          style: const TextStyle(fontSize: 12),
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

class HODAttendanceTab extends StatefulWidget {
  final String token;
  final String dept;

  const HODAttendanceTab({super.key, required this.token, required this.dept});

  @override
  State<HODAttendanceTab> createState() => _HODAttendanceTabState();
}

class _HODAttendanceTabState extends State<HODAttendanceTab> {
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
          ? Uri.parse('$API_URL/hod/attendance?date=$selectedDate')
          : Uri.parse('$API_URL/hod/attendance');
      // Attendance with caching (5 minutes for slow networks)
      final response = await apiClient.get(
        url.toString(),
        token: widget.token,
        cacheKey: 'hod_attendance',
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
                children: [
                  Text(
                    '${widget.dept.toUpperCase()} Attendance (${attendance.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          foregroundColor: Colors.teal,
                        ),
                        tooltip: 'Previous Day',
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _selectDate,
                        style: FilledButton.styleFrom(
                          backgroundColor: selectedDate != null
                              ? Colors.teal
                              : Colors.grey,
                        ),
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(selectedDate ?? 'Filter Date'),
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
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          foregroundColor: Colors.teal,
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
                              : '');
                    final timePart = timestamp.contains(' ')
                        ? timestamp.split(' ')[1]
                        : (timestamp.contains('T')
                              ? timestamp.split('T')[1]
                              : '');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.access_time,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        title: Text(record['name'] ?? 'Unknown'),
                        subtitle: Text(record['reg_no'] ?? ''),
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

class HODStaffTab extends StatefulWidget {
  final String token;
  final String dept;

  const HODStaffTab({super.key, required this.token, required this.dept});

  @override
  State<HODStaffTab> createState() => _HODStaffTabState();
}

class _HODStaffTabState extends State<HODStaffTab> {
  List<dynamic> staff = [];
  bool isLoading = true;
  final _formKey = GlobalKey<FormState>();

  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchStaff();
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchStaff() async {
    setState(() => isLoading = true);
    try {
      // Debug: log department for verification
      // print('[HODStaffTab] Fetching staff for department: ${widget.dept}');
      // Debug: log token for verification
      // print('[HODStaffTab] Using token: ${widget.token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse('$API_URL/hod/staff'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      // Debug: log response status
      // print('[HODStaffTab] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final staffData = jsonDecode(response.body)['staff'];
        // Debug: log raw staff data
        // print('[HODStaffTab] Raw staff data received: ${staffData.length} staff');

        // Department filtering is handled by the backend
        // Debug validation (can be removed in production)
        // final allStaff = jsonDecode(response.body)['staff'] as List;
        // for (var s in allStaff) {
        //   if (s['dept'] != widget.dept) {
        //     print('[WARNING] Staff ${s['name']} has wrong department!');
        //   }
        // }

        setState(() => staff = staffData);
        // Debug: log staff list update
        // print('[HODStaffTab] Staff list updated with ${staff.length} members');
      } else {
        // Debug: log error response
        // print('[HODStaffTab] Error response: ${response.body}');
      }
    } catch (e) {
      // Debug: log fetch error
      // print('[HODStaffTab] Error fetching staff: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _registerStaffFace(Map<String, dynamic> member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRegistrationWidget(
          token: widget.token,
          role: 'staff',
          initialRegNo: member['reg_no'],
          initialName: member['name'],
          initialDept: widget.dept,
          registerEndpoint: '/hod/face/register',
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Face registered successfully!')),
            );
            fetchStaff();
          },
        ),
      ),
    );
  }

  Future<void> _grantPermission(String regNo, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$API_URL/hod/face/permission/$regNo'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Permission granted to $name')));
        fetchStaff();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Failed to grant permission'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _revokePermission(String regNo, String name) async {
    try {
      final response = await http.delete(
        Uri.parse('$API_URL/hod/face/permission/$regNo'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Permission revoked for $name')));
        fetchStaff();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Failed to revoke permission'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> createStaff() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final response = await http.post(
        Uri.parse('$API_URL/hod/staff/create'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': usernameCtrl.text,
          'password': passwordCtrl.text,
          'name': nameCtrl.text,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff created successfully')),
        );
        fetchStaff();
        _clearForm();
        Navigator.pop(context);
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['detail'] ?? 'Failed to create staff')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _clearForm() {
    usernameCtrl.clear();
    passwordCtrl.clear();
    nameCtrl.clear();
  }

  void _showCreateStaffDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Staff to ${widget.dept}'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  obscureText: true,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.text_fields),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Staff will be added to ${widget.dept}',
                          style: TextStyle(
                            color: Colors.teal[700],
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
            onPressed: createStaff,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Create Staff'),
          ),
        ],
      ),
    );
  }

  Future<void> editStaff(Map<String, dynamic> staffMember) async {
    final nameCtrl = TextEditingController(text: staffMember['name']);
    final usernameCtrl = TextEditingController(text: staffMember['username']);
    final passwordCtrl = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password (leave empty to keep current)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final payload = {
                'name': nameCtrl.text,
                'username': usernameCtrl.text,
              };
              final password = passwordCtrl.text.trim();
              if (password.isNotEmpty) {
                payload['password'] = password;
              }
              Navigator.pop(context, payload);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final response = await http.put(
        Uri.parse('$API_URL/hod/staff/${staffMember['id']}'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(result),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff updated successfully')),
        );
        fetchStaff();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['detail'] ?? 'Failed to update staff')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> deleteStaff(int staffId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Are you sure you want to delete $username?'),
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
        Uri.parse('$API_URL/hod/staff/$staffId'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff deleted successfully')),
        );
        fetchStaff();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete staff')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.dept.toUpperCase()} Staff',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Total: ${staff.length}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action buttons row
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _showCreateStaffDialog,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(isMobile ? 'Add' : 'Add Staff'),
                        ),
                        OutlinedButton.icon(
                          onPressed: fetchStaff,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                          ),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : staff.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No staff in ${widget.dept}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _showCreateStaffDialog,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Staff'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 16,
                    vertical: 8,
                  ),
                  itemCount: staff.length,
                  itemBuilder: (context, index) {
                    final member = staff[index];
                    final faceRegistered = member['face_registered'] == true;
                    final canReregister = member['can_reregister'] == true;
                    return _HODStaffCard(
                      member: member,
                      faceRegistered: faceRegistered,
                      canReregister: canReregister,
                      isMobile: isMobile,
                      onRegisterFace: () => _registerStaffFace(member),
                      onTogglePermission: () {
                        if (canReregister) {
                          _revokePermission(member['reg_no'], member['name']);
                        } else {
                          _grantPermission(member['reg_no'], member['name']);
                        }
                      },
                      onEdit: () => editStaff(member),
                      onDelete: () =>
                          deleteStaff(member['id'], member['username']),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// HOD Staff Card Widget - Responsive
class _HODStaffCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool faceRegistered;
  final bool canReregister;
  final bool isMobile;
  final VoidCallback onRegisterFace;
  final VoidCallback onTogglePermission;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _HODStaffCard({
    required this.member,
    required this.faceRegistered,
    required this.canReregister,
    required this.isMobile,
    required this.onRegisterFace,
    required this.onTogglePermission,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return _buildMobileCard(context);
    } else {
      return _buildDesktopCard(context);
    }
  }

  Widget _buildMobileCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: faceRegistered
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  child: Icon(
                    faceRegistered ? Icons.check_circle : Icons.person,
                    color: faceRegistered ? Colors.green : Colors.teal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        member['username'] ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info row
            Row(
              children: [
                Icon(Icons.badge, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  member['reg_no'] ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Face status
            Row(
              children: [
                Icon(
                  faceRegistered ? Icons.face : Icons.face_outlined,
                  size: 16,
                  color: faceRegistered ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  faceRegistered ? 'Face Registered' : 'Face Not Registered',
                  style: TextStyle(
                    fontSize: 12,
                    color: faceRegistered ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action buttons - wrapped
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HODActionButton(
                  icon: faceRegistered ? Icons.refresh : Icons.add_a_photo,
                  label: faceRegistered ? 'Re-register' : 'Register',
                  color: faceRegistered ? Colors.blue : Colors.green,
                  onPressed: onRegisterFace,
                ),
                _HODActionButton(
                  icon: canReregister ? Icons.lock_open : Icons.lock,
                  label: canReregister ? 'Revoke' : 'Grant',
                  color: canReregister ? Colors.green : Colors.red,
                  onPressed: onTogglePermission,
                ),
                _HODActionButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  color: Colors.blue,
                  onPressed: onEdit,
                ),
                _HODActionButton(
                  icon: Icons.delete,
                  label: 'Delete',
                  color: Colors.red,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: faceRegistered
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: Icon(
            faceRegistered ? Icons.check_circle : Icons.person,
            color: faceRegistered ? Colors.green : Colors.orange,
            size: 20,
          ),
        ),
        title: Text(member['name'] ?? 'Unknown'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member['username'] ?? ''),
            Text(member['reg_no'] ?? '', style: const TextStyle(fontSize: 12)),
            Row(
              children: [
                Icon(
                  faceRegistered ? Icons.face : Icons.face_outlined,
                  size: 14,
                  color: faceRegistered ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  faceRegistered ? 'Face Registered' : 'Face Not Registered',
                  style: TextStyle(
                    fontSize: 10,
                    color: faceRegistered ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                faceRegistered ? Icons.refresh : Icons.add_a_photo,
                color: faceRegistered ? Colors.blue : Colors.green,
              ),
              onPressed: onRegisterFace,
              tooltip: faceRegistered ? 'Re-register face' : 'Register face',
            ),
            IconButton(
              icon: Icon(
                canReregister ? Icons.lock_open : Icons.lock,
                color: canReregister ? Colors.green : Colors.red,
              ),
              onPressed: onTogglePermission,
              tooltip: canReregister
                  ? 'Revoke re-register permission'
                  : 'Grant re-register permission',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
              tooltip: 'Edit staff',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// HOD Action Button Widget for mobile
class _HODActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _HODActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// HOD Staff Attendance Tab - View staff attendance records
class HODStaffAttendanceTab extends StatefulWidget {
  final String token;
  final String dept;

  const HODStaffAttendanceTab({
    super.key,
    required this.token,
    required this.dept,
  });

  @override
  State<HODStaffAttendanceTab> createState() => _HODStaffAttendanceTabState();
}

class _HODStaffAttendanceTabState extends State<HODStaffAttendanceTab> {
  List<dynamic> staffAttendance = [];
  bool isLoading = true;
  String? selectedDate;

  @override
  void initState() {
    super.initState();
    fetchStaffAttendance();
  }

  Future<void> fetchStaffAttendance() async {
    setState(() => isLoading = true);
    try {
      final url = selectedDate != null
          ? Uri.parse('$API_URL/hod/attendance/staff?date=$selectedDate')
          : Uri.parse('$API_URL/hod/attendance/staff');
      // Staff attendance with caching (2 minutes)
      final response = await apiClient.get(
        url.toString(),
        token: widget.token,
        cacheKey: 'hod_staff_attendance',
        cacheDuration: const Duration(minutes: 2),
      );
      if (response.statusCode == 200) {
        setState(
          () => staffAttendance = jsonDecode(response.body)['attendance'],
        );
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
      fetchStaffAttendance();
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
      fetchStaffAttendance();
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
      fetchStaffAttendance();
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
                      '${widget.dept.toUpperCase()} Staff Attendance (${staffAttendance.length})',
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
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          foregroundColor: Colors.teal,
                        ),
                        tooltip: 'Previous Day',
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _selectDate,
                        style: FilledButton.styleFrom(
                          backgroundColor: selectedDate != null
                              ? Colors.teal
                              : Colors.grey,
                        ),
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          selectedDate ?? 'Filter Date',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedDate != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {
                            setState(() => selectedDate = null);
                            fetchStaffAttendance();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(36, 36),
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
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          foregroundColor: Colors.teal,
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
              : staffAttendance.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        selectedDate != null
                            ? 'No staff attendance for $selectedDate'
                            : 'No staff attendance records',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: staffAttendance.length,
                  itemBuilder: (context, index) {
                    final record = staffAttendance[index];
                    final timestamp = record['timestamp']?.toString() ?? '';
                    // Handle both "2024-03-11 07:04:29" and "2024-03-11T07:04:29" formats
                    final datePart = timestamp.contains(' ')
                        ? timestamp.split(' ')[0]
                        : (timestamp.contains('T')
                              ? timestamp.split('T')[0]
                              : '');
                    final timePart = timestamp.contains(' ')
                        ? timestamp.split(' ')[1]
                        : (timestamp.contains('T')
                              ? timestamp.split('T')[1]
                              : '');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.person,
                            color: Colors.teal,
                            size: 20,
                          ),
                        ),
                        title: Text(record['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(record['reg_no'] ?? ''),
                            Text(
                              'Staff',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.teal,
                              ),
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

// HOD Mark Attendance Tab - HOD can mark their own attendance via face verification
class HODMarkAttendanceTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const HODMarkAttendanceTab({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<HODMarkAttendanceTab> createState() => _HODMarkAttendanceTabState();
}

class _HODMarkAttendanceTabState extends State<HODMarkAttendanceTab> {
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
        Uri.parse("$API_URL/hod/attendance?date=$today"),
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
          role: 'hod',
          initialRegNo: widget.user['regNo'],
          initialName: widget.user['name'],
          initialDept: widget.user['dept'],
          registerEndpoint: '/hod/face/register',
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.teal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mark Your Attendance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              _isRegistered
                                  ? "Face Registered"
                                  : "Face Not Registered",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!_isRegistered)
                              const Text(
                                "Please register your face to mark attendance",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: !_isWindowAllowed
                          ? Colors.red.withValues(alpha: 0.1)
                          : (_alreadyMarkedCurrentSlot
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_isWindowAllowed
                            ? Colors.red
                            : (_alreadyMarkedCurrentSlot ? Colors.green : Colors.orange),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !_isWindowAllowed
                              ? Icons.error_outline
                              : (_alreadyMarkedCurrentSlot
                                  ? Icons.check_circle
                                  : Icons.access_time),
                          color: !_isWindowAllowed
                              ? Colors.red
                              : (_alreadyMarkedCurrentSlot ? Colors.green : Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            !_isWindowAllowed
                                ? "Outside active attendance window"
                                : (_alreadyMarkedCurrentSlot
                                    ? "You have already marked ${_activeSlotType == 'check_in' ? 'check-in' : 'check-out'} attendance today!"
                                    : "Active Slot: ${_activeSlotType == 'check_in' ? 'Check-In' : 'Check-Out'} (Verification Required)"),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_isWindowAllowed
                                  ? Colors.red
                                  : (_alreadyMarkedCurrentSlot
                                      ? Colors.green
                                      : Colors.orange[700]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isRegistered) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _navigateToFaceRegistration,
                        icon: const Icon(Icons.face),
                        label: const Text("Register Face First"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (_isRegistered && _isWindowAllowed && !_alreadyMarkedCurrentSlot)
                          ? _navigateToMarkAttendance
                          : null,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(
                        !_isWindowAllowed
                            ? "Outside Window"
                            : (_alreadyMarkedCurrentSlot
                                ? "Already ${_activeSlotType == 'check_in' ? 'Checked-In' : 'Checked-Out'}"
                                : "Mark ${_activeSlotType == 'check_in' ? 'Check-In' : 'Check-Out'}"),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instructions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionTile(
                    Icons.camera_alt,
                    'Position your face in the camera frame',
                  ),
                  _buildInstructionTile(
                    Icons.face,
                    'Look at the camera for face detection',
                  ),
                  _buildInstructionTile(
                    Icons.check_circle,
                    'Attendance will be marked automatically',
                  ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// HOD Face Registration Tab - Only for self-registration
class HODFaceRegisterTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const HODFaceRegisterTab({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<HODFaceRegisterTab> createState() => _HODFaceRegisterTabState();
}

class _HODFaceRegisterTabState extends State<HODFaceRegisterTab> {
  bool _isRegistered = false;
  bool _isLoading = true;
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

  void _navigateToFaceRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRegistrationWidget(
          token: widget.token,
          role: 'hod',
          initialRegNo: widget.user['regNo'],
          initialName: widget.user['name'],
          initialDept: widget.user['dept'],
          registerEndpoint: '/hod/face/register',
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    _isRegistered
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: _isRegistered ? Colors.green : Colors.orange,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Face Registration',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegistered
                        ? 'Your face is registered'
                        : 'Face not registered yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isRegistered
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          label: 'Name',
                          value: widget.user['name'] ?? '',
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'ID',
                          value: widget.user['regNo'] ?? '',
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Dept',
                          value: widget.user['dept'] ?? '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToFaceRegistration,
                      icon: Icon(_isRegistered ? Icons.refresh : Icons.face),
                      label: Text(
                        _isRegistered ? 'Re-register Face' : 'Register Face',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.teal[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Instructions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionTile(
                    Icons.person_outline,
                    'This section is for registering YOUR own face only',
                  ),
                  _buildInstructionTile(
                    Icons.camera_alt_outlined,
                    'Position your face in the camera frame',
                  ),
                  _buildInstructionTile(
                    Icons.check_circle_outline,
                    'Tap capture when face is detected',
                  ),
                  _buildInstructionTile(
                    Icons.save_outlined,
                    'Confirm registration',
                  ),
                ],
              ),
            ),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _message,
                      style: const TextStyle(color: Colors.red),
                    ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          ': $value',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// HOD Merged Analytics Tab - Combines Dept Stats + Staff Analytics
class HODMergedAnalyticsTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final String dept;

  const HODMergedAnalyticsTab({
    super.key,
    required this.token,
    required this.user,
    required this.dept,
  });

  @override
  State<HODMergedAnalyticsTab> createState() => _HODMergedAnalyticsTabState();
}

class _HODMergedAnalyticsTabState extends State<HODMergedAnalyticsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.teal, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analytics',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                          ),
                          Text(
                            widget.dept.toUpperCase(),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1C1E)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? Colors.white70
                        : Colors.grey.shade700,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.group, size: 18),
                        text: 'Department',
                      ),
                      Tab(
                        icon: Icon(Icons.person, size: 18),
                        text: 'Individual',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _DeptStatsInner(token: widget.token, dept: widget.dept),
              _StaffAnalyticsInner(token: widget.token, dept: widget.dept),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeptStatsInner extends StatefulWidget {
  final String token;
  final String dept;
  const _DeptStatsInner({required this.token, required this.dept});
  @override
  State<_DeptStatsInner> createState() => _DeptStatsInnerState();
}

class _DeptStatsInnerState extends State<_DeptStatsInner> {
  bool isLoading = false;
  bool isGeneratingPdf = false;
  Map<String, dynamic>? statsData;
  String? startDate;
  String? endDate;
  Future<void> _generateAndDownloadPdf() async {
    if (statsData == null) return;
    setState(() => isGeneratingPdf = true);

    try {
      final data = statsData!;
      final summary = data['summary'] as Map<String, dynamic>;
      final staffList = data['staff'] as List? ?? [];
      final workingDays = data['working_days'] ?? 0;
      final totalStaff = data['total_staff'] ?? 0;
      final overallPct = (summary['overall_attendance_pct'] ?? 0).toDouble();
      
      final startDateStr = startDate ?? 'Start';
      final endDateStr = endDate ?? 'End';
      final deptName = widget.dept.replaceAll(' ', '_');
      final filename = 'attendance_report_${deptName}_${startDateStr}_to_$endDateStr.pdf';

      final pdf = pw.Document();

      // Theme Colors
      final primaryColor = PdfColor.fromInt(0xFF4F46E5);      // Modern Indigo
      final darkColor = PdfColor.fromInt(0xFF0F172A);         // Slate 900
      final lightColor = PdfColor.fromInt(0xFFF8FAFC);        // Slate 50
      final greyColor = PdfColor.fromInt(0xFF64748B);         // Slate 500
      final borderColor = PdfColor.fromInt(0xFFE2E8F0);       // Slate 200
      final highlightColor = PdfColor.fromInt(0xFFEEF2FF);   // Light Indigo tint

      final cardBuilder = (String title, String value, PdfColor color, bool highlight) {
        return pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: highlight ? highlightColor : PdfColors.white,
              border: pw.Border.all(color: highlight ? color : borderColor, width: highlight ? 1.5 : 1.0),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: highlight ? color : greyColor,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: highlight ? color : darkColor,
                  ),
                ),
              ],
            ),
          ),
        );
      };

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ATTENDANCE ANALYTICS REPORT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Department: ${widget.dept.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Period: $startDateStr to $endDateStr',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated: ${DateTime.now().toLocal().toString().split('.').first}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Summary KPI Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                cardBuilder('Overall Attendance', '${overallPct.toStringAsFixed(1)}%', primaryColor, true),
                pw.SizedBox(width: 12),
                cardBuilder('Total Staff', totalStaff.toString(), darkColor, false),
                pw.SizedBox(width: 12),
                cardBuilder('Working Days', workingDays.toString(), darkColor, false),
              ],
            ),
            pw.SizedBox(height: 24),
            
            // Stats Breakdown Table
            pw.Text(
              'Detailed Summary Metrics',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkColor),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Metric Description', 'Count / Value'],
              data: [
                ['Total Present Days (Scan)', summary['total_present']?.toString() ?? '0'],
                ['Total Absent Days', summary['total_absent']?.toString() ?? '0'],
                ['Total Approved Leaves', summary['total_leave']?.toString() ?? '0'],
                ['Total On Duty (OD) Days', summary['total_od']?.toString() ?? '0'],
              ],
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: darkColor),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: pw.BoxDecoration(color: lightColor),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 24),
            
            // Staff Table
            pw.Text(
              'Staff Performance & Attendance Breakdown',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkColor),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Name', 'Reg No', 'Present', 'Absent', 'Leave', 'OD', 'Attendance %'],
              data: staffList.map((s) {
                return [
                  s['name'] ?? 'Unknown',
                  s['reg_no'] ?? '',
                  s['present']?.toString() ?? '0',
                  s['absent']?.toString() ?? '0',
                  s['leave']?.toString() ?? '0',
                  s['od']?.toString() ?? '0',
                  '${(s['attendance_pct'] ?? 0).toStringAsFixed(1)}%',
                ];
              }).toList(),
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: pw.BoxDecoration(color: lightColor),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );

      await Printing.sharePdf(bytes: await pdf.save(), filename: filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isGeneratingPdf = false);
    }
  }
  @override
  void initState() {
    super.initState();
    _selectThisMonth();
  }

  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      startDate = _fmt(now);
      endDate = _fmt(now);
    });
    _loadStats();
  }

  void _selectThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      startDate = _fmt(startOfWeek);
      endDate = _fmt(now);
    });
    _loadStats();
  }

  void _selectThisMonth() {
    final now = DateTime.now();
    setState(() {
      startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      endDate = _fmt(now);
    });
    _loadStats();
  }

  void _selectLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDay = DateTime(now.year, now.month, 0);
    setState(() {
      startDate = _fmt(lastMonth);
      endDate = _fmt(lastDay);
    });
    _loadStats();
  }

  void _selectLast7Days() {
    final now = DateTime.now();
    final ago = now.subtract(const Duration(days: 6));
    setState(() {
      startDate = _fmt(ago);
      endDate = _fmt(now);
    });
    _loadStats();
  }

  void _selectLast30Days() {
    final now = DateTime.now();
    final ago = now.subtract(const Duration(days: 29));
    setState(() {
      startDate = _fmt(ago);
      endDate = _fmt(now);
    });
    _loadStats();
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    DateTime? initialStart;
    DateTime? initialEnd;

    // Load academic range bounds
    DateTime firstDate = DateTime(2024);
    DateTime lastDate = now;
    try {
      final acadResp = await http.get(Uri.parse('${CollegeIPConfig.defaultURL}/academics/current'));
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

    if (startDate != null) initialStart = DateTime.parse(startDate!);
    if (endDate != null) initialEnd = DateTime.parse(endDate!);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialStart != null && initialEnd != null
          ? DateTimeRange(start: initialStart, end: initialEnd)
          : DateTimeRange(start: initialStart ?? firstDate, end: initialEnd ?? lastDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (picked.start.isAfter(picked.end)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Start date cannot be after end date'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (picked.end.isAfter(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cannot select future dates'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        startDate = _fmt(picked.start);
        endDate = _fmt(picked.end);
      });
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    if (startDate == null || endDate == null) return;

    setState(() => isLoading = true);
    try {
      final url =
          '$API_URL/hod/attendance/range-stats?start_date=$startDate&end_date=$endDate';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() => statsData = jsonDecode(response.body));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load stats: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}/${d.month}/${d.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Date Range',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.teal),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, color: Colors.teal),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date Range',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    startDate != null && endDate != null
                                        ? '${_formatDate(startDate!)} - ${_formatDate(endDate!)}'
                                        : 'Tap to select',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.teal),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Quick Select',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickSelectChip(
                          label: 'Today',
                          onTap: _selectToday,
                          color: Colors.teal,
                        ),
                        _QuickSelectChip(
                          label: 'This Week',
                          onTap: _selectThisWeek,
                          color: Colors.blue,
                        ),
                        _QuickSelectChip(
                          label: 'This Month',
                          onTap: _selectThisMonth,
                          color: Colors.green,
                        ),
                        _QuickSelectChip(
                          label: 'Last Month',
                          onTap: _selectLastMonth,
                          color: Colors.orange,
                        ),
                        _QuickSelectChip(
                          label: 'Last 7 Days',
                          onTap: _selectLast7Days,
                          color: Colors.cyan,
                        ),
                        _QuickSelectChip(
                          label: 'Last 30 Days',
                          onTap: _selectLast30Days,
                          color: Colors.indigo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (statsData != null)
              _buildSummaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final data = statsData!;
    final summary = data['summary'] as Map<String, dynamic>;
    final staffList = data['staff'] as List? ?? [];
    final workingDays = data['working_days'] ?? 0;
    final totalStaff = data['total_staff'] ?? 0;
    final overallPct = summary['overall_attendance_pct'] ?? 0;
    final totalPresent = summary['total_present'] ?? 0;
    final totalLeave = summary['total_leave'] ?? 0;
    final totalAbsent = summary['total_absent'] ?? 0;
    final totalOd = summary['total_od'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.summarize, color: Colors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Summary (${_formatDate(data['start_date'])} - ${_formatDate(data['end_date'])})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: isGeneratingPdf
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.teal),
                              ),
                            )
                          : const Icon(Icons.download, color: Colors.teal),
                      onPressed: isGeneratingPdf ? null : _generateAndDownloadPdf,
                      tooltip: 'Download Report',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: overallPct / 100,
                                strokeWidth: 10,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation(
                                  overallPct >= 75
                                      ? Colors.green
                                      : overallPct >= 50
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${overallPct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                                Text(
                                  'Attendance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalStaff staff | $workingDays working days',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _MiniStatCard(
                      label: 'Present',
                      value: totalPresent.toString(),
                      color: Colors.green,
                      icon: Icons.check_circle,
                    ),
                    _MiniStatCard(
                      label: 'Absent',
                      value: totalAbsent.toString(),
                      color: Colors.red,
                      icon: Icons.cancel,
                    ),
                    _MiniStatCard(
                      label: 'Leave',
                      value: totalLeave.toString(),
                      color: Colors.orange,
                      icon: Icons.event_busy,
                    ),
                    _MiniStatCard(
                      label: 'On Duty',
                      value: totalOd.toString(),
                      color: Colors.blue,
                      icon: Icons.work,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Staff Breakdown',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (staffList.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No staff found in ${widget.dept.toUpperCase()}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: staffList.length,
            itemBuilder: (context, index) {
              final s = staffList[index];
              final pct = (s['attendance_pct'] ?? 0).toDouble();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: pct >= 75
                        ? Colors.green
                        : pct >= 50
                        ? Colors.orange
                        : Colors.red,
                    child: Text(
                      (s['name'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    s['name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['reg_no'] ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          pct >= 75
                              ? Colors.green
                              : pct >= 50
                              ? Colors.orange
                              : Colors.red,
                        ),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _InlineBadge(
                            label: 'P: ${s['present']}',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          _InlineBadge(
                            label: 'L: ${s['leave']}',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          _InlineBadge(
                            label: 'OD: ${s['od']}',
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          _InlineBadge(
                            label: 'A: ${s['absent']}',
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: pct >= 75
                          ? Colors.green
                          : pct >= 50
                          ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _StaffAnalyticsInner extends StatefulWidget {
  final String token;
  final String dept;
  const _StaffAnalyticsInner({required this.token, required this.dept});
  @override
  State<_StaffAnalyticsInner> createState() => _StaffAnalyticsInnerState();
}

class _StaffAnalyticsInnerState extends State<_StaffAnalyticsInner> {
  List<dynamic> staff = [];
  bool isLoadingStaff = true;
  bool isLoadingDetails = false;

  dynamic selectedStaff;
  String? startDate;
  String? endDate;
  Map<String, dynamic>? attendanceDetails;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  void _selectToday() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    setState(() {
      startDate = dateStr;
      endDate = dateStr;
    });
    _loadStaffDetails();
  }

  void _selectThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      startDate =
          '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';
      endDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  void _selectThisMonth() {
    final now = DateTime.now();
    setState(() {
      startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      endDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  void _selectLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
    setState(() {
      startDate =
          '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-01';
      endDate =
          '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-${lastDayOfLastMonth.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  void _selectLast7Days() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 6));
    setState(() {
      startDate =
          '${sevenDaysAgo.year}-${sevenDaysAgo.month.toString().padLeft(2, '0')}-${sevenDaysAgo.day.toString().padLeft(2, '0')}';
      endDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  void _selectLast30Days() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 29));
    setState(() {
      startDate =
          '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';
      endDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    DateTime? initialStart;
    DateTime? initialEnd;

    // Load academic range bounds
    DateTime firstDate = DateTime(2024);
    DateTime lastDate = now;
    try {
      final acadResp = await http.get(Uri.parse('${CollegeIPConfig.defaultURL}/academics/current'));
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

    if (startDate != null) initialStart = DateTime.parse(startDate!);
    if (endDate != null) initialEnd = DateTime.parse(endDate!);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialStart != null && initialEnd != null
          ? DateTimeRange(start: initialStart, end: initialEnd)
          : DateTimeRange(start: initialStart ?? firstDate, end: initialEnd ?? lastDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (picked.start.isAfter(picked.end)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Start date cannot be after end date'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (picked.end.isAfter(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cannot select future dates'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        startDate = _fmt(picked.start);
        endDate = _fmt(picked.end);
      });
      _loadStaffDetails();
    }
  }

  void _goToPreviousWeek() {
    if (startDate == null || endDate == null) return;
    try {
      final start = DateTime.parse(startDate!);
      final end = DateTime.parse(endDate!);
      final duration = end.difference(start).inDays;
      final newStart = start.subtract(Duration(days: duration + 1));
      final newEnd = end.subtract(Duration(days: duration + 1));
      setState(() {
        startDate = _fmt(newStart);
        endDate = _fmt(newEnd);
      });
      _loadStaffDetails();
    } catch (e) {
      debugPrint('Error navigating to previous week: $e');
    }
  }

  void _goToNextWeek() {
    if (startDate == null || endDate == null) return;
    try {
      final start = DateTime.parse(startDate!);
      final end = DateTime.parse(endDate!);
      final duration = end.difference(start).inDays;
      final newStart = start.add(Duration(days: duration + 1));
      final newEnd = end.add(Duration(days: duration + 1));
      if (newStart.isAfter(DateTime.now())) return;
      setState(() {
        startDate = _fmt(
          newStart.isAfter(DateTime.now()) ? DateTime.now() : newStart,
        );
        endDate = _fmt(
          newEnd.isAfter(DateTime.now()) ? DateTime.now() : newEnd,
        );
      });
      _loadStaffDetails();
    } catch (e) {
      debugPrint('Error navigating to next week: $e');
    }
  }

  void _clearDates() {
    setState(() {
      startDate = null;
      endDate = null;
      attendanceDetails = null;
    });
  }

  String _formatDateForDisplay(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}/${d.month}/${d.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _loadStaff() async {
    setState(() => isLoadingStaff = true);
    try {
      final url = '$API_URL/hod/attendance/staff-list?dept=${widget.dept}';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          staff = data['staff'] ?? [];
          isLoadingStaff = false;
        });
      } else {
        setState(() => isLoadingStaff = false);
      }
    } catch (e) {
      setState(() => isLoadingStaff = false);
    }
  }

  Future<void> _loadStaffDetails() async {
    if (selectedStaff == null) return;

    setState(() => isLoadingDetails = true);
    try {
      final regNo = selectedStaff['reg_no'];
      String url = '$API_URL/hod/attendance/staff-details?reg_no=$regNo';
      if (startDate != null && endDate != null) {
        url += '&start_date=$startDate&end_date=$endDate';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() => attendanceDetails = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error loading staff details: $e');
    } finally {
      setState(() => isLoadingDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Staff Member',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (isLoadingStaff)
                    const Center(child: CircularProgressIndicator())
                  else if (staff.isEmpty)
                    const Text('No staff members found in your department.')
                  else
                    DropdownButtonFormField<dynamic>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      hint: const Text('Select Staff'),
                      value: selectedStaff,
                      items: staff.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s['name']} (${s['reg_no']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedStaff = value;
                          attendanceDetails = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Date Range',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _goToPreviousWeek,
                        icon: const Icon(Icons.chevron_left),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          foregroundColor: Colors.teal,
                        ),
                        tooltip: 'Previous Week',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: _selectDateRange,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.teal),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.date_range, color: Colors.teal),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Select Range',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        startDate != null && endDate != null
                                            ? '${_formatDateForDisplay(startDate!)} to ${_formatDateForDisplay(endDate!)}'
                                            : 'Tap to select date range',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.teal),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _goToNextWeek,
                        icon: const Icon(Icons.chevron_right),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          foregroundColor: Colors.teal,
                        ),
                        tooltip: 'Next Week',
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _clearDates,
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: selectedStaff != null
                            ? _loadStaffDetails
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        icon: const Icon(Icons.search),
                        label: const Text('View Analytics'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Quick Select',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
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
                          color: Colors.teal,
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
                          color: Colors.cyan,
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
          ),
          const SizedBox(height: 16),
          if (isLoadingDetails)
            const Center(child: CircularProgressIndicator())
          else if (attendanceDetails != null)
            _buildResultsCard(),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final details = attendanceDetails!;
    final person = details['person'];
    final totalRecords = details['total_records'] ?? 0;
    final totalDays = details['total_days_present'] ?? 0;
    final datesPresent = details['dates_present'] as List? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Text(
                      person['name']
                              ?.toString()
                              .substring(0, 1)
                              .toUpperCase() ??
                          '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${person['reg_no']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AnimatedStatCard(
                    title: 'Total Records',
                    value: totalRecords.toString(),
                    icon: Icons.fingerprint,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedStatCard(
                    title: 'Days Present',
                    value: totalDays.toString(),
                    icon: Icons.calendar_today,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Attendance Dates',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (datesPresent.isEmpty)
              const Text('No attendance records found for the selected period.')
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: datesPresent.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      title: Text(datesPresent[index]),
                      dense: true,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// HOD Attendance Analytics Tab - View staff attendance with calendar
class HODAttendanceAnalyticsTab extends StatefulWidget {
  final String token;
  final String dept;

  const HODAttendanceAnalyticsTab({
    super.key,
    required this.token,
    required this.dept,
  });

  @override
  State<HODAttendanceAnalyticsTab> createState() =>
      _HODAttendanceAnalyticsTabState();
}

class _HODAttendanceAnalyticsTabState extends State<HODAttendanceAnalyticsTab> {
  List<dynamic> staff = [];
  bool isLoadingStaff = true;
  bool isLoadingDetails = false;

  dynamic selectedStaff;
  String? startDate;
  String? endDate;
  Map<String, dynamic>? attendanceDetails;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  // Quick select methods for common date ranges
  void _selectToday() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    setState(() {
      startDate = dateStr;
      endDate = dateStr;
    });
    _loadStaffDetails();
  }

  void _selectThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      startDate =
          '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';
      endDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  void _selectThisMonth() {
    final now = DateTime.now();
    setState(() {
      startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      endDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  void _selectLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
    setState(() {
      startDate =
          '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-01';
      endDate =
          '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-${lastDayOfLastMonth.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  void _selectLast7Days() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 6));
    setState(() {
      startDate =
          '${sevenDaysAgo.year}-${sevenDaysAgo.month.toString().padLeft(2, '0')}-${sevenDaysAgo.day.toString().padLeft(2, '0')}';
      endDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  void _selectLast30Days() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 29));
    setState(() {
      startDate =
          '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';
      endDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    });
    _loadStaffDetails();
  }

  void _clearDates() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    _loadStaffDetails();
  }

  // Week navigation methods for date range
  void _goToPreviousWeek() {
    if (startDate != null && endDate != null) {
      final start = DateTime.parse(startDate!);
      final end = DateTime.parse(endDate!);
      setState(() {
        startDate =
            '${start.subtract(const Duration(days: 7)).year}-${start.subtract(const Duration(days: 7)).month.toString().padLeft(2, '0')}-${start.subtract(const Duration(days: 7)).day.toString().padLeft(2, '0')}';
        endDate =
            '${end.subtract(const Duration(days: 7)).year}-${end.subtract(const Duration(days: 7)).month.toString().padLeft(2, '0')}-${end.subtract(const Duration(days: 7)).day.toString().padLeft(2, '0')}';
      });
      _loadStaffDetails();
    }
  }

  void _goToNextWeek() {
    final now = DateTime.now();
    if (startDate != null && endDate != null) {
      final start = DateTime.parse(startDate!);
      final end = DateTime.parse(endDate!);
      final newEnd = end.add(const Duration(days: 7));
      // Don't go beyond today
      if (newEnd.isAfter(now)) {
        return;
      }
      setState(() {
        startDate =
            '${start.add(const Duration(days: 7)).year}-${start.add(const Duration(days: 7)).month.toString().padLeft(2, '0')}-${start.add(const Duration(days: 7)).day.toString().padLeft(2, '0')}';
        endDate =
            '${newEnd.year}-${newEnd.month.toString().padLeft(2, '0')}-${newEnd.day.toString().padLeft(2, '0')}';
      });
      _loadStaffDetails();
    }
  }

  Future<void> _loadStaff() async {
    try {
      final response = await http.get(
        Uri.parse('$API_URL/hod/attendance/staff-list'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() => staff = jsonDecode(response.body)['staff']);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading staff: ${ApiResponseUtils.sanitize(e)}')));
    } finally {
      setState(() => isLoadingStaff = false);
    }
  }

  Future<void> _loadStaffDetails() async {
    if (selectedStaff == null) return;

    setState(() => isLoadingDetails = true);
    try {
      String url =
          '$API_URL/hod/attendance/staff-details?reg_no=${selectedStaff['reg_no'] ?? selectedStaff['username']}';
      if (startDate != null) url += '&start_date=$startDate';
      if (endDate != null) url += '&end_date=$endDate';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() => attendanceDetails = jsonDecode(response.body));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading details: ${ApiResponseUtils.sanitize(e)}')));
    } finally {
      setState(() => isLoadingDetails = false);
    }
  }

  // Google Calendar-like date range picker
  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    DateTime? initialStart;
    DateTime? initialEnd;

    if (startDate != null) {
      initialStart = DateTime.parse(startDate!);
    }
    if (endDate != null) {
      initialEnd = DateTime.parse(endDate!);
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: initialStart != null && initialEnd != null
          ? DateTimeRange(start: initialStart, end: initialEnd)
          : initialStart != null
          ? DateTimeRange(start: initialStart, end: now)
          : DateTimeRange(start: initialStart ?? DateTime(now.year, now.month, 1), end: initialEnd ?? now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
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
        startDate =
            '${picked.start.year}-${picked.start.month.toString().padLeft(2, '0')}-${picked.start.day.toString().padLeft(2, '0')}';
        endDate =
            '${picked.end.year}-${picked.end.month.toString().padLeft(2, '0')}-${picked.end.day.toString().padLeft(2, '0')}';
      });
      _loadStaffDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            color: Colors.teal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.analytics, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Staff Analytics',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.dept.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Staff Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Staff Member',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (isLoadingStaff)
                    const Center(child: CircularProgressIndicator())
                  else if (staff.isEmpty)
                    const Text('No staff members found in your department.')
                  else
                    DropdownButtonFormField<dynamic>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      hint: const Text('Select Staff'),
                      value: selectedStaff,
                      items: staff.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s['name']} (${s['reg_no']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedStaff = value;
                          attendanceDetails = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date Range Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Date Range',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // Week navigation + date range picker
                  Row(
                    children: [
                      // Previous week button
                      IconButton(
                        onPressed: _goToPreviousWeek,
                        icon: const Icon(Icons.chevron_left),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          foregroundColor: Colors.teal,
                        ),
                        tooltip: 'Previous Week',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: _selectDateRange,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.teal),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.date_range, color: Colors.teal),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Select Range',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        startDate != null && endDate != null
                                            ? '${_formatDateForDisplay(startDate!)} to ${_formatDateForDisplay(endDate!)}'
                                            : 'Tap to select date range',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.teal),
                              ],
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
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          foregroundColor: Colors.teal,
                        ),
                        tooltip: 'Next Week',
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _clearDates,
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: selectedStaff != null
                            ? _loadStaffDetails
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        icon: const Icon(Icons.search),
                        label: const Text('View Analytics'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Quick select buttons
                  const Text(
                    'Quick Select',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
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
                          color: Colors.teal,
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
                          color: Colors.cyan,
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
          ),
          const SizedBox(height: 16),

          // Results
          if (isLoadingDetails)
            const Center(child: CircularProgressIndicator())
          else if (attendanceDetails != null)
            _buildResultsCard(),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final details = attendanceDetails!;
    final person = details['person'];
    final totalRecords = details['total_records'] ?? 0;
    final totalDays = details['total_days_present'] ?? 0;
    final datesPresent = details['dates_present'] as List? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Person Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Text(
                      person['name']
                              ?.toString()
                              .substring(0, 1)
                              .toUpperCase() ??
                          '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${person['reg_no']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                Expanded(
                  child: AnimatedStatCard(
                    title: 'Total Records',
                    value: totalRecords.toString(),
                    icon: Icons.fingerprint,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedStatCard(
                    title: 'Days Present',
                    value: totalDays.toString(),
                    icon: Icons.calendar_today,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calendar View - List of dates
            const Text(
              'Attendance Dates',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (datesPresent.isEmpty)
              const Text('No attendance records found for the selected period.')
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: datesPresent.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      title: Text(datesPresent[index]),
                      dense: true,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// HOD Department Statistics Tab - Calendar range stats for all staff
class HODDeptStatsTab extends StatefulWidget {
  final String token;
  final String dept;

  const HODDeptStatsTab({super.key, required this.token, required this.dept});

  @override
  State<HODDeptStatsTab> createState() => _HODDeptStatsTabState();
}

class _HODDeptStatsTabState extends State<HODDeptStatsTab> {
  bool isLoading = false;
  bool isGeneratingPdf = false;
  Map<String, dynamic>? statsData;
  String? startDate;
  String? endDate;

  Future<void> _generateAndDownloadPdf() async {
    if (statsData == null) return;
    setState(() => isGeneratingPdf = true);

    try {
      final data = statsData!;
      final summary = data['summary'] as Map<String, dynamic>;
      final staffList = data['staff'] as List? ?? [];
      final workingDays = data['working_days'] ?? 0;
      final totalStaff = data['total_staff'] ?? 0;
      final overallPct = (summary['overall_attendance_pct'] ?? 0).toDouble();
      
      final startDateStr = startDate ?? 'Start';
      final endDateStr = endDate ?? 'End';
      final deptName = widget.dept.replaceAll(' ', '_');
      final filename = 'attendance_report_${deptName}_${startDateStr}_to_$endDateStr.pdf';

      final pdf = pw.Document();

      // Theme Colors
      final primaryColor = PdfColor.fromInt(0xFF4F46E5);      // Modern Indigo
      final darkColor = PdfColor.fromInt(0xFF0F172A);         // Slate 900
      final lightColor = PdfColor.fromInt(0xFFF8FAFC);        // Slate 50
      final greyColor = PdfColor.fromInt(0xFF64748B);         // Slate 500
      final borderColor = PdfColor.fromInt(0xFFE2E8F0);       // Slate 200
      final highlightColor = PdfColor.fromInt(0xFFEEF2FF);   // Light Indigo tint

      final cardBuilder = (String title, String value, PdfColor color, bool highlight) {
        return pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: highlight ? highlightColor : PdfColors.white,
              border: pw.Border.all(color: highlight ? color : borderColor, width: highlight ? 1.5 : 1.0),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: highlight ? color : greyColor,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: highlight ? color : darkColor,
                  ),
                ),
              ],
            ),
          ),
        );
      };

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ATTENDANCE ANALYTICS REPORT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Department: ${widget.dept.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Period: $startDateStr to $endDateStr',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated: ${DateTime.now().toLocal().toString().split('.').first}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Summary KPI Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                cardBuilder('Overall Attendance', '${overallPct.toStringAsFixed(1)}%', primaryColor, true),
                pw.SizedBox(width: 12),
                cardBuilder('Total Staff', totalStaff.toString(), darkColor, false),
                pw.SizedBox(width: 12),
                cardBuilder('Working Days', workingDays.toString(), darkColor, false),
              ],
            ),
            pw.SizedBox(height: 24),
            
            // Stats Breakdown Table
            pw.Text(
              'Detailed Summary Metrics',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkColor),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Metric Description', 'Count / Value'],
              data: [
                ['Total Present Days (Scan)', summary['total_present']?.toString() ?? '0'],
                ['Total Absent Days', summary['total_absent']?.toString() ?? '0'],
                ['Total Approved Leaves', summary['total_leave']?.toString() ?? '0'],
                ['Total On Duty (OD) Days', summary['total_od']?.toString() ?? '0'],
              ],
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: darkColor),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: pw.BoxDecoration(color: lightColor),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 24),
            
            // Staff Table
            pw.Text(
              'Staff Performance & Attendance Breakdown',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkColor),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Name', 'Reg No', 'Present', 'Absent', 'Leave', 'OD', 'Attendance %'],
              data: staffList.map((s) {
                return [
                  s['name'] ?? 'Unknown',
                  s['reg_no'] ?? '',
                  s['present']?.toString() ?? '0',
                  s['absent']?.toString() ?? '0',
                  s['leave']?.toString() ?? '0',
                  s['od']?.toString() ?? '0',
                  '${(s['attendance_pct'] ?? 0).toStringAsFixed(1)}%',
                ];
              }).toList(),
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: pw.BoxDecoration(color: lightColor),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );

      await Printing.sharePdf(bytes: await pdf.save(), filename: filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isGeneratingPdf = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectThisMonth();
  }

  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      startDate = _fmt(now);
      endDate = _fmt(now);
    });
    _loadStats();
  }

  void _selectThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      startDate = _fmt(startOfWeek);
      endDate = _fmt(now);
    });
    _loadStats();
  }

  void _selectThisMonth() {
    final now = DateTime.now();
    setState(() {
      startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      endDate = _fmt(now);
    });
    _loadStats();
  }

  void _selectLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDay = DateTime(now.year, now.month, 0);
    setState(() {
      startDate = _fmt(lastMonth);
      endDate = _fmt(lastDay);
    });
    _loadStats();
  }

  void _selectLast7Days() {
    final now = DateTime.now();
    final ago = now.subtract(const Duration(days: 6));
    setState(() {
      startDate = _fmt(ago);
      endDate = _fmt(now);
    });
    _loadStats();
  }

  void _selectLast30Days() {
    final now = DateTime.now();
    final ago = now.subtract(const Duration(days: 29));
    setState(() {
      startDate = _fmt(ago);
      endDate = _fmt(now);
    });
    _loadStats();
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    DateTime? initialStart;
    DateTime? initialEnd;

    if (startDate != null) initialStart = DateTime.parse(startDate!);
    if (endDate != null) initialEnd = DateTime.parse(endDate!);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: initialStart != null && initialEnd != null
          ? DateTimeRange(start: initialStart, end: initialEnd)
          : DateTimeRange(start: initialStart ?? DateTime(now.year, now.month, 1), end: initialEnd ?? now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (picked.start.isAfter(picked.end)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Start date cannot be after end date'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (picked.end.isAfter(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cannot select future dates'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        startDate = _fmt(picked.start);
        endDate = _fmt(picked.end);
      });
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    if (startDate == null || endDate == null) return;

    setState(() => isLoading = true);
    try {
      final url =
          '$API_URL/hod/attendance/range-stats?start_date=$startDate&end_date=$endDate';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        setState(() => statsData = jsonDecode(response.body));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load stats: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}/${d.month}/${d.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              color: Colors.teal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Department Attendance',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.dept.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date Range Picker
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Date Range',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.teal),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, color: Colors.teal),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date Range',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    startDate != null && endDate != null
                                        ? '${_formatDate(startDate!)} - ${_formatDate(endDate!)}'
                                        : 'Tap to select',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.teal),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Quick Select',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickSelectChip(
                          label: 'Today',
                          onTap: _selectToday,
                          color: Colors.teal,
                        ),
                        _QuickSelectChip(
                          label: 'This Week',
                          onTap: _selectThisWeek,
                          color: Colors.blue,
                        ),
                        _QuickSelectChip(
                          label: 'This Month',
                          onTap: _selectThisMonth,
                          color: Colors.green,
                        ),
                        _QuickSelectChip(
                          label: 'Last Month',
                          onTap: _selectLastMonth,
                          color: Colors.orange,
                        ),
                        _QuickSelectChip(
                          label: 'Last 7 Days',
                          onTap: _selectLast7Days,
                          color: Colors.cyan,
                        ),
                        _QuickSelectChip(
                          label: 'Last 30 Days',
                          onTap: _selectLast30Days,
                          color: Colors.indigo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Loading / Results
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (statsData != null)
              _buildSummaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final data = statsData!;
    final summary = data['summary'] as Map<String, dynamic>;
    final staffList = data['staff'] as List? ?? [];
    final workingDays = data['working_days'] ?? 0;
    final totalStaff = data['total_staff'] ?? 0;
    final overallPct = summary['overall_attendance_pct'] ?? 0;
    final totalPresent = summary['total_present'] ?? 0;
    final totalLeave = summary['total_leave'] ?? 0;
    final totalAbsent = summary['total_absent'] ?? 0;
    final totalOd = summary['total_od'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.summarize, color: Colors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Summary (${_formatDate(data['start_date'])} - ${_formatDate(data['end_date'])})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: isGeneratingPdf
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.teal),
                              ),
                            )
                          : const Icon(Icons.download, color: Colors.teal),
                      onPressed: isGeneratingPdf ? null : _generateAndDownloadPdf,
                      tooltip: 'Download Report',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Overall percentage
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: overallPct / 100,
                                strokeWidth: 10,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation(
                                  overallPct >= 75
                                      ? Colors.green
                                      : overallPct >= 50
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${overallPct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                                Text(
                                  'Attendance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalStaff staff | $workingDays working days',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Stats grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _MiniStatCard(
                      label: 'Present',
                      value: totalPresent.toString(),
                      color: Colors.green,
                      icon: Icons.check_circle,
                    ),
                    _MiniStatCard(
                      label: 'Absent',
                      value: totalAbsent.toString(),
                      color: Colors.red,
                      icon: Icons.cancel,
                    ),
                    _MiniStatCard(
                      label: 'Leave',
                      value: totalLeave.toString(),
                      color: Colors.orange,
                      icon: Icons.event_busy,
                    ),
                    _MiniStatCard(
                      label: 'On Duty',
                      value: totalOd.toString(),
                      color: Colors.blue,
                      icon: Icons.work,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Per-staff breakdown
        const Text(
          'Staff Breakdown',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (staffList.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No staff found in ${widget.dept.toUpperCase()}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: staffList.length,
            itemBuilder: (context, index) {
              final s = staffList[index];
              final pct = (s['attendance_pct'] ?? 0).toDouble();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: pct >= 75
                        ? Colors.green
                        : pct >= 50
                        ? Colors.orange
                        : Colors.red,
                    child: Text(
                      (s['name'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    s['name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['reg_no'] ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          pct >= 75
                              ? Colors.green
                              : pct >= 50
                              ? Colors.orange
                              : Colors.red,
                        ),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _InlineBadge(
                            label: 'P: ${s['present']}',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          _InlineBadge(
                            label: 'L: ${s['leave']}',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          _InlineBadge(
                            label: 'OD: ${s['od']}',
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          _InlineBadge(
                            label: 'A: ${s['absent']}',
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: pct >= 75
                          ? Colors.green
                          : pct >= 50
                          ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _InlineBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
