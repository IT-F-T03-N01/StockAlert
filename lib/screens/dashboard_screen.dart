import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/medicine.dart';
import '../models/supplier_order.dart';
import '../main.dart';

class DashboardScreen extends StatelessWidget {
  final List<Medicine> inventory;
  final List<SupplierOrder> supplierOrders;
  final String username;
  final VoidCallback onNavigateToInventory;
  final VoidCallback onNavigateToScanner;
  final VoidCallback onNavigateToSupplier;
  final VoidCallback onNavigateToExpiry;
  final VoidCallback onAddMedicine;

  const DashboardScreen({
    super.key,
    required this.inventory,
    required this.supplierOrders,
    required this.username,
    required this.onNavigateToInventory,
    required this.onNavigateToScanner,
    required this.onNavigateToSupplier,
    required this.onNavigateToExpiry,
    required this.onAddMedicine,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatCurrency(double value) {
    final wholePart = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < wholePart.length; i++) {
      if (i > 0 && (wholePart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(wholePart[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final totalUnits = inventory.fold<int>(0, (sum, item) => sum + item.quantity);
    final lowStockCount = inventory.where((m) => m.isLowStock).length;
    final expiringSoonCount = inventory.where((m) => m.daysToExpiry > 0 && m.daysToExpiry <= 90).length;
    final pendingOrders = supplierOrders.where((o) => o.status == 'Pending').length;
    final totalValue = inventory.fold<double>(0, (sum, item) => sum + item.totalValue);
    final categoryCount = inventory.map((m) => m.category).toSet().length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              decoration: const BoxDecoration(
                color: StockAlertApp.primaryTeal,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting, style: GoogleFonts.manrope(color: const Color(0xFF9FE1CB), fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(username,
                              style: GoogleFonts.manrope(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total inventory value',
                            style: GoogleFonts.manrope(color: const Color(0xFF9FE1CB), fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('GHS ${_formatCurrency(totalValue)}',
                            style: GoogleFonts.manrope(
                                color: StockAlertApp.accentGold, fontSize: 26, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Across $categoryCount categories',
                            style: GoogleFonts.manrope(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      GestureDetector(
                        onTap: onNavigateToInventory,
                        child: _StatTile(icon: Icons.medication_outlined, label: 'Medicines', value: '$totalUnits', color: const Color(0xFF0F6E56)),
                      ),
                      GestureDetector(
                        onTap: onNavigateToInventory,
                        child: _StatTile(icon: Icons.warning_amber_rounded, label: 'Low Stock', value: '$lowStockCount', color: const Color(0xFF993C1D)),
                      ),
                      GestureDetector(
                        onTap: onNavigateToExpiry,
                        child: _StatTile(icon: Icons.schedule, label: 'Expiring Soon', value: '$expiringSoonCount', color: const Color(0xFF854F0B)),
                      ),
                      GestureDetector(
                        onTap: onNavigateToSupplier,
                        child: _StatTile(icon: Icons.local_shipping_outlined, label: 'Pending Orders', value: '$pendingOrders', color: const Color(0xFF185FA5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Quick Actions',
                      style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onNavigateToScanner,
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: const Text('Scan Barcode'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onAddMedicine,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Medicine'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onNavigateToSupplier,
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('New Order'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.manrope(fontSize: 19, fontWeight: FontWeight.w600, color: color)),
          Text(label, style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}