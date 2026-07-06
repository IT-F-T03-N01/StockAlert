import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/inventory_provider.dart';
import '../providers/supplier_provider.dart';
import '../models/product.dart';
import 'scanner_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? existing;
  final String? prefilledBarcode;

  const ProductFormScreen({super.key, this.existing, this.prefilledBarcode});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _manufacturer;
  late final TextEditingController _unit;
  late final TextEditingController _unitPrice;
  late final TextEditingController _reorderLevel;
  String? _supplierId;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? widget.prefilledBarcode ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _manufacturer = TextEditingController(text: p?.manufacturer ?? '');
    _unit = TextEditingController(text: p?.unit ?? 'box');
    _unitPrice = TextEditingController(text: p?.unitPrice.toString() ?? '');
    _reorderLevel = TextEditingController(text: p?.reorderLevel.toString() ?? '10');
    _supplierId = p?.supplierId;
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen(returnResultOnly: true)),
    );
    if (result != null) setState(() => _barcode.text = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final inv = context.read<InventoryProvider>();
    if (widget.existing != null) {
      await inv.updateProduct(widget.existing!.copyWith(
        name: _name.text.trim(),
        barcode: _barcode.text.trim(),
        category: _category.text.trim(),
        manufacturer: _manufacturer.text.trim(),
        unit: _unit.text.trim(),
        unitPrice: double.tryParse(_unitPrice.text) ?? 0,
        reorderLevel: int.tryParse(_reorderLevel.text) ?? 10,
        supplierId: _supplierId,
      ));
    } else {
      await inv.addProduct(Product(
        id: const Uuid().v4(),
        name: _name.text.trim(),
        barcode: _barcode.text.trim(),
        category: _category.text.trim(),
        manufacturer: _manufacturer.text.trim(),
        unit: _unit.text.trim(),
        unitPrice: double.tryParse(_unitPrice.text) ?? 0,
        reorderLevel: int.tryParse(_reorderLevel.text) ?? 10,
        supplierId: _supplierId,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = context.watch<SupplierProvider>().suppliers;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add Product' : 'Edit Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Product name'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              decoration: InputDecoration(
                labelText: 'Barcode',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category (e.g. Antibiotics)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _manufacturer,
              decoration: const InputDecoration(labelText: 'Manufacturer'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Unit (box, bottle...)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitPrice,
                    decoration: const InputDecoration(labelText: 'Unit price'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reorderLevel,
              decoration: const InputDecoration(labelText: 'Reorder level (alert when stock ≤ this)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _supplierId,
              decoration: const InputDecoration(labelText: 'Preferred supplier'),
              items: suppliers
                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _supplierId = v),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Save Product')),
          ],
        ),
      ),
    );
  }
}
