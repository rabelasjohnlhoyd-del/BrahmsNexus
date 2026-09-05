import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_top_actions.dart';

/// Timer tab — normal na countdown timer, pero may rule-based na mga
/// paalala (hindi totoong AI/chatbot) habang papalapit sa 0.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final _minutesController = TextEditingController(text: '15');
  Timer? _ticker;
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  String? _lastReminder;

  @override
  void dispose() {
    _ticker?.cancel();
    _minutesController.dispose();
    super.dispose();
  }

  void _start() {
    final minutes = int.tryParse(_minutesController.text);
    if (minutes == null || minutes <= 0) return;

    setState(() {
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
      _isRunning = true;
      _lastReminder = null;
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        setState(() {
          _isRunning = false;
          _lastReminder = 'Tapos na ang oras — dapat malapit nang maluto '
              'ang karne!';
        });
        return;
      }
      setState(() {
        _remainingSeconds--;
        _lastReminder = _reminderFor(_remainingSeconds);
      });
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _totalSeconds = 0;
      _isRunning = false;
      _lastReminder = null;
    });
  }

  /// Simpleng rule-based na paalala base sa natitirang oras.
  String? _reminderFor(int remaining) {
    final halfway = _totalSeconds ~/ 2;
    if (remaining == halfway && halfway > 0) {
      return 'Kalahati na ng oras — tingnan ang karne.';
    }
    if (remaining == 300) return '5 minuto na lang!';
    if (remaining == 60) return '1 minuto na lang — halos luto na!';
    if (remaining == 10) return 'Halos tapos na — 10 segundo na lang.';
    return _lastReminder;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _totalSeconds == 0 ? 0.0 : 1 - (_remainingSeconds / _totalSeconds);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Timer'),
        trailing: StaffTopActions(initials: 'JD'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (!_isRunning && _remainingSeconds == 0) ...[
                const Text(
                  'Ilang minuto ang estimate mo bago maluto ang karne?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  placeholder: 'Minuto',
                  suffix: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Text('minuto',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 20),
                CupertinoButton(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _start,
                  child: const Text('Start Timer'),
                ),
              ] else ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CustomPaint(
                    painter: _CircularTimerPainter(
                      progress: progress.clamp(0, 1).toDouble(),
                      trackColor: AppColors.pastelBrown.withValues(alpha: 0.25),
                      progressColor: AppColors.accent,
                    ),
                    child: Center(
                      child: Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_lastReminder != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.bell_fill,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _lastReminder!,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: _isRunning
                            ? AppColors.warning
                            : AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _isRunning ? _pause : _start,
                        child: Text(_isRunning ? 'Pause' : 'Resume'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _reset,
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularTimerPainter extends CustomPainter {
  const _CircularTimerPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 10) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularTimerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
