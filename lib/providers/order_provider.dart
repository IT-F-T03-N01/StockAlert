import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/purchase_order.dart';
import 'inventory_provider.dart';

/// Frontend-only purchase order state — in memory, no backend.
class OrderProvider extends ChangeNotifier {
  final _uuid = const Uuid();

  final List<PurchaseOrder> _orders = [];
  final List<OrderItem> _items = [];

  List<PurchaseOrder> get orders =>
      List.unmodifiable(_orders..sort((a, b) => b.createdDate.compareTo(a.createdDate)));

  List<OrderItem> itemsFor(String orderId) =>
      _items.where((i) => i.orderId == orderId).toList();

  double orderTotal(String orderId) =>
      itemsFor(orderId).fold(0.0, (sum, i) => sum + i.lineTotal);

  Future<String> createOrder({
    required String supplierId,
    required String createdByUserId,
    String? notes,
  }) async {
    final order = PurchaseOrder(
      id: _uuid.v4(),
      supplierId: supplierId,
      createdDate: DateTime.now(),
      status: OrderStatus.draft,
      createdByUserId: createdByUserId,
      notes: notes,
    );
    _orders.add(order);
    notifyListeners();
    return order.id;
  }

  Future<void> addItem({
    required String orderId,
    required String productId,
    required int quantity,
    required double unitCost,
  }) async {
    _items.add(OrderItem(
      id: _uuid.v4(),
      orderId: orderId,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
    ));
    notifyListeners();
  }

  Future<void> removeItem(String itemId) async {
    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i != -1) _orders[i] = _orders[i].copyWith(status: status);
    notifyListeners();
  }

  /// Marks an order received and creates inventory batches for each item.
  Future<void> receiveOrder({
    required String orderId,
    required InventoryProvider inventoryProvider,
    required Map<String, ReceivedLineInfo> lineInfoByProductId,
  }) async {
    final items = itemsFor(orderId);
    final order = _orders.firstWhere((o) => o.id == orderId);
    for (final item in items) {
      final info = lineInfoByProductId[item.productId];
      if (info == null) continue;
      await inventoryProvider.addBatch(
        productId: item.productId,
        lotNumber: info.lotNumber,
        expiryDate: info.expiryDate,
        quantity: item.quantity,
        supplierId: order.supplierId,
      );
    }
    await updateStatus(orderId, OrderStatus.received);
  }

  Future<void> deleteOrder(String orderId) async {
    _orders.removeWhere((o) => o.id == orderId);
    notifyListeners();
  }

  /// Suggests draft order lines for every product at/below its reorder level.
  List<({String productId, int suggestedQty})> suggestReorderLines(
      InventoryProvider inventoryProvider) {
    return inventoryProvider.lowStockProducts
        .map((p) => (
              productId: p.id,
              suggestedQty: (p.reorderLevel * 2) - inventoryProvider.totalQuantityFor(p.id),
            ))
        .where((line) => line.suggestedQty > 0)
        .toList();
  }
}

class ReceivedLineInfo {
  final String lotNumber;
  final DateTime expiryDate;
  ReceivedLineInfo({required this.lotNumber, required this.expiryDate});
}
