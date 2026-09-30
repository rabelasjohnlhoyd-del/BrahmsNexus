import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Mobile-only auth screen layout for Login and Register screens.
///
/// Renders a dark chocolate header ([AppColors.headerStart]) with
/// "BRAHMS NEXUS" gold branding, ornamental dividers, and a smooth S-wave
/// curve transition into the warm [AppColors.background]-coloured body.
///
/// Ensures bottom buttons and links are always 100% visible and accessible
/// with generous clearance above the Android system navigation bar.
class MobileAuthLayout extends StatelessWidget {
  const MobileAuthLayout({
    super.key,
    required this.child,
    this.subtitle = 'Crispy Sisig & Bagnet',
    this.showBackButton = false,
    this.onBack,
  });

  /// The form / content rendered in the scrollable body below the wave.
  final Widget child;

  /// Subtitle shown beneath "BRAHMS NEXUS" in the dark header.
  /// Defaults to "Crispy Sisig & Bagnet".
  final String subtitle;

  /// Whether to show the back arrow in the top-left of the header.
  final bool showBackButton;

  /// Callback for the back button. Defaults to [Navigator.maybePop].
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Dark chocolate wave header ────────────────────────────────
          _MobileAuthHeader(
            subtitle: subtitle,
            showBackButton: showBackButton,
            onBack: onBack ?? () => Navigator.of(context).maybePop(),
          ),

          // ── Scrollable body with safe bottom clearance ────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                28,
                10,
                28,
                // Extra bottom clearance so Android navigation bar never blocks buttons
                28 + bottomInset,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal header widget ──────────────────────────────────────────────────

class _MobileAuthHeader extends StatelessWidget {
  const _MobileAuthHeader({
    required this.subtitle,
    required this.showBackButton,
    required this.onBack,
  });

  final String subtitle;
  final bool showBackButton;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    // Balanced header height that leaves plenty of room for forms & bottom buttons
    final double containerHeight = topPadding + 155.0;

    return ClipPath(
      clipper: _AuthWaveClipper(),
      child: Container(
        height: containerHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.headerStart, // #2B1B12
              Color(0xFF352216),
              AppColors.headerStart,
            ],
            stops: [0.0, 0.60, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Back arrow button (for Register or sub-pages)
              if (showBackButton)
                Positioned(
                  top: 2,
                  left: 4,
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFFE5B06B),
                        size: 22,
                      ),
                      onPressed: onBack,
                      splashRadius: 22,
                      tooltip: 'Back',
                    ),
                  ),
                ),

              // Centered brand block
              Align(
                alignment: const Alignment(0, -0.32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OrnamentalDivider(),
                    const SizedBox(height: 8),
                    const Text(
                      'BRAHMS NEXUS',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.8,
                        color: Color(0xFFD4A25A),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                        color: const Color(0xFFD4A25A).withValues(alpha: 0.80),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _OrnamentalDivider(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Thin gold ornamental divider ────────────────────────────────────────────

class _OrnamentalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 1,
          color: const Color(0xFFD4A25A).withValues(alpha: 0.45),
        ),
        const SizedBox(width: 8),
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFD4A25A),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 38,
          height: 1,
          color: const Color(0xFFD4A25A).withValues(alpha: 0.45),
        ),
      ],
    );
  }
}

// ── S-wave clipper for the dark header ─────────────────────────────────────

class _AuthWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    // Left edge down to wave start
    path.lineTo(0, size.height * 0.80);
    // S-curve: dips down on the left-center, rises on the right-center
    path.cubicTo(
      size.width * 0.26, size.height * 1.04, // ctrl1 — pull down-left
      size.width * 0.68, size.height * 0.58, // ctrl2 — pull up-right
      size.width, size.height * 0.80,         // right edge
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_AuthWaveClipper oldClipper) => false;
}
