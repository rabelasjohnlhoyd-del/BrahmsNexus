import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Landing screen — the first thing anyone sees. Purely a launchpad
/// into Login or Register.
///
/// No role selection happens here or anywhere else in the auth flow:
/// the account itself (looked up after login) determines whether
/// someone lands on the Owner, Staff, or Driver experience. See
/// role_router.dart.
///
/// Laid out with a [Stack] rather than a plain Column so the hero's
/// gradient can bleed a little past where the cream sheet starts. The
/// sheet's rounded top corners cut two small "notch" triangles out of
/// its own shape — with a plain Column, those notches exposed the
/// Scaffold's flat background color, which didn't match the hero's
/// gradient at that exact height and showed up as dark patches at
/// both corners. Painting a slightly taller strip of the *same*
/// gradient behind the sheet means whatever shows through the notches
/// is just a continuation of the hero itself, so the seam disappears
/// regardless of exact colors.
///
/// Fits one phone viewport with no scrolling — hero and content below
/// it always split the available height in the same proportion. The
/// content block uses fixed, comfortable gaps internally and is
/// centered vertically within the sheet, so any extra room on a
/// taller phone is shared evenly above and below instead of piling
/// into one oversized gap.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const double _heroBleed = 32;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final heroHeight = constraints.maxHeight * 0.44;
          return Stack(
            children: [
              // Gradient backdrop — deliberately taller than the
              // visible hero (see class doc) so it can bleed behind
              // the sheet's rounded corners.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: heroHeight + _heroBleed,
                child: const _HeroGradientBackdrop(),
              ),
              // Hero's actual decorative content, confined to its own
              // height so the burst/monogram stay centered in the
              // visible hero area rather than the bled-out one.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: heroHeight,
                child: const _HeroContent(),
              ),
              Positioned(
                top: heroHeight,
                left: 0,
                right: 0,
                bottom: 0,
                child: const _BottomSheet(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Plain gradient fill — no decorative content — sized slightly taller
/// than the hero itself so it can bleed behind the sheet's rounded
/// corners. See [WelcomeScreen]'s doc comment for why this exists as
/// its own layer instead of being part of [_HeroContent].
class _HeroGradientBackdrop extends StatelessWidget {
  const _HeroGradientBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.headerStart, AppColors.headerEnd],
        ),
      ),
    );
  }
}

/// The woven-burst graphic, decorative circles, and brand monogram —
/// the "illustration half" of the landing screen. Sits on top of
/// [_HeroGradientBackdrop], which supplies the actual color.
class _HeroContent extends StatelessWidget {
  const _HeroContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft decorative circles for depth — the same treatment
          // used on DriverNavBar/StaffNavBar.
          const Positioned(right: -40, top: -30, child: _DecorCircle(120)),
          const Positioned(left: -24, bottom: 6, child: _DecorCircle(84)),
          const Positioned.fill(
            child: CustomPaint(painter: _WovenBurstPainter()),
          ),
          const _Monogram(),
        ],
      ),
    );
  }
}

/// The cream, rounded-top content sheet: eyebrow/headline/subtitle,
/// the feature strip, the Log in CTA, and the footer credit line.
class _BottomSheet extends StatelessWidget {
  const _BottomSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(26, 16, 26, 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BRAHMS NEXUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every branch, one system.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Assignments, sales, inventory, and bilao orders — '
                  'tracked without the notes and group chats.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _FeatureStrip(),
            const SizedBox(height: 22),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: 'Log in',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(text: 'New staff or driver? '),
                          TextSpan(
                            text: 'Create an account',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Internal system for Brahms Crispy Sisig Bagnet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three-up row of quick feature highlights (Orders / Inventory /
/// Deliveries) — the same icon-in-a-tinted-circle language used by
/// [FeatureCard] and the Driver/Staff section headers, so the landing
/// screen previews the app's own visual vocabulary instead of
/// introducing a new one just for itself.
class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _FeatureChip(icon: Icons.receipt_long_rounded, label: 'Orders'),
        _FeatureChip(icon: Icons.inventory_2_rounded, label: 'Inventory'),
        _FeatureChip(
            icon: Icons.local_shipping_rounded, label: 'Deliveries'),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.accent),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DecorCircle extends StatelessWidget {
  const _DecorCircle(this.size);

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}

/// Circular brand monogram — sits at the center of the woven burst.
class _Monogram extends StatelessWidget {
  const _Monogram();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accentDark],
        ),
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Text(
        'BN',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Paints a ring of thin, round-capped spokes radiating outward —
/// an abstract nod to the woven rim of a bilao tray — plus a single
/// soft containing ring. Purely decorative, no external assets.
/// Scales automatically with whatever size it's given, since it reads
/// size.width/size.height rather than hardcoded pixel values.
class _WovenBurstPainter extends CustomPainter {
  const _WovenBurstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    const spokeCount = 26;
    final maxRadius = math.min(size.width, size.height) * 0.34;

    for (var i = 0; i < spokeCount; i++) {
      final angle = (2 * math.pi / spokeCount) * i;
      final lengthFactor = 0.6 + 0.4 * ((i % 3) / 2);
      final radius = maxRadius * lengthFactor;
      final start = Offset(
        center.dx + math.cos(angle) * radius * 0.42,
        center.dy + math.sin(angle) * radius * 0.42,
      );
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: i.isEven ? 0.20 : 0.13)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, paint);
    }

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, maxRadius * 0.78, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _WovenBurstPainter oldDelegate) => false;
}
