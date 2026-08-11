import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/college_ip_config.dart';

class AttendanceLogTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final String? token;

  const AttendanceLogTab({super.key, required this.user, this.token});

  @override
  State<AttendanceLogTab> createState() => _AttendanceLogTabState();
}

class _AttendanceLogTabState extends State<AttendanceLogTab> {
  DateTime? startDate;
  DateTime? endDate;
  List<dynamic> logs = [];
  bool isLoading = true;

  // Filter & Search states
  String searchQuery = '';
  String deptFilter = 'All';
  String statusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Summary stats
  int totalPresent = 0;
  int totalHalfDay = 0;
  int totalAbsent = 0;
  int totalLeave = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = now.subtract(const Duration(days: 30));
    endDate = now;
    fetchLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchLogs() async {
    setState(() => isLoading = true);
    try {
      final sStr = DateFormat('yyyy-MM-dd').format(startDate!);
      final eStr = DateFormat('yyyy-MM-dd').format(endDate!);
      
      final role = (widget.user['role'] ?? 'staff').toString().toLowerCase();
      final isAdmin = role == 'admin' || role == 'administrator';
      final isHod = role == 'hod';
      final isOtherStaff = role == 'other_staff' || role == 'other staff';
      
      final regNo = (isAdmin) ? '' : (widget.user['reg_no'] ?? widget.user['username'] ?? widget.user['id'] ?? '').toString();
      final dept = (isAdmin) ? '' : (widget.user['dept'] ?? widget.user['department'] ?? '').toString();

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (widget.token != null && widget.token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.token}';
      }

      // Candidate URLs based on Role
      final List<String> candidateUrls = [];

      // 1. Primary unified endpoint
      candidateUrls.add('${CollegeIPConfig.defaultURL}/attendance/logs?reg_no=$regNo&role=$role&dept=$dept&start_date=$sStr&end_date=$eStr');

      // 2. Role-specific fallback endpoints
      if (isAdmin) {
        candidateUrls.add('${CollegeIPConfig.defaultURL}/admin/attendance/staff?start_date=$sStr&end_date=$eStr');
        candidateUrls.add('${CollegeIPConfig.defaultURL}/admin/other_staff/attendance?start_date=$sStr&end_date=$eStr');
        candidateUrls.add('${CollegeIPConfig.defaultURL}/admin/attendance?start_date=$sStr&end_date=$eStr');
      } else if (isHod) {
        candidateUrls.add('${CollegeIPConfig.defaultURL}/hod/attendance/staff-list?dept=$dept&start_date=$sStr&end_date=$eStr');
        candidateUrls.add('${CollegeIPConfig.defaultURL}/admin/attendance/staff?dept=$dept&start_date=$sStr&end_date=$eStr');
      } else if (isOtherStaff) {
        if (regNo.isNotEmpty) {
          candidateUrls.add('${CollegeIPConfig.defaultURL}/admin/other_staff/attendance?reg_no=$regNo&start_date=$sStr&end_date=$eStr');
        }
        candidateUrls.add('${CollegeIPConfig.defaultURL}/admin/other_staff/attendance?start_date=$sStr&end_date=$eStr');
      } else {
        if (regNo.isNotEmpty) {
          candidateUrls.add('${CollegeIPConfig.defaultURL}/api/attendance/personal?reg_no=$regNo&start_date=$sStr&end_date=$eStr');
          candidateUrls.add('${CollegeIPConfig.defaultURL}/admin/attendance/person-details?reg_no=$regNo&start_date=$sStr&end_date=$eStr');
        }
        candidateUrls.add('${CollegeIPConfig.defaultURL}/admin/attendance/staff?start_date=$sStr&end_date=$eStr');
      }

      List<dynamic> collectedLogs = [];

      for (var url in candidateUrls) {
        try {
          debugPrint('Fetching attendance logs from candidate URL: $url');
          final response = await http.get(Uri.parse(url), headers: headers);
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final rawLogs = data['logs'] ?? data['attendance'] ?? data['records'] ?? data['data'];
            if (rawLogs is List && rawLogs.isNotEmpty) {
              collectedLogs.addAll(rawLogs);
              if (url.contains('/attendance/logs') || url.contains('/personal') || url.contains('/person-details')) {
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching logs from candidate $url: $e');
        }
      }

      if (collectedLogs.isNotEmpty) {
        _processRawLogs(collectedLogs);
      } else {
        setState(() {
          logs = [];
          totalPresent = 0;
          totalHalfDay = 0;
          totalAbsent = 0;
          totalLeave = 0;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching attendance logs: $e');
      setState(() => isLoading = false);
    }
  }

  void _processRawLogs(List<dynamic> rawLogs) {
    final Map<String, dynamic> uniqueMap = {};
    
    for (var log in rawLogs) {
      if (log is! Map) continue;
      final mapLog = Map<String, dynamic>.from(log);
      final id = mapLog['id']?.toString() ?? '';
      final regNo = mapLog['reg_no']?.toString() ?? '';
      final ts = mapLog['timestamp']?.toString() ?? '';
      final dateOnly = ts.length >= 10 ? ts.substring(0, 10) : ts;
      final sessionKey = (mapLog['session_type'] ?? mapLog['session'] ?? mapLog['slot_half'] ?? mapLog['punch_type'] ?? '').toString().toUpperCase();
      
      final key = id.isNotEmpty ? 'id_$id' : '${regNo}_${dateOnly}_$sessionKey';
      
      if (!uniqueMap.containsKey(key) || (mapLog['source'] == 'face_scan')) {
        uniqueMap[key] = mapLog;
      }
    }

    final sortedLogs = uniqueMap.values.toList();
    sortedLogs.sort((a, b) {
      final ta = (a['timestamp'] ?? '').toString();
      final tb = (b['timestamp'] ?? '').toString();
      return tb.compareTo(ta);
    });

    int p = 0;
    int h = 0;
    int a = 0;
    int l = 0;

    for (var log in sortedLogs) {
      final status = (log['status'] ?? '').toString();
      final statusLower = status.toLowerCase();
      final session = (log['session_type'] ?? log['session'] ?? log['slot_half'] ?? '').toString().toUpperCase();
      final punchType = (log['punch_type'] ?? log['type'] ?? '').toString().toLowerCase();
      final val = (log['attendance_value'] != null) ? double.tryParse(log['attendance_value'].toString()) : null;
      final source = (log['source'] ?? '').toString().toLowerCase();

      final isHalf = val == 0.5 || statusLower.contains('half') || session == 'FN' || session == 'AN' || statusLower.contains('fn') || statusLower.contains('an');
      final isPresent = (status == 'Present' || status == 'check_in' || status == 'check_out' || punchType == 'check_in' || punchType == 'check_out' || statusLower.contains('present') || isHalf);

      if (isHalf && (isPresent || val == 0.5 || statusLower.contains('fn') || session == 'FN' || session == 'AN')) {
        h++;
      } else if (isPresent) {
        p++;
      } else if (status == 'Leave' || source == 'leave' || source == 'od') {
        l++;
      } else if (status == 'Absent' || source == 'absent') {
        a++;
      }
    }

    setState(() {
      logs = sortedLogs;
      totalPresent = p;
      totalHalfDay = h;
      totalAbsent = a;
      totalLeave = l;
      isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: startDate!, end: endDate!),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark 
              ? const ColorScheme.dark(primary: Color(0xFF6366F1), onPrimary: Colors.white, surface: Color(0xFF1E1E24))
              : const ColorScheme.light(primary: Color(0xFF4F46E5), onPrimary: Colors.white, surface: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      fetchLogs();
    }
  }

  void _setQuickDate(int daysBack) {
    final now = DateTime.now();
    setState(() {
      endDate = now;
      if (daysBack == 0) {
        startDate = now;
      } else if (daysBack == 7) {
        startDate = now.subtract(const Duration(days: 7));
      } else if (daysBack == 30) {
        startDate = now.subtract(const Duration(days: 30));
      } else {
        startDate = now.subtract(Duration(days: daysBack));
      }
    });
    fetchLogs();
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      startDate = DateTime(now.year, now.month, 1);
      endDate = now;
    });
    fetchLogs();
  }

  Icon _getAbsentReasonIcon(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('face') || lower.contains('recognition') || lower.contains('mismatch') || lower.contains('spoof')) {
      return const Icon(Icons.face_retouching_off_rounded, color: Colors.redAccent, size: 22);
    } else if (lower.contains('boundary') || lower.contains('breach') || lower.contains('location')) {
      return const Icon(Icons.location_off_rounded, color: Colors.redAccent, size: 22);
    } else if (lower.contains('check out') || lower.contains('checkout')) {
      return const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22);
    }
    return const Icon(Icons.report_problem_rounded, color: Colors.redAccent, size: 22);
  }

  String _getAbsentReasonTitle(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('face') || lower.contains('recognition') || lower.contains('mismatch') || lower.contains('spoof')) {
      return 'Facial Verification Failed';
    } else if (lower.contains('boundary') || lower.contains('breach') || lower.contains('location')) {
      return 'Geofence Location Breach';
    } else if (lower.contains('check out') || lower.contains('checkout')) {
      return 'Checked Out Early';
    }
    return 'System Marked Absent';
  }

