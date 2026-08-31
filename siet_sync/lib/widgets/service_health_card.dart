import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/background_service_handler.dart';
import 'oem_autostart_helper.dart';

/// Compact service-health status card shown on each role dashboard.
///
/// States:
///  • Green  — service running, battery exempt.
///  • Amber  — service running but battery optimisation is active.
///  • Red    — service is not running.
///
/// Tapping amber/red triggers the remediation flow (battery exemption dialog
/// or OEM-specific auto-start screen).
class ServiceHealthCard extends StatefulWidget {
  const ServiceHealthCard({super.key});

  @override
  State<ServiceHealthCard> createState() => _ServiceHealthCardState();
}

class _ServiceHealthCardState extends State<ServiceHealthCard> {
  bool _running = false;
  bool _batteryExempt = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final status = await BackgroundLocationService.getServiceStatus();
      if (mounted) {
        setState(() {
          _running = status.running;
          _batteryExempt = status.batteryExempt;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleTap() async {
    if (_running && !_batteryExempt) {
      // Open battery-optimisation exemption dialog
      await BackgroundLocationService.requestBatteryOptimisationExemption();
      await Future.delayed(const Duration(seconds: 1));
      await _refresh();
      // If still not exempt, offer the OEM autostart screen
      if (mounted && !_batteryExempt) {
        final launched = await OemAutostartHelper.launchOemBatterySettings();
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Open your device battery settings and disable optimisation for VisionGate.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } else if (!_running) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sync stopped. Log out and log back in to restart.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only render on Android — the service is Android-only
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    final _StatusLevel level = _loading
        ? _StatusLevel.loading
        : !_running
            ? _StatusLevel.error
            : !_batteryExempt
                ? _StatusLevel.warning
                : _StatusLevel.ok;

    return GestureDetector(
      onTap: level == _StatusLevel.warning || level == _StatusLevel.error
          ? _handleTap
          : _refresh,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _levelColor(level, cs).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _levelColor(level, cs).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _StatusDot(color: _levelColor(level, cs), pulsing: level == _StatusLevel.loading),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _labelFor(level),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _levelColor(level, cs),
                ),
              ),
            ),
            if (level == _StatusLevel.warning || level == _StatusLevel.error)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: _levelColor(level, cs)),
          ],
        ),
      ),
    );
  }

  Color _levelColor(_StatusLevel level, ColorScheme cs) {
    return switch (level) {
      _StatusLevel.ok => const Color(0xFF16A34A),      // green-600
      _StatusLevel.warning => const Color(0xFFD97706), // amber-600
      _StatusLevel.error => cs.error,
      _StatusLevel.loading => cs.onSurface.withValues(alpha: 0.45),
    };
  }

  String _labelFor(_StatusLevel level) {
    return switch (level) {
      _StatusLevel.ok => 'Location sync is active',
      _StatusLevel.warning => 'Battery saver may interrupt sync — tap to fix',
      _StatusLevel.error => 'Location sync stopped — tap for help',
      _StatusLevel.loading => 'Checking service status…',
    };
  }
}

enum _StatusLevel { ok, warning, error, loading }

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulsing;
  const _StatusDot({required this.color, required this.pulsing});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.pulsing
        ? FadeTransition(
            opacity: _anim,
            child: _dot(),
          )
        : _dot();
  }

  Widget _dot() => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      );
}
