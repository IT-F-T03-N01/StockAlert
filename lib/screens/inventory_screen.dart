import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/medicine.dart';
import '../main.dart';

class InventoryScreen extends StatefulWidget {
  final List<Medicine> inventory;
  final Function(String id, int newQty) onQuantityChanged;
  final VoidCallback onAddMedicine;
  final Function(String id) onDeleteMedicine; // <-- ADDED: Callback for deletion

  const InventoryScreen({
    super.key,
    required this.inventory,
    required this.onQuantityChanged,
    required this.onAddMedicine,
    required this.onDeleteMedicine, // <-- ADDED: Required parameter
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _statusFilter = 'All';
  String _categoryFilter = 'All';
  String _searchQuery = '';
  bool _sortByExpiry = false;

  Color _statusTextColor(Medicine item) {
    if (item.isLowStock) return const Color(0xFF993C1D);
    switch (item.status) {
      case 'Expired':
        return const Color(0xFFA32D2D);
      case 'Near Expiry':
        return const Color(0xFF854F0B);
      default:
        return const Color(0xFF3B6D11);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...{for (final m in widget.inventory) m.category}];

    var filtered = widget.inventory.where((item) {
      final matchesStatus = _statusFilter == 'All'
          ? true
          : (_statusFilter == 'Low Stock' ? item.isLowStock : item.status == _statusFilter);
      final matchesCategory = _categoryFilter == 'All' || item.category == _categoryFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesCategory && matchesSearch;
    }).toList();

    if (_sortByExpiry) {
      filtered.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    } else {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      appBar: AppBar(
        title: const Text('Stock Inventory'),
        actions: [
          IconButton(
            icon: Icon(_sortByExpiry ? Icons.sort : Icons.sort_by_alpha),
            tooltip: 'Sort by expiry',
            onPressed: () => setState(() => _sortByExpiry = !_sortByExpiry),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StockAlertApp.primaryTeal,
        onPressed: widget.onAddMedicine,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search medicine',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(left: 16, right: 32),
              child: Row(
                children: ['All', 'Good', 'Near Expiry', 'Expired', 'Low Stock'].map((status) {
                  final isSelected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0, bottom: 8),
                    child: ChoiceChip(
                      label: Text(status, style: GoogleFonts.manrope(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: StockAlertApp.primaryTeal,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[800]),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? StockAlertApp.primaryTeal : Colors.grey.shade300),
                      ),
                      onSelected: (_) => setState(() => _statusFilter = status),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (categories.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8, left: 16, right: 32),
                child: Row(
                  children: categories.map((category) {
                    final isSelected = _categoryFilter == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(category, style: GoogleFonts.manrope(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: StockAlertApp.accentGold.withOpacity(0.3),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? StockAlertApp.accentGold : Colors.grey.shade300),
                        ),
                        onSelected: (_) => setState(() => _categoryFilter = category),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('No matching inventory records found.',
                              style: GoogleFonts.manrope(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        
                        // <-- ADDED: Dismissible wrapper for swipe-to-delete
                        return Dismissible(
                          key: Key(item.id),
                          direction: DismissDirection.endToStart, // Swipe left only
                          background: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.centerRight,
                            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                          ),
                          onDismissed: (direction) {
                            // Call the function when swiped
                            widget.onDeleteMedicine(item.id);
                            
                            // Optional: Show a quick snackbar to confirm
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${item.name} deleted'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(item.name,
                                                style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14)),
                                          ),
                                          Text('GHS ${item.price.toStringAsFixed(2)}',
                                              style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF854F0B))),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Stock: ${item.quantity}  •  Batch: ${item.batchNumber}',
                                          style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600])),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(color: _statusTextColor(item), shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(item.isLowStock ? 'Low Stock' : item.status,
                                              style: GoogleFonts.manrope(
                                                  fontSize: 12, color: _statusTextColor(item), fontWeight: FontWeight.w600)),
                                          const Spacer(),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                                            onPressed: item.quantity > 0
                                                ? () => widget.onQuantityChanged(item.id, item.quantity - 1)
                                                : null,
                                          ),
                                          Text('${item.quantity}', style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13)),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: Icon(Icons.add_circle_outline, size: 20, color: StockAlertApp.primaryTeal),
                                            onPressed: () => widget.onQuantityChanged(item.id, item.quantity + 1),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}