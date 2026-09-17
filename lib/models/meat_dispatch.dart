/// Record of meat pieces dispatched from the Main Warehouse to a specific branch.
/// Contains the 3 portion sizes:
/// - 250 grams = Regular (pcs)
/// - 300 grams = Medium (pcs)
/// - 400 grams = B1T1 (pcs)
class MeatDispatch {
  const MeatDispatch({
    required this.id,
    required this.destinationBranchId,
    required this.destinationBranchName,
    this.regular250gPcs = 0,
    this.medium300gPcs = 0,
    this.b1t1_400gPcs = 0,
    this.mayoPcs = 0,
    this.styroPcs = 0,
    this.toyoPcs = 0,
    this.status = 'pending', // 'pending' | 'delivered'
    required this.createdAt,
    this.deliveredAt,
    this.driverName,
  });

  final String id;
  final String destinationBranchId;
  final String destinationBranchName;

  // Pieces per meat portion size
  final int regular250gPcs; // 250 grams (Regular)
  final int medium300gPcs;  // 300 grams (Medium)
  final int b1t1_400gPcs;   // 400 grams (B1T1)

  // Supplies
  final int mayoPcs;
  final int styroPcs;
  final int toyoPcs;

  final String status;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final String? driverName;

  int get totalMeatPcs => regular250gPcs + medium300gPcs + b1t1_400gPcs;
  int get totalPcs => totalMeatPcs;

  bool get isDelivered => status == 'delivered';

  /// Summary description for display in lists
  String get itemsSummary {
    final parts = <String>[];
    if (regular250gPcs > 0) parts.add('$regular250gPcs pcs 250g');
    if (medium300gPcs > 0) parts.add('$medium300gPcs pcs 300g');
    if (b1t1_400gPcs > 0) parts.add('$b1t1_400gPcs pcs B1T1');
    if (mayoPcs > 0) parts.add('$mayoPcs Mayo');
    if (styroPcs > 0) parts.add('$styroPcs Styro');
    if (toyoPcs > 0) parts.add('$toyoPcs Toyo');
    if (parts.isEmpty) return '0 items';
    return parts.join(', ');
  }

  MeatDispatch copyWith({
    String? id,
    String? destinationBranchId,
    String? destinationBranchName,
    int? regular250gPcs,
    int? medium300gPcs,
    int? b1t1_400gPcs,
    int? mayoPcs,
    int? styroPcs,
    int? toyoPcs,
    String? status,
    DateTime? createdAt,
    DateTime? deliveredAt,
    String? driverName,
  }) {
    return MeatDispatch(
      id: id ?? this.id,
      destinationBranchId: destinationBranchId ?? this.destinationBranchId,
      destinationBranchName: destinationBranchName ?? this.destinationBranchName,
      regular250gPcs: regular250gPcs ?? this.regular250gPcs,
      medium300gPcs: medium300gPcs ?? this.medium300gPcs,
      b1t1_400gPcs: b1t1_400gPcs ?? this.b1t1_400gPcs,
      mayoPcs: mayoPcs ?? this.mayoPcs,
      styroPcs: styroPcs ?? this.styroPcs,
      toyoPcs: toyoPcs ?? this.toyoPcs,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      driverName: driverName ?? this.driverName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'destinationBranchId': destinationBranchId,
      'destinationBranchName': destinationBranchName,
      'regular250gPcs': regular250gPcs,
      'medium300gPcs': medium300gPcs,
      'b1t1_400gPcs': b1t1_400gPcs,
      'mayoPcs': mayoPcs,
      'styroPcs': styroPcs,
      'toyoPcs': toyoPcs,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'driverName': driverName,
    };
  }

  factory MeatDispatch.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parsedCreatedAt;
    if (map['createdAt'] != null) {
      if (map['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now();
      } else {
        parsedCreatedAt = DateTime.now();
      }
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime? parsedDeliveredAt;
    if (map['deliveredAt'] != null && map['deliveredAt'] is String) {
      parsedDeliveredAt = DateTime.tryParse(map['deliveredAt'] as String);
    }

    return MeatDispatch(
      id: docId ?? (map['id']?.toString() ?? ''),
      destinationBranchId: map['destinationBranchId']?.toString() ?? '',
      destinationBranchName: map['destinationBranchName']?.toString() ?? '',
      regular250gPcs: (map['regular250gPcs'] as num?)?.toInt() ?? 0,
      medium300gPcs: (map['medium300gPcs'] as num?)?.toInt() ?? 0,
      b1t1_400gPcs: (map['b1t1_400gPcs'] as num?)?.toInt() ?? 0,
      mayoPcs: (map['mayoPcs'] as num?)?.toInt() ?? 0,
      styroPcs: (map['styroPcs'] as num?)?.toInt() ?? 0,
      toyoPcs: (map['toyoPcs'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'pending',
      createdAt: parsedCreatedAt,
      deliveredAt: parsedDeliveredAt,
      driverName: map['driverName']?.toString(),
    );
  }
}
