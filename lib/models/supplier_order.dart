class SupplierOrder {
  final String orderId;
  final String supplierName;
  final String medicineName;
  final int quantityRequested;
  final DateTime orderDate;
  String status;

  SupplierOrder({
    required this.orderId,
    required this.supplierName,
    required this.medicineName,
    required this.quantityRequested,
    required this.orderDate,
    this.status = 'Pending',
  });

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'supplierName': supplierName,
        'medicineName': medicineName,
        'quantityRequested': quantityRequested,
        'orderDate': orderDate.toIso8601String(),
        'status': status,
      };

  factory SupplierOrder.fromJson(Map<String, dynamic> json) => SupplierOrder(
        orderId: json['orderId'],
        supplierName: json['supplierName'],
        medicineName: json['medicineName'],
        quantityRequested: json['quantityRequested'],
        orderDate: DateTime.parse(json['orderDate']),
        status: json['status'],
      );
}
