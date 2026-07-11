import 'package:flutter/material.dart';
import 'models/medicine.dart';
import 'models/supplier_order.dart';
import 'services/database_helper.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/supplier_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CommunityPharmacyApp());
}

class CommunityPharmacyApp extends StatelessWidget {
  const CommunityPharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RxInventory Core',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
      home: const ApplicationShell(),
    );
  }
}

class ApplicationShell extends StatefulWidget {
  const ApplicationShell({super.key});

  @override
  State<ApplicationShell> createState() => _ApplicationShellState();
}

class _ApplicationShellState extends State<ApplicationShell> {
  int _selectedNavigationIndex = 0;
  List<Medicine> _inventory = [];
  List<SupplierOrder> _supplierOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshDataPipeline();
  }

  Future<void> _refreshDataPipeline() async {
    setState(() => _isLoading = true);
    final currentInventory = await DatabaseHelper.instance.getInventory();
    final currentOrders = await DatabaseHelper.instance.getSupplierOrders();
    setState(() {
      _inventory = currentInventory;
      _supplierOrders = currentOrders;
      _isLoading = false;
    });
  }

  Future<void> _handleQuantityAdjustment(String id, int newQuantity) async {
    await DatabaseHelper.instance.updateMedicineQuantity(id, newQuantity);
    _refreshDataPipeline();
  }

  Future<void> _handlePlaceOrder(SupplierOrder order) async {
    await DatabaseHelper.instance.insertSupplierOrder(order);
    _refreshDataPipeline();
  }

  Future<void> _handleUpdateOrderStatus(String id, String status) async {
    await DatabaseHelper.instance.updateOrderStatus(id, status);
    _refreshDataPipeline();
  }

  void _handleBarcodeScanReceived(String barcode) {
    // Exact lookups against SQLite cache representation array
    final itemIndex = _inventory.indexWhere((m) => m.barcode == barcode);
    
    if (itemIndex != -1) {
      final matchedItem = _inventory[itemIndex];
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Asset Identifier Match'),
          content: Text('Target: ${matchedItem.name}\nExisting Units: ${matchedItem.quantity}\nIncrement system verification count by 1?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Discard')),
            ElevatedButton(
              onPressed: () {
                _handleQuantityAdjustment(matchedItem.id, matchedItem.quantity + 1);
                Navigator.pop(context);
              },
              child: const Text('Update Count'),
            )
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unknown System String'),
          content: Text('Scanned key layout "$barcode" is not attached to any registered active formulary item.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Acknowledge'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> structuralScreens = [
      DashboardScreen(
        inventory: _inventory,
        onNavigateToInventory: () => setState(() => _selectedNavigationIndex = 1),
        onNavigateToSupplier: () => setState(() => _selectedNavigationIndex = 2),
      ),
      InventoryScreen(
        inventory: _inventory,
        onBarcodeScanned: _handleBarcodeScanReceived,
        onQuantityChanged: _handleQuantityAdjustment,
      ),
      SupplierScreen(
        inventory: _inventory,
        orders: _supplierOrders,
        onPlaceOrder: _handlePlaceOrder,
        onUpdateStatus: _handleUpdateOrderStatus,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedNavigationIndex, children: structuralScreens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavigationIndex,
        onDestinationSelected: (idx) => setState(() => _selectedNavigationIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Console Overview'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.airport_shuttle), label: 'Procurement'),
        ],
      ),
    );
  }
}