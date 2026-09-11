import 'procurement_list.dart';

class FinancialPeriod {
  FinancialPeriod({
    required this.id,
    required this.monthName,
    required this.year,
    required this.productionPcs,
    required this.productionLaborDays,
    this.dailyOverheads = const [],
    this.procurementGroups = const [],
  });

  final String id;
  final String monthName;
  final int year;
  final int productionPcs; // From Production Batches
  final int productionLaborDays; // (abby/menes working days)
  final List<DailyOverheadEntry> dailyOverheads;
  final List<ProcurementGroup> procurementGroups;

  // --- REVENUE ---
  double get grossRevenue => productionPcs * 130.0;

  // --- EXPENSES ---
  double get totalProcurementCost => procurementGroups.fold(0, (sum, g) => sum + g.total);
  
  double get totalProductionLaborCost => productionLaborDays * 2200.0; // Sample rate: 2200 for both

  double get accumulatedStoreCost => dailyOverheads.fold(0, (sum, entry) => sum + entry.totalDailyOverhead);

  double get totalExpenses => totalProcurementCost + totalProductionLaborCost + accumulatedStoreCost;

  // --- FINAL BOTTOM LINE ---
  double get netMav => grossRevenue - totalExpenses;

  double get workingDaysCount => dailyOverheads.length.toDouble();
}

class DailyOverheadEntry {
  DailyOverheadEntry({
    required this.date,
    required this.totalStaffWages, // Automatically pulled from Sales Records
    this.butaw = 100.0,
    this.daddyNet = 700.0,
    this.trikeGas = 150.0,
  });

  final DateTime date;
  final double totalStaffWages;
  final double butaw;
  final double daddyNet;
  final double trikeGas;

  double get totalDailyOverhead => totalStaffWages + butaw + daddyNet + trikeGas;
}
