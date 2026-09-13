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

/// A confirmed advance/special bilao order recorded by the Owner after
/// receiving it via Messenger/phone (customers never order directly
/// in-app — this is out of scope per the requirements doc).
class BilaoOrder {
  const BilaoOrder({
    required this.id,
    required this.customerName,
    required this.contactNumber,
    required this.size,
    required this.quantity,
    required this.scheduledDateTime,
    this.deliveryAddress = '',
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
  final PreparationStatus preparationStatus;
  final DeliveryStatus deliveryStatus;

  double get totalAmount => size.price * quantity;

  BilaoOrder copyWith({
    String? id,
    String? customerName,
    String? contactNumber,
    BilaoSize? size,
    int? quantity,
    DateTime? scheduledDateTime,
    String? deliveryAddress,
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
      preparationStatus: preparationStatus ?? this.preparationStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }
}
