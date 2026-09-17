import 'branch.dart';

/// Represents the itemized meat inventory in pieces (pcs) for a branch:
/// - 250 grams = Regular
/// - 300 grams = Medium
/// - 400 grams = B1T1 (Buy 1 Take 1)
///
/// Default regular daily load across all 6 branches:
/// - 20 pcs of 250g (Regular)
/// - 10 pcs of 300g (Medium)
/// - 10 pcs of 400g (B1T1)
/// Total: 40 pcs
class BranchMeatStock {
  const BranchMeatStock({
    required this.branchId,
    required this.branchName,
    required this.date,
    this.regular250gTotal = 20,
    this.regular250gRemaining = 20,
    this.medium300gTotal = 10,
    this.medium300gRemaining = 10,
    this.b1t1_400gTotal = 10,
    this.b1t1_400gRemaining = 10,
    this.mayoTotal = 40,
    this.mayoRemaining = 40,
    this.styroTotal = 40,
    this.styroRemaining = 40,
    this.toyoTotal = 10,
    this.toyoRemaining = 10,
  });

  final String branchId;
  final String branchName;
  final DateTime date;

  // 250 grams = Regular
  final int regular250gTotal;
  final int regular250gRemaining;

  // 300 grams = Medium
  final int medium300gTotal;
  final int medium300gRemaining;

  // 400 grams = B1T1
  final int b1t1_400gTotal;
  final int b1t1_400gRemaining;

  // Supplies: Mayo, Styro, Toyo
  final int mayoTotal;
  final int mayoRemaining;

  final int styroTotal;
  final int styroRemaining;

  final int toyoTotal;
  final int toyoRemaining;

  int get totalAllocatedPcs => regular250gTotal + medium300gTotal + b1t1_400gTotal;
  int get totalRemainingPcs => regular250gRemaining + medium300gRemaining + b1t1_400gRemaining;
  int get totalUsedPcs => totalAllocatedPcs - totalRemainingPcs;

  /// Flags low stock when remaining meat is less than 20% of total
  bool get isRunningLow => totalAllocatedPcs > 0 && (totalRemainingPcs / totalAllocatedPcs) < 0.20;

  BranchMeatStock copyWith({
    String? branchId,
    String? branchName,
    DateTime? date,
    int? regular250gTotal,
    int? regular250gRemaining,
    int? medium300gTotal,
    int? medium300gRemaining,
    int? b1t1_400gTotal,
    int? b1t1_400gRemaining,
    int? mayoTotal,
    int? mayoRemaining,
    int? styroTotal,
    int? styroRemaining,
    int? toyoTotal,
    int? toyoRemaining,
  }) {
    return BranchMeatStock(
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      date: date ?? this.date,
      regular250gTotal: regular250gTotal ?? this.regular250gTotal,
      regular250gRemaining: regular250gRemaining ?? this.regular250gRemaining,
      medium300gTotal: medium300gTotal ?? this.medium300gTotal,
      medium300gRemaining: medium300gRemaining ?? this.medium300gRemaining,
      b1t1_400gTotal: b1t1_400gTotal ?? this.b1t1_400gTotal,
      b1t1_400gRemaining: b1t1_400gRemaining ?? this.b1t1_400gRemaining,
      mayoTotal: mayoTotal ?? this.mayoTotal,
      mayoRemaining: mayoRemaining ?? this.mayoRemaining,
      styroTotal: styroTotal ?? this.styroTotal,
      styroRemaining: styroRemaining ?? this.styroRemaining,
      toyoTotal: toyoTotal ?? this.toyoTotal,
      toyoRemaining: toyoRemaining ?? this.toyoRemaining,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'branchName': branchName,
      'date': date.toIso8601String(),
      'regular250gTotal': regular250gTotal,
      'regular250gRemaining': regular250gRemaining,
      'medium300gTotal': medium300gTotal,
      'medium300gRemaining': medium300gRemaining,
      'b1t1_400gTotal': b1t1_400gTotal,
      'b1t1_400gRemaining': b1t1_400gRemaining,
      'mayoTotal': mayoTotal,
      'mayoRemaining': mayoRemaining,
      'styroTotal': styroTotal,
      'styroRemaining': styroRemaining,
      'toyoTotal': toyoTotal,
      'toyoRemaining': toyoRemaining,
    };
  }

  factory BranchMeatStock.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parsedDate;
    if (map['date'] != null) {
      if (map['date'] is String) {
        parsedDate = DateTime.tryParse(map['date'] as String) ?? DateTime.now();
      } else {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return BranchMeatStock(
      branchId: id ?? (map['branchId']?.toString() ?? ''),
      branchName: map['branchName']?.toString() ?? '',
      date: parsedDate,
      regular250gTotal: (map['regular250gTotal'] as num?)?.toInt() ?? 20,
      regular250gRemaining: (map['regular250gRemaining'] as num?)?.toInt() ?? 20,
      medium300gTotal: (map['medium300gTotal'] as num?)?.toInt() ?? 10,
      medium300gRemaining: (map['medium300gRemaining'] as num?)?.toInt() ?? 10,
      b1t1_400gTotal: (map['b1t1_400gTotal'] as num?)?.toInt() ?? 10,
      b1t1_400gRemaining: (map['b1t1_400gRemaining'] as num?)?.toInt() ?? 10,
      mayoTotal: (map['mayoTotal'] as num?)?.toInt() ?? 40,
      mayoRemaining: (map['mayoRemaining'] as num?)?.toInt() ?? 40,
      styroTotal: (map['styroTotal'] as num?)?.toInt() ?? 40,
      styroRemaining: (map['styroRemaining'] as num?)?.toInt() ?? 40,
      toyoTotal: (map['toyoTotal'] as num?)?.toInt() ?? 10,
      toyoRemaining: (map['toyoRemaining'] as num?)?.toInt() ?? 10,
    );
  }

  /// Creates default initial stock for a branch:
  /// - 250G Regular: 20 pcs
  /// - 300G Medium: 10 pcs
  /// - 400G B1T1: 10 pcs
  /// - Mayo: 40
  /// - Styro: 40
  /// - Toyo: 10
  factory BranchMeatStock.defaultForBranch(Branch branch) {
    return BranchMeatStock(
      branchId: branch.id,
      branchName: branch.fullName,
      date: DateTime.now(),
      regular250gTotal: 20,
      regular250gRemaining: 20,
      medium300gTotal: 10,
      medium300gRemaining: 10,
      b1t1_400gTotal: 10,
      b1t1_400gRemaining: 10,
      mayoTotal: 40,
      mayoRemaining: 40,
      styroTotal: 40,
      styroRemaining: 40,
      toyoTotal: 10,
      toyoRemaining: 10,
    );
  }
}
