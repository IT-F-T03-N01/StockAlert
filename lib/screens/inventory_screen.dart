import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Medicine> _allMedicines = [];
  List<Medicine> _filteredMedicines = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'Expired', 'Near Expiry', 'Low Stock'
  String _activeSort = 'Name (A-Z)'; // 'Name (A-Z)', 'Expiry (Soonest)', 'Stock (Lowest)'

  final List<String> _filters = ['All', 'Expired', 'Near Expiry', 'Low Stock'];
  final List<String> _sortOptions = ['Name (A-Z)', 'Expiry (Soonest)', 'Stock (Lowest)'];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getInventory();
    setState(() {
      _allMedicines = list;
      _isLoading = false;
      _applyFiltersAndSorting();
    });
  }

  void _applyFiltersAndSorting() {
    List<Medicine> result = List.from(_allMedicines);

    // 1. Apply Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((m) {
        return m.name.toLowerCase().contains(q) ||
            m.genericName.toLowerCase().contains(q) ||
            m.barcode.contains(q);
      }).toList();
    }

    // 2. Apply Filters
    if (_activeFilter == 'Expired') {
      result = result.where((m) => m.daysToExpiry <= 0).toList();
    } else if (_activeFilter == 'Near Expiry') {
      result = result.where((m) => m.daysToExpiry > 0 && m.daysToExpiry <= 90).toList();
    } else if (_activeFilter == 'Low Stock') {
      result = result.where((m) => m.isDeficient).toList();
    }

    // 3. Apply Sorting
    if (_activeSort == 'Name (A-Z)') {
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_activeSort == 'Expiry (Soonest)') {
      result.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    } else if (_activeSort == 'Stock (Lowest)') {
      result.sort((a, b) => a.quantity.compareTo(b.quantity));
    }

    setState(() {
      _filteredMedicines = result;
    });
  }

  Future<void> _updateQuantity(Medicine med, int delta) async {
    final newQty = med.quantity + delta;
    if (newQty < 0) return; // Cannot go below zero

    final updated = med.copyWith(quantity: newQty);
    await DatabaseHelper.instance.updateMedicine(updated);

    // Update locally in memory to feel instantaneous
    setState(() {
      final index = _allMedicines.indexWhere((m) => m.id == med.id);
      if (index != -1) {
        _allMedicines[index] = updated;
      }
      _applyFiltersAndSorting();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${med.name} quantity updated to $newQty'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show bottom sheet or dialog to create/edit product
  void _showAddEditMedicineDialog([Medicine? medicine]) {
    final isEdit = medicine != null;
    final formKey = GlobalKey<FormState>();

    // Controllers
    final nameController = TextEditingController(text: medicine?.name ?? '');
    final genericController = TextEditingController(text: medicine?.genericName ?? '');
    final barcodeController = TextEditingController(text: medicine?.barcode ?? '');
    final quantityController = TextEditingController(text: medicine?.quantity.toString() ?? '10');
    final minQtyController = TextEditingController(text: medicine?.minQuantity.toString() ?? '5');
    final priceController = TextEditingController(text: medicine?.price.toString() ?? '1.99');
    final locationController = TextEditingController(text: medicine?.location ?? 'Shelf A1');

    DateTime selectedDate = medicine?.expiryDate ?? DateTime.now().add(const Duration(days: 365));
    String selectedDosage = medicine?.dosageForm ?? 'Tablet';

    final List<String> dosageForms = ['Tablet', 'Capsule', 'Syrup', 'Injection', 'Cream', 'Inhaler'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 24,
                left: 16,
                right: 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit ? 'Edit Product Details' : 'Register New Medicine',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (isEdit)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                              onPressed: () {
                                _deleteMedicine(medicine.id!);
                                Navigator.pop(ctx);
                              },
                            )
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Medicine Brand Name *',
                          prefixIcon: Icon(Icons.medication),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Brand name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: genericController,
                        decoration: const InputDecoration(
                          labelText: 'Generic Name / Active Ingredient *',
                          prefixIcon: Icon(Icons.science),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Generic name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'UPC/EAN Barcode *',
                                prefixIcon: Icon(Icons.qr_code),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Barcode is required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: quantityController,
                              decoration: const InputDecoration(
                                labelText: 'Stock Quantity',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => int.tryParse(v ?? '') == null ? 'Enter valid number' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: minQtyController,
                              decoration: const InputDecoration(
                                labelText: 'Alert Minimum Qty',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => int.tryParse(v ?? '') == null ? 'Enter valid number' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceController,
                              decoration: const InputDecoration(
                                labelText: 'Price per unit',
                                prefixText: '\$',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => double.tryParse(v ?? '') == null ? 'Enter valid decimal' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: locationController,
                              decoration: const InputDecoration(
                                labelText: 'Storage Location',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Dropdown & Expiry Date picker
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedDosage,
                              decoration: const InputDecoration(
                                labelText: 'Dosage Form',
                                border: OutlineInputBorder(),
                              ),
                              items: dosageForms.map((df) {
                                return DropdownMenuItem(value: df, child: Text(df));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedDosage = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                );
                                if (date != null) {
                                  setModalState(() => selectedDate = date);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final newMed = Medicine(
                                id: medicine?.id,
                                name: nameController.text.trim(),
                                genericName: genericController.text.trim(),
                                barcode: barcodeController.text.trim(),
                                quantity: int.parse(quantityController.text.trim()),
                                minQuantity: int.parse(minQtyController.text.trim()),
                                expiryDate: selectedDate,
                                dosageForm: selectedDosage,
                                location: locationController.text.trim(),
                                price: double.parse(priceController.text.trim()),
                              );

                              if (isEdit) {
                                await DatabaseHelper.instance.updateMedicine(newMed);
                              } else {
                                await DatabaseHelper.instance.insertMedicine(newMed);
                              }

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                _loadInventory();
                              }
                            }
                          },
                          child: Text(isEdit ? 'Save Changes' : 'Register Product'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMedicine(int id) async {
    await DatabaseHelper.instance.deleteMedicine(id);
    _loadInventory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medicine removed from inventory')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search brand, generic name, or barcode...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _applyFiltersAndSorting();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _applyFiltersAndSorting();
              },
            ),
          ),

          // 2. Filter chips & Sorting Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Filter chips horizontally scrollable
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        final isSelected = _activeFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: FilterChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _activeFilter = filter);
                                _applyFiltersAndSorting();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Sort Dropdown
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _activeSort,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.sort, size: 20),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  items: _sortOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt,
                      child: Text(opt),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _activeSort = val);
                      _applyFiltersAndSorting();
                    }
                  },
                ),
              ],
            ),
          ),

          // 3. Main List view
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMedicines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No matching items found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInventory,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _filteredMedicines.length,
                          itemBuilder: (context, index) {
                            final med = _filteredMedicines[index];
                            final days = med.daysToExpiry;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showAddEditMedicineDialog(med),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      // Status Color Stripe indicator
                                      Container(
                                        width: 5,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: med.statusColor,
                                          borderRadius: BorderRadius.circular(2.5),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Medication Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              med.name,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${med.dosageForm} • ${med.genericName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.textTheme.bodySmall?.color
                                                    ?.withOpacity(0.6),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                // Expiry status indicator badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: med.statusColor.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    days <= 0
                                                        ? 'Expired'
                                                        : days <= 90
                                                            ? '$days Days Left'
                                                            : '${(days / 30).toStringAsFixed(0)} Mo Left',
                                                    style: TextStyle(
                                                      color: med.statusColor,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Location badge
                                                Text(
                                                  med.location,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: isDark ? Colors.white54 : Colors.grey,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),

                                      // Stock Increments & Price
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '\$${med.price.toStringAsFixed(2)}',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Row for quick overrides: Minus / Qty / Plus
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildQuickQuantityBtn(
                                                Icons.remove,
                                                () => _updateQuantity(med, -1),
                                                theme,
                                                isDark,
                                              ),
                                              Container(
                                                width: 32,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '${med.quantity}',
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: med.isDeficient
                                                        ? const Color(0xFFEF4444)
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              _buildQuickQuantityBtn(
                                                Icons.add,
                                                () => _updateQuantity(med, 1),
                                                theme,
                                                isDark,
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditMedicineDialog(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuickQuantityBtn(
    IconData icon,
    VoidCallback onPressed,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(icon, color: isDark ? Colors.white70 : Colors.black87),
        onPressed: onPressed,
      ),
    );
  }
}
