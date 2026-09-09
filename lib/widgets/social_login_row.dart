import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// Row of "continue with ___" social buttons for Login/Register.
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
            customIcon: const _GoogleActualLogo(),
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
      ],
    );
  }
}

class _SocialPill extends StatelessWidget {
  const _SocialPill({
    this.icon,
    this.iconColor,
    this.customIcon,
    required this.label,
    required this.onTap,
  });

  final IconData? icon;
  final Color? iconColor;
  final Widget? customIcon;
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
              if (customIcon != null)
                SizedBox(width: 18, height: 18, child: customIcon)
              else if (icon != null)
                Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _GoogleActualLogo extends StatelessWidget {
  const _GoogleActualLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double centerX = w / 2;
    final double centerY = h / 2;
    
    // Precise thickness to match real Google G proportions
    final double thickness = w * 0.24; 
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: Offset(centerX, centerY), radius: (w - thickness) / 2);

    double degToRad(double deg) => deg * (math.pi / 180.0);

    // 1. Red (Top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, degToRad(198), degToRad(112), false, paint);

    // 2. Yellow (Left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, degToRad(150), degToRad(48), false, paint);

    // 3. Green (Bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, degToRad(45), degToRad(105), false, paint);

    // 4. Blue (Right side arc)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, degToRad(0), degToRad(45), false, paint);
    
    // Blue Bar (Tail) - Now flush and aligned
    final barPaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    // We start the bar from center and ensure it matches the arc's vertical position exactly
    canvas.drawRect(
      Rect.fromLTWH(centerX, centerY - thickness / 2, w / 2, thickness),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
