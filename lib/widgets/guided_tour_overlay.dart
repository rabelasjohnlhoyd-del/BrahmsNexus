import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class GuidedTourStep {
  const GuidedTourStep({
    required this.targetKey,
    required this.roleBadge,
    required this.title,
    required this.instruction,
    required this.explanation,
    this.tip,
    this.onTargetTapped,
    this.borderRadius = 14.0,
    this.padding = const EdgeInsets.all(6.0),
  });

  /// The GlobalKey of the live widget on screen that will be spotlighted.
  final GlobalKey targetKey;

  /// Header badge (e.g. 'BRANCH COOK ONBOARDING')
  final String roleBadge;

  /// Main title of the step
  final String title;

  /// The clear action directive (what button to tap)
  final String instruction;

  /// Detailed explanation of what the button does
  final String explanation;

  /// Optional company tip or reminder
  final String? tip;

  /// Callback executed when the spotlighted target is tapped
  final VoidCallback? onTargetTapped;

  /// Corner radius for the spotlight cutout
  final double borderRadius;

  /// Extra padding around the target widget for the spotlight hole
  final EdgeInsets padding;
}

// ─────────────────────────────────────────────────────────────────────────────
// Guided Tour Controller & Overlay
// ─────────────────────────────────────────────────────────────────────────────

class GuidedTourOverlay extends StatefulWidget {
  const GuidedTourOverlay({
    super.key,
    required this.steps,
    required this.onCompleted,
    required this.onSkipped,
  });

  final List<GuidedTourStep> steps;
  final VoidCallback onCompleted;
  final VoidCallback onSkipped;

