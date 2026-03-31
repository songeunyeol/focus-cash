class StoreItem {
  final String id;
  final String name;
  final int cost;
  final int iconCode;
  final bool isActive;
  final int order;

  const StoreItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.iconCode,
    this.isActive = true,
    this.order = 0,
  });

  factory StoreItem.fromMap(Map<String, dynamic> map) => StoreItem(
        id: map['id'] as String,
        name: map['name'] as String,
        cost: map['cost'] as int,
        iconCode: map['iconCode'] as int,
        isActive: map['isActive'] as bool? ?? true,
        order: map['order'] as int? ?? 0,
      );
}
