import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Soft, brand-forward icon mark used at the top of the auth screens
/// (Login, Register).
///
/// A circular gradient badge with a gentle color-matched glow — stands
/// in for the old literal "lock" icon and the old boxed hero banner.
/// Reads as "this business" rather than "this is a security form",
/// while staying light enough not to box the page in.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({
    super.key,
    required this.icon,
    this.size = 68,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accentDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.30),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.44),
    );
  }
}
