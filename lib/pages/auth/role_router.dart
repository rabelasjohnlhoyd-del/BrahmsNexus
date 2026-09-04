import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
import '../admin_web/admin_web_shell.dart';
import '../driver_app/driver_home_screen.dart';
import '../owner_app/owner_dashboard_screen.dart';
import '../staff_app/staff_home_screen.dart';
import 'account_status_screen.dart';

/// Central place para sa "saan pupunta pagkatapos mag-login/register"
/// logic. Lahat ng ganitong desisyon ay dito lang dapat, para hindi
/// kalat sa ibat-ibang screen.
///
/// Logic:
/// 1. Kung hindi pa [AccountStatus.approved] ang account (Pending o
///    Rejected), diretso sa [AccountStatusScreen] — hindi pa dapat
///    makapasok sa app.
/// 2. Kung approved na:
///    - Owner + Web  -> [AdminWebShell] (buong admin control)
///    - Owner + Mobile -> [OwnerDashboardScreen] (monitoring lang)
///    - Staff -> [StaffHomeScreen]
///    - Driver -> [DriverHomeScreen]
class RoleRouter {
  const RoleRouter._();

  static Widget resolveDestination({
    required UserRole role,
    required AccountStatus status,
  }) {
    if (status != AccountStatus.approved) {
      return AccountStatusScreen(status: status);
    }

    switch (role) {
      case UserRole.owner:
        return kIsWeb ? const AdminWebShell() : const OwnerDashboardScreen();
      case UserRole.staff:
        return const StaffHomeScreen();
      case UserRole.driver:
        return const DriverHomeScreen();
    }
  }
}
