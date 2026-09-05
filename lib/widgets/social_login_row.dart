import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Row of "continue with ___" social buttons for Login/Register.
///
/// Purely presentational for now — wiring up real Google/Facebook/Apple
/// sign-in is a backend-phase task, so tapping just shows a "not
/// available yet" message, consistent with the other not-yet-wired
/// actions on these screens (e.g. Forgot Password).
class SocialLoginRow extends StatelessWidget {
  const SocialLoginRow({super.key});

  void _notReady(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is not available yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(
          label: 'G',
          color: const Color(0xFFDB4437),
          onTap: () => _notReady(context, 'Google sign-in'),
        ),
        const SizedBox(width: 16),
        _SocialButton(
          icon: Icons.facebook_rounded,
          color: const Color(0xFF1877F2),
          onTap: () => _notReady(context, 'Facebook sign-in'),
        ),
        const SizedBox(width: 16),
        _SocialButton(
          icon: Icons.apple_rounded,
          color: AppColors.textPrimary,
          onTap: () => _notReady(context, 'Apple sign-in'),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    this.icon,
    this.label,
    required this.color,
    required this.onTap,
  });

  final IconData? icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentDark.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: icon != null
              ? Icon(icon, color: color, size: 22)
              : Text(
                  label!,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
        ),
      ),
    );
  }
}
