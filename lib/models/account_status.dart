/// Status of a registered account. New Staff/Driver registrations start
/// as [pending] until the Owner accepts or rejects them from the Admin
/// Web account-approvals page. The Owner account itself is pre-seeded
/// and is always [approved] — it does not go through registration.
/// [deactivated] is a temporary freeze set by the Owner — the account
/// still exists but cannot log in until re-activated.
enum AccountStatus {
  pending,
  approved,
  rejected,
  deactivated;

  String get label {
    switch (this) {
      case AccountStatus.pending:
        return 'Pending';
      case AccountStatus.approved:
        return 'Approved';
      case AccountStatus.rejected:
        return 'Rejected';
      case AccountStatus.deactivated:
        return 'Deactivated';
    }
  }
}
