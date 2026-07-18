import 'package:flutter/material.dart';

class Medicine {
  final int? id;
  final String name;
  final String genericName;
  final String barcode;
  final String batchNumber;
  final int quantity;
  final int minQuantity;
  final DateTime expiryDate;
  final String dosageForm;
  final String location;
  final double price;
  final String supplierName; // Added supplierName for supplier tracking

  const Medicine({
    this.id,
    required this.name,
    required this.genericName,
    required this.barcode,
    required this.batchNumber,
    required this.quantity,
    required this.minQuantity,
    required this.expiryDate,
    required this.dosageForm,
    required this.location,
    required this.price,
    this.supplierName = 'PharmaCorp Global', // Default supplier
  });

  /// Computes remaining lifespans using date difference logic
  int get daysToExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  /// Categorize states instantly: <=0 days (Expired), <=90 days (Near Expiry), >90 days (Healthy)
  String get statusLabel {
    final days = daysToExpiry;
    if (days <= 0) return 'Expired';
    if (days <= 90) return 'Near Expiry';
    return 'Healthy';
  }

  /// Map status labels to standard visual theme colors
  Color get statusColor {
    final days = daysToExpiry;
    if (days <= 0) {
      return const Color(0xFFEF4444); // Expired - Red
    }
    if (days <= 90) {
      return const Color(0xFFF97316); // Near Expiry - Orange
    }
    return const Color(0xFF10B981); // Healthy - Emerald Green
  }

  bool get isDeficient => quantity < minQuantity;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'genericName': genericName,
      'barcode': barcode,
      'batchNumber': batchNumber,
      'quantity': quantity,
      'minQuantity': minQuantity,
      'expiryDate': expiryDate.toIso8601String(),
      'dosageForm': dosageForm,
      'location': location,
      'price': price,
      'supplierName': supplierName,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String,
      genericName: map['genericName'] as String,
      barcode: map['barcode'] as String,
      batchNumber: map['batchNumber'] as String? ?? 'B-GENERIC',
      quantity: map['quantity'] as int,
      minQuantity: map['minQuantity'] as int,
      expiryDate: DateTime.parse(map['expiryDate'] as String),
      dosageForm: map['dosageForm'] as String,
      location: map['location'] as String,
      price: (map['price'] as num).toDouble(),
      supplierName: map['supplierName'] as String? ?? 'PharmaCorp Global',
    );
  }

  Medicine copyWith({
    int? id,
    String? name,
    String? genericName,
    String? barcode,
    String? batchNumber,
    int? quantity,
    int? minQuantity,
    DateTime? expiryDate,
    String? dosageForm,
    String? location,
    double? price,
    String? supplierName,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      barcode: barcode ?? this.barcode,
      batchNumber: batchNumber ?? this.batchNumber,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      expiryDate: expiryDate ?? this.expiryDate,
      dosageForm: dosageForm ?? this.dosageForm,
      location: location ?? this.location,
      price: price ?? this.price,
      supplierName: supplierName ?? this.supplierName,
    );
  }
}
