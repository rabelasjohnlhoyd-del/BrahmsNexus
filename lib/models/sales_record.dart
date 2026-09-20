import 'branch_daily_inventory.dart';
import 'wage_calculator.dart';

/// Daily sales submitted by Staff for a branch, used both for the
/// Sales & Payroll admin screen and for the auto-computed wage per
/// the "Sales and Auto-Payroll" flowchart (portions sold -> total
/// sales -> staff wage/commission -> expected cash remittance).
class SalesRecord {
  const SalesRecord({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.portionsSold,
    required this.commissionRatePerPortion,
    required this.totalSalesAmount,
    this.totalOrders,
    this.remainingStock,
    this.wage,
    this.regularSold,
    this.mediumSold,
    this.b1t1OrdersSold,
    this.discrepancyNote,
  });

  final String id;
  final String branchId;
  final String branchName;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final int portionsSold;
  final double commissionRatePerPortion;
  final double totalSalesAmount;
  final int? totalOrders;
  /// End-of-day remaining stock submitted by Staff — mirrors what they
  /// entered in the Remaining Stock section of the Sales tab.
  final ActualReceivedCounts? remainingStock;

  final double? wage;
  final int? regularSold;
  final int? mediumSold;
  final int? b1t1OrdersSold;
  final String? discrepancyNote;

  /// Total customer orders (1 regular = 1 order, 1 medium = 1 order, 1 B1T1 = 1 order).
  int get displayTotalOrders {
    if (totalOrders != null && totalOrders! > 0) return totalOrders!;
    if (regularSold != null || mediumSold != null || b1t1OrdersSold != null) {
      return (regularSold ?? 0) + (mediumSold ?? 0) + (b1t1OrdersSold ?? 0);
    }
    return portionsSold;
  }

  /// Total karne portions (pcs of meat: 1 per regular, 1 per medium, 2 per B1T1 order).
  int get displayPortions {
    if (regularSold != null || mediumSold != null || b1t1OrdersSold != null) {
      final computed = (regularSold ?? 0) + (mediumSold ?? 0) + ((b1t1OrdersSold ?? 0) * 2);
      if (computed > 0) return computed;
    }
    return portionsSold;
  }

  /// Auto-computed daily wage — uses stored tiered wage if provided,
  /// else falls back to WageCalculator or commission rate.
  double get computedWage =>
      wage ??
      (displayPortions > 0
          ? WageCalculator.computeWage(displayPortions).toDouble()
          : (displayPortions * commissionRatePerPortion));

  /// Cash the Driver should collect from this branch/employee.
  double get expectedCashRemittance => totalSalesAmount - computedWage;
}
