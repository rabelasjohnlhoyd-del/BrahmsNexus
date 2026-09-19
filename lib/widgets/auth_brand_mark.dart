import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Official circular brand emblem for Brahms Crispy Sisig Bagnet.
/// Clean, circular presentation displaying the client's official mascot logo
/// with a polished metallic golden/sienna border and soft ambient shadow (no sun rays).
/// Can also display an optional icon if explicitly specified (e.g. for forgot password).
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({
    super.key,
    this.icon,
    this.size = 86,
  });

  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Soft ambient shadow for depth
          Container(
            width: size * 0.94,
            height: size * 0.94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentDark.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),

          // 2. Elegant double-tone metallic golden & sienna border
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFDFB0),
                  Color(0xFFC77A38),
                  Color(0xFF8B4513),
                  Color(0xFFE29A5C),
                ],
              ),
            ),
          ),

          // 3. Crisp white inner ring
          Container(
            width: size * 0.91,
            height: size * 0.91,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),

          // 4. Client's Official Logo Image or Icon
          Container(
            width: size * 0.85,
            height: size * 0.85,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: icon != null
                ? Container(
                    color: const Color(0xFF381A0B),
                    child: Center(
                      child: Icon(
                        icon,
                        color: const Color(0xFFFFD4A8),
                        size: size * 0.40,
                      ),
                    ),
                  )
                : Image.asset(
                    'assets/images/brahms_logo.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(-0.45, -0.45),
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.accentDark,
                        child: const Center(
                          child: Icon(
                            Icons.restaurant_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
