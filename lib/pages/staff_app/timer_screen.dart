import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staff_button.dart';
import '../../widgets/staff_card.dart';
import '../../widgets/staff_nav_bar.dart';
import '../../widgets/staff_top_actions.dart';

/// Timer tab — a normal countdown timer, with rule-based reminders
/// (not a real AI/chatbot) as it approaches zero.
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
          _lastReminder = "Time's up — the Karne should be almost done "
              'cooking!';
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

  /// Confirms before resetting a timer that's still running or has
  /// time left — a single accidental tap shouldn't be enough to wipe
  /// out progress on something that's actively cooking.
  Future<void> _confirmReset() async {
    if (!_isRunning && _remainingSeconds == 0) {
      _reset();
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Reset Timer?'),
        content: const Text(
          'This will clear the current countdown. Are you sure?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) _reset();
  }

  /// Simple rule-based reminder based on time remaining.
  String? _reminderFor(int remaining) {
    final halfway = _totalSeconds ~/ 2;
    if (remaining == halfway && halfway > 0) {
      return 'Halfway there — check on the Karne.';
    }
    if (remaining == 300) return '5 minutes left!';
    if (remaining == 60) return '1 minute left — almost done!';
    if (remaining == 10) return 'Almost done — 10 seconds left.';
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
      navigationBar: const StaffNavBar(
        title: 'Timer',
        trailing: StaffTopActions(initials: 'JD'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              if (!_isRunning && _remainingSeconds == 0) ...[
                const SizedBox(height: 12),
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.pastelBrown.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.timer,
                      size: 38, color: AppColors.accent),
                ),
                const SizedBox(height: 20),
                const Text(
                  'How many minutes until the Karne is cooked?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                StaffCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: CupertinoTextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    placeholder: 'Minutes',
                    decoration: const BoxDecoration(color: CupertinoColors.white),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    suffix: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Text('minutes',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                StaffButton(
                  label: 'Start Timer',
                  icon: CupertinoIcons.play_fill,
                  onPressed: _start,
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
                      child: StaffButton(
                        label: _isRunning ? 'Pause' : 'Resume',
                        icon: _isRunning
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        color: _isRunning
                            ? AppColors.warning
                            : AppColors.success,
                        onPressed: _isRunning ? _pause : _start,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StaffButton(
                        label: 'Reset',
                        icon: CupertinoIcons.arrow_counterclockwise,
                        color: AppColors.error,
                        onPressed: _confirmReset,
                      ),
                    ),
                  ],
                ),
              ],
              ],
            ),
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
