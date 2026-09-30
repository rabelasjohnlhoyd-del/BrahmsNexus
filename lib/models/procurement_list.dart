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
    String? id,
    String? name,
    double? price,
    bool? isPaid,
  }) {
    return ProcurementItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'isPaid': isPaid,
    };
  }

  factory ProcurementItem.fromMap(Map<String, dynamic> map) {
    return ProcurementItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      isPaid: map['isPaid'] as bool? ?? false,
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
    String? id,
    String? title,
    List<ProcurementItem>? items,
  }) {
    return ProcurementGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory ProcurementGroup.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return ProcurementGroup(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      items: rawItems
          .map((i) => ProcurementItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}
