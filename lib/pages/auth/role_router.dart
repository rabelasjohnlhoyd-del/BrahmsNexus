import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
import '../admin_web/admin_web_shell.dart';
import '../driver_app/driver_shell.dart';
import '../staff_app/staff_shell.dart';
import 'account_status_screen.dart';

/// Central place for the "where to go after login/register" logic.
/// All decisions like this should live here, so they don't end up
/// scattered across different screens.
///
/// Logic:
/// 1. If the account is not yet [AccountStatus.approved] (Pending or
///    Rejected), go straight to [AccountStatusScreen] — they
///    shouldn't be able to enter the app yet.
/// 2. If already approved:
///    - Owner -> [AdminWebShell] (WEB ONLY — there's no separate
///      mobile app for Owner; they can still open the website
///      itself in their phone's browser if they're out and about)
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
