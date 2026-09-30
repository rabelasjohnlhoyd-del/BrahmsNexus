import 'procurement_list.dart';

class FinancialPeriod {
  FinancialPeriod({
    required this.id,
    required this.monthName,
    required this.year,
    this.notes = '',
    this.roiInvestment = 165000.0,
    int? regular250gCount,
    this.medium300gCount = 0,
    this.b1t1400gCount = 0,
    int? productionCookingSessions,
    this.productionCookDailyRate = 1100.0,
    this.productionCutterDailyRate = 1100.0,
    this.driverWorkingDays = 25,
    this.driverDailyWage = 650.0,
    this.branchCookLaborTotal = 0.0,
    this.dailyButawRate = 100.0,
    this.dailyDaddyNetRate = 700.0,
    this.dailyTrikeGasRate = 150.0,
    this.dailyOverheads = const [],
    this.procurementGroups = const [],
    int? productionPcs,
    int? productionLaborDays,
  })  : regular250gCount = regular250gCount ?? (productionPcs ?? 0),
        productionCookingSessions =
            productionCookingSessions ?? (productionLaborDays ?? 0);

  final String id;
  final String monthName;
  final int year;
  final String notes;
  final double roiInvestment; // Capital / ROI target for the month

  // Meat output quantities (pulled from Warehouse cooking sessions)
  final int regular250gCount;
  final int medium300gCount;
  final int b1t1400gCount;

  // Production staff labor settings
  final int productionCookingSessions;
  final double productionCookDailyRate;
  final double productionCutterDailyRate;

  // Driver labor settings
  final int driverWorkingDays;
  final double driverDailyWage;

  // Branch Cook labor (from Sales & Payroll)
  final double branchCookLaborTotal;

  // Fixed daily store overheads
  final double dailyButawRate;
  final double dailyDaddyNetRate;
  final double dailyTrikeGasRate;

  final List<DailyOverheadEntry> dailyOverheads;
  final List<ProcurementGroup> procurementGroups;

  // --- PRODUCTION PCS ---
  int get totalProductionPcs =>
      regular250gCount + medium300gCount + b1t1400gCount;

  int get productionPcs => totalProductionPcs;
  int get productionLaborDays => productionCookingSessions;

  // --- GROSS REVENUE ---
  // Regular 250G x 130 | Medium 300G x 160 | B1T1 400G x 210
  double get regular250gRevenue => regular250gCount * 130.0;
  double get medium300gRevenue => medium300gCount * 160.0;
  double get b1t1400gRevenue => b1t1400gCount * 210.0;

  double get grossRevenue {
    final computed = regular250gRevenue + medium300gRevenue + b1t1400gRevenue;
    if (computed > 0) return computed;
    return totalProductionPcs * 130.0;
  }

  // --- EXPENSES BREAKDOWN ---
  double get totalProcurementCost =>
      procurementGroups.fold(0, (sum, g) => sum + g.total);

  double get totalProductionLaborCost =>
      productionCookingSessions *
      (productionCookDailyRate + productionCutterDailyRate);

  double get totalDriverLaborCost => driverWorkingDays * driverDailyWage;

  double get totalDailyFixedOverheads =>
      driverWorkingDays *
      (dailyButawRate + dailyDaddyNetRate + dailyTrikeGasRate);

  double get accumulatedStoreCost =>
      totalDriverLaborCost +
      effectiveBranchCookLabor +
      totalDailyFixedOverheads;

  double get effectiveBranchCookLabor {
    if (branchCookLaborTotal > 0) return branchCookLaborTotal;
    return dailyOverheads.fold(0, (sum, e) => sum + e.totalStaffWages);
  }

  double get totalExpenses =>
      totalProcurementCost +
      totalProductionLaborCost +
      totalDriverLaborCost +
      effectiveBranchCookLabor +
      totalDailyFixedOverheads;

  // --- BOTTOM LINE ---
  /// Operating Profit (Gross Revenue - Total Expenses)
  double get operatingProfit => grossRevenue - totalExpenses;

  /// Net Mav (Tunay na Kita ni Sir Mav pagkatapos mabawi ang ininvest na kapital).
  /// Naka-0 ito hangga't hindi pa nababawi ang buong puhunan para sa buwang ito.
  double get netMav {
    final profit = operatingProfit;
    if (profit <= roiInvestment) return 0.0;
    return profit - roiInvestment;
  }

  /// Halaga na kailangan pang kitain bago mabawi ang buong puhunan
  double get capitalRemainingToRecover {
    final profit = operatingProfit;
    if (profit >= roiInvestment) return 0.0;
    return roiInvestment - profit;
  }

  // Difference between Operating Profit and Invested Capital
  double get roiDifference => operatingProfit - roiInvestment;
  bool get isRoiAchieved => operatingProfit >= roiInvestment;

  int get workingDaysCount =>
      driverWorkingDays > 0 ? driverWorkingDays : dailyOverheads.length;

