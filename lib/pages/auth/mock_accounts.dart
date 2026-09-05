import '../../models/account_status.dart';
import '../../models/user_role.dart';

/// TEMPORARY, DEV-ONLY stand-in for a backend.
///
/// Once Firebase Auth + Firestore are wired up, logging in will look up
/// the authenticated user's actual role and account status from their
/// Firestore user record — role is never chosen by the person logging
/// in, it's a property of the account. This map exists only so the
/// login flow (including [RoleRouter] and the Pending/Rejected screens)
/// can be exercised end-to-end before that backend exists.
///
/// Delete this file once real auth + user records are live, and replace
/// the lookup in login_screen.dart with the real one.
class MockAccount {
  const MockAccount({
    required this.password,
    required this.role,
    required this.status,
  });

  final String password;
  final UserRole role;
  final AccountStatus status;
}

const Map<String, MockAccount> kMockAccounts = {
  'owner': MockAccount(
    password: 'owner123',
    role: UserRole.owner,
    status: AccountStatus.approved, // pre-seeded, always approved
  ),
  'staff': MockAccount(
    password: 'staff123',
    role: UserRole.staff,
    status: AccountStatus.approved,
  ),
  'staff.pending': MockAccount(
    password: 'staff123',
    role: UserRole.staff,
    status: AccountStatus.pending,
  ),
  'driver': MockAccount(
    password: 'driver123',
    role: UserRole.driver,
    status: AccountStatus.approved,
  ),
  'driver.rejected': MockAccount(
    password: 'driver123',
    role: UserRole.driver,
    status: AccountStatus.rejected,
  ),
};
