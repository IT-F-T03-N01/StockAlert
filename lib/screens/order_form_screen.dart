import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/auth_provider.dart';
import 'order_detail_screen.dart';

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  String? _supplierId;
  bool _creating = false;

  Future<void> _create() async {
    if (_supplierId == null) return;
    setState(() => _creating = true);
    final orderProvider = context.read<OrderProvider>();
    final auth = context.read<AuthProvider>();
    final inv = context.read<InventoryProvider>();

    final orderId = await orderProvider.createOrder(
      supplierId: _supplierId!,
      createdByUserId: auth.currentUser!.id,
    );

    // Pre-fill lines for low-stock products from this supplier.
    final suggestions = orderProvider.suggestReorderLines(inv);
    for (final line in suggestions) {
      final product = inv.products.firstWhere((p) => p.id == line.productId);
      if (product.supplierId == _supplierId) {
        await orderProvider.addItem(
          orderId: orderId,
          productId: product.id,
          quantity: line.suggestedQty,
          unitCost: product.unitPrice,
        );
      }
    }

    if (!mounted) return;
    setState(() => _creating = false);
    final order = orderProvider.orders.firstWhere((o) => o.id == orderId);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = context.watch<SupplierProvider>().suppliers;

    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select a supplier to order from:'),
            const SizedBox(height: 12),
            if (suppliers.isEmpty)
              const Text('No suppliers found. Add one in the Suppliers tab first.'),
            ...suppliers.map((s) => RadioListTile<String>(
                  title: Text(s.name),
                  subtitle: Text(s.contactPerson),
                  value: s.id,
                  groupValue: _supplierId,
                  onChanged: (v) => setState(() => _supplierId = v),
                )),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_supplierId == null || _creating) ? null : _create,
              child: _creating
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Order (auto-fills low stock items)'),
            ),
          ],
        ),
      ),
    );
  }
}