  /// Shows the interactive guided tour overlay over the current screen
  static OverlayEntry? show({
    required BuildContext context,
    required List<GuidedTourStep> steps,
    required VoidCallback onCompleted,
    VoidCallback? onSkipped,
  }) {
    OverlayState? overlayState = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => GuidedTourOverlay(
        steps: steps,
        onCompleted: () {
          entry.remove();
          onCompleted();
        },
        onSkipped: () {
          entry.remove();
          onSkipped?.call();
        },
      ),
    );
    overlayState.insert(entry);
    return entry;
  }

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  Rect? _targetRect;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _brandBrown = Color(0xFF8B4513);
  static const _brandAmber = Color(0xFFD97706);
  static const _brandDark = Color(0xFF24140B);
  static const _scrimColor = Color(0xC70D0805); // 78% dark warm espresso scrim

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveTargetRect();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _resolveTargetRect() {
    if (!mounted || widget.steps.isEmpty) return;
    final currentStep = widget.steps[_currentStepIndex];
    final context = currentStep.targetKey.currentContext;

    if (context != null) {
      try {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          alignment: 0.5,
        );
      } catch (_) {}

      Future.delayed(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        final targetCtx = currentStep.targetKey.currentContext;
        final renderBox = targetCtx?.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;
          final rawRect = position & size;

          final paddedRect = Rect.fromLTRB(
            rawRect.left - currentStep.padding.left,
            rawRect.top - currentStep.padding.top,
            rawRect.right + currentStep.padding.right,
            rawRect.bottom + currentStep.padding.bottom,
          );

          setState(() {
            _targetRect = paddedRect;
          });
        }
      });
      return;
    }

    // Fallback if target is temporarily offscreen or rendering: retry after 200ms
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _resolveTargetRect();
    });
  }

  void _handleTargetTapped() {
    final currentStep = widget.steps[_currentStepIndex];
    currentStep.onTargetTapped?.call();

    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _targetRect = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveTargetRect();
      });
    } else {
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    final screenSize = MediaQuery.sizeOf(context);
    final currentStep = widget.steps[_currentStepIndex];
    final rect = _targetRect;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dark Scrim with Spotlight Hole Cutout ────────────────────
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: screenSize,
                painter: _SpotlightPainter(
                  targetRect: rect,
                  borderRadius: currentStep.borderRadius,
                  scrimColor: _scrimColor,
                  pulseScale: _pulseAnimation.value,
                ),
              );
            },
          ),

          // ── Tappable Interactive Area over Spotlight Hole ────────────
          if (rect != null)
            Positioned.fromRect(
              rect: rect,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleTargetTapped,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(currentStep.borderRadius),
                    ),
                  ),
                ),
              ),
            ),

          // ── Pulsing Hand Gesture Indicator ───────────────────────────
          if (rect != null)
            Positioned(
              left: math.max(16.0, rect.center.dx - 18),
              top: (rect.center.dy > screenSize.height * 0.48)
                  ? math.max(MediaQuery.paddingOf(context).top + 50, rect.top - 44)
                  : math.min(screenSize.height - 80, rect.bottom + 8),
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _brandAmber,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _brandAmber.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Floating Corporate Tooltip Card ──────────────────────────
          _buildFloatingTooltip(screenSize, rect, currentStep),

          // ── Top Header Bar (Company Branding & Exit Button) ──────────
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _brandDark.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _brandAmber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: _brandAmber, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        currentStep.roleBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: widget.onSkipped,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Laktawan (Exit)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.close_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTooltip(
    Size screenSize,
    Rect? targetRect,
    GuidedTourStep step,
  ) {
    // If targetRect is not yet ready, center the card
    final bool hasRect = targetRect != null;
    final double safeTop = MediaQuery.paddingOf(context).top + 52;
    final double safeBottom = screenSize.height - MediaQuery.paddingOf(context).bottom - 20;

    // Determine placement:
    // If target is in the lower 52% of the screen, place the card at the TOP.
    // If target is in the upper half of the screen, place the card BELOW the target.
    final bool targetInLowerHalf = hasRect && targetRect.center.dy > screenSize.height * 0.48;

    final double maxWidth = math.min(screenSize.width - 32, 420.0);
    double topPosition;

    if (!hasRect) {
      topPosition = screenSize.height * 0.28;
    } else if (targetInLowerHalf) {
      // Place near top of screen with plenty of clearance above target
      topPosition = safeTop;
    } else {
      // Place below target with safe margin
      topPosition = math.min(targetRect.bottom + 16, safeBottom - 320);
    }

    return Positioned(
      top: topPosition,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF9), // Warm Ivory
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8DED3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Indicator & Counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _brandBrown.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'HAKBANG ${_currentStepIndex + 1} NG ${widget.steps.length}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: _brandBrown,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 14, color: _brandAmber),
                        SizedBox(width: 4),
                        Text(
                          'Pindutin ang Target',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _brandAmber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Step Title
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _brandDark,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Action Directive Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_right_alt_rounded, color: _brandAmber, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          step.instruction,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Explanation
                Text(
                  step.explanation,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF4A3B32),
                    height: 1.4,
                  ),
                ),

                // Tip Box
                if (step.tip != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            step.tip!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF166534),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Footer Prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pindutin ang naka-highlight na button 👆',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: _brandBrown.withValues(alpha: 0.8),
                      ),
                    ),
                    InkWell(
                      onTap: _handleTargetTapped,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE8DED3)),
                        ),
                        child: const Text(
                          'Next ➔',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brandDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter for Cutout Spotlight Hole
// ─────────────────────────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.targetRect,
    required this.borderRadius,
    required this.scrimColor,
    required this.pulseScale,
  });

  final Rect? targetRect;
  final double borderRadius;
  final Color scrimColor;
  final double pulseScale;

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect == null) {
      canvas.drawPath(screenPath, Paint()..color = scrimColor);
      return;
    }

    final rrect = RRect.fromRectAndRadius(targetRect!, Radius.circular(borderRadius));
    final holePath = Path()..addRRect(rrect);

    // Difference between full screen and the target cutout
    final combinedPath = Path.combine(PathOperation.difference, screenPath, holePath);
    canvas.drawPath(combinedPath, Paint()..color = scrimColor);

    // Glowing border around cutout
    final glowPaint = Paint()
      ..color = const Color(0xFFD97706).withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * pulseScale;

    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseScale != pulseScale;
  }
}
