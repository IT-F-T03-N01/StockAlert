import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/inventory_provider.dart';
import '../models/purchase_order.dart';
import '../utils/theme.dart';
import 'order_form_screen.dart';
import 'order_detail_screen.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.draft:
        return Colors.grey;
      case OrderStatus.submitted:
        return AppTheme.warning;
      case OrderStatus.received:
        return AppTheme.success;
      case OrderStatus.cancelled:
        return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().orders;
    final suppliers = context.watch<SupplierProvider>();
    final inv = context.watch<InventoryProvider>();
    final lowStockCount = inv.lowStockProducts.length;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (lowStockCount > 0)
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.trending_down, color: AppTheme.warning),
                title: Text('$lowStockCount product(s) at or below reorder level'),
                subtitle: const Text('Tap "New Order" below to restock a supplier'),
              ),
            ),
          const SizedBox(height: 8),
          if (orders.isEmpty) const Center(child: Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text('No purchase orders yet'),
          )),
          ...orders.map((o) {
            final supplier = suppliers.byId(o.supplierId);
            final total = context.read<OrderProvider>().orderTotal(o.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)),
                ),
                leading: CircleAvatar(
                  backgroundColor: _statusColor(o.status).withOpacity(0.15),
                  child: Icon(Icons.receipt_long, color: _statusColor(o.status)),
                ),
                title: Text(supplier?.name ?? 'Unknown supplier'),
                subtitle: Text(DateFormat.yMMMd().format(o.createdDate)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(o.status.label, style: TextStyle(color: _statusColor(o.status), fontSize: 12)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'newOrder',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const OrderFormScreen())),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Order'),
      ),
    );
  }
}
