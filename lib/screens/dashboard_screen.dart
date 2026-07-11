import 'package:flutter/material.dart';
import '../models/medicine.dart';

class DashboardScreen extends StatelessWidget {
  final List<Medicine> inventory;
  final VoidCallback onNavigateToInventory;
  final VoidCallback onNavigateToSupplier;

  const DashboardScreen({
    super.key,
    required this.inventory,
    required this.onNavigateToInventory,
    required this.onNavigateToSupplier,
  });

  @override
  Widget build(BuildContext context) {
    int expiredCount = inventory.where((m) => m.daysToExpiry <= 0).length;
    int nearExpiryCount = inventory.where((m) => m.daysToExpiry > 0 && m.daysToExpiry <= 90).length;
    int lowStockCount = inventory.where((m) => m.isLowStock).length;
    int totalItems = inventory.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacy Control Panel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operational Health Summary',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard('Expired Batches', expiredCount.toString(), Colors.red),
                _buildStatCard('Near Expiry (90d)', nearExpiryCount.toString(), Colors.orange),
                _buildStatCard('Stock Deficiencies', lowStockCount.toString(), Colors.amber),
                _buildStatCard('Total Units Maintained', totalItems.toString(), Colors.blue),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.blue),
              title: const Text('Manage Drug Repositories'),
              subtitle: const Text('View layout, track lots, and scan components'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: onNavigateToInventory,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.local_shipping, color: Colors.green),
              title: const Text('Procurement & Supplier Pipelines'),
              subtitle: const Text('Review restock requests and open purchase orders'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: onNavigateToSupplier,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}