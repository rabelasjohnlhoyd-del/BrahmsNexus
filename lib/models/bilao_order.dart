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
  outForDelivery,
  delivered,
  completed;

  String get label {
    switch (this) {
      case DeliveryStatus.forDelivery:
        return 'For Delivery';
      case DeliveryStatus.outForDelivery:
        return 'Out For Delivery';
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

/// Order channel/source confirmed by client:
/// - branchOrder: Customer placed order directly via branch walk-in / branch phone.
///   Branch Cook gets the commission (+₱62, +₱87, +₱125) once completed.
/// - directToOwner: Customer placed order directly with Owner / Main Office.
///   Branch Cook gets ₱0 commission.
enum BilaoOrderChannel {
  branchOrder,
  directToOwner;

  String get label {
    switch (this) {
      case BilaoOrderChannel.branchOrder:
        return 'Branch Order';
      case BilaoOrderChannel.directToOwner:
        return 'Direct to Owner';
    }
  }

  String get commissionBadge {
    switch (this) {
      case BilaoOrderChannel.branchOrder:
        return 'With Cook Commission';
      case BilaoOrderChannel.directToOwner:
        return 'No Commission';
    }
  }
}

/// Payment method chosen by the customer.
enum PaymentMethod {
  cash,
  gcash;

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.gcash:
        return 'GCash';
    }
  }
}

/// Whether the customer is paying in full now or just leaving a down payment.
enum PaymentType {
  fullPayment,
  downPayment;

  String get label {
    switch (this) {
      case PaymentType.fullPayment:
        return 'Full Payment';
      case PaymentType.downPayment:
        return 'Down Payment';
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
    this.orderChannel = BilaoOrderChannel.branchOrder,
    this.pickupBranchId,
    this.pickupBranchName,
    this.notes,
    this.unitPrice,
    this.depositAmount = 0.0,
    this.createdAt,
    this.preparationStatus = PreparationStatus.pending,
    this.deliveryStatus = DeliveryStatus.forDelivery,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentType = PaymentType.fullPayment,
    this.gcashRefNumber,
    this.gcashAmount,
    this.gcashProofUrl,
    this.gcashVerified = false,
    this.gcashVerifiedAt,
    this.gcashVerifiedBy,
    this.deliveryProofUrl,
    this.isCancelled = false,
    this.cancellationReason,
  });

  final String id;
  final String customerName;
  final String contactNumber;
  final BilaoSize size;
  final int quantity;
  final DateTime scheduledDateTime;
  final String deliveryAddress;
  final BilaoFulfillmentType fulfillmentType;
  final BilaoOrderChannel orderChannel;
  final String? pickupBranchId;
  final String? pickupBranchName;
  final String? notes;
  final double? unitPrice;
  final double depositAmount;
  final DateTime? createdAt;
  final PreparationStatus preparationStatus;
  final DeliveryStatus deliveryStatus;

  // ── Payment ──────────────────────────────────────────────────────────────────
  /// How the customer is paying (Cash or GCash).
  final PaymentMethod paymentMethod;

  /// Whether the customer paid in full now or left a down payment.
  final PaymentType paymentType;

  // ── GCash-specific ───────────────────────────────────────────────────────────
  /// GCash reference number extracted from the receipt (OCR or manual).
  final String? gcashRefNumber;

  /// Amount shown on the GCash receipt.
  final double? gcashAmount;

  /// Supabase Storage public URL of the GCash receipt photo.
  final String? gcashProofUrl;

  /// True once Owner/Admin has verified the GCash payment.
  final bool gcashVerified;

  /// Timestamp when Owner verified.
  final DateTime? gcashVerifiedAt;

  /// Name of Owner/Admin who verified.
  final String? gcashVerifiedBy;

  // ── Delivery proof ───────────────────────────────────────────────────────────
  /// Supabase Storage public URL of the driver's delivery proof photo.
  final String? deliveryProofUrl;

  // ── Cancellation ─────────────────────────────────────────────────────────────
  final bool isCancelled;
  final String? cancellationReason;

  double get effectiveUnitPrice => unitPrice ?? size.price;
  double get totalAmount => effectiveUnitPrice * quantity;
  double get remainingBalance => (totalAmount - depositAmount).clamp(0.0, totalAmount);

  /// Cook commission is ONLY awarded if the order originated from the Branch.
  /// Direct orders to Owner yield ₱0 commission to the branch cook.
  double get commissionAmount =>
      orderChannel == BilaoOrderChannel.branchOrder ? (size.commission * quantity) : 0.0;

  bool get hasCookCommission => orderChannel == BilaoOrderChannel.branchOrder;

  bool get isBranchPickup => fulfillmentType == BilaoFulfillmentType.branchPickup;

  /// True if this GCash order is still waiting for owner verification.
  bool get isPendingGcashVerification =>
      paymentMethod == PaymentMethod.gcash && !gcashVerified && !isCancelled;

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
    BilaoOrderChannel? orderChannel,
    String? pickupBranchId,
    String? pickupBranchName,
    String? notes,
    double? unitPrice,
    double? depositAmount,
    DateTime? createdAt,
    PreparationStatus? preparationStatus,
    DeliveryStatus? deliveryStatus,
    PaymentMethod? paymentMethod,
    PaymentType? paymentType,
    String? gcashRefNumber,
    double? gcashAmount,
    String? gcashProofUrl,
    bool? gcashVerified,
    DateTime? gcashVerifiedAt,
    String? gcashVerifiedBy,
    String? deliveryProofUrl,
    bool? isCancelled,
    String? cancellationReason,
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
      orderChannel: orderChannel ?? this.orderChannel,
      pickupBranchId: pickupBranchId ?? this.pickupBranchId,
      pickupBranchName: pickupBranchName ?? this.pickupBranchName,
      notes: notes ?? this.notes,
      unitPrice: unitPrice ?? this.unitPrice,
      depositAmount: depositAmount ?? this.depositAmount,
      createdAt: createdAt ?? this.createdAt,
      preparationStatus: preparationStatus ?? this.preparationStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentType: paymentType ?? this.paymentType,
      gcashRefNumber: gcashRefNumber ?? this.gcashRefNumber,
      gcashAmount: gcashAmount ?? this.gcashAmount,
      gcashProofUrl: gcashProofUrl ?? this.gcashProofUrl,
      gcashVerified: gcashVerified ?? this.gcashVerified,
      gcashVerifiedAt: gcashVerifiedAt ?? this.gcashVerifiedAt,
      gcashVerifiedBy: gcashVerifiedBy ?? this.gcashVerifiedBy,
      deliveryProofUrl: deliveryProofUrl ?? this.deliveryProofUrl,
      isCancelled: isCancelled ?? this.isCancelled,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}
