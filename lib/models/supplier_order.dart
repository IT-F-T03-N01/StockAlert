import 'dart:convert';

class SupplierOrderItem {
  final String barcode;
  final String name;
  final int quantity;
  final double unitPrice;

  const SupplierOrderItem({
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory SupplierOrderItem.fromMap(Map<String, dynamic> map) {
    return SupplierOrderItem(
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unitPrice'] as num).toDouble(),
    );
  }
}

class SupplierOrder {
  final int? id;
  final String supplierName;
  final DateTime orderDate;
  final String status; // "Pending" or "Received"
  final List<SupplierOrderItem> items;
  final double totalAmount;

  const SupplierOrder({
    this.id,
    required this.supplierName,
    required this.orderDate,
    required this.status,
    required this.items,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'supplierName': supplierName,
      'orderDate': orderDate.toIso8601String(),
      'status': status,
      'itemsJson': jsonEncode(items.map((i) => i.toMap()).toList()),
      'totalAmount': totalAmount,
    };
  }

  factory SupplierOrder.fromMap(Map<String, dynamic> map) {
    final list = jsonDecode(map['itemsJson'] as String) as List<dynamic>;
    final parsedItems = list
        .map((x) => SupplierOrderItem.fromMap(x as Map<String, dynamic>))
        .toList();

    return SupplierOrder(
      id: map['id'] as int?,
      supplierName: map['supplierName'] as String,
      orderDate: DateTime.parse(map['orderDate'] as String),
      status: map['status'] as String,
      items: parsedItems,
      totalAmount: (map['totalAmount'] as num).toDouble(),
    );
  }

  SupplierOrder copyWith({
    int? id,
    String? supplierName,
    DateTime? orderDate,
    String? status,
    List<SupplierOrderItem>? items,
    double? totalAmount,
  }) {
    return SupplierOrder(
      id: id ?? this.id,
      supplierName: supplierName ?? this.supplierName,
      orderDate: orderDate ?? this.orderDate,
      status: status ?? this.status,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
