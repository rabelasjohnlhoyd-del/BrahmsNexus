import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Elevated white surface shared by the Login and Register forms.
class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key, 
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
