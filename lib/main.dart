import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/supplier_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PharmacyApp());
}

class PharmacyApp extends StatefulWidget {
  const PharmacyApp({super.key});

  @override
  State<PharmacyApp> createState() => _PharmacyAppState();
}

class _PharmacyAppState extends State<PharmacyApp> {
  // Global light/dark state
  ThemeMode _themeMode = ThemeMode.dark; // Default to premium dark mode

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Light Theme: Teal/Cyan medical theme
    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
      ).copyWith(
        primary: Colors.teal.shade700,
        primaryContainer: Colors.teal.shade50,
        secondary: Colors.cyan.shade700,
        surface: const Color(0xFFF8FAFC), // Soft gray-blue canvas background
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        titleTextStyle: TextStyle(
          color: Colors.grey.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.teal.shade800,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.teal.shade800,
      ),
    );

    // 2. Dark Theme: Charcoal navy canvas with glowing emerald details
    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF10B981), // Emerald accent
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF10B981), // Glowing emerald
        primaryContainer: const Color(0xFF1E293B),
        secondary: Colors.cyanAccent,
        surface: const Color(0xFF121824), // Deep charcoal navy slate canvas
      ),
      scaffoldBackgroundColor: const Color(0xFF121824),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E293B),
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFF10B981),
        unselectedLabelColor: Colors.white70,
        indicatorColor: Color(0xFF10B981),
      ),
    );

    return MaterialApp(
      title: 'StockAlert',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: NavigationShell(
        themeMode: _themeMode,
        onThemeToggle: _toggleTheme,
      ),
    );
  }
}

class NavigationShell extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onThemeToggle;

  const NavigationShell({
    super.key,
    required this.themeMode,
    required this.onThemeToggle,
  });

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;

  // Render screens dynamically to trigger initState and database refresh on switch
  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return DashboardScreen(
          onNavigateToInventory: () => setState(() => _currentIndex = 1),
          onNavigateToScanner: () => setState(() => _currentIndex = 2),
          onNavigateToSupplier: () => setState(() => _currentIndex = 3),
        );
      case 1:
        return const InventoryScreen();
      case 2:
        return const ScannerScreen();
      case 3:
        return const SupplierScreen();
      default:
        return const Center(child: Text('Screen not found'));
    }
  }

  String _getScreenTitle() {
    switch (_currentIndex) {
      case 0:
        return 'StockAlert';
      case 1:
        return 'Pharmacy Stock';
      case 2:
        return 'Barcode Scanner';
      case 3:
        return 'Procurement Engine';
      default:
        return 'StockAlert';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.healing_outlined,
              color: isDark ? const Color(0xFF10B981) : Colors.teal.shade800,
            ),
            const SizedBox(width: 10),
            Text(_getScreenTitle()),
          ],
        ),
        actions: [
          // Theme toggler switch icon
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: isDark ? Colors.amberAccent : Colors.teal.shade900,
              ),
              onPressed: widget.onThemeToggle,
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Procure',
          ),
        ],
      ),
    );
  }
}
