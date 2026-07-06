class Product {
  final String id;
  final String name;
  final String barcode;
  final String category;
  final String? manufacturer;
  final String unit; // e.g. box, bottle, strip
  final double unitPrice;
  final int reorderLevel; // trigger low-stock alert below this qty
  final String? supplierId; // preferred supplier

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    this.manufacturer,
    required this.unit,
    required this.unitPrice,
    required this.reorderLevel,
    this.supplierId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'category': category,
        'manufacturer': manufacturer,
        'unit': unit,
        'unitPrice': unitPrice,
        'reorderLevel': reorderLevel,
        'supplierId': supplierId,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        name: map['name'] as String,
        barcode: map['barcode'] as String,
        category: map['category'] as String,
        manufacturer: map['manufacturer'] as String?,
        unit: map['unit'] as String,
        unitPrice: (map['unitPrice'] as num).toDouble(),
        reorderLevel: map['reorderLevel'] as int,
        supplierId: map['supplierId'] as String?,
      );

  Product copyWith({
    String? name,
    String? barcode,
    String? category,
    String? manufacturer,
    String? unit,
    double? unitPrice,
    int? reorderLevel,
    String? supplierId,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      manufacturer: manufacturer ?? this.manufacturer,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      supplierId: supplierId ?? this.supplierId,
    );
  }
}

/// A batch represents a specific lot of stock for a product with its own
/// expiry date and quantity. A product can have many batches over time.
class Batch {
  final String id;
  final String productId;
  final String lotNumber;
  final DateTime expiryDate;
  final int quantity;
  final DateTime receivedDate;
  final String? supplierId;

  Batch({
    required this.id,
    required this.productId,
    required this.lotNumber,
    required this.expiryDate,
    required this.quantity,
    required this.receivedDate,
    this.supplierId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'lotNumber': lotNumber,
        'expiryDate': expiryDate.toIso8601String(),
        'quantity': quantity,
        'receivedDate': receivedDate.toIso8601String(),
        'supplierId': supplierId,
      };

  factory Batch.fromMap(Map<String, dynamic> map) => Batch(
        id: map['id'] as String,
        productId: map['productId'] as String,
        lotNumber: map['lotNumber'] as String,
        expiryDate: DateTime.parse(map['expiryDate'] as String),
        quantity: map['quantity'] as int,
        receivedDate: DateTime.parse(map['receivedDate'] as String),
        supplierId: map['supplierId'] as String?,
      );

  Batch copyWith({int? quantity}) => Batch(
        id: id,
        productId: productId,
        lotNumber: lotNumber,
        expiryDate: expiryDate,
        quantity: quantity ?? this.quantity,
        receivedDate: receivedDate,
        supplierId: supplierId,
      );

  int get daysUntilExpiry =>
      expiryDate.difference(DateTime.now()).inDays;

  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
}
