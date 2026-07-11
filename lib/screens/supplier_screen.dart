import 'package:flutter/material.dart';
import '../models/supplier_order.dart';
import '../models/medicine.dart';

class SupplierScreen extends StatefulWidget {
  final List<SupplierOrder> orders;
  final List<Medicine> inventory;
  final Function(SupplierOrder newOrder) onPlaceOrder;
  final Function(String orderId, String status) onUpdateStatus;

  const SupplierScreen({
    super.key,
    required this.orders,
    required this.inventory,
    required this.onPlaceOrder,
    required this.onUpdateStatus,
  });

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  @override
  Widget build(BuildContext context) {
    // Collect entities currently breaching minimum safe operating storage buffers
    final lowStockItems = widget.inventory.where((m) => m.isLowStock).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Procurement Control Hub')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Automated Pipeline Replenishment Suggestion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (lowStockItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('All current system parameters show safe supply quantities maintained.', style: TextStyle(color: Colors.green)),
                ),
              )
            else
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: lowStockItems.map((item) {
                      int recommendedQty = (item.minStockThreshold * 3) - item.quantity;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${item.name} (Current: ${item.quantity} / Min: ${item.minStockThreshold})')),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.shopping_cart, size: 14),
                            label: Text('Order $recommendedQty'),
                            onPressed: () {
                              final newOrder = SupplierOrder(
                                orderId: 'PO-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                                supplierName: 'Central Logistics Distributor Ltd',
                                medicineName: item.name,
                                quantityRequested: recommendedQty,
                                orderDate: DateTime.now(),
                              );
                              widget.onPlaceOrder(newOrder);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Dispatched standard purchase transaction ${newOrder.orderId}')),
                              );
                            },
                          )
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text('Active Purchase Records Pipeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: widget.orders.isEmpty
                  ? const Center(child: Text('No archival transactions currently found in pipeline state.'))
                  : ListView.builder(
                      itemCount: widget.orders.length,
                      itemBuilder: (context, index) {
                        final order = widget.orders[index];
                        return Card(
                          child: ListTile(
                            title: Text('${order.medicineName} (Units: ${order.quantityRequested})'),
                            subtitle: Text('ID: ${order.orderId}\nSupplier: ${order.supplierName}'),
                            trailing: DropdownButton<String>(
                              value: order.status,
                              items: ['Pending', 'Approved', 'Delivered'].map((status) {
                                return DropdownMenuItem(value: status, child: Text(status));
                              }).toList(),
                              onChanged: (newStatus) {
                                if (newStatus != null) {
                                  widget.onUpdateStatus(order.orderId, newStatus);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }
}