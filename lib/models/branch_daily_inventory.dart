import 'wage_calculator.dart';

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

/// The actual counts physically entered by Staff during verification.
class ActualReceivedCounts {
  const ActualReceivedCounts({
    required this.mayo,
    required this.toyo,
    required this.styro,
    required this.regular,
    required this.medium,
    required this.b1t1,
  });

  final int mayo;
  final int toyo;
  final int styro;
  final int regular;
  final int medium;
  final int b1t1;
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
    this.actualReceived,
    this.verifiedBy,
    this.verifiedAt,
  });

  final String branchId;
  final String branchName;
  final DateTime date;
  final InventoryCounts allocated;
  final InventoryVerificationStatus status;
  final String? discrepancyNote;
  final ActualReceivedCounts? actualReceived;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  BranchDailyInventory copyWith({
    String? branchId,
    String? branchName,
    DateTime? date,
    InventoryCounts? allocated,
    InventoryVerificationStatus? status,
    String? discrepancyNote,
    ActualReceivedCounts? actualReceived,
    String? verifiedBy,
    DateTime? verifiedAt,
  }) {
    return BranchDailyInventory(
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      date: date ?? this.date,
      allocated: allocated ?? this.allocated,
      status: status ?? this.status,
      discrepancyNote: discrepancyNote ?? this.discrepancyNote,
      actualReceived: actualReceived ?? this.actualReceived,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}

/// Prices per product type (fixed by Owner).
class ProductPrices {
  static const int regular = 130; // 250g Sisig
  static const int medium = 160;  // 300g Sisig
  static const int b1t1 = 210;    // B1T1 combo (2 pcs)
}

/// Result of the Sales-tab end-of-day computation.
///
/// Business rules:
///  - Regular: ₱130 per order (uses 1 pc meat, 1 mayo, 1 styro)
///  - Medium:  ₱160 per order (uses 1 pc meat, 1 mayo, 1 styro)
///  - B1T1:    ₱210 per order (uses 2 pcs meat combo, e.g. 2 bagnet or 1 sisig + 1 bagnet; 2 styros)
///
/// Salary bracket uses weighted orders where 1 B1T1 order = 2 orders:
///   weightedOrders = regularSold + mediumSold + (b1t1OrdersSold * 2)
class DailySalesComputation {
  const DailySalesComputation({
    required this.allocatedRegular,
    required this.allocatedMedium,
    required this.allocatedB1t1,
    required this.allocatedMayo,
    required this.allocatedToyo,
    required this.allocatedStyro,
    this.remainingRegular,
    this.remainingMedium,
    this.remainingB1t1,
    this.remainingMayo,
    this.remainingToyo,
    this.remainingStyro,
  });

  // Allocated (what was delivered today)
  final int allocatedRegular;
  final int allocatedMedium;
  final int allocatedB1t1; // in pcs
  final int allocatedMayo;
  final int allocatedToyo;
  final int allocatedStyro;

  // Remaining (what the cook enters at end of day — null if not entered yet)
  final int? remainingRegular;
  final int? remainingMedium;
  final int? remainingB1t1; // in pcs
  final int? remainingMayo;
  final int? remainingToyo;
  final int? remainingStyro;

  // --- Has input checks ---
  bool get hasRegularInput => remainingRegular != null;
  bool get hasMediumInput => remainingMedium != null;
  bool get hasB1t1Input => remainingB1t1 != null;
  bool get hasMeatInput => hasRegularInput || hasMediumInput || hasB1t1Input;
  bool get hasStyroInput => remainingStyro != null;

  // --- Sold counts ---
  // If not entered (null), sold is 0 so it doesn't prematurely calculate before user inputs it
  int get regularSold => remainingRegular != null
      ? (allocatedRegular - remainingRegular!).clamp(0, 9999)
      : 0;

  /// Medium pcs sold = 1 per order
  int get mediumSold => remainingMedium != null
      ? (allocatedMedium - remainingMedium!).clamp(0, 9999)
      : 0;

  /// B1T1 pcs used (each order uses 2 pcs)
  int get b1t1PcsUsed => remainingB1t1 != null
      ? (allocatedB1t1 - remainingB1t1!).clamp(0, 9999)
      : 0;

  /// B1T1 orders = pcs used ÷ 2
  int get b1t1OrdersSold => b1t1PcsUsed ~/ 2;

  // --- Condiment & supply used ---
  int get mayoUsed => remainingMayo != null
      ? (allocatedMayo - remainingMayo!).clamp(0, 9999)
      : 0;

  int get toyoUsed => remainingToyo != null
      ? (allocatedToyo - remainingToyo!).clamp(0, 9999)
      : 0;

  int get styroUsed => remainingStyro != null
      ? (allocatedStyro - remainingStyro!).clamp(0, 9999)
      : 0;

  // --- Total orders count (actual orders handed to customers) ---
  int get totalOrders => regularSold + mediumSold + b1t1OrdersSold;

  // Backward compatibility alias
  int get ordersSold => totalOrders;

  // --- Weighted total for salary bracket ---
  // 1 B1T1 order = 2 orders for wage bracket
  int get weightedOrders => regularSold + mediumSold + (b1t1OrdersSold * 2);

  // --- Revenue ---
  int get regularRevenue => regularSold * ProductPrices.regular;
  int get mediumRevenue => mediumSold * ProductPrices.medium;
  int get b1t1Revenue => b1t1OrdersSold * ProductPrices.b1t1;
  int get totalRevenue => regularRevenue + mediumRevenue + b1t1Revenue;

  // Backward compatibility alias
  double get salesAmount => totalRevenue.toDouble();

  // --- Salary (based on weighted orders) ---
  int get salary => weightedOrders > 0 ? WageCalculator.computeWage(weightedOrders) : 0;

  // Backward compatibility alias
  int get wage => salary;

  // --- Cash remittance ---
  int get cashRemit => totalRevenue - salary;

  // Backward compatibility alias
  double get netTotal => cashRemit.toDouble();

  // Total meat portions (pcs) used
  int get totalKarneUsed => regularSold + mediumSold + b1t1PcsUsed;

  // Backward compatibility alias
  int get karneUsed => totalKarneUsed;

  // --- Discrepancy check ---
  // Only check if cook actually entered both meat and styro
  int get expectedStyroUsed => regularSold + mediumSold + (b1t1OrdersSold * 2);
  bool get hasDiscrepancy => hasStyroInput && hasMeatInput && (styroUsed != expectedStyroUsed);
}
