import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier.dart';

/// Frontend-only supplier state — in memory, seeded with one sample supplier.
class SupplierProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final List<Supplier> _suppliers = [];

  List<Supplier> get suppliers => List.unmodifiable(_suppliers);

  SupplierProvider() {
    _suppliers.add(Supplier(
      id: _uuid.v4(),
      name: 'MediSupply Ghana Ltd',
      contactPerson: 'Ama Owusu',
      phone: '+233 24 000 0000',
      email: 'orders@medisupply.example',
      address: 'Spintex Road, Accra',
    ));
  }

  Supplier? byId(String? id) {
    if (id == null) return null;
    try {
      return _suppliers.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    _suppliers.add(supplier);
    notifyListeners();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final i = _suppliers.indexWhere((s) => s.id == supplier.id);
    if (i != -1) _suppliers[i] = supplier;
    notifyListeners();
  }

  Future<void> deleteSupplier(String id) async {
    _suppliers.removeWhere((s) => s.id == id);
    notifyListeners();
  }
}
