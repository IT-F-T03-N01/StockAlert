import 'package:flutter/material.dart';
import '../models/medicine.dart';

class ExpiryScreen extends StatelessWidget {
  final List<Medicine> inventory;
  final Function(String id, int newQty) onQuantityChanged;
  final Function(String id, double newPrice) onPriceChanged;

  const ExpiryScreen({
    super.key,
    required this.inventory,
    required this.onQuantityChanged,
    required this.onPriceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final expired = inventory.where((m) => m.daysToExpiry <= 0).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    final expiringSoon = inventory.where((m) => m.daysToExpiry > 0 && m.daysToExpiry <= 30).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    final warning = inventory.where((m) => m.daysToExpiry > 30 && m.daysToExpiry <= 90).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return Scaffold(
      appBar: AppBar(title: const Text('Expiry Tracker')),
      body: (expired.isEmpty && expiringSoon.isEmpty && warning.isEmpty)
          ? const Center(child: Text('No expiry concerns right now. 🎉'))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if (expired.isNotEmpty) ...[
                  _SectionHeader(emoji: '⛔', label: 'Expired', color: Colors.red.shade900),
                  ...expired.map((m) => _ExpiryCard(
                        medicine: m,
                        color: Colors.red,
                        onRemoveStock: () => onQuantityChanged(m.id, 0),
                        onPriceChanged: onPriceChanged,
                      )),
                  const SizedBox(height: 16),
                ],
                if (expiringSoon.isNotEmpty) ...[
                  _SectionHeader(emoji: '🔴', label: 'Expiring Soon', color: Colors.red),
                  ...expiringSoon.map((m) => _ExpiryCard(
                        medicine: m,
                        color: Colors.red,
                        onRemoveStock: () => onQuantityChanged(m.id, 0),
                        onPriceChanged: onPriceChanged,
                      )),
                  const SizedBox(height: 16),
                ],
                if (warning.isNotEmpty) ...[
                  _SectionHeader(emoji: '🟡', label: 'Warning', color: Colors.orange),
                  ...warning.map((m) => _ExpiryCard(
                        medicine: m,
                        color: Colors.orange,
                        onRemoveStock: () => onQuantityChanged(m.id, 0),
                        onPriceChanged: onPriceChanged,
                      )),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;

  const _SectionHeader({required this.emoji, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text('$emoji $label', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _ExpiryCard extends StatelessWidget {
  final Medicine medicine;
  final Color color;
  final VoidCallback onRemoveStock;
  final Function(String id, double newPrice) onPriceChanged;

  const _ExpiryCard({
    required this.medicine,
    required this.color,
    required this.onRemoveStock,
    required this.onPriceChanged,
  });

  String _formatMonthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _showDiscountDialog(BuildContext context) async {
    final percentController = TextEditingController(text: '20');
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discount ${medicine.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current price: GHS ${medicine.price.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: percentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Discount percentage',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply')),
        ],
      ),
    );

    if (applied != true) return;
    final percent = double.tryParse(percentController.text.trim());
    if (percent == null || percent <= 0 || percent >= 100) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a discount between 1 and 99')),
        );
      }
      return;
    }
    final newPrice = medicine.price * (1 - percent / 100);
    onPriceChanged(medicine.id, double.parse(newPrice.toStringAsFixed(2)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${medicine.name} discounted to GHS ${newPrice.toStringAsFixed(2)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(medicine.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Expires: ${_formatMonthYear(medicine.expiryDate)}', style: TextStyle(color: color)),
            const SizedBox(height: 4),
            Text('Price: GHS ${medicine.price.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => _showDiscountDialog(context),
                  child: const Text('Create Discount'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onRemoveStock,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Remove Stock'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}