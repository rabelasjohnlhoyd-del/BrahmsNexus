import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
import '../admin_web/admin_web_shell.dart';
import '../driver_app/driver_shell.dart';
import '../staff_app/staff_shell.dart';
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
///    - Owner -> [AdminWebShell] (WEB LANG — walang separate mobile
///      app para sa Owner; puwede pa rin niyang buksan ang website
///      mismo sa browser ng kanyang phone kung nasa labas siya)
///    - Staff -> [StaffShell]
///    - Driver -> [DriverShell]
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
        return const AdminWebShell();
      case UserRole.staff:
        return const StaffShell();
      case UserRole.driver:
        return const DriverShell();
    }
  }
}
