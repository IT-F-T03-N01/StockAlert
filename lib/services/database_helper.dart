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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

 Future _upgradeDB(Database db, int oldVersion, int newVersion) async {

  if (oldVersion < 2) {

    final columns = await db.rawQuery("PRAGMA table_info(medicines)");

    final hasPrice = columns.any(

      (column) => column['name'] == 'price',

    );

    if (!hasPrice) {

      await db.execute(

        'ALTER TABLE medicines ADD COLUMN price REAL NOT NULL DEFAULT 0',

      );

    }

  }

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
        batchNumber TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0
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

    await db.rawInsert('''
      INSERT INTO medicines (id, name, category, quantity, minStockThreshold, barcode, expiryDate, batchNumber, price)
      VALUES 
      ('m1', 'Amoxicillin 500mg Capsule', 'Antibiotics', 12, 30, '8901234567890', '${DateTime.now().add(const Duration(days: 45)).toIso8601String()}', 'AMX-2026-004', 8.50),
      ('m2', 'Paracetamol 500mg Tablet', 'Analgesics', 350, 50, '7501234567891', '${DateTime.now().add(const Duration(days: 400)).toIso8601String()}', 'PCT-2025-089', 2.00),
      ('m3', 'Metformin 850mg XR', 'Antidiabetics', 85, 20, '6901234567892', '${DateTime.now().subtract(const Duration(days: 5)).toIso8601String()}', 'MET-2024-112', 5.75),
      ('m4', 'Insulin Glargine 100IU', 'Hormones', 22, 15, '5901234567893', '${DateTime.now().add(const Duration(days: 20)).toIso8601String()}', 'INS-2026-002', 45.00),
      ('m5', 'Vitamin C 1000mg', 'Supplements', 210, 40, '4901234567894', '${DateTime.now().add(const Duration(days: 150)).toIso8601String()}', 'VTC-2025-071', 3.25),
      ('m6', 'Panadol Extra', 'Analgesics', 200, 50, '3901234567895', '${DateTime.now().add(const Duration(days: 300)).toIso8601String()}', 'PX12345', 4.00)
    ''');
  }

  // Medicine CRUD
  Future<List<Medicine>> getInventory() async {
    final db = await instance.database;
    final result = await db.query('medicines', orderBy: 'name ASC');
    return result.map((json) => Medicine.fromJson(json)).toList();
  }

  Future<Medicine?> getMedicineByBarcode(String barcode) async {
    final db = await instance.database;
    final result = await db.query('medicines', where: 'barcode = ?', whereArgs: [barcode]);
    if (result.isEmpty) return null;
    return Medicine.fromJson(result.first);
  }

  Future<int> insertMedicine(Medicine medicine) async {
    final db = await instance.database;
    return await db.insert('medicines', medicine.toJson());
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

  Future<int> updateMedicinePrice(String id, double price) async {
    final db = await instance.database;
    return await db.update(
      'medicines',
      {'price': price},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMedicine(String id) async {
    final db = await instance.database;
    return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
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