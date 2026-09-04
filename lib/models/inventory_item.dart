/// Daily stock allocated to a specific branch from the main warehouse,
/// plus how much of it remains. `remainingKg` is what Staff submit at
/// end-of-day (see Submit Inventory), and is what the Owner's
/// Inventory Monitor / Admin Web Inventory screen displays.
class BranchStock {
  const BranchStock({
    required this.branchId,
    required this.branchName,
    required this.date,
    required this.allocatedKg,
    required this.remainingKg,
  });

  final String branchId;
  final String branchName;
  final DateTime date;
  final double allocatedKg;
  final double remainingKg;

  double get usedKg => allocatedKg - remainingKg;

  /// True once a branch is running low — used to flag branches that
  /// may need a Driver stock-transfer stop (see the Inventory
  /// Management flowchart: "Is branch running low on stock?").
  bool get isRunningLow => allocatedKg > 0 && (remainingKg / allocatedKg) < 0.15;
}

/// Record of meat (or other stock) moved from one branch to another by
/// the Driver, at the Owner's instruction.
class StockTransferLog {
  const StockTransferLog({
    required this.id,
    required this.sourceBranchId,
    required this.sourceBranchName,
    required this.destinationBranchId,
    required this.destinationBranchName,
    required this.quantityKg,
    required this.dateTime,
  });

  final String id;
  final String sourceBranchId;
  final String sourceBranchName;
  final String destinationBranchId;
  final String destinationBranchName;
  final double quantityKg;
  final DateTime dateTime;
}

/// Total stock at the main warehouse (e.g. the 1-ton pre-cooked meat
/// count mentioned in the requirements doc) before it gets allocated
/// out to branches for the day.
class WarehouseStock {
  const WarehouseStock({
    required this.date,
    required this.totalKg,
    required this.allocatedKg,
  });

  final DateTime date;
  final double totalKg;
  final double allocatedKg;

  double get unallocatedKg => totalKg - allocatedKg;
}
