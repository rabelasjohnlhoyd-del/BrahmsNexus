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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _BrandGraphic(),
              const SizedBox(height: 34),
              const Text(
                'BRAHMS NEXUS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Run Every Branch\nFrom One Place',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Inventory, sales, reports, and your whole team — '
                'organized in one simple app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
              ),
              const Spacer(flex: 3),
              PrimaryButton(
                label: 'Login',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    foregroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Register as Staff / Driver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hand-built decorative graphic — no external image assets required.
/// Soft concentric circles behind a storefront glyph, with a few small
/// floating accent dots for visual interest. Deliberately abstract
/// rather than a literal illustration, to stay original.
class _BrandGraphic extends StatelessWidget {
  const _BrandGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              color: AppColors.pastelBrown.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 152,
            height: 152,
            decoration: BoxDecoration(
              color: AppColors.pastelBrown.withValues(alpha: 0.38),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentDark.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          Positioned(
            top: 10,
            right: 26,
            child: _floatingDot(14, AppColors.accent.withValues(alpha: 0.85)),
          ),
          Positioned(
            bottom: 18,
            left: 20,
            child: _floatingDot(10, AppColors.accentDark.withValues(alpha: 0.6)),
          ),
          Positioned(
            bottom: 40,
            right: 4,
            child: _floatingDot(8, AppColors.accent.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _floatingDot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
