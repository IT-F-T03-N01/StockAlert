import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/medicine.dart';
import '../models/supplier_order.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // In-memory mock storage for unit/widget tests
  List<Medicine>? _mockMedicines;
  final List<SupplierOrder> _mockOrders = [];

  DatabaseHelper._init();

  bool get isTesting {
    return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pharmacy_inventory.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  FutureOr<void> _createDB(Database db, int version) async {
    // 1. Create Medicines Table
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        genericName TEXT NOT NULL,
        barcode TEXT NOT NULL UNIQUE,
        quantity INTEGER NOT NULL,
        minQuantity INTEGER NOT NULL,
        expiryDate TEXT NOT NULL,
        dosageForm TEXT NOT NULL,
        location TEXT NOT NULL,
        price REAL NOT NULL
      )
    ''');

    // 2. Create Supplier Orders Table
    await db.execute('''
      CREATE TABLE supplier_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplierName TEXT NOT NULL,
        orderDate TEXT NOT NULL,
        status TEXT NOT NULL,
        itemsJson TEXT NOT NULL,
        totalAmount REAL NOT NULL
      )
    ''');

    // 3. Seed initial realistic pharmacy data
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now();

    final medicines = _getSeedMedicines(now);

    for (final med in medicines) {
      await db.insert('medicines', med.toMap());
    }
  }

  List<Medicine> _getSeedMedicines(DateTime now) {
    return [
      Medicine(
        name: 'Paracetamol',
        genericName: 'Acetaminophen',
        barcode: '8801234567890',
        quantity: 15,
        minQuantity: 20, // Low stock
        expiryDate: now.add(const Duration(days: 180)), // 6 months (Healthy)
        dosageForm: 'Tablet',
        location: 'Shelf A1',
        price: 1.50,
      ),
      Medicine(
        name: 'Amoxicillin',
        genericName: 'Amoxil',
        barcode: '8809876543210',
        quantity: 50,
        minQuantity: 15, // Healthy stock
        expiryDate: now.add(const Duration(days: 45)), // 45 days (Near Expiry)
        dosageForm: 'Capsule',
        location: 'Shelf B3',
        price: 12.00,
      ),
      Medicine(
        name: 'Metformin',
        genericName: 'Glucophage',
        barcode: '5012345678901',
        quantity: 120,
        minQuantity: 40,
        expiryDate: now.add(const Duration(days: 365)), // 1 year (Healthy)
        dosageForm: 'Tablet',
        location: 'Shelf C1',
        price: 8.50,
      ),
      Medicine(
        name: 'Ibuprofen',
        genericName: 'Advil',
        barcode: '4001234567892',
        quantity: 8,
        minQuantity: 30, // Low stock & Expired
        expiryDate: now.subtract(const Duration(days: 10)), // Expired
        dosageForm: 'Tablet',
        location: 'Shelf A2',
        price: 3.20,
      ),
      Medicine(
        name: 'Cetirizine',
        genericName: 'Zyrtec',
        barcode: '3011234567893',
        quantity: 4,
        minQuantity: 15, // Low stock & Near Expiry
        expiryDate: now.add(const Duration(days: 25)), // 25 days (Near Expiry)
        dosageForm: 'Tablet',
        location: 'Shelf D2',
        price: 4.50,
      ),
      Medicine(
        name: 'Atorvastatin',
        genericName: 'Lipitor',
        barcode: '7611234567894',
        quantity: 65,
        minQuantity: 20,
        expiryDate: now.add(const Duration(days: 540)), // 1.5 years (Healthy)
        dosageForm: 'Tablet',
        location: 'Shelf C4',
        price: 24.50,
      ),
      Medicine(
        name: 'Cough Syrup',
        genericName: 'Guaifenesin',
        barcode: '6901234567895',
        quantity: 2,
        minQuantity: 10, // Low stock & Expired
        expiryDate: now.subtract(const Duration(days: 45)), // Expired
        dosageForm: 'Syrup',
        location: 'Fridge F1',
        price: 9.00,
      ),
    ];
  }

  void _seedMockDataInMemory() {
    _mockMedicines = _getSeedMedicines(DateTime.now());
    // Auto-generate ids for mock list
    for (int i = 0; i < _mockMedicines!.length; i++) {
      _mockMedicines![i] = _mockMedicines![i].copyWith(id: i + 1);
    }
  }

  // ================= MEDICINES CRUD =================

  Future<int> insertMedicine(Medicine medicine) async {
    if (isTesting) {
      if (_mockMedicines == null) _seedMockDataInMemory();
      final id = medicine.id ?? (_mockMedicines!.length + 1);
      final medWithId = medicine.copyWith(id: id);
      _mockMedicines!.removeWhere((m) => m.barcode == medicine.barcode);
      _mockMedicines!.add(medWithId);
      return id;
    }

    final db = await instance.database;
    return await db.insert('medicines', medicine.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Medicine>> getInventory() async {
    if (isTesting) {
      if (_mockMedicines == null) _seedMockDataInMemory();
      final list = List<Medicine>.from(_mockMedicines!);
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    }

    final db = await instance.database;
    final result = await db.query('medicines', orderBy: 'name ASC');
    return result.map((json) => Medicine.fromMap(json)).toList();
  }

  Future<Medicine?> getMedicineById(int id) async {
    if (isTesting) {
      if (_mockMedicines == null) _seedMockDataInMemory();
      final matches = _mockMedicines!.where((m) => m.id == id).toList();
      return matches.isNotEmpty ? matches.first : null;
    }

    final db = await instance.database;
    final result = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Medicine.fromMap(result.first);
    }
    return null;
  }

  Future<Medicine?> getMedicineByBarcode(String barcode) async {
    if (isTesting) {
      if (_mockMedicines == null) _seedMockDataInMemory();
      final matches = _mockMedicines!.where((m) => m.barcode == barcode).toList();
      return matches.isNotEmpty ? matches.first : null;
    }

    final db = await instance.database;
    final result = await db.query(
      'medicines',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (result.isNotEmpty) {
      return Medicine.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateMedicine(Medicine medicine) async {
    if (isTesting) {
      if (_mockMedicines == null) _seedMockDataInMemory();
      final idx = _mockMedicines!.indexWhere((m) => m.id == medicine.id);
      if (idx != -1) {
        _mockMedicines![idx] = medicine;
        return 1;
      }
      return 0;
    }

    final db = await instance.database;
    return await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    if (isTesting) {
      if (_mockMedicines == null) _seedMockDataInMemory();
      _mockMedicines!.removeWhere((m) => m.id == id);
      return 1;
    }

    final db = await instance.database;
    return await db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ================= SUPPLIER ORDERS CRUD =================

  Future<int> insertSupplierOrder(SupplierOrder order) async {
    if (isTesting) {
      final id = order.id ?? (_mockOrders.length + 1);
      _mockOrders.add(order.copyWith(id: id));
      return id;
    }

    final db = await instance.database;
    return await db.insert('supplier_orders', order.toMap());
  }

  Future<List<SupplierOrder>> getSupplierOrders() async {
    if (isTesting) {
      final list = List<SupplierOrder>.from(_mockOrders);
      list.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      return list;
    }

    final db = await instance.database;
    final result = await db.query('supplier_orders', orderBy: 'orderDate DESC');
    return result.map((json) => SupplierOrder.fromMap(json)).toList();
  }

  Future<int> updateSupplierOrder(SupplierOrder order) async {
    if (isTesting) {
      final idx = _mockOrders.indexWhere((o) => o.id == order.id);
      if (idx != -1) {
        _mockOrders[idx] = order;
        return 1;
      }
      return 0;
    }

    final db = await instance.database;
    return await db.update(
      'supplier_orders',
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  /// Transactional receipt tracking: receive an order, update product quantities in database
  Future<bool> receiveSupplierOrder(SupplierOrder order) async {
    if (isTesting) {
      if (_mockMedicines == null) _seedMockDataInMemory();

      // 1. Mark order as received
      final idx = _mockOrders.indexWhere((o) => o.id == order.id);
      if (idx != -1) {
        _mockOrders[idx] = order.copyWith(status: 'Received');
      }

      // 2. Increment medicine quantities in-memory
      for (final item in order.items) {
        final medIdx = _mockMedicines!.indexWhere((m) => m.barcode == item.barcode);
        if (medIdx != -1) {
          final currentMed = _mockMedicines![medIdx];
          _mockMedicines![medIdx] = currentMed.copyWith(quantity: currentMed.quantity + item.quantity);
        }
      }
      return true;
    }

    final db = await instance.database;
    final batch = db.batch();

    // 1. Mark order as received
    final updatedOrder = order.copyWith(status: 'Received');
    batch.update(
      'supplier_orders',
      updatedOrder.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );

    // 2. Increment medicine quantities in batch
    for (final item in order.items) {
      // Find the medicine in database
      final result = await db.query(
        'medicines',
        where: 'barcode = ?',
        whereArgs: [item.barcode],
      );
      if (result.isNotEmpty) {
        final currentMed = Medicine.fromMap(result.first);
        final newQuantity = currentMed.quantity + item.quantity;
        batch.update(
          'medicines',
          {'quantity': newQuantity},
          where: 'id = ?',
          whereArgs: [currentMed.id],
        );
      }
    }

    await batch.commit(noResult: true);
    return true;
  }
}
