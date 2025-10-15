class InventoryItem {
  final String id;
  final String barcode;
  final String name;
  final String unit;
  final double quantity;
  final double averagePrice;
  final double totalAmount;
  final DateTime date;
  final String department;

  InventoryItem({
    required this.id,
    required this.barcode,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.averagePrice,
    required this.totalAmount,
    required this.date,
    required this.department,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'averagePrice': averagePrice,
      'totalAmount': totalAmount,
      'date': date.toIso8601String(),
      'department': department,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] ?? '',
      barcode: json['barcode'] ?? '',
      name: json['name'] ?? '',
      unit: json['unit'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      averagePrice: (json['averagePrice'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      department: json['department'] ?? '',
    );
  }

  InventoryItem copyWith({
    String? id,
    String? barcode,
    String? name,
    String? unit,
    double? quantity,
    double? averagePrice,
    double? totalAmount,
    DateTime? date,
    String? department,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      averagePrice: averagePrice ?? this.averagePrice,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      department: department ?? this.department,
    );
  }
}
