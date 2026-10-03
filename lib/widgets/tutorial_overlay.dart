import 'package:flutter/material.dart';

import '../data/tutorial_steps.dart';
import '../services/tutorial_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single rich step in the tutorial walkthrough.
class TutorialStep {
  const TutorialStep({
    required this.icon,
    required this.stepBadge,
    required this.title,
    required this.actionInstruction,
    required this.description,
    required this.interactivePreview,
    this.tip,
  });

  final IconData icon;
  final String stepBadge;
  final String title;
  final String actionInstruction;
  final String description;
  final Widget interactivePreview;
  final String? tip;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tutorial Overlay Widget
// ─────────────────────────────────────────────────────────────────────────────

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onDone,
    this.initialRole = 'staff',
    this.accentColor = const Color(0xFF8B4513),
  });

  final List<TutorialStep> steps;
  final VoidCallback onDone;
  final String initialRole;
  final Color accentColor;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  late final PageController _pageController;
  late String _currentRole;
  late List<TutorialStep> _activeSteps;
  int _currentPage = 0;

  static const _brandBrown = Color(0xFF8B4513);
  static const _brandAmber = Color(0xFFD97706);
  static const _brandDark = Color(0xFF24140B);
  static const _brandSurface = Color(0xFFFFFDF9);
  static const _brandBorder = Color(0xFFE8DED3);

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;
    _activeSteps = widget.steps.isNotEmpty ? widget.steps : _getStepsForRole(_currentRole);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<TutorialStep> _getStepsForRole(String role) {
    switch (role) {
      case 'staff':
        return TutorialSteps.staffSteps;
      case 'driver':
        return TutorialSteps.driverSteps;
      case 'production':
        return TutorialSteps.productionSteps;
      case 'owner':
        return TutorialSteps.ownerSteps;
      default:
        return TutorialSteps.staffSteps;
    }
  }

  void _switchRole(String role) {
    if (_currentRole == role) return;
    setState(() {
      _currentRole = role;
      _activeSteps = _getStepsForRole(role);
      _currentPage = 0;
    });
    _pageController.jumpToPage(0);
  }

  void _finish() {
    TutorialService.markTutorialSeen(_currentRole);
    widget.onDone();
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 450;

    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: size.height * 0.90,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20, vertical: 16),
            child: Container(
              decoration: BoxDecoration(
                color: _brandSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _brandBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header with Brand Gradient ─────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_brandDark, _brandBrown],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: _brandAmber.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _brandAmber.withValues(alpha: 0.5)),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Color(0xFFFDE68A),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Brahms Nexus • Interactive Tutorial',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    'Aktwal na gabay sa bawat pindutan at workflow',
                                    style: TextStyle(
                                      color: Color(0xFFF3E8DC),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _finish,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Skip',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Role Selector Bar ──────────────────────────────
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _roleChip('staff', '🍳 Branch Cook', Icons.storefront_rounded),
                              const SizedBox(width: 6),
                              _roleChip('driver', '🚚 Driver', Icons.local_shipping_rounded),
                              const SizedBox(width: 6),
                              _roleChip('production', '🔪 Production', Icons.soup_kitchen_rounded),
                              const SizedBox(width: 6),
                              _roleChip('owner', '💻 Owner Web', Icons.computer_rounded),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── PageView Content ───────────────────────────────────
                  Flexible(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _activeSteps.length,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                      },
                      itemBuilder: (context, index) {
                        return _StepSlide(
                          step: _activeSteps[index],
                          currentStepNumber: index + 1,
                          totalSteps: _activeSteps.length,
                        );
                      },
                    ),
                  ),

                  // ── Footer Controls ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F4EE),
                      border: Border(top: BorderSide(color: _brandBorder)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dots Indicator
                        _DotIndicator(
                          count: _activeSteps.length,
                          current: _currentPage,
                          accentColor: _brandAmber,
                        ),
                        const SizedBox(height: 12),

                        // Buttons Row
                        Row(
                          children: [
                            // Previous Button
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: _currentPage > 0
                                      ? () => _goToPage(_currentPage - 1)
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _brandDark,
                                    side: BorderSide(
                                      color: _currentPage > 0 ? _brandBorder : Colors.transparent,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Bumalik',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Next / Done Button
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _currentPage < _activeSteps.length - 1
                                      ? () => _goToPage(_currentPage + 1)
                                      : _finish,
                                  icon: Icon(
                                    _currentPage < _activeSteps.length - 1
                                        ? Icons.arrow_forward_rounded
                                        : Icons.check_circle_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _currentPage < _activeSteps.length - 1
                                        ? 'Susunod na Hakbang'
                                        : 'Naiintindihan Ko Na',
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _brandBrown,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
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
        ),
      ),
    );
  }

  Widget _roleChip(String roleKey, String label, IconData icon) {
    final isSelected = _currentRole == roleKey;
    return InkWell(
      onTap: () => _switchRole(roleKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _brandAmber : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFDE68A) : Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFFF3E8DC),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFFF3E8DC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Slide Widget with Live Interactive Mock Preview
// ─────────────────────────────────────────────────────────────────────────────

class _StepSlide extends StatelessWidget {
  const _StepSlide({
    required this.step,
    required this.currentStepNumber,
    required this.totalSteps,
  });

  final TutorialStep step;
  final int currentStepNumber;
  final int totalSteps;

  static const _brandBrown = Color(0xFF8B4513);
  static const _brandAmber = Color(0xFFD97706);
  static const _brandDark = Color(0xFF24140B);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number badge + icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _brandBrown.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _brandBrown.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'HAKBANG $currentStepNumber NG $totalSteps',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: _brandBrown,
                  ),
                ),
              ),
              const Spacer(),
              Icon(step.icon, color: _brandAmber, size: 20),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _brandDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),

          // Action Instruction Banner (Ano ang pipindutin)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: _brandAmber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.actionInstruction,
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
          const SizedBox(height: 12),

          // ── INTERACTIVE MOCK PREVIEW BOX ─────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2D4C5), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.ads_click_rounded, size: 14, color: _brandBrown),
                    const SizedBox(width: 6),
                    Text(
                      'Subukang Pindutin / Interactive Button:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _brandBrown.withValues(alpha: 0.9),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(child: step.interactivePreview),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Detailed explanation
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF4A3B32),
              height: 1.45,
            ),
          ),

          // Optional tip
          if (step.tip != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(
                      step.tip!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot Indicator
// ─────────────────────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.count,
    required this.current,
    required this.accentColor,
  });

  final int count;
  final int current;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? accentColor : const Color(0xFFDCCFC3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
