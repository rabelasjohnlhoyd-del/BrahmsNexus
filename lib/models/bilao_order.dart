/// Bilao package sizes, prices, and cook commissions confirmed by client:
/// - Small: 10 Pax | 1.25 kg | ₱650 | Commission: ₱62
/// - Medium: 15 Pax | 1.75 kg | ₱900 | Commission: ₱87
/// - Large: 20 Pax | 2.5 kg | ₱1,300 | Commission: ₱125
enum BilaoSize {
  small,
  medium,
  large;

  String get label {
    switch (this) {
      case BilaoSize.small:
        return 'Small';
      case BilaoSize.medium:
        return 'Medium';
      case BilaoSize.large:
        return 'Large';
    }
  }

  double get price {
    switch (this) {
      case BilaoSize.small:
        return 650;
      case BilaoSize.medium:
        return 900;
      case BilaoSize.large:
        return 1300;
    }
  }

  double get commission {
    switch (this) {
      case BilaoSize.small:
        return 62;
      case BilaoSize.medium:
        return 87;
      case BilaoSize.large:
        return 125;
    }
  }

  int get pax {
    switch (this) {
      case BilaoSize.small:
        return 10;
      case BilaoSize.medium:
        return 15;
      case BilaoSize.large:
        return 20;
    }
  }

  String get weightLabel {
    switch (this) {
      case BilaoSize.small:
        return '1 Kilo and 250 Grams';
      case BilaoSize.medium:
        return '1 Kilo and 750 Grams';
      case BilaoSize.large:
        return '2 Kilos and 500 Grams';
    }
  }
}

enum PreparationStatus {
  pending,
  preparing,
  ready;

  String get label {
    switch (this) {
      case PreparationStatus.pending:
        return 'Pending';
      case PreparationStatus.preparing:
        return 'Preparing';
      case PreparationStatus.ready:
        return 'Ready';
    }
  }
}

enum DeliveryStatus {
  forDelivery,
  delivered,
  completed;

  String get label {
    switch (this) {
      case DeliveryStatus.forDelivery:
        return 'For Delivery';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.completed:
        return 'Completed';
    }
  }
}

enum BilaoFulfillmentType {
  branchPickup,
  directDelivery;

  String get label {
    switch (this) {
      case BilaoFulfillmentType.branchPickup:
        return 'Branch Pickup';
      case BilaoFulfillmentType.directDelivery:
        return 'Direct Delivery';
    }
  }
}

/// A confirmed advance/special bilao order recorded by the Owner or Staff after
/// receiving it via Messenger/phone or in-store walk-in.
class BilaoOrder {
  const BilaoOrder({
    required this.id,
    required this.customerName,
    required this.contactNumber,
    required this.size,
    required this.quantity,
    required this.scheduledDateTime,
    this.deliveryAddress = '',
    this.fulfillmentType = BilaoFulfillmentType.directDelivery,
    this.pickupBranchId,
    this.pickupBranchName,
    this.notes,
    this.unitPrice,
    this.createdAt,
    this.preparationStatus = PreparationStatus.pending,
    this.deliveryStatus = DeliveryStatus.forDelivery,
  });

  final String id;
  final String customerName;
  final String contactNumber;
  final BilaoSize size;
  final int quantity;
  final DateTime scheduledDateTime;
  final String deliveryAddress;
  final BilaoFulfillmentType fulfillmentType;
  final String? pickupBranchId;
  final String? pickupBranchName;
  final String? notes;
  final double? unitPrice;
  final DateTime? createdAt;
  final PreparationStatus preparationStatus;
  final DeliveryStatus deliveryStatus;

  double get effectiveUnitPrice => unitPrice ?? size.price;
  double get totalAmount => effectiveUnitPrice * quantity;

  bool get isBranchPickup => fulfillmentType == BilaoFulfillmentType.branchPickup;

  String get destinationDisplay {
    if (isBranchPickup) {
      return (pickupBranchName != null && pickupBranchName!.isNotEmpty)
          ? 'Pickup: $pickupBranchName'
          : 'Branch Pickup';
    }
    return deliveryAddress.isNotEmpty ? deliveryAddress : 'Direct Delivery';
  }

  BilaoOrder copyWith({
    String? id,
    String? customerName,
    String? contactNumber,
    BilaoSize? size,
    int? quantity,
    DateTime? scheduledDateTime,
    String? deliveryAddress,
    BilaoFulfillmentType? fulfillmentType,
    String? pickupBranchId,
    String? pickupBranchName,
    String? notes,
    double? unitPrice,
    DateTime? createdAt,
    PreparationStatus? preparationStatus,
    DeliveryStatus? deliveryStatus,
  }) {
    return BilaoOrder(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      contactNumber: contactNumber ?? this.contactNumber,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      fulfillmentType: fulfillmentType ?? this.fulfillmentType,
      pickupBranchId: pickupBranchId ?? this.pickupBranchId,
      pickupBranchName: pickupBranchName ?? this.pickupBranchName,
      notes: notes ?? this.notes,
      unitPrice: unitPrice ?? this.unitPrice,
      createdAt: createdAt ?? this.createdAt,
      preparationStatus: preparationStatus ?? this.preparationStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }
}
