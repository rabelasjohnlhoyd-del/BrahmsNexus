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

  /// Auto-computed daily wage — portions sold × commission rate.
  double get computedWage => portionsSold * commissionRatePerPortion;

  /// Cash the Driver should collect from this branch/employee.
  double get expectedCashRemittance => totalSalesAmount - computedWage;
}
