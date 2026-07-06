enum OrderStatus { draft, submitted, received, cancelled }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.draft:
        return 'Draft';
      case OrderStatus.submitted:
        return 'Submitted';
      case OrderStatus.received:
        return 'Received';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => OrderStatus.draft,
    );
  }
}

class PurchaseOrder {
  final String id;
  final String supplierId;
  final DateTime createdDate;
  final OrderStatus status;
  final String createdByUserId;
  final String? notes;

  PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.createdDate,
    required this.status,
    required this.createdByUserId,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplierId': supplierId,
        'createdDate': createdDate.toIso8601String(),
        'status': status.name,
        'createdByUserId': createdByUserId,
        'notes': notes,
      };

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) => PurchaseOrder(
        id: map['id'] as String,
        supplierId: map['supplierId'] as String,
        createdDate: DateTime.parse(map['createdDate'] as String),
        status: OrderStatusX.fromString(map['status'] as String),
        createdByUserId: map['createdByUserId'] as String,
        notes: map['notes'] as String?,
      );

  PurchaseOrder copyWith({OrderStatus? status, String? notes}) => PurchaseOrder(
        id: id,
        supplierId: supplierId,
        createdDate: createdDate,
        status: status ?? this.status,
        createdByUserId: createdByUserId,
        notes: notes ?? this.notes,
      );
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitCost;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitCost,
  });

  double get lineTotal => quantity * unitCost;

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'productId': productId,
        'quantity': quantity,
        'unitCost': unitCost,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        id: map['id'] as String,
        orderId: map['orderId'] as String,
        productId: map['productId'] as String,
        quantity: map['quantity'] as int,
        unitCost: (map['unitCost'] as num).toDouble(),
      );
}
