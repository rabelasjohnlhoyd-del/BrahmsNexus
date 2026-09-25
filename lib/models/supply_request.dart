enum SupplyRequestStatus {
  pending,
  replied,
  fulfilled;

  String get label {
    switch (this) {
      case SupplyRequestStatus.pending:
        return 'Pending';
      case SupplyRequestStatus.replied:
        return 'Replied';
      case SupplyRequestStatus.fulfilled:
        return 'Fulfilled';
    }
  }
}

class SupplyRequest {
  const SupplyRequest({
    required this.id,
    required this.itemName,
    required this.requestedBy,
    required this.requestedById,
    required this.createdAt,
    this.status = SupplyRequestStatus.pending,
    this.ownerReply,
    this.repliedAt,
  });

  final String id;
  final String itemName;
  final String requestedBy;
  final String requestedById;
  final DateTime createdAt;
  final SupplyRequestStatus status;
  final String? ownerReply;
  final DateTime? repliedAt;

  bool get isPending => status == SupplyRequestStatus.pending;

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'requestedBy': requestedBy,
      'requestedById': requestedById,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'ownerReply': ownerReply,
      'repliedAt': repliedAt?.toIso8601String(),
    };
  }

  factory SupplyRequest.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parsedCreated;
    if (map['createdAt'] != null) {
      if (map['createdAt'] is String) {
        parsedCreated = DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now();
      } else {
        parsedCreated = DateTime.now();
      }
    } else {
      parsedCreated = DateTime.now();
    }

    DateTime? parsedReplied;
    if (map['repliedAt'] != null && map['repliedAt'] is String) {
      parsedReplied = DateTime.tryParse(map['repliedAt'] as String);
    }

    final statusStr = map['status'] as String? ?? 'pending';
    final status = SupplyRequestStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => SupplyRequestStatus.pending,
    );

    return SupplyRequest(
      id: docId ?? (map['id']?.toString() ?? ''),
      itemName: map['itemName'] as String? ?? '',
      requestedBy: map['requestedBy'] as String? ?? '',
      requestedById: map['requestedById'] as String? ?? '',
      createdAt: parsedCreated,
      status: status,
      ownerReply: map['ownerReply'] as String?,
      repliedAt: parsedReplied,
    );
  }

  SupplyRequest copyWith({
    String? id,
    String? itemName,
    String? requestedBy,
    String? requestedById,
    DateTime? createdAt,
    SupplyRequestStatus? status,
    String? ownerReply,
    DateTime? repliedAt,
  }) {
    return SupplyRequest(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedById: requestedById ?? this.requestedById,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      ownerReply: ownerReply ?? this.ownerReply,
      repliedAt: repliedAt ?? this.repliedAt,
    );
  }
}
