import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';
import '../models/product.dart';
import '../utils/theme.dart';
import 'product_detail_screen.dart';

class ExpiryScreen extends StatefulWidget {
  const ExpiryScreen({super.key});

  @override
  State<ExpiryScreen> createState() => _ExpiryScreenState();
}

class _ExpiryScreenState extends State<ExpiryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          tabs: [
            Tab(text: 'Expired (${inv.expiredBatches.length})'),
            Tab(text: 'Expiring Soon (${inv.expiringSoonBatches.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _BatchList(batches: inv.expiredBatches, products: inv.products),
              _BatchList(batches: inv.expiringSoonBatches, products: inv.products),
            ],
          ),
        ),
      ],
    );
  }
}

class _BatchList extends StatelessWidget {
  final List<Batch> batches;
  final List<Product> products;
  const _BatchList({required this.batches, required this.products});

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) {
      return const Center(child: Text('Nothing here — all clear'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: batches.length,
      itemBuilder: (context, i) {
        final b = batches[i];
        Product? product;
        for (final p in products) {
          if (p.id == b.productId) {
            product = p;
            break;
          }
        }
        if (product == null) return const SizedBox.shrink();
        final color = expiryColor(b.daysUntilExpiry);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product!)),
            ),
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(Icons.event_busy, color: color),
            ),
            title: Text(product.name),
            subtitle: Text(
              'Lot ${b.lotNumber} · Qty ${b.quantity} · '
              '${b.isExpired ? "Expired" : "Expires"} ${DateFormat.yMMMd().format(b.expiryDate)}',
            ),
            trailing: Text(
              b.isExpired ? '${-b.daysUntilExpiry}d ago' : '${b.daysUntilExpiry}d left',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
