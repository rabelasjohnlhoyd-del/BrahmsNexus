class ProcurementItem {
  ProcurementItem({
    required this.id,
    required this.name,
    required this.price,
    this.isPaid = false,
  });

  final String id;
  String name;
  double price;
  bool isPaid;

  ProcurementItem copyWith({
    String? name,
    double? price,
    bool? isPaid,
  }) {
    return ProcurementItem(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}

class ProcurementGroup {
  ProcurementGroup({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  String title;
  List<ProcurementItem> items;

  double get total => items.fold(0, (sum, item) => sum + item.price);

  ProcurementGroup copyWith({
    String? title,
    List<ProcurementItem>? items,
  }) {
    return ProcurementGroup(
      id: id,
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }
}
