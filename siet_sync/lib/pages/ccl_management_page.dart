import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/college_ip_config.dart';
import '../services/leave_balance_notifier.dart';

class CCLManagementPage extends StatefulWidget {
  final String token;

  const CCLManagementPage({super.key, required this.token});

  @override
  State<CCLManagementPage> createState() => _CCLManagementPageState();
}

class _CCLManagementPageState extends State<CCLManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Settings Tab State
  bool _earlyCclEnabled = false;
  bool _lateCclEnabled = false;
  TimeOfDay _earlyStart = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _earlyEnd = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lateStart = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _lateEnd = const TimeOfDay(hour: 18, minute: 0);
  bool _savingSettings = false;

  // Balances Tab State
  List<dynamic> _balances = [];
  List<dynamic> _filteredBalances = [];
  bool _loadingBalances = true;
  String _balanceSearchQuery = '';
  String _selectedDeptFilter = 'All';
  List<String> _departments = ['All'];

  // History Tab State
  List<dynamic> _history = [];
  bool _loadingHistory = true;

  late VoidCallback _balanceListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _loadBalances();
      } else if (_tabController.index == 2) {
        _loadHistory();
      }
    });
    _loadSettings();
    _balanceListener = () {
      _loadBalances(silent: true);
    };
    LeaveBalanceNotifier.instance.addListener(_balanceListener);
  }

  @override
  void dispose() {
    LeaveBalanceNotifier.instance.removeListener(_balanceListener);
    _tabController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _parseTimeStr(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  // API Calls
  Future<void> _loadSettings() async {
    try {
      final response = await http.get(
        Uri.parse('${CollegeIPConfig.defaultURL}/admin/ccl/settings'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['success'] == true) {
          final data = res['data'];
          setState(() {
            _earlyCclEnabled = data['early_check_in_ccl_enabled'] ?? false;
            _lateCclEnabled = data['late_check_out_ccl_enabled'] ?? false;
            _earlyStart = _parseTimeStr(data['early_check_in_start'] ?? '07:00');
            _earlyEnd = _parseTimeStr(data['early_check_in_end'] ?? '08:00');
            _lateStart = _parseTimeStr(data['late_check_out_start'] ?? '17:00');
            _lateEnd = _parseTimeStr(data['late_check_out_end'] ?? '18:00');
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error loading settings: $e', Colors.red);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    try {
      final response = await http.post(
        Uri.parse('${CollegeIPConfig.defaultURL}/admin/ccl/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'early_check_in_ccl_enabled': _earlyCclEnabled,
          'late_check_out_ccl_enabled': _lateCclEnabled,
          'early_check_in_start': _formatTimeOfDay(_earlyStart),
          'early_check_in_end': _formatTimeOfDay(_earlyEnd),
          'late_check_out_start': _formatTimeOfDay(_lateStart),
          'late_check_out_end': _formatTimeOfDay(_lateEnd),
        }),
      );

      final res = json.decode(response.body);
      if (response.statusCode == 200 && res['success'] == true) {
        _showSnackBar('CCL Settings saved successfully!', Colors.green);
      } else {
        final errorMsg = res['detail'] ?? res['message'] ?? 'Failed to save settings';
        _showSnackBar(errorMsg, Colors.red);
        if (response.statusCode == 400) {
          _showConflictDialog(errorMsg);
        }
      }
    } catch (e) {
      _showSnackBar('Network error saving settings: $e', Colors.red);
    } finally {
      setState(() => _savingSettings = false);
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

  Future<void> _loadBalances({bool silent = false}) async {
    if (!silent) {
      setState(() => _loadingBalances = true);
    }
    try {
      final response = await http.get(
        Uri.parse('${CollegeIPConfig.defaultURL}/admin/ccl/balances'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['success'] == true) {
          final List<dynamic> data = res['data'] ?? [];
          setState(() {
            _balances = data;
            
            // Extract departments for filter
            final depts = <String>{'All'};
            for (var b in _balances) {
              if (b['dept'] != null && b['dept'].toString().isNotEmpty) {
                depts.add(b['dept'].toString().trim());
              }
            }
            _departments = depts.toList()..sort();
            
            _applyFilters();
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error loading balances: $e', Colors.red);
    } finally {
      if (!silent) {
        setState(() => _loadingBalances = false);
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final response = await http.get(
        Uri.parse('${CollegeIPConfig.defaultURL}/admin/ccl/history'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['success'] == true) {
          setState(() {
            _history = res['data'] ?? [];
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error loading history: $e', Colors.red);
    } finally {
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _adjustBalance(String regNo, double adj, {double? absVal}) async {
    try {
      final body = {
        'reg_no': regNo,
        'adjustment': adj,
      };
      if (absVal != null) {
        body['balance'] = absVal;
      }
      final response = await http.post(
        Uri.parse('${CollegeIPConfig.defaultURL}/admin/ccl/adjust'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['success'] == true) {
          _showSnackBar(res['message'] ?? 'Balance adjusted successfully', Colors.green);
          _loadBalances();
          LeaveBalanceNotifier.instance.notifyBalanceChanged();
        }
      } else {
        final res = json.decode(response.body);
        _showSnackBar(res['detail'] ?? 'Failed to adjust balance', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error adjusting balance: $e', Colors.red);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredBalances = _balances.where((b) {
        final matchesSearch = b['name'].toString().toLowerCase().contains(_balanceSearchQuery.toLowerCase()) ||
                              b['reg_no'].toString().toLowerCase().contains(_balanceSearchQuery.toLowerCase());
        final matchesDept = _selectedDeptFilter == 'All' || b['dept'] == _selectedDeptFilter;
        return matchesSearch && matchesDept;
      }).toList();
    });
  }

  void _showSnackBar(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 4)),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, bool isEarly, bool isStart) async {
    final current = isEarly 
        ? (isStart ? _earlyStart : _earlyEnd)
        : (isStart ? _lateStart : _lateEnd);
        
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked != null) {
      setState(() {
        if (isEarly) {
          if (isStart) {
            _earlyStart = picked;
          } else {
            _earlyEnd = picked;
          }
        } else {
          if (isStart) {
            _lateStart = picked;
          } else {
            _lateEnd = picked;
          }
        }
      });
    }
  }

  // UI Renderers
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: Container(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.deepPurple,
                labelColor: isDark ? Colors.white : Colors.black87,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(icon: Icon(Icons.timer, size: 20), text: 'CCL Rules & Settings'),
                  Tab(icon: Icon(Icons.account_balance_wallet, size: 20), text: 'Earned Leave Balances'),
                  Tab(icon: Icon(Icons.history, size: 20), text: 'CCL Earnings History'),
                ],
              ),
              Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSettingsTab(isDark),
          _buildBalancesTab(isDark),
          _buildHistoryTab(isDark),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 15 * (1.0 - val)),
            child: child,
          ),
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CCL General Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Setup rules to reward users with Earned Leave (EL) for working outside normal hours.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Divider(height: 32),
                
                // Early Check-In Card
                Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF161622) : Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Early Check-In CCL',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Enable extra leave for scanning early.',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _earlyCclEnabled,
                              activeTrackColor: Colors.deepPurple,
                              onChanged: (val) => setState(() => _earlyCclEnabled = val),
                            )
                          ],
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTimePickerTile('Start Time', _earlyStart, () => _pickTime(context, true, true), isDark),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTimePickerTile('End Time', _earlyEnd, () => _pickTime(context, true, false), isDark),
                                ),
                              ],
                            ),
                          ),
                          crossFadeState: _earlyCclEnabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Late Check-Out Card
                Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF161622) : Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Late Check-Out CCL',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Enable extra leave for scanning lately.',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _lateCclEnabled,
                              activeTrackColor: Colors.deepPurple,
                              onChanged: (val) => setState(() => _lateCclEnabled = val),
                            )
                          ],
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTimePickerTile('Start Time', _lateStart, () => _pickTime(context, false, true), isDark),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTimePickerTile('End Time', _lateEnd, () => _pickTime(context, false, false), isDark),
                                ),
                              ],
                            ),
                          ),
                          crossFadeState: _lateCclEnabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _savingSettings ? null : _saveSettings,
                    icon: _savingSettings 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Apply Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerTile(String label, TimeOfDay time, VoidCallback onTap, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2E3E) : Colors.grey[200]!,
                  width: 1.5,
                ),
                color: isDark ? const Color(0xFF161622) : Colors.grey[50],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: isDark ? Colors.deepPurple[300] : Colors.deepPurple,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      time.format(context),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalancesTab(bool isDark) {
    if (_loadingBalances) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.96, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 10 * (1.0 - val)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                final searchField = TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    hintText: 'Search by name or ID...',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF161622) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    _balanceSearchQuery = val;
                    _applyFilters();
                  },
                );

                final deptDropdown = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161622) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E2E3E) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDeptFilter,
                      icon: const Icon(Icons.filter_list_rounded, color: Colors.grey),
                      dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      items: _departments.map((dept) {
                        return DropdownMenuItem(value: dept, child: Text(dept));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedDeptFilter = val;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                );

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: deptDropdown,
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: searchField,
                      ),
                      const SizedBox(width: 16),
                      deptDropdown,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _filteredBalances.isEmpty
                      ? const Center(child: Text('No balances found.'))
                      : ListView.separated(
                          itemCount: _filteredBalances.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.grey[850] : Colors.grey[200]),
                          itemBuilder: (context, idx) {
                            final item = _filteredBalances[idx];
                            return ListTile(
                              title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${item['reg_no']} • ${item['dept']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${item['balance']} EL',
                                      style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                    onPressed: () => _showAdjustmentDialog(item),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }

    if (_history.isEmpty) {
      return const Center(child: Text('No CCL points earned yet.'));
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.96, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 10 * (1.0 - val)),
            child: child,
          ),
        );
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.grey[850] : Colors.grey[200]),
        itemBuilder: (context, idx) {
          final item = _history[idx];
          final isEarly = item['slot_type'] == 'early_check_in';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isEarly ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
              child: Icon(
                isEarly ? Icons.login : Icons.logout,
                color: isEarly ? Colors.green : Colors.amber,
                size: 20,
              ),
            ),
            title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '${item['reg_no']} • ${item['dept']}\nEarned on ${item['date']} at ${item['time']}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${item['earned_points']} EL',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  isEarly ? 'Early Check-In' : 'Late Check-Out',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAdjustmentDialog(dynamic staff) {
    final adjController = TextEditingController();
    final absController = TextEditingController(text: staff['balance'].toString());
    bool isAbsolute = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Adjust Balance: ${staff['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Add / Deduct'),
                          selected: !isAbsolute,
                          onSelected: (val) => setDialogState(() => isAbsolute = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Set Absolute'),
                          selected: isAbsolute,
                          onSelected: (val) => setDialogState(() => isAbsolute = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  isAbsolute
                      ? TextField(
                          controller: absController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'New Absolute Balance (EL)',
                            border: OutlineInputBorder(),
                          ),
                        )
                      : TextField(
                          controller: adjController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: 'Adjustment (e.g. +1.0 or -0.5)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final adjVal = double.tryParse(adjController.text) ?? 0.0;
                    final absVal = double.tryParse(absController.text);
                    Navigator.of(context).pop();
                    _adjustBalance(
                      staff['reg_no'],
                      isAbsolute ? 0.0 : adjVal,
                      absVal: isAbsolute ? absVal : null,
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  child: const Text('Update'),
                )
              ],
            );
          },
        );
      },
    );
  }
}
