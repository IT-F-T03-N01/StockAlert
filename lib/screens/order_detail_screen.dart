import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/supplier_provider.dart';
import '../models/purchase_order.dart';

class OrderDetailScreen extends StatelessWidget {
  final PurchaseOrder order;
  const OrderDetailScreen({super.key, required this.order});

  Future<void> _addItemDialog(BuildContext context) async {
    final inv = context.read<InventoryProvider>();
    String? productId;
    final qtyController = TextEditingController();
    final costController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Order Line'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: productId,
                decoration: const InputDecoration(labelText: 'Product'),
                items: inv.products
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    productId = v;
                    final product = inv.products.firstWhere((p) => p.id == v);
                    costController.text = product.unitPrice.toString();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                decoration: const InputDecoration(labelText: 'Unit cost'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyController.text) ?? 0;
                final cost = double.tryParse(costController.text) ?? 0;
                if (productId == null || qty <= 0) return;
                await context.read<OrderProvider>().addItem(
                      orderId: order.id,
                      productId: productId!,
                      quantity: qty,
                      unitCost: cost,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _receiveFlow(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();
    final inv = context.read<InventoryProvider>();
    final items = orderProvider.itemsFor(order.id);
    final lineInfo = <String, ReceivedLineInfo>{};

    for (final item in items) {
      final product = inv.products.firstWhere((p) => p.id == item.productId);
      final lotController = TextEditingController();
      DateTime? expiry;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text('Receiving: ${product.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Quantity ordered: ${item.quantity} ${product.unit}'),
                const SizedBox(height: 12),
                TextField(
                  controller: lotController,
                  decoration: const InputDecoration(labelText: 'Lot number'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expiry == null
                      ? 'Select expiry date'
                      : 'Expires: ${DateFormat.yMMMd().format(expiry!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => expiry = picked);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Skip this item'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (lotController.text.isEmpty || expiry == null) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true) {
        lineInfo[item.productId] = ReceivedLineInfo(
          lotNumber: lotController.text.trim(),
          expiryDate: expiry!,
        );
      }
    }

    await orderProvider.receiveOrder(
      orderId: order.id,
      inventoryProvider: inv,
      lineInfoByProductId: lineInfo,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order received and stock updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final supplier = context.watch<SupplierProvider>().byId(order.supplierId);
    final inv = context.watch<InventoryProvider>();
    final items = orderProvider.itemsFor(order.id);
    final currentOrder = orderProvider.orders.firstWhere(
      (o) => o.id == order.id,
      orElse: () => order,
    );

    return Scaffold(
      appBar: AppBar(title: Text(supplier?.name ?? 'Order')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(label: Text(currentOrder.status.label)),
                Text('Total: \$${orderProvider.orderTotal(order.id).toStringAsFixed(2)}'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final product = inv.products.firstWhere(
                  (p) => p.id == item.productId,
                  orElse: () => inv.products.first,
                );
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Text('${item.quantity} × \$${item.unitCost.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\$${item.lineTotal.toStringAsFixed(2)}'),
                        if (currentOrder.status == OrderStatus.draft)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => orderProvider.removeItem(item.id),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (currentOrder.status == OrderStatus.draft) ...[
                  OutlinedButton.icon(
                    onPressed: () => _addItemDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Line Item'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: items.isEmpty
                          ? null
                          : () => orderProvider.updateStatus(order.id, OrderStatus.submitted),
                      child: const Text('Submit Order to Supplier'),
                    ),
                  ),
                ],
                if (currentOrder.status == OrderStatus.submitted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _receiveFlow(context),
                      icon: const Icon(Icons.inventory),
                      label: const Text('Receive Order (log lots & expiry)'),
                    ),
                  ),
                if (currentOrder.status == OrderStatus.received)
                  const Text('This order has been received and added to stock.',
                      style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
