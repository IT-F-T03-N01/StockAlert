import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';

/// Frontend-only inventory state: everything lives in memory for the life
/// of the app run. No persistence, no backend. Seeded with a few sample
/// products/batches so the UI has something to show immediately.
class InventoryProvider extends ChangeNotifier {
  final _uuid = const Uuid();

  final List<Product> _products = [];
  final List<Batch> _batches = [];

  List<Product> get products => List.unmodifiable(_products);
  List<Batch> get batches => List.unmodifiable(_batches);

  InventoryProvider() {
    _seedSampleData();
  }

  void _seedSampleData() {
    final amoxicillin = Product(
      id: _uuid.v4(),
      name: 'Amoxicillin 500mg',
      barcode: '8901030875021',
      category: 'Antibiotics',
      manufacturer: 'Cipla',
      unit: 'box',
      unitPrice: 4.50,
      reorderLevel: 20,
    );
    final paracetamol = Product(
      id: _uuid.v4(),
      name: 'Paracetamol 500mg',
      barcode: '8901030875038',
      category: 'Analgesics',
      manufacturer: 'GSK',
      unit: 'box',
      unitPrice: 1.20,
      reorderLevel: 30,
    );
    _products.addAll([amoxicillin, paracetamol]);

    _batches.addAll([
      Batch(
        id: _uuid.v4(),
        productId: amoxicillin.id,
        lotNumber: 'AMX-2024-011',
        expiryDate: DateTime.now().add(const Duration(days: 15)),
        quantity: 12,
        receivedDate: DateTime.now().subtract(const Duration(days: 90)),
      ),
      Batch(
        id: _uuid.v4(),
        productId: paracetamol.id,
        lotNumber: 'PCM-2023-044',
        expiryDate: DateTime.now().subtract(const Duration(days: 5)),
        quantity: 8,
        receivedDate: DateTime.now().subtract(const Duration(days: 200)),
      ),
      Batch(
        id: _uuid.v4(),
        productId: paracetamol.id,
        lotNumber: 'PCM-2025-002',
        expiryDate: DateTime.now().add(const Duration(days: 200)),
        quantity: 40,
        receivedDate: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ]);
  }

  int totalQuantityFor(String productId) => _batches
      .where((b) => b.productId == productId)
      .fold(0, (sum, b) => sum + b.quantity);

  List<Batch> batchesFor(String productId) =>
      _batches.where((b) => b.productId == productId).toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  List<Batch> get expiredBatches =>
      _batches.where((b) => b.isExpired && b.quantity > 0).toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  List<Batch> get expiringSoonBatches =>
      _batches.where((b) => b.isExpiringSoon && b.quantity > 0).toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  List<Product> get lowStockProducts => _products
      .where((p) => totalQuantityFor(p.id) <= p.reorderLevel)
      .toList();

  Product? findByBarcode(String barcode) {
    try {
      return _products.firstWhere((p) => p.barcode == barcode);
    } catch (_) {
      return null;
    }
  }

  Future<void> addProduct(Product product) async {
    _products.add(product);
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i != -1) _products[i] = product;
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> addBatch({
    required String productId,
    required String lotNumber,
    required DateTime expiryDate,
    required int quantity,
    String? supplierId,
  }) async {
    _batches.add(Batch(
      id: _uuid.v4(),
      productId: productId,
      lotNumber: lotNumber,
      expiryDate: expiryDate,
      quantity: quantity,
      receivedDate: DateTime.now(),
      supplierId: supplierId,
    ));
    notifyListeners();
  }

  /// Reduce stock (e.g. dispensed or sold), oldest-expiry-first (FEFO).
  Future<void> consumeStock(String productId, int quantity) async {
    var remaining = quantity;
    final relevant = batchesFor(productId).where((b) => b.quantity > 0);
    for (final batch in relevant) {
      if (remaining <= 0) break;
      final take = remaining >= batch.quantity ? batch.quantity : remaining;
      final i = _batches.indexWhere((b) => b.id == batch.id);
      _batches[i] = batch.copyWith(quantity: batch.quantity - take);
      remaining -= take;
    }
    notifyListeners();
  }

  Future<void> deleteBatch(String id) async {
    _batches.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  Future<void> removeExpiredBatch(String id) async => deleteBatch(id);
}
