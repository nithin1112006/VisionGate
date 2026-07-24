import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/college_ip_config.dart';

class AttendanceDurationSettings extends StatefulWidget {
  final String token;

  const AttendanceDurationSettings({super.key, required this.token});

  @override
  State<AttendanceDurationSettings> createState() => _AttendanceDurationSettingsState();
}

class _AttendanceDurationSettingsState extends State<AttendanceDurationSettings> {
  List<Map<String, dynamic>> _slots = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Master Session Boundaries
  String _fhStart = '08:30';
  String _fhEnd = '13:00';
  String _shStart = '13:00';
  String _shEnd = '17:30';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final url = '${CollegeIPConfig.defaultURL}/admin/attendance/duration';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['session_boundaries'] != null) {
          final sb = data['session_boundaries'];
          _fhStart = sb['first_half_start'] ?? '08:30';
          _fhEnd = sb['first_half_end'] ?? '13:00';
          _shStart = sb['second_half_start'] ?? '13:00';
          _shEnd = sb['second_half_end'] ?? '17:30';
        }
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          setState(() {
            _slots = (data['data'] as List).map((e) {
              final map = Map<String, dynamic>.from(e);
              map['slot_type'] = map['slot_type'] ?? 'check_in';
              map['slot_half'] = map['slot_half'] ?? 'full_day';
              return map;
            }).toList();
          });
        } else {
          // Initialize with default slots
          _slots = [
            {'slot_number': 1, 'start_time': '09:00', 'duration_minutes': 30, 'is_enabled': true, 'slot_type': 'check_in', 'slot_half': 'first_half'},
            {'slot_number': 2, 'start_time': '14:00', 'duration_minutes': 30, 'is_enabled': true, 'slot_type': 'check_out', 'slot_half': 'second_half'},
          ];
        }
      } else {
        _slots = [
          {'slot_number': 1, 'start_time': '09:00', 'duration_minutes': 30, 'is_enabled': true, 'slot_type': 'check_in', 'slot_half': 'first_half'},
          {'slot_number': 2, 'start_time': '14:00', 'duration_minutes': 30, 'is_enabled': true, 'slot_type': 'check_out', 'slot_half': 'second_half'},
        ];
      }
    } catch (e) {
      print('Error loading duration settings: $e');
      _slots = [
        {'slot_number': 1, 'start_time': '09:00', 'duration_minutes': 30, 'is_enabled': true, 'slot_type': 'check_in', 'slot_half': 'first_half'},
        {'slot_number': 2, 'start_time': '14:00', 'duration_minutes': 30, 'is_enabled': true, 'slot_type': 'check_out', 'slot_half': 'second_half'},
      ];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final url = '${CollegeIPConfig.defaultURL}/admin/attendance/duration';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'settings': _slots,
          'session_boundaries': {
            'first_half_start': _fhStart,
            'first_half_end': _fhEnd,
            'second_half_start': _shStart,
            'second_half_end': _shEnd,
          },
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Duration settings saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        String errorMsg = 'Failed to save settings';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('detail')) {
            errorMsg = errorData['detail'].toString();
          } else if (errorData is Map && errorData.containsKey('message')) {
            errorMsg = errorData['message'].toString();
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
            ),
          );
          if (response.statusCode == 400) {
            _showConflictDialog(errorMsg);
          }
        }
      }
    } catch (e) {
      print('Error saving duration settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showConflictDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              const Text('Timing Conflict Detected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Understand',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.deepPurple, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBoundaryTimePicker(String label, String timeStr, Function(String) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final parts = timeStr.split(':');
            final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            final picked = await showTimePicker(context: context, initialTime: initial);
            if (picked != null) {
              onPicked('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(_slots[index]['start_time'].split(':')[0]),
        minute: int.parse(_slots[index]['start_time'].split(':')[1]),
      ),
    );

    if (picked != null) {
      setState(() {
        _slots[index]['start_time'] = 
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _addSlot() {
    if (_slots.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 slots allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _slots.add({
        'slot_number': _slots.length + 1,
        'start_time': '09:00',
        'duration_minutes': 30,
        'is_enabled': true,
        'slot_type': 'check_in',
      });
    });
  }

  void _removeSlot(int index) {
    if (_slots.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one slot is required'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _slots.removeAt(index);
      // Renumber slots
      for (int i = 0; i < _slots.length; i++) {
        _slots[i]['slot_number'] = i + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Duration'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master Session Boundaries Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule, color: Colors.deepPurple, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Overall Half Session Boundaries',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Define master operating hours for First Half and Second Half. Check-in/out slots must stay strictly within their session boundary.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),

                          // First Half Boundary Controls
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.wb_sunny_outlined, color: Colors.amber, size: 18),
                                    SizedBox(width: 8),
                                    Text('First Half Session Boundary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildBoundaryTimePicker('Start Time', _fhStart, (newTime) {
                                        setState(() => _fhStart = newTime);
                                      }),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildBoundaryTimePicker('End Time', _fhEnd, (newTime) {
                                        setState(() => _fhEnd = newTime);
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Second Half Boundary Controls
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.nights_stay_outlined, color: Colors.indigo, size: 18),
                                    SizedBox(width: 8),
                                    Text('Second Half Session Boundary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildBoundaryTimePicker('Start Time', _shStart, (newTime) {
                                        setState(() => _shStart = newTime);
                                      }),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildBoundaryTimePicker('End Time', _shEnd, (newTime) {
                                        setState(() => _shEnd = newTime);
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Slots List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _slots.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Slot ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: _slots[index]['is_enabled'] ?? true,
                                    onChanged: (value) {
                                      setState(() {
                                        _slots[index]['is_enabled'] = value;
                                      });
                                    },
                                    activeColor: Colors.green,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeSlot(index),
                                    tooltip: 'Remove Slot',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Slot Type & Slot Half Selector
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Slot Type (Purpose)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey[300]!),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: DropdownButton<String>(
                                            value: _slots[index]['slot_type'] ?? 'check_in',
                                            isExpanded: true,
                                            underline: const SizedBox(),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'check_in',
                                                child: Text('Check-In Attendance'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'check_out',
                                                child: Text('Check-Out Attendance'),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  _slots[index]['slot_type'] = value;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Session / Half Split',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey[300]!),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: DropdownButton<String>(
                                            value: _slots[index]['slot_half'] ?? 'full_day',
                                            isExpanded: true,
                                            underline: const SizedBox(),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'full_day',
                                                child: Text('Full Day / Standard'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'first_half',
                                                child: Text('First Half Slot'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'second_half',
                                                child: Text('Second Half Slot'),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  _slots[index]['slot_half'] = value;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Start Time
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Start Time',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _selectTime(index),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey[300]!),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  _slots[index]['start_time'] ?? '09:00',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Icon(Icons.access_time, color: Colors.grey[600]),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Duration (minutes)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey[300]!),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: DropdownButton<int>(
                                            value: _slots[index]['duration_minutes'] ?? 30,
                                            isExpanded: true,
                                            underline: const SizedBox(),
                                            items: [15, 30, 45, 60, 90, 120]
                                                .map((value) => DropdownMenuItem(
                                                      value: value,
                                                      child: Text('$value minutes'),
                                                    ))
                                                .toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _slots[index]['duration_minutes'] = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // End Time Display
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.event_available, 
                                         color: Colors.green[700], size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Attendance window: ${_slots[index]['start_time']} - ${_calculateEndTime(_slots[index])}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Add Slot Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _addSlot,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Time Slot'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Info Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How it works',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• Staff can only mark attendance during the configured time windows.\n'
                                  '• If no slots are enabled, attendance can be marked at any time.\n'
                                  '• Each slot defines when attendance window opens and for how long it stays open.',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _calculateEndTime(Map<String, dynamic> slot) {
    try {
      final startTime = slot['start_time'] ?? '09:00';
      final duration = slot['duration_minutes'] ?? 30;
      
      final parts = startTime.split(':');
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      
      final totalMinutes = hours * 60 + minutes + duration;
      final endHours = totalMinutes ~/ 60;
      final endMinutes = totalMinutes % 60;
      
      return '${endHours.toString().padLeft(2, '0')}:${endMinutes.toString().padLeft(2, '0')}';
    } catch (e) {
      return '09:30';
    }
  }
}
