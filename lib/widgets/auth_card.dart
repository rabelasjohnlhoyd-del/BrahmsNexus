import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Elevated white surface shared by the Login and Register forms — the
/// same soft, brown-tinted shadow + border-radius language as
/// widgets/driver_card.dart / widgets/staff_card.dart, adapted to a
/// Material context (this uses Colors.white rather than
/// CupertinoColors.white, since the auth flow is built with Material
/// widgets like Form/TextFormField throughout, while Driver/Staff use
/// Cupertino). Keeping this as one shared widget means Login and
/// Register can't drift apart in padding/radius/shadow the way the
/// three-tab apps used to before DriverCard/StaffCard existed.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
