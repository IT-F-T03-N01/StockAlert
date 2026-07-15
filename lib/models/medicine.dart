import 'package:flutter/material.dart';

class Medicine {
  final String id;
  final String name;
  final String category;
  int quantity;
  final int minStockThreshold;
  final String barcode;
  final DateTime expiryDate;
  final String batchNumber;
  final double price;

  Medicine({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.minStockThreshold,
    required this.barcode,
    required this.expiryDate,
    required this.batchNumber,
    required this.price,
  });

  int get daysToExpiry => expiryDate.difference(DateTime.now()).inDays;

  String get status {
    int days = daysToExpiry;
    if (days <= 0) return 'Expired';
    if (days <= 90) return 'Near Expiry';
    return 'Good';
  }

  Color get statusColor {
    if (daysToExpiry <= 0) return Colors.red;
    if (daysToExpiry <= 90) return Colors.orange;
    return Colors.green;
  }

  bool get isLowStock => quantity <= minStockThreshold;

  double get totalValue => price * quantity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'quantity': quantity,
        'minStockThreshold': minStockThreshold,
        'barcode': barcode,
        'expiryDate': expiryDate.toIso8601String(),
        'batchNumber': batchNumber,
        'price': price,
      };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        quantity: json['quantity'],
        minStockThreshold: json['minStockThreshold'],
        barcode: json['barcode'],
        expiryDate: DateTime.parse(json['expiryDate']),
        batchNumber: json['batchNumber'],
        price: (json['price'] as num).toDouble(),
      );
}