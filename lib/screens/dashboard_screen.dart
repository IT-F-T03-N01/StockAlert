import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/theme.dart';
import 'inventory_screen.dart';
import 'scanner_screen.dart';
import 'expiry_screen.dart';
import 'supplier_screen.dart';
import 'order_screen.dart';
import 'team_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;

  static const _screens = [
    _HomeTab(),
    InventoryScreen(),
    ExpiryScreen(),
    OrderScreen(),
    SupplierScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('DLA Company Ltd'),
        actions: [
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: 'Team accounts',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TeamScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out (${auth.currentUser?.name ?? ''})',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: _screens[_tabIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.event_busy_outlined), label: 'Expiry'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'Suppliers'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final auth = context.watch<AuthProvider>();

    return RefreshIndicator(
      // No backend here — everything is in-memory, so there's nothing to
      // actually re-fetch. This just gives a satisfying pull-to-refresh feel.
      onRefresh: () => Future.delayed(const Duration(milliseconds: 400)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, ${auth.currentUser?.name ?? ''}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),

          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                label: 'Total Products',
                value: '${inv.products.length}',
                icon: Icons.inventory_2,
                color: AppTheme.primary,
              ),
              _StatCard(
                label: 'Expired Batches',
                value: '${inv.expiredBatches.length}',
                icon: Icons.dangerous_outlined,
                color: AppTheme.danger,
              ),
              _StatCard(
                label: 'Expiring ≤30 Days',
                value: '${inv.expiringSoonBatches.length}',
                icon: Icons.warning_amber_outlined,
                color: AppTheme.warning,
              ),
              _StatCard(
                label: 'Low Stock',
                value: '${inv.lowStockProducts.length}',
                icon: Icons.trending_down,
                color: Colors.blueGrey,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (inv.expiredBatches.isNotEmpty) ...[
            Text('Needs immediate attention', style: Theme.of(context).textTheme.titleMedium,),
            const SizedBox(height: 8),
            ...inv.expiredBatches.take(5).map((b) {
              final product = inv.products.firstWhere(
                (p) => p.id == b.productId,
                orElse: () => inv.products.first,
              );
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.dangerous, color: AppTheme.danger),
                  title: Text(product.name),
                  subtitle: Text('Lot ${b.lotNumber} · Expired ${-b.daysUntilExpiry} days ago · Qty ${b.quantity}'),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
