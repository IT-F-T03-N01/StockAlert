import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';
import '../main.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _batchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minStockController = TextEditingController(text: '20');
  final _priceController = TextEditingController();
  final _barcodeController = TextEditingController();
  DateTime? _expiryDate;
  String _category = 'Analgesics';
  bool _isSaving = false;

  final _categories = const [
    'Analgesics',
    'Antibiotics',
    'Antidiabetics',
    'Hormones',
    'Supplements',
    'Antimalarials',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _batchController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: StockAlertApp.primaryTeal),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QuickScanScreen()),
    );
    if (scanned != null) {
      setState(() => _barcodeController.text = scanned);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an expiry date')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final medicine = Medicine(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      category: _category,
      quantity: int.parse(_quantityController.text.trim()),
      minStockThreshold: int.parse(_minStockController.text.trim()),
      barcode: _barcodeController.text.trim().isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : _barcodeController.text.trim(),
      expiryDate: _expiryDate!,
      batchNumber: _batchController.text.trim(),
      price: double.parse(_priceController.text.trim()),
    );

    await DatabaseHelper.instance.insertMedicine(medicine);
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      appBar: AppBar(title: const Text('Add Medicine')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _sectionLabel('Basic details'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Medicine Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a medicine name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode',
                suffixIcon: IconButton(
                  icon: Icon(Icons.qr_code_scanner, color: StockAlertApp.primaryTeal),
                  onPressed: _scanBarcode,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _batchController,
              decoration: const InputDecoration(labelText: 'Batch Number'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a batch number' : null,
            ),
            _sectionLabel('Stock & pricing'),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a quantity';
                if (int.tryParse(v.trim()) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minStockController,
              decoration: const InputDecoration(labelText: 'Minimum Stock Threshold'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a threshold';
                if (int.tryParse(v.trim()) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price', prefixText: 'GHS '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a price';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                return null;
              },
            ),
            _sectionLabel('Expiry'),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickExpiryDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Expiry Date'),
                child: Text(
                  _expiryDate == null
                      ? 'Select date'
                      : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                  style: GoogleFonts.manrope(
                    color: _expiryDate == null ? Colors.grey[500] : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SAVE MEDICINE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Lightweight scanner used only to capture a barcode value for the form field above.
class _QuickScanScreen extends StatelessWidget {
  const _QuickScanScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        controller: MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates),
        onDetect: (capture) {
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            Navigator.of(context).pop(barcodes.first.rawValue);
          }
        },
      ),
    );
  }
}