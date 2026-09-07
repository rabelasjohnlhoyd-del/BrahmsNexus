import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
import '../admin_web/admin_web_shell.dart';
import '../driver_app/driver_shell.dart';
import '../owner_app/owner_shell.dart';
import '../production_app/production_shell.dart';
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
///    - Owner + running on Web (kIsWeb) -> [AdminWebShell] (account/
///      system management: Dashboard, Staff Management, Account
///      Approvals, DSS Analytics)
///    - Owner + running on the INSTALLED APP (not web) -> [OwnerShell]
///      — day-to-day operations and staff monitoring (Assignments,
///      Inventory, Sales & Payroll, Bilao Orders, Employee Reports,
///      Announcements)
///    - Staff -> [StaffShell]
///    - Driver -> [DriverShell]
class RoleRouter {
  const RoleRouter._();

  static Widget resolveDestination({
    required UserRole role,
    required AccountStatus status,
    String position = '',
  }) {
    if (status != AccountStatus.approved) {
      return AccountStatusScreen(status: status);
    }

    if (role == UserRole.owner) {
      return kIsWeb ? const AdminWebShell() : const OwnerShell();
    }

    // Staff routing based on position
    switch (position) {
      case 'Driver':
        return const DriverShell();
      case 'Production Area Cook':
      case 'Production Area Meat Cutter':
        return ProductionShell(position: position);
      default:
        // Default for Branch Cook or undefined positions
        return const StaffShell();
    }
  }
}
