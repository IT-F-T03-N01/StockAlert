import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../models/supplier_order.dart';
import '../services/database_helper.dart';

class SuppliedBatchEntry {
  final TextEditingController batchController;
  final TextEditingController qtyController;
  DateTime expiryDate;
  Medicine? selectedExistingBatch;

  SuppliedBatchEntry({
    required String initialBatch,
    required String initialQty,
    required DateTime initialExpiry,
    this.selectedExistingBatch,
  })  : batchController = TextEditingController(text: initialBatch),
        qtyController = TextEditingController(text: initialQty),
        expiryDate = initialExpiry;
}

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Medicine> _deficientMedicines = [];
  List<SupplierOrder> _orders = [];
  bool _isLoadingDeficiencies = true;
  bool _isLoadingOrders = true;

  // Track checked boxes for purchase order generation
  final Map<String, bool> _selectedItemForOrder = {};
  final Map<String, int> _orderQuantities = {};
  final Map<String, double> _orderPrices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDeficiencies();
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load low stock items from database (grouped by barcode to prevent duplicate batch rows)
  Future<void> _loadDeficiencies() async {
    setState(() => _isLoadingDeficiencies = true);
    final allMeds = await DatabaseHelper.instance.getInventory();

    final Map<String, List<Medicine>> grouped = {};
    for (final med in allMeds) {
      grouped.putIfAbsent(med.barcode, () => []).add(med);
    }

    final List<Medicine> lowStock = [];
    grouped.forEach((barcode, batches) {
      final totalQty = batches.fold<int>(0, (sum, m) => sum + m.quantity);
      final first = batches.first;
      if (totalQty < first.minQuantity) {
        lowStock.add(Medicine(
          id: first.id,
          name: first.name,
          genericName: first.genericName,
          barcode: first.barcode,
          batchNumber: 'AGGREGATED',
          quantity: totalQty,
          minQuantity: first.minQuantity,
          expiryDate: batches.map((m) => m.expiryDate).reduce((a, b) => a.isBefore(b) ? a : b),
          dosageForm: first.dosageForm,
          location: first.location,
          price: first.price,
          supplierName: first.supplierName,
        ));
      }
    });

    setState(() {
      _deficientMedicines = lowStock;
      for (final med in lowStock) {
        _selectedItemForOrder.putIfAbsent(med.barcode, () => true);
        _orderQuantities.putIfAbsent(med.barcode, () => _calculateSuggestedQuantity(med));
        _orderPrices.putIfAbsent(med.barcode, () => med.price * 0.65);
      }
      _isLoadingDeficiencies = false;
    });
  }

  // Load procurement history from database
  Future<void> _loadOrders() async {
    setState(() => _isLoadingOrders = true);
    final list = await DatabaseHelper.instance.getSupplierOrders();
    setState(() {
      _orders = list;
      _isLoadingOrders = false;
    });
  }

  // Map medicine to recommended supplier dynamically
  String _getRecommendedSupplier(Medicine med) {
    return med.supplierName;
  }

  // Generate order item quantity based on target level
  int _calculateSuggestedQuantity(Medicine med) {
    // Suggested: target safety stock is 2.5x min quantity
    final targetLevel = (med.minQuantity * 2.5).round();
    final difference = targetLevel - med.quantity;
    return difference > 0 ? difference : med.minQuantity;
  }

  // Batch generate Supplier Orders for selected deficiencies
  Future<void> _generatePurchaseOrders() async {
    final itemsToOrder = _deficientMedicines.where((m) => _selectedItemForOrder[m.barcode] == true).toList();

    if (itemsToOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item to order')),
      );
      return;
    }

    // Group items by recommended supplier
    final Map<String, List<SupplierOrderItem>> supplierGroups = {};

    for (final med in itemsToOrder) {
      final supplier = _getRecommendedSupplier(med);
      final orderQty = _orderQuantities[med.barcode] ?? _calculateSuggestedQuantity(med);
      final orderPrice = _orderPrices[med.barcode] ?? (med.price * 0.65);
      final orderItem = SupplierOrderItem(
        barcode: med.barcode,
        name: med.name,
        quantity: orderQty,
        unitPrice: orderPrice,
      );

      supplierGroups.putIfAbsent(supplier, () => []).add(orderItem);
    }

    // Create database records
    int generatedCount = 0;
    for (final entry in supplierGroups.entries) {
      final supplier = entry.key;
      final items = entry.value;
      final total = items.fold(0.0, (sum, item) => sum + item.totalPrice);

      final order = SupplierOrder(
        supplierName: supplier,
        orderDate: DateTime.now(),
        status: 'Pending',
        items: items,
        totalAmount: total,
      );

      await DatabaseHelper.instance.insertSupplierOrder(order);
      generatedCount++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated $generatedCount Purchase Orders successfully!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );

    // Refresh views
    _loadDeficiencies();
    _loadOrders();
    // Switch to order history tab
    _tabController.animateTo(1);
  }

  // Receive and check-in procurement items (allowing multiple batch allocations per ordered item)
  Future<void> _checkInOrder(SupplierOrder order) async {
    final inventory = await DatabaseHelper.instance.getInventory();
    final Map<String, List<SuppliedBatchEntry>> suppliedEntries = {};

    for (final item in order.items) {
      suppliedEntries[item.barcode] = [
        SuppliedBatchEntry(
          initialBatch: '',
          initialQty: item.quantity.toString(),
          initialExpiry: DateTime.now().add(const Duration(days: 365)),
        )
      ];
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Check-In Order #${order.id ?? 1}'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Confirm batch details for received medication. Click "Add Batch Split" if the item arrives in multiple batches:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ...order.items.map((item) {
                        final entries = suppliedEntries[item.barcode]!;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      'Ordered: ${item.quantity}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                ...List.generate(entries.length, (index) {
                                  final entry = entries[index];
                                  final existingMatches = inventory.where((m) => m.barcode == item.barcode).toList();
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).dividerColor.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: DropdownButtonFormField<Medicine?>(
                                                value: entry.selectedExistingBatch,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'Batch Allocation *',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: [
                                                  const DropdownMenuItem<Medicine?>(
                                                    value: null,
                                                    child: Text('New Batch', style: TextStyle(fontSize: 12)),
                                                  ),
                                                  ...existingMatches.map((b) => DropdownMenuItem<Medicine?>(
                                                    value: b,
                                                    child: Text(
                                                      'Previous Batch: ${b.batchNumber}',
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                  )),
                                                ],
                                                onChanged: (selected) {
                                                  setModalState(() {
                                                    entry.selectedExistingBatch = selected;
                                                    if (selected != null) {
                                                      entry.batchController.text = selected.batchNumber;
                                                      entry.expiryDate = selected.expiryDate;
                                                    } else {
                                                      entry.batchController.text = '';
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                            if (entries.length > 1) ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  setModalState(() {
                                                    entries.removeAt(index);
                                                  });
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 4,
                                              child: TextFormField(
                                                controller: entry.batchController,
                                                enabled: entry.selectedExistingBatch == null,
                                                decoration: const InputDecoration(
                                                  labelText: 'Batch Number *',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              flex: 2,
                                              child: TextFormField(
                                                controller: entry.qtyController,
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: 'Qty *',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              flex: 3,
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: entry.selectedExistingBatch != null
                                                    ? null
                                                    : () async {
                                                        final d = await showDatePicker(
                                                          context: ctx,
                                                          initialDate: entry.expiryDate,
                                                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                                                        );
                                                        if (d != null) {
                                                          setModalState(() {
                                                            entry.expiryDate = d;
                                                          });
                                                        }
                                                      },
                                                child: Text(
                                                  entry.selectedExistingBatch != null
                                                      ? 'Fixed Exp'
                                                      : '${entry.expiryDate.month}/${entry.expiryDate.day}/${entry.expiryDate.year.toString().substring(2)}',
                                                  style: const TextStyle(fontSize: 10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setModalState(() {
                                        entries.add(SuppliedBatchEntry(
                                          initialBatch: '',
                                          initialQty: '0',
                                          initialExpiry: DateTime.now().add(const Duration(days: 365)),
                                        ));
                                      });
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Batch Split', style: TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);

                    setState(() {
                      _isLoadingOrders = true;
                      _isLoadingDeficiencies = true;
                    });

                    final List<Medicine> suppliedBatches = [];
                    for (final item in order.items) {
                      final entries = suppliedEntries[item.barcode]!;
                      
                      // Resolve metadata from existing inventory
                      final existingMatches = inventory.where((m) => m.barcode == item.barcode).toList();
                      final generic = existingMatches.isNotEmpty ? existingMatches.first.genericName : 'Generic';
                      final dosage = existingMatches.isNotEmpty ? existingMatches.first.dosageForm : 'Tablet';
                      final location = existingMatches.isNotEmpty ? existingMatches.first.location : 'Shelf A1';
                      final minQty = existingMatches.isNotEmpty ? existingMatches.first.minQuantity : 15;

                      for (final entry in entries) {
                        final batchNum = entry.batchController.text.trim().isEmpty
                            ? 'B-UNKNOWN'
                            : entry.batchController.text.trim();
                        final qty = int.tryParse(entry.qtyController.text.trim()) ?? 0;

                        suppliedBatches.add(Medicine(
                          name: item.name,
                          genericName: generic,
                          barcode: item.barcode,
                          batchNumber: batchNum,
                          quantity: qty,
                          minQuantity: minQty,
                          expiryDate: entry.expiryDate,
                          dosageForm: dosage,
                          location: location,
                          price: item.unitPrice,
                          supplierName: order.supplierName,
                        ));
                      }
                    }

                    final success = await DatabaseHelper.instance.receiveSupplierOrder(order, suppliedBatches);

                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order Checked-In! Added ${suppliedBatches.length} supplied batches to inventory.'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }

                    await _loadDeficiencies();
                    await _loadOrders();
                  },
                  child: const Text('Confirm Check-In'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: theme.scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.analytics_outlined),
                text: 'Deficiency Engine',
              ),
              Tab(
                icon: Icon(Icons.history_edu),
                text: 'Procurement Orders',
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Deficiency Analysis Engine
          _buildDeficiencyTab(theme, isDark),

          // Tab 2: Supplier Orders tracking
          _buildOrdersTab(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildDeficiencyTab(ThemeData theme, bool isDark) {
    if (_isLoadingDeficiencies) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_deficientMedicines.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDeficiencies,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 72),
                const SizedBox(height: 16),
                Text(
                  'No Stock Deficiencies Detected',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'All pharmaceutical products are currently above their safety threshold minimums.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Informative header
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.15 : 0.4),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Analysis shows ${_deficientMedicines.length} products below safety levels. Wholesale POs will be generated grouped by supplier.',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // List of deficient items
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDeficiencies,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _deficientMedicines.length,
              itemBuilder: (context, index) {
                final med = _deficientMedicines[index];
                final suggestedQty = _calculateSuggestedQuantity(med);
                final supplier = _getRecommendedSupplier(med);
                
                final currentQty = _orderQuantities[med.barcode] ?? suggestedQty;
                final currentPrice = _orderPrices[med.barcode] ?? (med.price * 0.65);
                final double estCost = currentQty * currentPrice;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          activeColor: theme.colorScheme.primary,
                          value: _selectedItemForOrder[med.barcode] ?? false,
                          onChanged: (val) {
                            setState(() {
                              _selectedItemForOrder[med.barcode] = val ?? false;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stock: ${med.quantity} (Min: ${med.minQuantity})',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Text(
                                'Supplier: $supplier',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 70,
                                    height: 32,
                                    child: TextFormField(
                                      initialValue: currentQty.toString(),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: const InputDecoration(
                                        labelText: 'Qty',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        final parsed = int.tryParse(val);
                                        if (parsed != null && parsed > 0) {
                                          _orderQuantities[med.barcode] = parsed;
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 90,
                                    height: 32,
                                    child: TextFormField(
                                      initialValue: currentPrice.toStringAsFixed(2),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(fontSize: 12),
                                      decoration: const InputDecoration(
                                        labelText: 'Price \$',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        final parsed = double.tryParse(val);
                                        if (parsed != null && parsed > 0) {
                                          _orderPrices[med.barcode] = parsed;
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('EST. COST', style: TextStyle(fontSize: 8, color: Colors.grey)),
                              Text(
                                '\$${estCost.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.cyanAccent : Colors.cyan.shade800,
                                  fontSize: 12,
                                ),
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
        ),

        // Action generate button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: _generatePurchaseOrders,
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Generate Grouped Purchase Orders'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab(ThemeData theme, bool isDark) {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadOrders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_outlined, size: 72, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No Procurement History',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generated purchase orders will appear here for check-in tracking.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final isPending = order.status == 'Pending';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              ),
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  order.supplierName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Order Date: ${order.orderDate.month}/${order.orderDate.day}/${order.orderDate.year} • ${order.items.length} items',
                  style: const TextStyle(fontSize: 11),
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.amber.withOpacity(0.12)
                        : const Color(0xFF10B981).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPending ? Icons.hourglass_empty : Icons.assignment_turned_in,
                    color: isPending ? Colors.amber.shade800 : const Color(0xFF10B981),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPending
                            ? Colors.amber.withOpacity(0.15)
                            : const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: TextStyle(
                          color: isPending ? Colors.amber.shade800 : const Color(0xFF10B981),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  const Divider(height: 1),
                  // List of items inside order
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.items.length,
                    itemBuilder: (ctx, i) {
                      final item = order.items[i];
                      return ListTile(
                        dense: true,
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Barcode: ${item.barcode} • Wholesale Price: \$${item.unitPrice.toStringAsFixed(2)}'),
                        trailing: Text(
                          'Qty: ${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                  if (isPending) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _checkInOrder(order),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Mark Received & Restock Inventory'),
                        ),
                      ),
                    )
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
