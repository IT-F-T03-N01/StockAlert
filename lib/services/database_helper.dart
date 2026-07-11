import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicine.dart';
import '../models/supplier_order.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pharmacy.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        minStockThreshold INTEGER NOT NULL,
        barcode TEXT NOT NULL,
        expiryDate TEXT NOT NULL,
        batchNumber TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE supplier_orders (
        orderId TEXT PRIMARY KEY,
        supplierName TEXT NOT NULL,
        medicineName TEXT NOT NULL,
        quantityRequested INTEGER NOT NULL,
        orderDate TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // Inject Initial Seed Data
    await db.rawInsert('''
      INSERT INTO medicines (id, name, category, quantity, minStockThreshold, barcode, expiryDate, batchNumber)
      VALUES 
      ('m1', 'Amoxicillin 500mg Capsule', 'Antibiotics', 12, 30, '8901234567890', '${DateTime.now().add(const Duration(days: 45)).toIso8601String()}', 'AMX-2026-004'),
      ('m2', 'Paracetamol 500mg Tablet', 'Analgesics', 150, 50, '7501234567891', '${DateTime.now().add(const Duration(days: 400)).toIso8601String()}', 'PCT-2025-089'),
      ('m3', 'Metformin 850mg XR', 'Antidiabetics', 85, 20, '6901234567892', '${DateTime.now().subtract(const Duration(days: 5)).toIso8601String()}', 'MET-2024-112')
    ''');
  }

  // Medicine CRUD
  Future<List<Medicine>> getInventory() async {
    final db = await instance.database;
    final result = await db.query('medicines');
    return result.map((json) => Medicine.fromJson(json)).toList();
  }

  Future<int> updateMedicineQuantity(String id, int quantity) async {
    final db = await instance.database;
    return await db.update(
      'medicines',
      {'quantity': quantity},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Supplier Orders CRUD
  Future<List<SupplierOrder>> getSupplierOrders() async {
    final db = await instance.database;
    final result = await db.query('supplier_orders', orderBy: 'orderDate DESC');
    return result.map((json) => SupplierOrder.fromJson(json)).toList();
  }

  Future<int> insertSupplierOrder(SupplierOrder order) async {
    final db = await instance.database;
    return await db.insert('supplier_orders', order.toJson());
  }

  Future<int> updateOrderStatus(String orderId, String status) async {
    final db = await instance.database;
    return await db.update(
      'supplier_orders',
      {'status': status},
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
  }
}