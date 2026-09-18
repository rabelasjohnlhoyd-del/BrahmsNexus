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
    this.remainingStock,
    this.wage,
    this.regularSold,
    this.mediumSold,
    this.b1t1OrdersSold,
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
  /// End-of-day remaining stock submitted by Staff — mirrors what they
  /// entered in the Remaining Stock section of the Sales tab.
  final ActualReceivedCounts? remainingStock;

  final double? wage;
  final int? regularSold;
  final int? mediumSold;
  final int? b1t1OrdersSold;

  /// Auto-computed daily wage — uses stored tiered wage if provided,
  /// else falls back to WageCalculator or commission rate.
  double get computedWage =>
      wage ??
      (portionsSold > 0
          ? WageCalculator.computeWage(portionsSold).toDouble()
          : (portionsSold * commissionRatePerPortion));

  /// Cash the Driver should collect from this branch/employee.
  double get expectedCashRemittance => totalSalesAmount - computedWage;
}
