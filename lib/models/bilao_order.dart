/// Bilao package sizes and their prices, as stated by the client:
/// Small ₱750, Medium ₱950, Large ₱1300.
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
        return 750;
      case BilaoSize.medium:
        return 950;
      case BilaoSize.large:
        return 1300;
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
    this.preparationStatus = PreparationStatus.pending,
    this.deliveryStatus = DeliveryStatus.forDelivery,
  });

  final String id;
  final String customerName;
  final String contactNumber;
  final BilaoSize size;
  final int quantity;
  final DateTime scheduledDateTime;
  final PreparationStatus preparationStatus;
  final DeliveryStatus deliveryStatus;

  double get totalAmount => size.price * quantity;

  BilaoOrder copyWith({
    PreparationStatus? preparationStatus,
    DeliveryStatus? deliveryStatus,
  }) {
    return BilaoOrder(
      id: id,
      customerName: customerName,
      contactNumber: contactNumber,
      size: size,
      quantity: quantity,
      scheduledDateTime: scheduledDateTime,
      preparationStatus: preparationStatus ?? this.preparationStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }
}
