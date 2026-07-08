import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/college_ip_config.dart';
import '../services/api_client.dart';

class AttendanceLogTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const AttendanceLogTab({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<AttendanceLogTab> createState() => _AttendanceLogTabState();
}

class _AttendanceLogTabState extends State<AttendanceLogTab> {
  List<dynamic> logs = [];
  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;
  
  // Search and Filter variables for Admin
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String deptFilter = 'All';
  String statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = now;
    fetchLogs();
  }

  Future<void> fetchLogs() async {
    setState(() => isLoading = true);
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate!);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate!);
      
      final isAdmin = widget.user['role'] == 'admin';
      final url = isAdmin 
          ? '${CollegeIPConfig.defaultURL}/admin/attendance/daily-status?start_date=$startStr&end_date=$endStr'
          : '${CollegeIPConfig.defaultURL}/api/attendance/personal?start_date=$startStr&end_date=$endStr';
      
      final response = await apiClient.get(
        url,
        token: widget.token,
        cacheKey: '${isAdmin ? "admin" : "personal"}_attendance_${startDate.hashCode}_${endDate.hashCode}',
        cacheDuration: const Duration(minutes: 2),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          logs = isAdmin ? (body['data'] ?? []) : (body['attendance'] ?? []);
        });
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load logs: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: DateTimeRange(start: startDate!, end: endDate!),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: isDark ? const Color(0xFF1F2937) : Colors.white,
              onSurface: isDark ? Colors.white : Colors.black,
            ),
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

  Icon _getAbsentReasonIcon(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('face') || lower.contains('verify') || lower.contains('verification')) {
      return const Icon(Icons.face_retouching_off_rounded, color: Colors.redAccent, size: 18);
    } else if (lower.contains('boundary') || lower.contains('breach') || lower.contains('location')) {
      return const Icon(Icons.wrong_location_rounded, color: Colors.redAccent, size: 18);
    } else if (lower.contains('check out') || lower.contains('checkout')) {
      return const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 18);
    }
    return const Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 18);
  }

  String _getAbsentReasonTitle(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('face') || lower.contains('verify') || lower.contains('verification')) {
      return 'Face Verification Failure';
    } else if (lower.contains('boundary') || lower.contains('breach') || lower.contains('location')) {
      return 'Boundary Breach Detected';
    } else if (lower.contains('check out') || lower.contains('checkout')) {
      return 'Checked Out';
    }
    return reason;
  }

  String _getAbsentReasonDescription(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('face') || lower.contains('verify') || lower.contains('verification')) {
      return 'The user attempted to mark attendance, but facial identity validation was not verified by the system.';
    } else if (lower.contains('boundary') || lower.contains('breach') || lower.contains('location')) {
      return 'The attendance request was rejected because the device location was outside the permitted geofence boundary.';
    } else if (lower.contains('check out') || lower.contains('checkout')) {
      return 'The user checked out of the session, and is marked absent or checked-out for the remainder of the period.';
    }
    return 'Marked absent by system policy. Reason: $reason';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final isAdmin = widget.user['role'] == 'admin';

    // Unique departments extracted dynamically
    final uniqueDepts = <String>{'All'};
    for (var l in logs) {
      if (l['dept'] != null) {
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
        if ((log['dept'] ?? '').toString() != deptFilter) {
          return false;
        }
      }
      if (statusFilter != 'All') {
        if ((log['status'] ?? '').toString() != statusFilter) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF3F4F6),
      body: Column(
        children: [
          // Premium Date Range Selector Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: InkWell(
              onTap: _selectDateRange,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.date_range_rounded, color: primaryColor),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date Range',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormat('MMM d, y').format(startDate!)} - ${DateFormat('MMM d, y').format(endDate!)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: primaryColor),
                  ],
                ),
              ),
            ),
          ),
          
          // Search & Filters Panel for Admin
          if (isAdmin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    // Search text field
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search Name or Reg No...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
                      ),
                      onChanged: (val) {
                        setState(() => searchQuery = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Department filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: deptFilter,
                            decoration: InputDecoration(
                              labelText: 'Dept',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: uniqueDepts.map((d) {
                              return DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis));
                            }).toList(),
                            onChanged: (val) {
                              setState(() => deptFilter = val ?? 'All');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: statusFilter,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All')),
                              DropdownMenuItem(value: 'Present', child: Text('Present')),
                              DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                              DropdownMenuItem(value: 'Leave', child: Text('Leave')),
                              DropdownMenuItem(value: 'Holiday', child: Text('Holiday')),
                            ],
                            onChanged: (val) {
                              setState(() => statusFilter = val ?? 'All');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Log List
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No attendance logs found',
                              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchLogs,
                        color: primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            final status = log['status'] ?? 'Present';
                            final source = log['source'] ?? 'face_scan';
                            final rawTime = log['timestamp'] ?? log['date'] ?? '';
                            
                            DateTime? parsedTime;
                            try {
                              parsedTime = DateTime.parse(rawTime);
                            } catch (_) {}

                            String timeStr = rawTime;
                            if (parsedTime != null) {
                              timeStr = DateFormat('MMM d, y • h:mm a').format(parsedTime);
                            } else if (log['date'] != null) {
                              try {
                                timeStr = DateFormat('MMM d, y').format(DateTime.parse(log['date'].toString()));
                              } catch (_) {}
                            }

                            Color statusColor = Colors.green;
                            IconData statusIcon = Icons.check_circle_rounded;
                            String displayStatus = 'Present';

                            if (status == 'Leave') {
                              statusColor = Colors.blue;
                              statusIcon = Icons.beach_access_rounded;
                              displayStatus = 'Leave (${log['leave_type'] ?? 'General'})';
                            } else if (status == 'Absent') {
                              statusColor = Colors.red;
                              statusIcon = Icons.cancel_rounded;
                              displayStatus = 'Absent';
                            } else if (status == 'Present' && source == 'od') {
                              statusColor = Colors.indigo;
                              statusIcon = Icons.star_rounded;
                              displayStatus = 'On Duty';
                            } else if (status == 'Holiday') {
                              statusColor = Colors.orange;
                              statusIcon = Icons.celebration_rounded;
                              displayStatus = 'Holiday';
                            }

                            final isAbsent = status == 'Absent';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.grey.shade100,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // User Header (only visible to Admin)
                                  if (isAdmin) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                log['name'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${log['reg_no'] ?? ''} • ${log['dept'] ?? ''}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white60 : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                                    const SizedBox(height: 12),
                                  ],

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(statusIcon, color: statusColor, size: 24),
                                          const SizedBox(width: 12),
                                          Text(
                                            displayStatus,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (source == 'face_scan')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Face Scan',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  // For non-admin, render time below status
                                  if (!isAdmin) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white60 : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                                                  if (isAbsent && log['absent_reason'] != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
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
                                              _getAbsentReasonIcon(log['absent_reason'].toString()),
                                              const SizedBox(width: 8),
                                              Text(
                                                _getAbsentReasonTitle(log['absent_reason'].toString()),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _getAbsentReasonDescription(log['absent_reason'].toString()),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
