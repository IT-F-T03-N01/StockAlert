import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local, on-device auth. Password is hashed before storage, never stored in
// plain text. Swap this out for a real backend when the app needs multi-device
// or multi-user accounts.
class AuthService {
  static const _keyLoggedIn = 'isLoggedIn';
  static const _keyUsername = 'username';
  static const _keyPasswordHash = 'passwordHash';

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // True once a user has created an account on this device.
  Future<bool> hasAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyPasswordHash);
  }

  Future<bool> register(String username, String password) async {
    if (username.trim().isEmpty || password.trim().isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username.trim());
    await prefs.setString(_keyPasswordHash, _hashPassword(password));
    await prefs.setBool(_keyLoggedIn, true);
    return true;
  }

  Future<bool> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUsername = prefs.getString(_keyUsername);
    final storedHash = prefs.getString(_keyPasswordHash);
    if (storedUsername == null || storedHash == null) return false;
    if (storedUsername != username.trim()) return false;
    if (_hashPassword(password) != storedHash) return false;
    await prefs.setBool(_keyLoggedIn, true);
    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, false);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? 'Pharmacist';
  }
}