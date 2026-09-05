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
      children: [
        Expanded(
          child: _SocialPill(
            icon: Icons.g_mobiledata_rounded,
            iconColor: const Color(0xFFDB4437),
            label: 'Google',
            onTap: () => _notReady(context, 'Google sign-in'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialPill(
            icon: Icons.facebook_rounded,
            iconColor: const Color(0xFF1877F2),
            label: 'Facebook',
            onTap: () => _notReady(context, 'Facebook sign-in'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialPill(
            icon: Icons.apple_rounded,
            iconColor: AppColors.textPrimary,
            label: 'Apple',
            onTap: () => _notReady(context, 'Apple sign-in'),
          ),
        ),
      ],
    );
  }
}

class _SocialPill extends StatelessWidget {
  const _SocialPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
