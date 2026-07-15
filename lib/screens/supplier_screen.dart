import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/supplier_order.dart';
import '../models/medicine.dart';
import '../main.dart';

class SupplierScreen extends StatelessWidget {
  final List<SupplierOrder> orders;
  final List<Medicine> inventory;
  final Function(SupplierOrder newOrder) onPlaceOrder;
  final Function(String orderId, String status) onUpdateStatus;

  const SupplierScreen({
    super.key,
    required this.orders,
    required this.inventory,
    required this.onPlaceOrder,
    required this.onUpdateStatus,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Delivered':
        return const Color(0xFF3B6D11);
      case 'Approved':
        return const Color(0xFF185FA5);
      default:
        return const Color(0xFF854F0B);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Delivered':
        return Icons.check_circle;
      case 'Approved':
        return Icons.thumb_up_alt;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowStockItems = inventory.where((m) => m.isLowStock).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      appBar: AppBar(
        title: const Text('Supplier Orders'),
        actions: [
          TextButton.icon(
            onPressed: () => _showNewOrderSheet(context, lowStockItems),
            icon: Icon(Icons.add, color: StockAlertApp.primaryTeal),
            label: Text('New Order', style: TextStyle(color: StockAlertApp.primaryTeal, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 44, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('No purchase orders yet.', style: GoogleFonts.manrope(color: Colors.grey[600])),
                  Text('Tap "New Order" to create one.', style: GoogleFonts.manrope(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final color = _statusColor(order.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.supplierName, style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Items: ${order.medicineName} (${order.quantityRequested})',
                          style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(_statusIcon(order.status), size: 14, color: color),
                          const SizedBox(width: 6),
                          Text(order.status, style: GoogleFonts.manrope(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
                          const Spacer(),
                          DropdownButton<String>(
                            value: order.status,
                            underline: const SizedBox(),
                            style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[800]),
                            items: ['Pending', 'Approved', 'Delivered'].map((status) {
                              return DropdownMenuItem(value: status, child: Text(status));
                            }).toList(),
                            onChanged: (newStatus) {
                              if (newStatus != null) onUpdateStatus(order.orderId, newStatus);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showNewOrderSheet(BuildContext context, List<Medicine> lowStockItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _NewOrderSheet(
          lowStockItems: lowStockItems,
          inventory: inventory,
          onPlaceOrder: onPlaceOrder,
        );
      },
    );
  }
}

class _NewOrderSheet extends StatefulWidget {
  final List<Medicine> lowStockItems;
  final List<Medicine> inventory;
  final Function(SupplierOrder newOrder) onPlaceOrder;

  const _NewOrderSheet({
    required this.lowStockItems,
    required this.inventory,
    required this.onPlaceOrder,
  });

  @override
  State<_NewOrderSheet> createState() => _NewOrderSheetState();
}

class _NewOrderSheetState extends State<_NewOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController(text: 'Central Logistics Distributor Ltd');
  final _quantityController = TextEditingController();
  Medicine? _selectedMedicine;

  @override
  void dispose() {
    _supplierController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submitCustomOrder() {
    if (!_formKey.currentState!.validate() || _selectedMedicine == null) return;
    final newOrder = SupplierOrder(
      orderId: 'PO-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      supplierName: _supplierController.text.trim(),
      medicineName: _selectedMedicine!.name,
      quantityRequested: int.parse(_quantityController.text.trim()),
      orderDate: DateTime.now(),
    );
    widget.onPlaceOrder(newOrder);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order ${newOrder.orderId} placed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Restock Suggestions', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (widget.lowStockItems.isEmpty)
              Text('All stock levels are currently healthy.', style: GoogleFonts.manrope(color: Colors.grey[600]))
            else
              ...widget.lowStockItems.map((item) {
                final recommendedQty = (item.minStockThreshold * 3) - item.quantity;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${item.name} (${item.quantity}/${item.minStockThreshold})',
                            style: GoogleFonts.manrope(fontSize: 13)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final newOrder = SupplierOrder(
                            orderId: 'PO-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                            supplierName: 'Central Logistics Distributor Ltd',
                            medicineName: item.name,
                            quantityRequested: recommendedQty,
                            orderDate: DateTime.now(),
                          );
                          widget.onPlaceOrder(newOrder);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Order ${newOrder.orderId} placed')),
                          );
                        },
                        child: Text('Order $recommendedQty'),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text('Create a Custom Order', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Medicine>(
                    value: _selectedMedicine,
                    decoration: const InputDecoration(labelText: 'Medicine'),
                    items: widget.inventory
                        .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedMedicine = value),
                    validator: (value) => value == null ? 'Select a medicine' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter a quantity';
                      if (int.tryParse(v.trim()) == null || int.parse(v.trim()) <= 0) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _supplierController,
                    decoration: const InputDecoration(labelText: 'Supplier Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a supplier name' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitCustomOrder,
                      child: const Text('PLACE ORDER'),
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