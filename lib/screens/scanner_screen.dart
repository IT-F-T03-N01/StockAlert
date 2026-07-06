import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/inventory_provider.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

/// If [returnResultOnly] is true, a successful scan/entry just pops the
/// screen and returns the barcode string (used by the product form to
/// fill in a barcode field). Otherwise it looks up the product directly
/// and opens its detail page, or offers to create a new product.
class ScannerScreen extends StatefulWidget {
  final bool returnResultOnly;
  const ScannerScreen({super.key, this.returnResultOnly = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final _manualController = TextEditingController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    _handleCode(code);
  }

  void _handleCode(String code) {
    if (widget.returnResultOnly) {
      Navigator.of(context).pop(code);
      return;
    }
    final inv = context.read<InventoryProvider>();
    final product = inv.findByBarcode(code);
    if (product != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      );
    } else {
      _showNotFoundDialog(code);
    }
  }

  void _showNotFoundDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Barcode not found'),
        content: Text('No product is registered with barcode "$code".'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _handled = false);
            },
            child: const Text('Scan again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(prefilledBarcode: code),
                ),
              );
            },
            child: const Text('Add product'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Center(
                  child: Container(
                    width: 250,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      decoration: const InputDecoration(
                        labelText: 'Or enter barcode manually',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (v) {
                        if (v.isNotEmpty) _handleCode(v.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final v = _manualController.text.trim();
                      if (v.isNotEmpty) _handleCode(v);
                    },
                    child: const Text('Go'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
