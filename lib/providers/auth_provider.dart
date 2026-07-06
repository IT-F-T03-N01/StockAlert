import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/user.dart';

/// Frontend-only auth: accounts live in memory for the life of the app run.
/// Nothing is persisted — restarting the app resets to the seeded accounts.
/// Swap this for a real backend (Firestore, REST API, etc.) later; every
/// screen only talks to this provider's public methods, so that's a
/// contained change.
class AuthProvider extends ChangeNotifier {
  final _uuid = const Uuid();

  final List<AppUser> _users = [];

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  AuthProvider() {
    _seedDefaultAdmin();
  }

  String _hash(String password) => sha256.convert(utf8.encode(password)).toString();

  void _seedDefaultAdmin() {
    _users.add(AppUser(
      id: _uuid.v4(),
      name: 'Abeiku',
      username: 'Abeii',
      passwordHash: _hash('Abei@123'),
      role: UserRole.admin,
    ));
  }

  Future<bool> login(String username, String password) async {
    final hash = _hash(password);
    AppUser? match;
    for (final u in _users) {
      if (u.username == username && u.passwordHash == hash) {
        match = u;
        break;
      }
    }
    if (match == null) return false;
    _currentUser = match;
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  Future<List<AppUser>> getAllUsers() async => List.unmodifiable(_users);

  Future<void> createUser({
    required String name,
    required String username,
    required String password,
    required UserRole role,
  }) async {
    _users.add(AppUser(
      id: _uuid.v4(),
      name: name,
      username: username,
      passwordHash: _hash(password),
      role: role,
    ));
    notifyListeners();
  }

  Future<void> deleteUser(String id) async {
    _users.removeWhere((u) => u.id == id);
    notifyListeners();
  }
}
