import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';
import '../providers/supplier_provider.dart';
import '../models/product.dart';
import '../utils/theme.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  Future<void> _addBatchDialog(BuildContext context) async {
    final lotController = TextEditingController();
    final qtyController = TextEditingController();
    DateTime? expiry;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Receive New Batch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lotController,
                decoration: const InputDecoration(labelText: 'Lot number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Quantity received'),
                keyboardType: TextInputType.number,
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyController.text) ?? 0;
                if (lotController.text.isEmpty || qty <= 0 || expiry == null) return;
                await context.read<InventoryProvider>().addBatch(
                      productId: product.id,
                      lotNumber: lotController.text.trim(),
                      expiryDate: expiry!,
                      quantity: qty,
                      supplierId: product.supplierId,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add Batch'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _consumeDialog(BuildContext context) async {
    final qtyController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispense / Remove Stock'),
        content: TextField(
          controller: qtyController,
          decoration: const InputDecoration(labelText: 'Quantity (oldest expiry used first)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) return;
              await context.read<InventoryProvider>().consumeStock(product.id, qty);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final supplier = context.watch<SupplierProvider>().byId(product.supplierId);
    final batches = inv.batchesFor(product.id);
    final totalQty = inv.totalQuantityFor(product.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProductFormScreen(existing: product)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Barcode', product.barcode),
                  _infoRow('Category', product.category),
                  _infoRow('Manufacturer', product.manufacturer ?? '—'),
                  _infoRow('Unit price', '\$${product.unitPrice.toStringAsFixed(2)}'),
                  _infoRow('Reorder level', '${product.reorderLevel} ${product.unit}'),
                  _infoRow('Preferred supplier', supplier?.name ?? '—'),
                  const Divider(height: 24),
                  _infoRow('Total stock on hand', '$totalQty ${product.unit}', bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addBatchDialog(context),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Receive Batch'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _consumeDialog(context),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Dispense'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Batches (${batches.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (batches.isEmpty) const Text('No batches on record'),
          ...batches.map((b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: expiryColor(b.daysUntilExpiry).withOpacity(0.15),
                    child: Icon(Icons.circle, size: 12, color: expiryColor(b.daysUntilExpiry)),
                  ),
                  title: Text('Lot ${b.lotNumber} · Qty ${b.quantity}'),
                  subtitle: Text(
                    b.isExpired
                        ? 'Expired ${DateFormat.yMMMd().format(b.expiryDate)}'
                        : 'Expires ${DateFormat.yMMMd().format(b.expiryDate)} (${b.daysUntilExpiry}d)',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => context.read<InventoryProvider>().deleteBatch(b.id),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
