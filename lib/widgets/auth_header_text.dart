import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Header used at the top of the auth screens (Login, Register).
///
/// Deliberately NOT a filled box/card — just an icon, title, and
/// subtitle sitting directly on the page background (matches how the
/// rest of the screen looks), but styled with a bit more intention
/// than plain stacked Text: a generously-sized icon in the accent
/// color, a bold title, and a short accent "eyebrow" bar that gives
/// the block a clear visual anchor without boxing it in.
class AuthHeaderText extends StatelessWidget {
  const AuthHeaderText({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 38, color: AppColors.accent),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14.5,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
