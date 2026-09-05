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
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = math.max(300.0, screenHeight * 0.46);

    return Scaffold(
      backgroundColor: AppColors.accent,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: heroHeight,
              child: const _HeroPanel(),
            ),
            Container(
              constraints: BoxConstraints(minHeight: screenHeight - heroHeight),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'BRAHMS NEXUS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Every branch,\none system.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Daily assignments, sales, inventory, and bilao orders '
                    '— tracked from Pending to Delivered, without the '
                    'notes and group chats.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: 'Log in',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 14,
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
                  const SizedBox(height: 12),
                  const Text(
                    'Internal system for Brahms Crispy Sisig Bagnet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed colored panel behind the woven-burst hero graphic and
/// brand monogram — the "illustration half" of the landing screen.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        // Flat, solid accent brown — the same fill DriverNavBar and
        // StaffNavBar use everywhere else in the app, so the Landing
        // screen doesn't introduce a one-off gradient look.
        color: AppColors.accent,
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _WovenBurstPainter()),
            ),
            const _Monogram(),
            Positioned(
              top: 28,
              left: 28,
              child: _floatingDot(10, Colors.white.withValues(alpha: 0.28)),
            ),
            Positioned(
              bottom: 32,
              right: 40,
              child: _floatingDot(7, Colors.white.withValues(alpha: 0.32)),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _floatingDot(double size, Color color) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Circular brand monogram — sits at the center of the woven burst.
class _Monogram extends StatelessWidget {
  const _Monogram();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Text(
        'BN',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Paints a ring of thin, round-capped spokes radiating outward —
/// an abstract nod to the woven rim of a bilao tray — plus a single
/// soft containing ring. Purely decorative, no external assets.
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