  FinancialPeriod copyWith({
    String? id,
    String? monthName,
    int? year,
    String? notes,
    double? roiInvestment,
    int? regular250gCount,
    int? medium300gCount,
    int? b1t1400gCount,
    int? productionCookingSessions,
    double? productionCookDailyRate,
    double? productionCutterDailyRate,
    int? driverWorkingDays,
    double? driverDailyWage,
    double? branchCookLaborTotal,
    double? dailyButawRate,
    double? dailyDaddyNetRate,
    double? dailyTrikeGasRate,
    List<DailyOverheadEntry>? dailyOverheads,
    List<ProcurementGroup>? procurementGroups,
  }) {
    return FinancialPeriod(
      id: id ?? this.id,
      monthName: monthName ?? this.monthName,
      year: year ?? this.year,
      notes: notes ?? this.notes,
      roiInvestment: roiInvestment ?? this.roiInvestment,
      regular250gCount: regular250gCount ?? this.regular250gCount,
      medium300gCount: medium300gCount ?? this.medium300gCount,
      b1t1400gCount: b1t1400gCount ?? this.b1t1400gCount,
      productionCookingSessions:
          productionCookingSessions ?? this.productionCookingSessions,
      productionCookDailyRate:
          productionCookDailyRate ?? this.productionCookDailyRate,
      productionCutterDailyRate:
          productionCutterDailyRate ?? this.productionCutterDailyRate,
      driverWorkingDays: driverWorkingDays ?? this.driverWorkingDays,
      driverDailyWage: driverDailyWage ?? this.driverDailyWage,
      branchCookLaborTotal:
          branchCookLaborTotal ?? this.branchCookLaborTotal,
      dailyButawRate: dailyButawRate ?? this.dailyButawRate,
      dailyDaddyNetRate: dailyDaddyNetRate ?? this.dailyDaddyNetRate,
      dailyTrikeGasRate: dailyTrikeGasRate ?? this.dailyTrikeGasRate,
      dailyOverheads: dailyOverheads ?? this.dailyOverheads,
      procurementGroups: procurementGroups ?? this.procurementGroups,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monthName': monthName,
      'year': year,
      'notes': notes,
      'roiInvestment': roiInvestment,
      'regular250gCount': regular250gCount,
      'medium300gCount': medium300gCount,
      'b1t1400gCount': b1t1400gCount,
      'productionCookingSessions': productionCookingSessions,
      'productionCookDailyRate': productionCookDailyRate,
      'productionCutterDailyRate': productionCutterDailyRate,
      'driverWorkingDays': driverWorkingDays,
      'driverDailyWage': driverDailyWage,
      'branchCookLaborTotal': branchCookLaborTotal,
      'dailyButawRate': dailyButawRate,
      'dailyDaddyNetRate': dailyDaddyNetRate,
      'dailyTrikeGasRate': dailyTrikeGasRate,
      'procurementGroups': procurementGroups.map((g) => g.toMap()).toList(),
      'dailyOverheads': dailyOverheads.map((o) => o.toMap()).toList(),
    };
  }

  factory FinancialPeriod.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawGroups = map['procurementGroups'] as List<dynamic>? ?? [];
    final rawOverheads = map['dailyOverheads'] as List<dynamic>? ?? [];

    return FinancialPeriod(
      id: docId ?? map['id']?.toString() ?? '',
      monthName: map['monthName']?.toString() ?? 'Current Month',
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      notes: map['notes']?.toString() ?? '',
      roiInvestment: (map['roiInvestment'] as num?)?.toDouble() ?? 165000.0,
      regular250gCount: (map['regular250gCount'] as num?)?.toInt() ?? 0,
      medium300gCount: (map['medium300gCount'] as num?)?.toInt() ?? 0,
      b1t1400gCount: (map['b1t1400gCount'] as num?)?.toInt() ?? 0,
      productionCookingSessions:
          (map['productionCookingSessions'] as num?)?.toInt() ?? 0,
      productionCookDailyRate:
          (map['productionCookDailyRate'] as num?)?.toDouble() ?? 1100.0,
      productionCutterDailyRate:
          (map['productionCutterDailyRate'] as num?)?.toDouble() ?? 1100.0,
      driverWorkingDays: (map['driverWorkingDays'] as num?)?.toInt() ?? 25,
      driverDailyWage: (map['driverDailyWage'] as num?)?.toDouble() ?? 650.0,
      branchCookLaborTotal:
          (map['branchCookLaborTotal'] as num?)?.toDouble() ?? 0.0,
      dailyButawRate: (map['dailyButawRate'] as num?)?.toDouble() ?? 100.0,
      dailyDaddyNetRate:
          (map['dailyDaddyNetRate'] as num?)?.toDouble() ?? 700.0,
      dailyTrikeGasRate:
          (map['dailyTrikeGasRate'] as num?)?.toDouble() ?? 150.0,
      procurementGroups: rawGroups
          .map((g) => ProcurementGroup.fromMap(Map<String, dynamic>.from(g as Map)))
          .toList(),
      dailyOverheads: rawOverheads
          .map((o) => DailyOverheadEntry.fromMap(Map<String, dynamic>.from(o as Map)))
          .toList(),
    );
  }
}

class DailyOverheadEntry {
  DailyOverheadEntry({
    required this.date,
    required this.totalStaffWages,
    this.butaw = 100.0,
    this.daddyNet = 700.0,
    this.trikeGas = 150.0,
  });

  final DateTime date;
  final double totalStaffWages;
  final double butaw;
  final double daddyNet;
  final double trikeGas;

  double get totalDailyOverhead =>
      totalStaffWages + butaw + daddyNet + trikeGas;

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'totalStaffWages': totalStaffWages,
      'butaw': butaw,
      'daddyNet': daddyNet,
      'trikeGas': trikeGas,
    };
  }

  factory DailyOverheadEntry.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }
    return DailyOverheadEntry(
      date: parsedDate,
      totalStaffWages: (map['totalStaffWages'] as num?)?.toDouble() ?? 0.0,
      butaw: (map['butaw'] as num?)?.toDouble() ?? 100.0,
      daddyNet: (map['daddyNet'] as num?)?.toDouble() ?? 700.0,
      trikeGas: (map['trikeGas'] as num?)?.toDouble() ?? 150.0,
    );
  }
}
