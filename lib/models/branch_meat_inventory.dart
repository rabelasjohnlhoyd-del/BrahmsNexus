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
    this.isClosed = false,
    int? baseRegular250g,
    int? baseMedium300g,
    int? baseB1t1_400g,
    int? baseMayo,
    int? baseStyro,
    int? baseToyo,
    this.regLowAlertSent = false,
    this.medLowAlertSent = false,
    this.b1t1LowAlertSent = false,
    this.mayoLowAlertSent = false,
    this.toyoLowAlertSent = false,
    this.styroLowAlertSent = false,
    this.lowStockAlertDate,
    this.spoilagePenalty = 0.0,
  })  : baseRegular250g = baseRegular250g ?? (regular250gTotal > 0 ? regular250gTotal : 20),
        baseMedium300g = baseMedium300g ?? (medium300gTotal > 0 ? medium300gTotal : 10),
        baseB1t1_400g = baseB1t1_400g ?? (b1t1_400gTotal > 0 ? b1t1_400gTotal : 10),
        baseMayo = baseMayo ?? (mayoTotal > 0 ? mayoTotal : 40),
        baseStyro = baseStyro ?? (styroTotal > 0 ? styroTotal : 40),
        baseToyo = baseToyo ?? (toyoTotal > 0 ? toyoTotal : 10);

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

  // Branch open/closed status & baseline allocation memory
  final bool isClosed;
  final int baseRegular250g;
  final int baseMedium300g;
  final int baseB1t1_400g;
  final int baseMayo;
  final int baseStyro;
  final int baseToyo;

  final bool regLowAlertSent;
  final bool medLowAlertSent;
  final bool b1t1LowAlertSent;
  final bool mayoLowAlertSent;
  final bool toyoLowAlertSent;
  final bool styroLowAlertSent;
  final String? lowStockAlertDate;
  final double spoilagePenalty;

  int get totalAllocatedPcs => regular250gTotal + medium300gTotal + b1t1_400gTotal;
  int get totalRemainingPcs => regular250gRemaining + medium300gRemaining + b1t1_400gRemaining;
  int get totalUsedPcs => totalAllocatedPcs - totalRemainingPcs;

  /// Flags low stock when remaining meat is less than 20% of total (only if branch is open)
  bool get isRunningLow => !isClosed && totalAllocatedPcs > 0 && (totalRemainingPcs / totalAllocatedPcs) < 0.20;

  /// Returns a new BranchMeatStock marked as CLOSED with all active stock set to 0,
  /// while preserving baseline configured allocation.
  BranchMeatStock toClosed() {
    return copyWith(
      isClosed: true,
      regular250gTotal: 0,
      regular250gRemaining: 0,
      medium300gTotal: 0,
      medium300gRemaining: 0,
      b1t1_400gTotal: 0,
      b1t1_400gRemaining: 0,
      mayoTotal: 0,
      mayoRemaining: 0,
      styroTotal: 0,
      styroRemaining: 0,
      toyoTotal: 0,
      toyoRemaining: 0,
    );
  }

  /// Returns a new BranchMeatStock marked as OPEN with stock restored to its configured baseline.
  BranchMeatStock toOpen() {
    final reg = baseRegular250g > 0 ? baseRegular250g : 20;
    final med = baseMedium300g > 0 ? baseMedium300g : 10;
    final b1t1 = baseB1t1_400g > 0 ? baseB1t1_400g : 10;
    final mayo = baseMayo > 0 ? baseMayo : 40;
    final styro = baseStyro > 0 ? baseStyro : 40;
    final toyo = baseToyo > 0 ? baseToyo : 10;
    return copyWith(
      isClosed: false,
      regular250gTotal: reg,
      regular250gRemaining: reg,
      medium300gTotal: med,
      medium300gRemaining: med,
      b1t1_400gTotal: b1t1,
      b1t1_400gRemaining: b1t1,
      mayoTotal: mayo,
      mayoRemaining: mayo,
      styroTotal: styro,
      styroRemaining: styro,
      toyoTotal: toyo,
      toyoRemaining: toyo,
    );
  }

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
    bool? isClosed,
    int? baseRegular250g,
    int? baseMedium300g,
    int? baseB1t1_400g,
    int? baseMayo,
    int? baseStyro,
    int? baseToyo,
    bool? regLowAlertSent,
    bool? medLowAlertSent,
    bool? b1t1LowAlertSent,
    bool? mayoLowAlertSent,
    bool? toyoLowAlertSent,
    bool? styroLowAlertSent,
    String? lowStockAlertDate,
    double? spoilagePenalty,
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
      isClosed: isClosed ?? this.isClosed,
      baseRegular250g: baseRegular250g ?? this.baseRegular250g,
      baseMedium300g: baseMedium300g ?? this.baseMedium300g,
      baseB1t1_400g: baseB1t1_400g ?? this.baseB1t1_400g,
      baseMayo: baseMayo ?? this.baseMayo,
      baseStyro: baseStyro ?? this.baseStyro,
      baseToyo: baseToyo ?? this.baseToyo,
      regLowAlertSent: regLowAlertSent ?? this.regLowAlertSent,
      medLowAlertSent: medLowAlertSent ?? this.medLowAlertSent,
      b1t1LowAlertSent: b1t1LowAlertSent ?? this.b1t1LowAlertSent,
      mayoLowAlertSent: mayoLowAlertSent ?? this.mayoLowAlertSent,
      toyoLowAlertSent: toyoLowAlertSent ?? this.toyoLowAlertSent,
      styroLowAlertSent: styroLowAlertSent ?? this.styroLowAlertSent,
      lowStockAlertDate: lowStockAlertDate ?? this.lowStockAlertDate,
      spoilagePenalty: spoilagePenalty ?? this.spoilagePenalty,
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
      'isClosed': isClosed,
      'baseRegular250g': baseRegular250g,
      'baseMedium300g': baseMedium300g,
      'baseB1t1_400g': baseB1t1_400g,
      'baseMayo': baseMayo,
      'baseStyro': baseStyro,
      'baseToyo': baseToyo,
      'regLowAlertSent': regLowAlertSent,
      'medLowAlertSent': medLowAlertSent,
      'b1t1LowAlertSent': b1t1LowAlertSent,
      'mayoLowAlertSent': mayoLowAlertSent,
      'toyoLowAlertSent': toyoLowAlertSent,
      'styroLowAlertSent': styroLowAlertSent,
      'lowStockAlertDate': lowStockAlertDate,
      'spoilagePenalty': spoilagePenalty,
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

    final isClosed = map['isClosed'] as bool? ?? false;
    final regTotal = (map['regular250gTotal'] as num?)?.toInt() ?? 20;
    final medTotal = (map['medium300gTotal'] as num?)?.toInt() ?? 10;
    final b1t1Total = (map['b1t1_400gTotal'] as num?)?.toInt() ?? 10;
    final mayoTotal = (map['mayoTotal'] as num?)?.toInt() ?? 40;
    final styroTotal = (map['styroTotal'] as num?)?.toInt() ?? 40;
    final toyoTotal = (map['toyoTotal'] as num?)?.toInt() ?? 10;

    return BranchMeatStock(
      branchId: id ?? (map['branchId']?.toString() ?? ''),
      branchName: map['branchName']?.toString() ?? '',
      date: parsedDate,
      regular250gTotal: regTotal,
      regular250gRemaining: (map['regular250gRemaining'] as num?)?.toInt() ?? regTotal,
      medium300gTotal: medTotal,
      medium300gRemaining: (map['medium300gRemaining'] as num?)?.toInt() ?? medTotal,
      b1t1_400gTotal: b1t1Total,
      b1t1_400gRemaining: (map['b1t1_400gRemaining'] as num?)?.toInt() ?? b1t1Total,
      mayoTotal: mayoTotal,
      mayoRemaining: (map['mayoRemaining'] as num?)?.toInt() ?? mayoTotal,
      styroTotal: styroTotal,
      styroRemaining: (map['styroRemaining'] as num?)?.toInt() ?? styroTotal,
      toyoTotal: toyoTotal,
      toyoRemaining: (map['toyoRemaining'] as num?)?.toInt() ?? toyoTotal,
      isClosed: isClosed,
      baseRegular250g: (map['baseRegular250g'] as num?)?.toInt() ?? (isClosed ? 20 : (regTotal > 0 ? regTotal : 20)),
      baseMedium300g: (map['baseMedium300g'] as num?)?.toInt() ?? (isClosed ? 10 : (medTotal > 0 ? medTotal : 10)),
      baseB1t1_400g: (map['baseB1t1_400g'] as num?)?.toInt() ?? (isClosed ? 10 : (b1t1Total > 0 ? b1t1Total : 10)),
      baseMayo: (map['baseMayo'] as num?)?.toInt() ?? (isClosed ? 40 : (mayoTotal > 0 ? mayoTotal : 40)),
      baseStyro: (map['baseStyro'] as num?)?.toInt() ?? (isClosed ? 40 : (styroTotal > 0 ? styroTotal : 40)),
      baseToyo: (map['baseToyo'] as num?)?.toInt() ?? (isClosed ? 10 : (toyoTotal > 0 ? toyoTotal : 10)),
      regLowAlertSent: map['regLowAlertSent'] as bool? ?? false,
      medLowAlertSent: map['medLowAlertSent'] as bool? ?? false,
      b1t1LowAlertSent: map['b1t1LowAlertSent'] as bool? ?? false,
      mayoLowAlertSent: map['mayoLowAlertSent'] as bool? ?? false,
      toyoLowAlertSent: map['toyoLowAlertSent'] as bool? ?? false,
      styroLowAlertSent: map['styroLowAlertSent'] as bool? ?? false,
      lowStockAlertDate: map['lowStockAlertDate']?.toString(),
      spoilagePenalty: (map['spoilagePenalty'] as num?)?.toDouble() ?? 0.0,
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
      isClosed: false,
      baseRegular250g: 20,
      baseMedium300g: 10,
      baseB1t1_400g: 10,
      baseMayo: 40,
      baseStyro: 40,
      baseToyo: 10,
    );
  }
}