  String _getAbsentReasonDescription(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('face') || lower.contains('recognition') || lower.contains('mismatch') || lower.contains('spoof')) {
      return 'User attempted to mark attendance, but facial identity was not verified by the system.';
    } else if (lower.contains('boundary') || lower.contains('breach') || lower.contains('location')) {
      return 'Request was rejected because the device location was outside the permitted geofence boundary.';
    } else if (lower.contains('check out') || lower.contains('checkout')) {
      return 'Checked out of the session, and is marked absent for the remainder of the period.';
    }
    return 'Marked absent by system. Reason: $reason';
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final dt = DateTime(2020, 1, 1, h, m);
        return DateFormat('hh:mm a').format(dt);
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  void _showDetailedView(dynamic log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            backgroundColor: cardBg,
            child: Container(
              width: 650,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: _buildDetailedModalContent(log, isDesktop: true),
            ),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: _buildDetailedModalContent(log, isDesktop: false),
          );
        },
      );
    }
  }

  Widget _buildDetailedModalContent(dynamic log, {required bool isDesktop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;

    final name = (log['name'] ?? widget.user['name'] ?? 'User').toString();
    final regNo = (log['reg_no'] ?? widget.user['reg_no'] ?? 'N/A').toString();
    final dept = (log['dept'] ?? widget.user['dept'] ?? 'N/A').toString();
    final rawStatus = (log['status'] ?? '').toString();
    final rawStatusLower = rawStatus.toLowerCase();
    final session = (log['session_type'] ?? log['session'] ?? log['slot_half'] ?? '').toString().toUpperCase();
    final punchType = (log['punch_type'] ?? log['type'] ?? '').toString().toLowerCase();
    final source = (log['source'] ?? '').toString().toLowerCase();
    final val = (log['attendance_value'] != null) ? double.tryParse(log['attendance_value'].toString()) : null;

    final inTime = log['in_time']?.toString() ?? log['first_half_in_time']?.toString();

    final isHalfDay = (val == 0.5) || rawStatusLower.contains('half') || session == 'FN' || session == 'AN' || rawStatusLower.contains('fn') || rawStatusLower.contains('an');
    final isPresent = (rawStatusLower == 'present' || rawStatusLower == 'check_in' || rawStatusLower == 'check_out' || punchType == 'check_in' || punchType == 'check_out' || rawStatusLower.contains('present') || isHalfDay);

    final ts = log['timestamp'] != null ? log['timestamp'].toString() : '';
    String displayDate = '';
    String displayTime = '';
    if (ts.length >= 10) {
      try {
        final dt = DateTime.parse(ts);
        displayDate = DateFormat('EEEE, MMMM d, yyyy').format(dt);
        displayTime = DateFormat('hh:mm:ss a').format(dt);
      } catch (e) {
        displayDate = ts;
      }
    }

    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    if (isHalfDay && (isPresent || inTime != null || val == 0.5 || rawStatusLower.contains('fn') || session == 'FN' || session == 'AN')) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.timelapse_rounded;
      statusTitle = session == 'AN' ? 'Half Day Present (AN)' : 'Half Day Present (FN)';
    } else if (isPresent) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'Present (Full Day)';
    } else if (rawStatusLower == 'leave' || source == 'leave' || source == 'od') {
      statusColor = const Color(0xFF3B82F6);
      statusIcon = Icons.beach_access_rounded;
      statusTitle = (source == 'od') ? 'On Duty (OD)' : 'On Leave';
    } else {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_rounded;
      statusTitle = 'Absent';
    }

    final double effectiveVal = val ?? (
      isHalfDay ? 0.5 :
      isPresent ? 1.0 :
      (rawStatusLower == 'leave' || source == 'leave' || source == 'od') ? 1.0 : 0.0
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Drag Handle (Mobile only)
        if (!isDesktop)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

        // Header Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayDate,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),

        // Detailed Body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: primaryColor.withValues(alpha: 0.2),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reg No: $regNo',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              'Department: $dept',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Attendance Value Meter
                Text(
                  'Attendance Weightage',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Value Credited: ',
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey.shade600),
                          ),
                          Text(
                            '${effectiveVal.toStringAsFixed(effectiveVal.truncateToDouble() == effectiveVal ? 0 : 1)} / 1.0 Day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: effectiveVal,
                          backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Session breakdown (FN / AN)
                Text(
                  'Daily Half-Wise Session Logs',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                _buildHalfDayDetails(log, isDark, cardBg, primaryColor),
                const SizedBox(height: 20),

                // Face Scan Details
                if (source == 'face_scan') ...[
                  Text(
                    'Verification Metadata',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFaceScanDetails(log, displayTime, isDark, primaryColor, cardBg),
                  const SizedBox(height: 20),
                ],

                // System Absent Detailed Reason
                if ((rawStatus == 'Absent' || !isPresent) && log['absent_reason'] != null) ...[
                  Text(
                    'System Absence Diagnostic',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSystemAbsentDetails(log, isDark, primaryColor),
                  const SizedBox(height: 20),
                ],

                // Leave / OD Details
                if (rawStatus == 'Leave' || source == 'leave' || source == 'od') ...[
                  Text(
                    'Leave / On-Duty Record',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLeaveDetails(log, isDark, primaryColor),
                  const SizedBox(height: 20),
                ],

                // Quick Copy / Actions
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final text = 'Attendance Log Details:\nName: $name\nReg No: $regNo\nDept: $dept\nDate: $displayDate\nStatus: $statusTitle\nValue: $effectiveVal';
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied attendance details to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Detailed Log Summary'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
    final bgCol = isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final roleStr = (widget.user['role'] ?? 'staff').toString().toLowerCase();
    final isAdmin = roleStr == 'admin' || roleStr == 'administrator';
    final isHOD = roleStr == 'hod';
    final showFilters = isAdmin || isHOD;

    // Unique departments extracted dynamically
    final uniqueDepts = <String>{'All'};
    for (var l in logs) {
      if (l['dept'] != null && l['dept'].toString().isNotEmpty) {
        uniqueDepts.add(l['dept'].toString());
      }
    }

    final filteredLogs = logs.where((log) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final n = (log['name'] ?? '').toString().toLowerCase();
        final r = (log['reg_no'] ?? '').toString().toLowerCase();
        if (!n.contains(q) && !r.contains(q)) {
          return false;
        }
      }
      if (deptFilter != 'All') {
        final logDept = (log['dept'] ?? '').toString().toLowerCase();
        if (logDept != deptFilter.toLowerCase()) {
          return false;
        }
      }
      if (statusFilter != 'All') {
        final st = (log['status'] ?? '').toString();
        final stLower = st.toLowerCase();
        final session = (log['session_type'] ?? log['session'] ?? log['slot_half'] ?? '').toString().toUpperCase();
        final punchType = (log['punch_type'] ?? log['type'] ?? '').toString().toLowerCase();
        final source = (log['source'] ?? '').toString().toLowerCase();
        final val = (log['attendance_value'] != null) ? double.tryParse(log['attendance_value'].toString()) : null;

        final isHalfDay = (val == 0.5) || stLower.contains('half') || session == 'FN' || session == 'AN' || stLower.contains('fn') || stLower.contains('an');
        final isPresent = (stLower == 'present' || stLower == 'check_in' || stLower == 'check_out' || punchType == 'check_in' || punchType == 'check_out' || stLower.contains('present') || isHalfDay);

        if (statusFilter == 'Present') {
          if (!isPresent || isHalfDay) return false;
        } else if (statusFilter == 'Half Day') {
          if (!isHalfDay) return false;
        } else if (statusFilter == 'Absent') {
          if (isPresent || isHalfDay) return false;
        } else if (statusFilter == 'Leave') {
          final isLeave = stLower == 'leave' || source == 'leave';
          if (!isLeave) return false;
        } else if (statusFilter == 'OD') {
          final isOd = source == 'od' || stLower.contains('od');
          if (!isOd) return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bgCol,
      body: RefreshIndicator(
        onRefresh: fetchLogs,
        color: primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Stats Banner
            SliverToBoxAdapter(
              child: _buildStatsBanner(isDark, cardBg),
            ),

            // Date Range & Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    _buildDateSelector(isDark, cardBg, primaryColor),
                    if (showFilters) ...[
                      const SizedBox(height: 12),
                      _buildFilters(isDark, cardBg, uniqueDepts.toList(), primaryColor),
                    ],
                  ],
                ),
              ),
            ),

            // Loading / Empty / List
            if (isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredLogs.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(isDark),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final log = filteredLogs[index];
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: InkWell(
                          onTap: () => _showDetailedView(log),
                          borderRadius: BorderRadius.circular(16),
                          child: _buildLogCard(log, isDark, cardBg, primaryColor, showFilters),
                        ),
                      );
                    },
                    childCount: filteredLogs.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBanner(bool isDark, Color cardBg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Present', totalPresent, const Color(0xFF10B981), Icons.check_circle_rounded, isDark),
          _buildStatItem('Half Day', totalHalfDay, const Color(0xFFF59E0B), Icons.timelapse_rounded, isDark),
          _buildStatItem('Absent', totalAbsent, const Color(0xFFEF4444), Icons.cancel_rounded, isDark),
          _buildStatItem('Leave/OD', totalLeave, const Color(0xFF3B82F6), Icons.beach_access_rounded, isDark),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color, IconData icon, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(bool isDark, Color cardBg, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _selectDateRange,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.date_range_rounded, color: primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Date Range',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('MMM d, y').format(startDate!)} - ${DateFormat('MMM d, y').format(endDate!)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_drop_down_rounded, color: primaryColor),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickFilterBtn('Today', 0, isDark, primaryColor),
                  const SizedBox(width: 8),
                  _buildQuickFilterBtn('7 Days', 7, isDark, primaryColor),
                  const SizedBox(width: 8),
                  _buildQuickFilterBtn('30 Days', 30, isDark, primaryColor),
                  const SizedBox(width: 8),
                  _buildMonthFilterBtn('This Month', isDark, primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterBtn(String label, int days, bool isDark, Color primaryColor) {
    return InkWell(
      onTap: () => _setQuickDate(days),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          color: primaryColor.withValues(alpha: 0.05),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthFilterBtn(String label, bool isDark, Color primaryColor) {
    return InkWell(
      onTap: _setThisMonth,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          color: primaryColor.withValues(alpha: 0.05),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isDark, Color cardBg, List<String> depts, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => searchQuery = v),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search Name or Reg No...',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: deptFilter,
                  items: depts,
                  onChanged: (v) => setState(() => deptFilter = v!),
                  icon: Icons.business_rounded,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  value: statusFilter,
                  items: ['All', 'Present', 'Half Day', 'Absent', 'Leave', 'OD'],
                  onChanged: (v) => setState(() => statusFilter = v!),
                  icon: Icons.filter_list_rounded,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF2C2C35) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            'No Attendance Logs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No records found for the selected date range.',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(dynamic log, bool isDark, Color cardBg, Color primaryColor, bool showUserInfo) {
    final rawStatus = (log['status'] ?? '').toString();
    final rawStatusLower = rawStatus.toLowerCase();
    final session = (log['session_type'] ?? log['session'] ?? log['slot_half'] ?? '').toString().toUpperCase();
    final punchType = (log['punch_type'] ?? log['type'] ?? '').toString().toLowerCase();
    final source = (log['source'] ?? '').toString().toLowerCase();
    final val = (log['attendance_value'] != null) ? double.tryParse(log['attendance_value'].toString()) : null;
    final inTime = log['in_time']?.toString() ?? log['first_half_in_time']?.toString();

    final isHalfDay = (val == 0.5) || rawStatusLower.contains('half') || session == 'FN' || session == 'AN' || rawStatusLower.contains('fn') || rawStatusLower.contains('an');
    final isPresent = (rawStatusLower == 'present' || rawStatusLower == 'check_in' || rawStatusLower == 'check_out' || punchType == 'check_in' || punchType == 'check_out' || rawStatusLower.contains('present') || isHalfDay);

    final double effectiveVal = val ?? (
      isHalfDay ? 0.5 :
      isPresent ? 1.0 :
      (rawStatusLower == 'leave' || source == 'leave' || source == 'od') ? 1.0 : 0.0
    );

    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    if (isHalfDay && (isPresent || inTime != null || val == 0.5 || rawStatusLower.contains('fn') || session == 'FN' || session == 'AN')) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.timelapse_rounded;
      statusTitle = session == 'AN' ? 'Half Day Present (AN)' : 'Half Day Present (FN)';
    } else if (isPresent) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'Present (Full Day)';
    } else if (rawStatusLower == 'leave' || source == 'leave' || source == 'od') {
      statusColor = const Color(0xFF3B82F6);
      statusIcon = Icons.beach_access_rounded;
      statusTitle = (source == 'od') ? 'On Duty (OD)' : 'On Leave';
    } else {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_rounded;
      statusTitle = 'Absent';
    }

    final ts = log['timestamp'] != null ? log['timestamp'].toString() : '';
    String displayDate = '';
    String displayTime = '';
    if (ts.length >= 10) {
      try {
        final dt = DateTime.parse(ts);
        displayDate = DateFormat('MMM d, yyyy').format(dt);
        displayTime = DateFormat('hh:mm a').format(dt);
      } catch (e) {
        displayDate = ts;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.white54 : Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Text(
                          displayDate,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white38 : Colors.grey.shade400),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showUserInfo) ...[
                    // User Info Header (For Admin/HOD)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                          child: Text(
                            (log['name'] ?? 'U').toString().isNotEmpty ? (log['name'] ?? 'U').toString()[0].toUpperCase() : 'U',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log['name']?.toString() ?? 'Unknown User',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${log['reg_no'] ?? ''} • ${log['dept'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Attendance Value Meter (Always Displayed)
                  Row(
                    children: [
                      Text(
                        'Attendance Value: ',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                      Text(
                        '${effectiveVal.toStringAsFixed(effectiveVal.truncateToDouble() == effectiveVal ? 0 : 1)} / 1.0',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: effectiveVal,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 16),

                  // 2. Daily Half-Wise Session Logs (Always Displayed for all records)
                  _buildHalfDayDetails(log, isDark, cardBg, primaryColor),

                  // 3. System Absent Diagnostic Reason (If present)
                  if ((rawStatus == 'Absent' || !isPresent) && log['absent_reason'] != null) ...[
                    const SizedBox(height: 12),
                    _buildSystemAbsentDetails(log, isDark, primaryColor),
                  ],

                  // 4. Face Scan Metadata (If face_scan source)
                  if (source == 'face_scan') ...[
                    const SizedBox(height: 12),
                    _buildFaceScanDetails(log, displayTime, isDark, primaryColor, cardBg),
                  ],

                  // 5. Leave / OD Details (If leave/od source or status)
                  if (rawStatus == 'Leave' || source == 'leave' || source == 'od') ...[
                    const SizedBox(height: 12),
                    _buildLeaveDetails(log, isDark, primaryColor),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceScanDetails(dynamic log, String displayTime, bool isDark, Color primaryColor, Color cardBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.face_retouching_natural_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Face Scan Recorded',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                  ),
                  Text(
                    'Timestamp: $displayTime',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemAbsentDetails(dynamic log, bool isDark, Color primaryColor) {
    final absentReason = log['absent_reason']?.toString() ?? 'System marked absent';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getAbsentReasonIcon(absentReason),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getAbsentReasonTitle(absentReason),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getAbsentReasonDescription(absentReason),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Raw Reason: $absentReason',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHalfDayDetails(dynamic log, bool isDark, Color cardBg, Color primaryColor) {
    final rawStatus = (log['status'] ?? '').toString();
    final rawStatusLower = rawStatus.toLowerCase();
    final source = (log['source'] ?? '').toString().toLowerCase();
    final session = (log['session_type'] ?? log['session'] ?? log['slot_half'] ?? '').toString().toUpperCase();
    final punchType = (log['punch_type'] ?? log['type'] ?? '').toString().toLowerCase();
    final val = (log['attendance_value'] != null) ? double.tryParse(log['attendance_value'].toString()) : null;

    final isHalfDay = (val == 0.5) || rawStatusLower.contains('half') || session == 'FN' || session == 'AN' || rawStatusLower.contains('fn') || rawStatusLower.contains('an');

    final ts = log['timestamp']?.toString() ?? log['date']?.toString() ?? log['created_at']?.toString();
    String? defaultInTime;
    if (ts != null && ts.contains('T')) {
      defaultInTime = ts.split('T').last;
    } else if (ts != null && ts.contains(' ')) {
      defaultInTime = ts.split(' ').last;
    }

    final String? extractedInTime = log['first_half_in_time']?.toString() ??
        log['in_time']?.toString() ??
        log['check_in_time']?.toString() ??
        log['time']?.toString() ??
        defaultInTime;

    final String? extractedOutTime = log['first_half_out_time']?.toString() ??
        log['second_half_out_time']?.toString() ??
        log['out_time']?.toString() ??
        log['check_out_time']?.toString();

    final bool isFnPresent = session == 'FN' || session == 'FIRST_HALF' || rawStatusLower.contains('fn') ||
        (val == 0.5 && session != 'AN') || (extractedInTime != null && session != 'AN' && !rawStatusLower.contains('an')) ||
        (log['first_half_status']?.toString().toLowerCase() == 'present') ||
        (isHalfDay && session != 'AN');

    final bool isAnPresent = session == 'AN' || session == 'SECOND_HALF' || rawStatusLower.contains('an') ||
        (val == 0.5 && session == 'AN') ||
        (log['second_half_status']?.toString().toLowerCase() == 'present');

    String fhStatus = log['first_half_status']?.toString() ?? '';
    if (isFnPresent || (isHalfDay && !isAnPresent) || rawStatusLower == 'check_in' || rawStatusLower == 'check_out' || punchType.contains('in')) {
      fhStatus = 'Present';
    } else if (fhStatus.isEmpty || fhStatus == 'N/A') {
      if (rawStatusLower == 'absent' || source == 'absent') {
        fhStatus = 'Absent';
      } else if (rawStatusLower == 'leave' || source == 'leave' || source == 'od') {
        fhStatus = (source == 'od') ? 'OD' : 'Leave';
      } else {
        fhStatus = 'Absent';
      }
    }

    String shStatus = log['second_half_status']?.toString() ?? '';
    if (isAnPresent) {
      shStatus = 'Present';
    } else if (shStatus.isEmpty || shStatus == 'N/A' || shStatus == 'Absent' || shStatus.contains('Check-In') || shStatus.contains('Check-in')) {
      if (isFnPresent) {
        shStatus = 'Pending';
      } else if (rawStatusLower == 'absent' || source == 'absent') {
        shStatus = 'Absent';
      } else if (rawStatusLower == 'leave' || source == 'leave' || source == 'od') {
        shStatus = (source == 'od') ? 'OD' : 'Leave';
      } else {
        shStatus = 'Absent';
      }
    }

    final fhIn = _formatTime(fhStatus == 'Present' ? (log['first_half_in_time']?.toString() ?? extractedInTime) : null);
    final fhOut = _formatTime(log['first_half_out_time']?.toString() ?? (fhStatus == 'Present' ? extractedOutTime : null));
    final shIn = _formatTime(shStatus == 'Present' ? (log['second_half_in_time']?.toString() ?? extractedInTime) : null);
    final shOut = _formatTime(shStatus == 'Present' ? (log['second_half_out_time']?.toString() ?? extractedOutTime) : null);

    return Row(
      children: [
        Expanded(
          child: _buildHalfCard('FN (Morning)', fhStatus, fhIn, fhOut, isDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildHalfCard('AN (Evening)', shStatus, shIn, shOut, isDark),
        ),
      ],
    );
  }

  Widget _buildHalfCard(String title, String status, String inTime, String outTime, bool isDark) {
    Color col;
    IconData icon;
    if (status == 'Present') {
      col = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
    } else if (status == 'Absent') {
      col = const Color(0xFFEF4444);
      icon = Icons.cancel_rounded;
    } else if (status == 'Leave' || status.contains('od') || status.contains('earned') || status.contains('casual')) {
      col = const Color(0xFF3B82F6);
      icon = Icons.beach_access_rounded;
      status = 'Leave/OD';
    } else if (status == 'Pending' || status.toLowerCase().contains('check-in') || status.toLowerCase().contains('pending')) {
      col = const Color(0xFFF59E0B);
      icon = Icons.schedule_rounded;
    } else {
      col = isDark ? Colors.white54 : Colors.grey.shade500;
      icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 16, color: col),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: col),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
          const SizedBox(height: 8),
          _buildTimeRow('In', inTime, isDark),
          const SizedBox(height: 4),
          _buildTimeRow('Out', outTime, isDark),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, String time, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.w600, 
            color: (time == '--:--') ? (isDark ? Colors.white24 : Colors.grey.shade400) : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveDetails(dynamic log, bool isDark, Color primaryColor) {
    final leaveType = log['leave_type']?.toString() ?? 'Unspecified Leave';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.beach_access_rounded, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Approved Leave / OD',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Type: ${leaveType.toUpperCase()}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

