/// The 4 itemized inventory items tracked per branch, per day.
/// - karne: meat, pre-portioned in plastic per order (Sisig or Bagnet)
/// - mayo: used only for Sisig orders
/// - toyo: used only for Bagnet orders
/// - styro: 1 container per order, regardless of size
class InventoryCounts {
  const InventoryCounts({
    required this.karne,
    required this.mayo,
    required this.styro,
    required this.toyo,
  });

  final int karne;
  final int mayo;
  final int styro;
  final int toyo;

  InventoryCounts copyWith({int? karne, int? mayo, int? styro, int? toyo}) {
    return InventoryCounts(
      karne: karne ?? this.karne,
      mayo: mayo ?? this.mayo,
      styro: styro ?? this.styro,
      toyo: toyo ?? this.toyo,
    );
  }
}

enum InventoryVerificationStatus {
  pending,
  confirmed,
  discrepancyReported;

  String get label {
    switch (this) {
      case InventoryVerificationStatus.pending:
        return 'Pending';
      case InventoryVerificationStatus.confirmed:
        return 'Confirmed';
      case InventoryVerificationStatus.discrepancyReported:
        return 'Discrepancy Reported';
    }
  }
}

/// What the Owner recorded as sent to a branch for the day, plus the
/// cook's physical recount and verification result. This is a
/// DELIVERY check (does what arrived match what Owner logged) — not
/// the same as end-of-day remaining stock (see Sales tab).
///
/// The Homepage confirm/deny flow is non-blocking: the cook can still
/// use the Sales tab even while [status] is
/// [InventoryVerificationStatus.discrepancyReported] — the Owner
/// resolves it by sending extra stock.
class BranchDailyInventory {
  const BranchDailyInventory({
    required this.branchId,
    required this.branchName,
    required this.date,
    required this.allocated,
    this.status = InventoryVerificationStatus.pending,
    this.discrepancyNote,
  });

  final String branchId;
  final String branchName;
  final DateTime date;
  final InventoryCounts allocated;
  final InventoryVerificationStatus status;
  final String? discrepancyNote;

  BranchDailyInventory copyWith({
    InventoryVerificationStatus? status,
    String? discrepancyNote,
  }) {
    return BranchDailyInventory(
      branchId: branchId,
      branchName: branchName,
      date: date,
      allocated: allocated,
      status: status ?? this.status,
      discrepancyNote: discrepancyNote ?? this.discrepancyNote,
    );
  }
}

/// Result of the Sales-tab end-of-day computation. Orders sold is
/// derived from Karne usage (each portion = exactly one order, since
/// meat arrives pre-divided per order). Styro usage is cross-checked
/// against it — since 1 order should also use exactly 1 styro
/// container, a mismatch flags a possible discrepancy (lost/extra
/// container, miscount, etc.) worth the Owner's attention.
class DailySalesComputation {
  const DailySalesComputation({
    required this.allocated,
    required this.remaining,
    required this.pricePerOrder,
  });

  final InventoryCounts allocated;
  final InventoryCounts remaining;
  final double pricePerOrder;

  int get karneUsed => allocated.karne - remaining.karne;
  int get mayoUsed => allocated.mayo - remaining.mayo;
  int get styroUsed => allocated.styro - remaining.styro;
  int get toyoUsed => allocated.toyo - remaining.toyo;

  /// Orders sold — derived from Karne usage (the reliable 1:1 counter).
  int get ordersSold => karneUsed;

  /// True when Karne-derived and Styro-derived counts disagree —
  /// exactly the kind of discrepancy the Owner used to have to find
  /// manually.
  bool get hasDiscrepancy => karneUsed != styroUsed;

  double get salesAmount => ordersSold * pricePerOrder;

  int get wage => WageCalculator.computeWage(ordersSold);

  double get netTotal => salesAmount - wage;
}
