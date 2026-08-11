import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/college_ip_config.dart';

class StudentAttendanceLogWidget extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final bool isHod;
  final bool isAdmin;
  final String? defaultDept;

  const StudentAttendanceLogWidget({
    super.key,
    required this.token,
    required this.user,
    this.isHod = false,
    this.isAdmin = false,
    this.defaultDept,
  });

  @override
  State<StudentAttendanceLogWidget> createState() =>
      _StudentAttendanceLogWidgetState();
}

class _StudentAttendanceLogWidgetState
    extends State<StudentAttendanceLogWidget> {
  static const Color primaryColor = Color(0xFF1E3A8A); // Deep Navy
  static const Color accentColor = Color(0xFF2563EB); // Royal Blue
  static const Color backgroundColor = Color(0xFFF8FAFC);

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  String _selectedDept = "ALL";
  String _selectedStatus = "ALL";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _logs = [];
  Map<String, dynamic> _summary = {};
  List<String> _departments = ["ALL"];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isHod && widget.defaultDept != null && widget.defaultDept!.isNotEmpty) {
      _selectedDept = widget.defaultDept!.trim();
    }
    _fetchDepartments();
    _fetchLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      };

  String get _apiUrl => CollegeIPConfig.defaultURL;

  Future<void> _fetchDepartments() async {
    try {
      final response = await http
          .get(Uri.parse('$_apiUrl/staff/departments'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['departments'] is List) {
          final List<String> fetched = ["ALL"];
          for (var d in data['departments']) {
            final str = d.toString().trim();
            if (str.isNotEmpty && !fetched.contains(str)) {
              fetched.add(str);
            }
          }
          if (mounted) {
            setState(() {
              _departments = fetched;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final queryParams = {
        'start_date': startStr,
        'end_date': endStr,
        'dept': _selectedDept,
        'status': _selectedStatus,
        'search': _searchQuery,
      };

      final uri = Uri.parse('$_apiUrl/student/attendance/logs')
          .replace(queryParameters: queryParams);

      final response =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          final List<dynamic> allLogs = data['logs'] ?? [];
          final Map<String, dynamic> rawSummary = Map<String, dynamic>.from(data['summary'] ?? {});
          
          // Exclude staff members from student logs
          final List<dynamic> rawLogs = allLogs.where((log) {
            if (log is! Map) return false;
            final role = (log['role'] ?? log['user_type'] ?? log['type'] ?? '').toString().toLowerCase();
            final regNo = (log['reg_no'] ?? log['staff_id'] ?? '').toString().toUpperCase();
            if (role == 'staff' || role == 'admin' || role == 'hod' || role == 'other_staff' || regNo.startsWith('STAFF_')) {
              return false;
            }
            return true;
          }).toList();

          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final currentHour = DateTime.now().hour;
          
          int absentCount = 0;
          int presentCount = 0;
          int leaveCount = 0;

          for (var log in rawLogs) {
            if (log is! Map) continue;
            final st = (log['status'] ?? '').toString().toLowerCase();
            final ts = (log['timestamp'] ?? log['date'] ?? '').toString();
            final isToday = ts.length >= 10 && ts.startsWith(todayStr);
            final isSessionClosed = (log['is_session_closed'] == true || log['session_closed'] == true) ||
                (!isToday) || (currentHour >= 17);

            if (st == 'present' || st == 'check_in' || st == 'check_out') {
              presentCount++;
            } else if (st == 'leave' || st.contains('leave')) {
              leaveCount++;
            } else if (st == 'absent') {
              if (isSessionClosed) {
                absentCount++;
              } else {
                log['status'] = 'Session Active';
              }
            }
          }

          rawSummary['absent_count'] = absentCount;
          rawSummary['present_count'] = presentCount;
          rawSummary['leave_count'] = leaveCount;
          final total = rawLogs.length;
          rawSummary['total_records'] = total;
          rawSummary['present_percentage'] = total > 0 ? (presentCount / total * 100).toStringAsFixed(1) : '0';

          setState(() {
            _logs = rawLogs;
            _summary = rawSummary;
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Server returned status ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load student attendance logs. $e";
        });
      }
    }
  }

  void _selectDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      switch (preset) {
        case 'Today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
          break;
        case 'Yesterday':
          final yest = now.subtract(const Duration(days: 1));
          _startDate = DateTime(yest.year, yest.month, yest.day);
          _endDate = DateTime(yest.year, yest.month, yest.day);
          break;
        case 'Last 7 Days':
          _startDate = now.subtract(const Duration(days: 6));
          _endDate = now;
          break;
        case 'This Month':
        default:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
      }
    });
    _fetchLogs();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
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
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchLogs();
    }
  }

  Future<void> _generatePdfReport() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No logs available to generate PDF report."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final doc = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final dateRangeStr =
        "${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}";
    final genTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final userName = widget.user['name'] ?? widget.user['username'] ?? 'Administrator';
    final userRole = widget.isHod
        ? "HOD (${widget.defaultDept ?? 'Department'})"
        : (widget.isAdmin ? "System Administrator" : "Staff Member");

    final totalRec = _summary['total_records'] ?? _logs.length;
    final presentCnt = _summary['present_count'] ?? 0;
    final absentCnt = _summary['absent_count'] ?? 0;
    final leaveCnt = _summary['leave_count'] ?? 0;
    final pct = _summary['present_percentage'] ?? 0.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Clean Institutional Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#0F172A'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "ATTENDA • ACADEMIC MANAGEMENT SYSTEM",
                        style: pw.TextStyle(
                          font: fontBold,
                          color: PdfColors.white,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "STUDENT ATTENDANCE LOG REPORT",
                        style: pw.TextStyle(
                          font: fontBold,
                          color: PdfColor.fromHex('#38BDF8'),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Generated: $genTimeStr",
                        style: pw.TextStyle(
                          font: font,
                          color: PdfColor.fromHex('#E2E8F0'),
                          fontSize: 8.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "By: $userName ($userRole)",
                        style: pw.TextStyle(
                          font: font,
                          color: PdfColor.fromHex('#94A3B8'),
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Metadata & Active Filters Info Box
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Date Period: $dateRangeStr",
                    style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColor.fromHex('#1E293B')),
                  ),
                  pw.Text(
                    "Department: ${_selectedDept.toUpperCase()}",
                    style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColor.fromHex('#1E293B')),
                  ),
                  pw.Text(
                    "Status: ${_selectedStatus.toUpperCase()}",
                    style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColor.fromHex('#1E293B')),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Clean 4-Box Summary Metrics Bar
            pw.Row(
              children: [
                _buildPdfStatBox(fontBold, font, "Total Logs", "$totalRec", '#475569', '#F1F5F9'),
                pw.SizedBox(width: 8),
                _buildPdfStatBox(fontBold, font, "Present Rate", "$presentCnt ($pct%)", '#16A34A', '#F0FDF4'),
                pw.SizedBox(width: 8),
                _buildPdfStatBox(fontBold, font, "Absent Count", "$absentCnt", '#DC2626', '#FEF2F2'),
                pw.SizedBox(width: 8),
                _buildPdfStatBox(fontBold, font, "On Leave", "$leaveCnt", '#2563EB', '#EFF6FF'),
              ],
            ),
            pw.SizedBox(height: 14),

            // High-Craft Tabular Attendance Log Table
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
              headerStyle: pw.TextStyle(
                font: fontBold,
                color: PdfColors.white,
                fontSize: 8.5,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E293B'),
              ),
              rowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
              oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              headers: <String>[
                '#',
                'Date',
                'Reg No',
                'Student Name',
                'Dept',
                'Status',
                'In Time',
                'Out Time',
                'Remarks'
              ],
              data: List<List<String>>.generate(
                _logs.length,
                (index) {
                  final item = _logs[index];
                  return [
                    '${index + 1}',
                    '${item['date'] ?? ''}',
                    '${item['reg_no'] ?? ''}',
                    '${item['name'] ?? ''}',
                    '${item['dept'] ?? ''}',
                    '${item['status'] ?? 'Present'}',
                    '${item['entry_time'] ?? '--'}',
                    '${item['exit_time'] ?? '--'}',
                    '${item['remarks'] ?? 'Verified'}',
                  ];
                },
              ),
            ),
            pw.SizedBox(height: 28),

            // Clean Signature Footer Area
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 140,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text("Class In-Charge Signature",
                        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColor.fromHex('#475569'))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 140,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text("HOD / Principal Signature",
                        style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#0F172A'))),
                  ],
                ),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount} • Official Attendance Record • Attenda System',
              style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Student_Attendance_Report_${DateFormat('yyyyMMdd').format(_startDate)}.pdf',
    );
  }

  pw.Widget _buildPdfStatBox(
      pw.Font fontBold, pw.Font font, String title, String value, String colorHex, String bgHex) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex(bgHex),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColor.fromHex(colorHex), width: 0.8),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 10.5, color: PdfColor.fromHex(colorHex)),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              title,
              style: pw.TextStyle(
                  font: font, fontSize: 7.5, color: PdfColor.fromHex('#475569')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: RefreshIndicator(
        onRefresh: _fetchLogs,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Header Action Banner Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_search_outlined,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Student Attendance Log",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.isAdmin
                                    ? "Institution-wide Student Attendance & PDF Export"
                                    : (widget.isHod
                                        ? "Department Student Attendance & Date Range Log"
                                        : "My Assigned & Department Students Attendance Log"),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text(
                              "Generate PDF Report",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 1,
                            ),
                            onPressed: _generatePdfReport,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          tooltip: "Refresh Logs",
                          onPressed: _fetchLogs,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filters & Date Range Selection Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Date Preset Chips + Custom Range Selector
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip("This Month"),
                          _buildPresetChip("Today"),
                          _buildPresetChip("Yesterday"),
                          _buildPresetChip("Last 7 Days"),
                          ActionChip(
                            avatar: const Icon(Icons.date_range,
                                size: 16, color: primaryColor),
                            label: Text(
                              "${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: primaryColor,
                              ),
                            ),
                            backgroundColor: Colors.blue.shade50,
                            onPressed: _pickCustomDateRange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Department & Status Filter Dropdowns + Search Bar
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        return isMobile
                            ? Column(
                                children: [
                                  _buildDeptDropdown(),
                                  const SizedBox(height: 10),
                                  _buildStatusDropdown(),
                                  const SizedBox(height: 10),
                                  _buildSearchField(),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: _buildDeptDropdown()),
                                  const SizedBox(width: 10),
                                  Expanded(child: _buildStatusDropdown()),
                                  const SizedBox(width: 10),
                                  Expanded(child: _buildSearchField()),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Responsive Summary Statistics Cards
              _buildSummaryTilesSection(),
              const SizedBox(height: 12),

              // Full Page Scrollable Logs List Section
              _buildLogsListSection(),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSummaryTilesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          if (isMobile) {
            return Column(
              children: [
                Row(
                  children: [
                    _buildSummaryTile(
                        "Total Logs",
                        "${_summary['total_records'] ?? _logs.length}",
                        Colors.blueGrey),
                    const SizedBox(width: 8),
                    _buildSummaryTile(
                        "Present",
                        "${_summary['present_count'] ?? 0} (${_summary['present_percentage'] ?? 0}%)",
                        Colors.green),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSummaryTile(
                        "Absent", "${_summary['absent_count'] ?? 0}", Colors.red),
                    const SizedBox(width: 8),
                    _buildSummaryTile(
                        "On Leave", "${_summary['leave_count'] ?? 0}", Colors.blue),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              _buildSummaryTile(
                  "Total Logs",
                  "${_summary['total_records'] ?? _logs.length}",
                  Colors.blueGrey),
              const SizedBox(width: 8),
              _buildSummaryTile(
                  "Present",
                  "${_summary['present_count'] ?? 0} (${_summary['present_percentage'] ?? 0}%)",
                  Colors.green),
              const SizedBox(width: 8),
              _buildSummaryTile(
                  "Absent", "${_summary['absent_count'] ?? 0}", Colors.red),
              const SizedBox(width: 8),
              _buildSummaryTile(
                  "On Leave", "${_summary['leave_count'] ?? 0}", Colors.blue),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogsListSection() {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 12),
            Text("Loading student logs...",
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchLogs,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_logs.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              "No student attendance records found for selected filters.",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return _buildLogCard(log, index);
        },
      ),
    );
  }

  Widget _buildPresetChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: false,
        onSelected: (_) => _selectDatePreset(label),
      ),
    );
  }

  Widget _buildDeptDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _selectedDept,
      decoration: InputDecoration(
        labelText: "Department",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _departments.map((dept) {
        return DropdownMenuItem<String>(
          value: dept,
          child: Text(
            dept == "ALL" ? "All Departments" : dept,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedDept = val;
          });
          _fetchLogs();
        }
      },
    );
  }

  Widget _buildStatusDropdown() {
    final statuses = ["ALL", "Present", "Absent", "On Leave"];
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _selectedStatus,
      decoration: InputDecoration(
        labelText: "Status",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: statuses.map((st) {
        return DropdownMenuItem<String>(
          value: st,
          child: Text(
            st == "ALL" ? "All Statuses" : st,
            style: const TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedStatus = val;
          });
          _fetchLogs();
        }
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: "Search Name / Reg No",
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = "";
                  });
                  _fetchLogs();
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onSubmitted: (val) {
        setState(() {
          _searchQuery = val.trim();
        });
        _fetchLogs();
      },
    );
  }

  Widget _buildSummaryTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, int index) {
    final status = (log['status'] ?? 'Present').toString();
    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle_outline;

    if (status.toLowerCase() == 'absent') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
    } else if (status.toLowerCase().contains('leave')) {
      statusColor = Colors.blue;
      statusIcon = Icons.event_available;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          log['name'] ?? 'Student Name',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Reg: ${log['reg_no'] ?? ''} • Dept: ${log['dept'] ?? ''}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        log['date'] ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.schedule, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        "${log['entry_time'] ?? '--'} - ${log['exit_time'] ?? '--'}",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
