import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../config/college_ip_config.dart';
import '../../theme/admin_theme.dart';
import 'period_timing_helper.dart';

class PeriodConfigDialog extends StatefulWidget {
  final String token;
  final String dept;
  final VoidCallback onSaved;

  const PeriodConfigDialog({
    super.key,
    required this.token,
    required this.dept,
    required this.onSaved,
  });

  @override
  State<PeriodConfigDialog> createState() => _PeriodConfigDialogState();
}

class _PeriodConfigDialogState extends State<PeriodConfigDialog> {
  bool _isLoading = true;
  bool _isSaving = false;

  String _startTime = '08:45';
  int _totalPeriods = 7;
  int _periodDurationMins = 50;
  List<String> _workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  List<Map<String, dynamic>> _breaks = [];

  final List<String> _allWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${CollegeIPConfig.defaultURL}/api/v1/academics/period-config?dept=${Uri.encodeComponent(widget.dept)}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _startTime = data['start_time'] ?? '08:45';
        _totalPeriods = (data['total_periods'] as num?)?.toInt() ?? 7;
        _periodDurationMins = (data['period_duration_mins'] as num?)?.toInt() ?? 50;
        _workingDays = List<String>.from(data['working_days'] ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']);
        _breaks = List<Map<String, dynamic>>.from(data['breaks'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _addBreak() {
    setState(() {
      _breaks.add({
        'title': 'Break ${_breaks.length + 1}',
        'after_period': 2,
        'duration_mins': 15,
      });
    });
  }

  void _removeBreak(int index) {
    setState(() {
      _breaks.removeAt(index);
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      final res = await http.post(
        Uri.parse('${CollegeIPConfig.defaultURL}/api/v1/academics/period-config/save'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'dept': widget.dept,
          'semester_type': 'all',
          'start_time': _startTime,
          'total_periods': _totalPeriods,
          'period_duration_mins': _periodDurationMins,
          'working_days': _workingDays,
          'breaks': _breaks,
        }),
      );
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Timetable period & break timings saved for ${widget.dept}!'), backgroundColor: AdminColors.success),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: AdminColors.danger));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeline = PeriodTimingHelper.computeTimeline(
      startTime: _startTime,
      totalPeriods: _totalPeriods,
      periodDurationMins: _periodDurationMins,
      breaks: _breaks,
    );

    return Dialog(
      backgroundColor: AdminColors.getCard(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(heightFactor: 5, child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AdminColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.schedule_rounded, color: AdminColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customize Periods & Break Structure', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AdminColors.getTextPrimary(isDark))),
                              Text('Department: ${widget.dept}', style: GoogleFonts.inter(fontSize: 12, color: AdminColors.getTextSecondary(isDark))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildParamDropdown(
                            isDark,
                            label: 'Day Start Time',
                            value: _startTime,
                            options: ['08:00', '08:30', '08:45', '09:00', '09:15', '09:30'],
                            onChanged: (v) => setState(() => _startTime = v ?? '08:45'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildParamDropdown(
                            isDark,
                            label: 'Period Duration',
                            value: '$_periodDurationMins mins',
                            options: ['40 mins', '45 mins', '50 mins', '55 mins', '60 mins'],
                            onChanged: (v) {
                              final num = int.tryParse(v?.replaceAll(' mins', '') ?? '50') ?? 50;
                              setState(() => _periodDurationMins = num);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildParamDropdown(
                            isDark,
                            label: 'Total Periods / Day',
                            value: '$_totalPeriods Periods',
                            options: ['5 Periods', '6 Periods', '7 Periods', '8 Periods', '9 Periods'],
                            onChanged: (v) {
                              final num = int.tryParse(v?.replaceAll(' Periods', '') ?? '7') ?? 7;
                              setState(() => _totalPeriods = num);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Working Days Chips
                    Text('Active Working Days', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AdminColors.getTextPrimary(isDark))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allWeekdays.map((day) {
                        final isSel = _workingDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: isSel,
                          selectedColor: AdminColors.primarySoft,
                          checkmarkColor: AdminColors.primary,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? AdminColors.primary : AdminColors.getTextPrimary(isDark),
                          ),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _workingDays.add(day);
                              } else if (_workingDays.length > 1) {
                                _workingDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Break Intervals & Recesses', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AdminColors.getTextPrimary(isDark))),
                        TextButton.icon(
                          onPressed: _addBreak,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Break'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._breaks.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final b = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminColors.getBorder(isDark)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: b['title']?.toString() ?? 'Break',
                                decoration: const InputDecoration(labelText: 'Break Title', isDense: true, border: InputBorder.none),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                onChanged: (v) => b['title'] = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: (b['after_period'] as num?)?.toInt() ?? 2,
                                  items: List.generate(_totalPeriods, (i) => i + 1).map((p) {
                                    return DropdownMenuItem<int>(value: p, child: Text('After P$p', style: GoogleFonts.inter(fontSize: 12)));
                                  }).toList(),
                                  onChanged: (v) => setState(() => b['after_period'] = v ?? 2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: (b['duration_mins'] as num?)?.toInt() ?? 15,
                                  items: [10, 15, 20, 30, 40, 45, 50, 60].map((d) {
                                    return DropdownMenuItem<int>(value: d, child: Text('$d mins', style: GoogleFonts.inter(fontSize: 12)));
                                  }).toList(),
                                  onChanged: (v) => setState(() => b['duration_mins'] = v ?? 15),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeBreak(idx),
                              icon: const Icon(Icons.close_rounded, size: 18, color: AdminColors.danger),
                              tooltip: 'Remove Break',
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Text('Live Schedule Preview', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AdminColors.getTextPrimary(isDark))),
                    const SizedBox(height: 8),
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        itemCount: timeline.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (ctx, i) {
                          final slot = timeline[i];
                          final isBrk = slot.isBreak;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isBrk ? Colors.amber[100] : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isBrk ? Colors.amber[700]! : AdminColors.getBorder(isDark)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(slot.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isBrk ? Colors.amber[900] : AdminColors.primary)),
                                Text('${slot.startTime} - ${slot.endTime}', style: GoogleFonts.inter(fontSize: 9, color: Colors.blueGrey)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AdminColors.getTextSecondary(isDark)))),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveConfig,
                          icon: _isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Save Timetable Timings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildParamDropdown(
    bool isDark, {
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AdminColors.getTextSecondary(isDark))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminColors.getBorder(isDark)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: options.contains(value) ? value : options.first,
              items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
