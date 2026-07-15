import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../main.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  String _username = 'Pharmacist';

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final username = await _authService.getUsername();
    if (!mounted) return;
    setState(() => _username = username);
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Color(0xFFA32D2D))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _menuTile({required IconData icon, required String title, required VoidCallback onTap, Color? iconColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (iconColor ?? StockAlertApp.primaryTeal).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor ?? StockAlertApp.primaryTeal),
        ),
        title: Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w500, fontSize: 14, color: iconColor)),
        trailing: iconColor == null ? const Icon(Icons.arrow_forward_ios, size: 14) : null,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: StockAlertApp.primaryTeal.withOpacity(0.1),
                  child: Icon(Icons.person, size: 40, color: StockAlertApp.primaryTeal),
                ),
                const SizedBox(height: 12),
                Text(_username, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Store Manager', style: GoogleFonts.manrope(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _menuTile(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () {}),
          _menuTile(icon: Icons.security_outlined, title: 'Security', onTap: () {}),
          _menuTile(icon: Icons.backup_outlined, title: 'Backup Data', onTap: () {}),
          const SizedBox(height: 8),
          _menuTile(
            icon: Icons.logout,
            title: 'Logout',
            iconColor: const Color(0xFFA32D2D),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }
}