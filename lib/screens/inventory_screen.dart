import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/medicine.dart';

class InventoryScreen extends StatefulWidget {
  final List<Medicine> inventory;
  final Function(String barcode) onBarcodeScanned;
  final Function(String id, int newQty) onQuantityChanged;

  const InventoryScreen({
    super.key,
    required this.inventory,
    required this.onBarcodeScanned,
    required this.onQuantityChanged,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String filterStatus = 'All';

  void _openLiveScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Scan Product Barcode')),
          body: MobileScanner(
            controller: MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates),
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                final String rawValue = barcodes.first.rawValue!;
                Navigator.of(context).pop(); // Dismiss viewfinder UI sheet
                widget.onBarcodeScanned(rawValue); // Dispatch event bubble to processor
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.inventory.where((item) {
      if (filterStatus == 'All') return true;
      if (filterStatus == 'Low Stock') return item.isLowStock;
      return item.status == filterStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drug Master Registry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Launch Camera Scanner',
            onPressed: _openLiveScanner,
          )
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: ['All', 'Good', 'Near Expiry', 'Expired', 'Low Stock'].map((status) {
                final isSelected = filterStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (_) => setState(() => filterStatus = status),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text('No matching inventory records found.'))
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Batch: ${item.batchNumber}\nBarcode: ${item.barcode}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                onPressed: item.quantity > 0 ? () => widget.onQuantityChanged(item.id, item.quantity - 1) : null,
                              ),
                              Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                onPressed: () => widget.onQuantityChanged(item.id, item.quantity + 1),
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
    );
  }
}