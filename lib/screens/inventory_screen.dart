import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../models/product.dart';
import 'product_form_screen.dart';
import 'product_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final filtered = inv.products.where((p) {
      final q = _query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, barcode, or category',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No products found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final qty = inv.totalQuantityFor(p.id);
                      final low = qty <= p.reorderLevel;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(product: p)),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: low
                                ? Colors.orange.shade100
                                : Colors.teal.shade50,
                            child: Icon(Icons.medication_outlined,
                                color: low ? Colors.orange.shade800 : Colors.teal),
                          ),
                          title: Text(p.name),
                          subtitle: Text('${p.category} · Barcode: ${p.barcode}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$qty ${p.unit}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: low ? Colors.orange.shade800 : null)),
                              if (low)
                                const Text('Low stock',
                                    style: TextStyle(fontSize: 11, color: Colors.orange)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addProduct',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
