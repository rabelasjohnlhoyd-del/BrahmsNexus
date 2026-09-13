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
    this.position = '',
    this.fullName = '',
    this.branchName = '',
    this.phone = '',
  });

  final String password;
  final UserRole role;
  final AccountStatus status;
  final String position;
  final String fullName;
  final String branchName;
  final String phone;
}

const Map<String, MockAccount> kMockAccounts = {
  // 1. BUSINESS OWNER
  'owner': MockAccount(
    password: 'owner123',
    role: UserRole.owner,
    status: AccountStatus.approved,
    fullName: 'Business Owner',
    phone: '09123456789',
  ),

  // 2. OFFICIAL 6 BRANCH COOKS (Client's Real Personnel)
  'leany_malla': MockAccount(
    password: 'pass123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Branch Cook',
    fullName: 'Leany Hernandez Malla',
    branchName: 'Brgy. Dayap, Calauan',
    phone: '09917063234',
  ),
  'jobelle_fuentes': MockAccount(
    password: 'pass123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Branch Cook',
    fullName: 'Jobelle T. Fuentes',
    branchName: 'Brgy. Labuin, Pila',
    phone: '09260715146',
  ),
  'virgenita_espiritu': MockAccount(
    password: 'pass123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Branch Cook',
    fullName: 'Virgenita Espiritu',
    branchName: 'Brgy. Nanhaya, Victoria',
    phone: '09853652758',
  ),
  'jovelle_camila': MockAccount(
    password: 'pass123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Branch Cook',
    fullName: 'Jovelle P. Camila',
    branchName: 'Brgy. Gatid, Sta. Cruz',
    phone: '09655818582',
  ),
  'patricia_espiritu': MockAccount(
    password: 'pass123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Branch Cook',
    fullName: 'Patricia Mharie M. Espiritu',
    branchName: 'Brgy. Sta. Clara Sur, Pila',
    phone: '09152319790',
  ),
  'alma_agonos': MockAccount(
    password: 'pass123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Branch Cook',
    fullName: 'Alma D. Agonos',
    branchName: 'Brgy. San Francisco, Victoria',
    phone: '09949178538',
  ),

  // 3. LOGISTICS & PRODUCTION CREW
  'danilo_driver': MockAccount(
    password: 'pass123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Driver',
    fullName: 'Danilo Ramos',
    phone: '09123456789',
  ),
  'menes_cook': MockAccount(
    password: 'pass123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Production Area Cook',
    fullName: 'Menes Bantug',
  ),
  'abby_cutter': MockAccount(
    password: 'pass123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Production Area Meat Cutter',
    fullName: 'Abby Torres',
  ),

  // 4. LEGACY ALIASES (backward compatibility)
  'staff': MockAccount(
    password: 'staff123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Branch Cook',
    fullName: 'Default Staff',
  ),
  'staff.pending': MockAccount(
    password: 'staff123',
    role: UserRole.staff,
    status: AccountStatus.pending,
    position: 'Branch Cook',
  ),
  'driver': MockAccount(
    password: 'driver123',
    role: UserRole.staff,
    status: AccountStatus.approved,
    position: 'Driver',
    fullName: 'Default Driver',
  ),
  'driver.rejected': MockAccount(
    password: 'driver123',
    role: UserRole.staff,
    status: AccountStatus.rejected,
    position: 'Driver',
  ),
};
