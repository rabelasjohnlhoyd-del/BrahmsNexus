/// Status of a registered account. New Staff/Driver registrations start
/// as [pending] until the Owner accepts or rejects them from the Admin
/// Web account-approvals page. The Owner account itself is pre-seeded
/// and is always [approved] — it does not go through registration.
enum AccountStatus {
  pending,
  approved,
  rejected;

  String get label {
    switch (this) {
      case AccountStatus.pending:
        return 'Pending';
      case AccountStatus.approved:
        return 'Approved';
      case AccountStatus.rejected:
        return 'Rejected';
    }
  }
}
