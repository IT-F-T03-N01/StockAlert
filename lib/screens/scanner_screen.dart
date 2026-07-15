import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/medicine.dart';
import '../main.dart';

class ScannerScreen extends StatefulWidget {
  final List<Medicine> inventory;
  final Function(String id, int newQty) onQuantityChanged;

  const ScannerScreen({
    super.key,
    required this.inventory,
    required this.onQuantityChanged,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  Medicine? _foundMedicine;
  String? _unknownBarcode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_foundMedicine != null || _unknownBarcode != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;
    final rawValue = barcodes.first.rawValue!;

    final match = widget.inventory.where((m) => m.barcode == rawValue);
    setState(() {
      if (match.isNotEmpty) {
        _foundMedicine = match.first;
        _unknownBarcode = null;
      } else {
        _unknownBarcode = rawValue;
        _foundMedicine = null;
      }
    });
  }

  void _reset() {
    setState(() {
      _foundMedicine = null;
      _unknownBarcode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: StockAlertApp.primaryTeal,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(controller: _controller, onDetect: _handleDetect),
                      if (_foundMedicine == null && _unknownBarcode == null)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              'Point camera at barcode',
                              style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _foundMedicine != null
                  ? _MedicineFoundCard(
                      medicine: _foundMedicine!,
                      onUpdateStock: () {
                        widget.onQuantityChanged(_foundMedicine!.id, _foundMedicine!.quantity + 1);
                        _reset();
                      },
                      onScanAgain: _reset,
                    )
                  : _unknownBarcode != null
                      ? _UnknownBarcodeCard(barcode: _unknownBarcode!, onScanAgain: _reset)
                      : Center(
                          child: Text('Awaiting scan...', style: GoogleFonts.manrope(color: Colors.grey[500])),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineFoundCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onUpdateStock;
  final VoidCallback onScanAgain;

  const _MedicineFoundCard({
    required this.medicine,
    required this.onUpdateStock,
    required this.onScanAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF3B6D11), size: 18),
              const SizedBox(width: 6),
              Text('Medicine Found',
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF3B6D11))),
            ],
          ),
          const SizedBox(height: 10),
          Text(medicine.name, style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Batch: ${medicine.batchNumber}', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[700])),
          Text('Quantity: ${medicine.quantity}', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[700])),
          Text('Price: GHS ${medicine.price.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[700])),
          Text('Expiry: ${medicine.expiryDate.month}/${medicine.expiryDate.year}',
              style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onUpdateStock,
                  child: const Text('Update Stock'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onScanAgain, child: const Text('Scan Again')),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnknownBarcodeCard extends StatelessWidget {
  final String barcode;
  final VoidCallback onScanAgain;

  const _UnknownBarcodeCard({required this.barcode, required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFA32D2D), size: 18),
              const SizedBox(width: 6),
              Text('No Match Found',
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFA32D2D))),
            ],
          ),
          const SizedBox(height: 10),
          Text('Barcode "$barcode" is not linked to any medicine in the registry.',
              style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onScanAgain, child: const Text('Scan Again')),
        ],
      ),
    );
  }
}