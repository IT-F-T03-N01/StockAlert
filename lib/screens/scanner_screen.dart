import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // Modes: 0 = Dispense / Sale Mode (Red), 1 = Receive / Restock Mode (Green)
  int _activeMode = 0;
  bool _isScanCooldown = false;

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  // For manual testing/simulation on emulators
  final TextEditingController _simulatedBarcodeController = TextEditingController();

  @override
  void dispose() {
    _scannerController.dispose();
    _simulatedBarcodeController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScanned(String barcodeValue) async {
    if (_isScanCooldown) return;

    setState(() {
      _isScanCooldown = true;
    });

    final barcode = barcodeValue.trim();
    if (barcode.isEmpty) {
      setState(() => _isScanCooldown = false);
      return;
    }

    // Lookup in SQLite: fetch all batches for this barcode
    final inventory = await DatabaseHelper.instance.getInventory();
    final barcodeBatches = inventory.where((m) => m.barcode == barcode).toList();

    if (barcodeBatches.isNotEmpty) {
      if (_activeMode == 0) {
        // Dispense Mode: Fetch soonest to expire batch with stock (FEFO)
        final fefoMed = await DatabaseHelper.instance.getFefoMedicine(barcode);
        if (fefoMed == null) {
          _showStatusMessage(
            'Cannot dispense ${barcodeBatches.first.name}. Out of stock in all batches!',
            isSuccess: false,
          );
        } else {
          final updated = fefoMed.copyWith(quantity: fefoMed.quantity - 1);
          await DatabaseHelper.instance.updateMedicine(updated);
          final bool isExpired = fefoMed.daysToExpiry <= 0;
          _showStatusMessage(
            '${fefoMed.name} (Batch: ${fefoMed.batchNumber}) Dispensed (-1)' +
                (isExpired ? ' - WARNING: EXPIRED BATCH!' : ''),
            isSuccess: !isExpired,
          );
        }
      } else {
        // Receive Mode: Prompt user to choose which batch to restock or register a new batch
        _showReceiveStockDialog(barcode, barcodeBatches);
      }
    } else {
      // Barcode not found, show registration dialog
      _showRegisterMissingItemDialog(barcode);
    }

    // Cooldown delay of 2.5 seconds to prevent spam scans
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      setState(() {
        _isScanCooldown = false;
      });
    }
  }

  void _showReceiveStockDialog(String barcode, List<Medicine> existingBatches) {
    final formKey = GlobalKey<FormState>();
    final batchController = TextEditingController(text: '');
    final qtyController = TextEditingController(text: '10');
    DateTime expiryDate = DateTime.now().add(const Duration(days: 365));
    final priceController = TextEditingController(text: existingBatches.first.price.toString());
    final locationController = TextEditingController(text: existingBatches.first.location);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Receive Stock: ${existingBatches.first.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tap an existing batch to add custom quantity:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ...existingBatches.map((b) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        title: Text('Batch: ${b.batchNumber} (Stock: ${b.quantity})'),
                        subtitle: Text(
                          'Expires: ${b.expiryDate.month}/${b.expiryDate.day}/${b.expiryDate.year}',
                          style: TextStyle(color: b.statusColor, fontWeight: FontWeight.bold),
                        ),
                        trailing: const Icon(Icons.add, color: Colors.teal),
                        onTap: () async {
                          final addQtyController = TextEditingController(text: '10');
                          final int? qtyToAdd = await showDialog<int>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: Text('Restock Batch ${b.batchNumber}'),
                              content: TextFormField(
                                controller: addQtyController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity to Add',
                                  border: OutlineInputBorder(),
                                ),
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final val = int.tryParse(addQtyController.text);
                                    Navigator.pop(dialogCtx, val);
                                  },
                                  child: const Text('Add Stock'),
                                ),
                              ],
                            ),
                          );

                          if (qtyToAdd != null && qtyToAdd > 0) {
                            final updated = b.copyWith(quantity: b.quantity + qtyToAdd);
                            await DatabaseHelper.instance.updateMedicine(updated);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            _showStatusMessage('${b.name} (Batch: ${b.batchNumber}) Restocked (+$qtyToAdd)');
                          }
                        },
                      ),
                    )),
                    const Divider(height: 24),
                    const Text(
                      'Or Receive a New Supplier Batch:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Form(
                      key: formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: batchController,
                            decoration: const InputDecoration(
                              labelText: 'New Batch Number *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: qtyController,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity *',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                      context: ctx,
                                      initialDate: expiryDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                                    );
                                    if (d != null) {
                                      setModalState(() => expiryDate = d);
                                    }
                                  },
                                  child: Text(
                                    '${expiryDate.month}/${expiryDate.day}/${expiryDate.year}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final sample = existingBatches.first;
                      final newMed = Medicine(
                        name: sample.name,
                        genericName: sample.genericName,
                        barcode: barcode,
                        batchNumber: batchController.text.trim(),
                        quantity: int.parse(qtyController.text.trim()),
                        minQuantity: sample.minQuantity,
                        expiryDate: expiryDate,
                        dosageForm: sample.dosageForm,
                        location: locationController.text.trim(),
                        price: double.parse(priceController.text.trim()),
                      );
                      await DatabaseHelper.instance.insertMedicine(newMed);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      _showStatusMessage(
                        '${newMed.name} (Batch: ${newMed.batchNumber}) Restocked (+${newMed.quantity})',
                      );
                    }
                  },
                  child: const Text('Receive Batch'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStatusMessage(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? (_activeMode == 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981))
            : Colors.amber.shade800,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showRegisterMissingItemDialog(String scannedBarcode) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final genericController = TextEditingController();
    final batchController = TextEditingController(text: '');
    final qtyController = TextEditingController(text: '10');
    final minQtyController = TextEditingController(text: '5');
    final priceController = TextEditingController(text: '4.99');
    final locationController = TextEditingController(text: 'Shelf A1');
    final supplierController = TextEditingController(text: '');
    DateTime expiryDate = DateTime.now().add(const Duration(days: 365));
    String dosageForm = 'Tablet';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.add_to_photos, color: Colors.teal),
                  const SizedBox(width: 10),
                  const Text('New Barcode Found', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Barcode "$scannedBarcode" is not registered. Please enter medication details to save it to inventory.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Brand Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: genericController,
                        decoration: const InputDecoration(
                          labelText: 'Generic Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: batchController,
                        decoration: const InputDecoration(
                          labelText: 'Batch Number *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: supplierController,
                        decoration: const InputDecoration(
                          labelText: 'Recommended Supplier *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: qtyController,
                              decoration: const InputDecoration(labelText: 'Qty'),
                              keyboardType: TextInputType.number,
                              validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: minQtyController,
                              decoration: const InputDecoration(labelText: 'Min Alert'),
                              keyboardType: TextInputType.number,
                              validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceController,
                              decoration: const InputDecoration(labelText: 'Price (\$)'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: locationController,
                              decoration: const InputDecoration(labelText: 'Location'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Expiry:', style: TextStyle(fontSize: 12)),
                          OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: expiryDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (d != null) {
                                setState(() => expiryDate = d);
                              }
                            },
                            child: Text(
                              '${expiryDate.month}/${expiryDate.day}/${expiryDate.year}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
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
                    if (formKey.currentState!.validate()) {
                      final newMed = Medicine(
                        name: nameController.text.trim(),
                        genericName: genericController.text.trim(),
                        barcode: scannedBarcode,
                        batchNumber: batchController.text.trim(),
                        quantity: int.parse(qtyController.text.trim()),
                        minQuantity: int.parse(minQtyController.text.trim()),
                        expiryDate: expiryDate,
                        dosageForm: dosageForm,
                        location: locationController.text.trim(),
                        price: double.parse(priceController.text.trim()),
                        supplierName: supplierController.text.trim(),
                      );

                      await DatabaseHelper.instance.insertMedicine(newMed);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        _showStatusMessage('${newMed.name} (Batch: ${newMed.batchNumber}) Registered successfully!');
                      }
                    }
                  },
                  child: const Text('Register'),
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

    // Determine colors based on active scanning mode
    final Color modeColor = _activeMode == 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final String modeLabel = _activeMode == 0 ? 'DISPENSE / SALE MODE (-1)' : 'RECEIVE / RESTOCK MODE (+1)';

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Dual Mode Segmented Switch Selector
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    // Mode 0: Dispense (Sale)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeMode = 0),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(13),
                          bottomLeft: Radius.circular(13),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _activeMode == 0 ? const Color(0xFFEF4444) : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(13),
                              bottomLeft: Radius.circular(13),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.outbox_rounded,
                                color: _activeMode == 0 ? Colors.white : const Color(0xFFEF4444),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Dispense / Sale',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _activeMode == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Mode 1: Receive (Restock)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeMode = 1),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(13),
                          bottomRight: Radius.circular(13),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _activeMode == 1 ? const Color(0xFF10B981) : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(13),
                              bottomRight: Radius.circular(13),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.move_to_inbox,
                                color: _activeMode == 1 ? Colors.white : const Color(0xFF10B981),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Receive / Restock',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _activeMode == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Active Mode Display Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: modeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: modeColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  modeLabel,
                  style: TextStyle(
                    color: modeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Camera Viewport frame
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: modeColor, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The camera scanner stream
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                          _handleBarcodeScanned(barcodes.first.rawValue!);
                        }
                      },
                    ),

                    // HUD Scan Overlay
                    Container(
                      width: 180,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: modeColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),

                    // Throttled notification layer
                    if (_isScanCooldown)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 8),
                            Text(
                              'Processing scan...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. Barcode Simulator Panel (For test verification on Android/iOS simulators)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.videogame_asset_outlined, color: Colors.cyan),
                      const SizedBox(width: 8),
                      Text(
                        'Emulator Scan Simulator',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Input any barcode below or tap quick simulation presets to mock scanning of seeded database products.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _simulatedBarcodeController,
                          decoration: const InputDecoration(
                            hintText: 'Enter barcode string...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: modeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          final text = _simulatedBarcodeController.text.trim();
                          if (text.isNotEmpty) {
                            _handleBarcodeScanned(text);
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Scan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Quick Seed Presets:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip('Paracetamol', '8801234567890'),
                      _buildPresetChip('Amoxicillin', '8809876543210'),
                      _buildPresetChip('Ibuprofen', '4001234567892'),
                      _buildPresetChip('Unregistered Barcode', '9999999999999'),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String code) {
    return ActionChip(
      avatar: const Icon(Icons.copy, size: 12),
      label: Text('$label ($code)', style: const TextStyle(fontSize: 10)),
      onPressed: () {
        _simulatedBarcodeController.text = code;
      },
    );
  }
}
