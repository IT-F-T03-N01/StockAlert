import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../models/supplier_order.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'scanner_screen.dart';
import 'supplier_screen.dart';
import 'profile_screen.dart';
import 'add_medicine_screen.dart';
import 'expiry_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  List<Medicine> _inventory = [];
  List<SupplierOrder> _supplierOrders = [];
  bool _isLoading = true;
  String _username = 'Pharmacist';
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final inventory = await DatabaseHelper.instance.getInventory();
    final orders = await DatabaseHelper.instance.getSupplierOrders();
    final username = await _authService.getUsername();
    if (!mounted) return;
    setState(() {
      _inventory = inventory;
      _supplierOrders = orders;
      _username = username;
      _isLoading = false;
    });
  }

  Future<void> _handleQuantityChanged(String id, int newQty) async {
    await DatabaseHelper.instance.updateMedicineQuantity(id, newQty);
    _refreshData();
  }

  Future<void> _handlePriceChanged(String id, double newPrice) async {
    await DatabaseHelper.instance.updateMedicinePrice(id, newPrice);
    _refreshData();
  }

  Future<void> _handlePlaceOrder(SupplierOrder order) async {
    await DatabaseHelper.instance.insertSupplierOrder(order);
    _refreshData();
  }

  Future<void> _handleUpdateOrderStatus(String orderId, String status) async {
    await DatabaseHelper.instance.updateOrderStatus(orderId, status);
    _refreshData();
  }

  // 👇 ADDED: The new function to handle deleting a medicine from the database
  Future<void> _handleDeleteMedicine(String id) async {
    await DatabaseHelper.instance.deleteMedicine(id);
    _refreshData();
  }

  void _goToTab(int index) => setState(() => _selectedIndex = index);

  Future<void> _openAddMedicine() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
    );
    if (added == true) _refreshData();
  }

  void _openExpiryTracker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpiryScreen(
          inventory: _inventory,
          onQuantityChanged: _handleQuantityChanged,
          onPriceChanged: _handlePriceChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      DashboardScreen(
        inventory: _inventory,
        supplierOrders: _supplierOrders,
        username: _username,
        onNavigateToInventory: () => _goToTab(1),
        onNavigateToScanner: () => _goToTab(2),
        onNavigateToSupplier: () => _goToTab(3),
        onNavigateToExpiry: _openExpiryTracker,
        onAddMedicine: _openAddMedicine,
      ),
      InventoryScreen(
        inventory: _inventory,
        onQuantityChanged: _handleQuantityChanged,
        onAddMedicine: _openAddMedicine,
        onDeleteMedicine: _handleDeleteMedicine, // 👇 ADDED: Passed the function here
      ),
      ScannerScreen(
        inventory: _inventory,
        onQuantityChanged: _handleQuantityChanged,
      ),
      SupplierScreen(
        inventory: _inventory,
        orders: _supplierOrders,
        onPlaceOrder: _handlePlaceOrder,
        onUpdateStatus: _handleUpdateOrderStatus,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), selectedIcon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}