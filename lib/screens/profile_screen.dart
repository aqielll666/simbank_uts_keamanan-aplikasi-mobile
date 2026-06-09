// screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/security_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name    = '';
  String _account = '';
  bool   _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final name    = await StorageService.getOwnerName();
    final account = await StorageService.getAccountNumber();
    setState(() { _name = name; _account = account; _loading = false; });
  }

  void _showChangePIN() {
    final oldPin = TextEditingController();
    final newPin = TextEditingController();
    String err = '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF0D2137),
          title: const Text('Ganti PIN', style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (err.isNotEmpty)
              Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(err, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
            TextField(controller: oldPin, obscureText: true, keyboardType: TextInputType.number, maxLength: 6,
                style: const TextStyle(color: Colors.white),
                decoration: _deco('PIN Lama')),
            const SizedBox(height: 10),
            TextField(controller: newPin, obscureText: true, keyboardType: TextInputType.number, maxLength: 6,
                style: const TextStyle(color: Colors.white),
                decoration: _deco('PIN Baru (6 digit)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                if (oldPin.text.length != 6 || newPin.text.length != 6) {
                  setD(() => err = 'PIN harus 6 digit'); return;
                }
                final ok = await StorageService.verifyPIN(oldPin.text);
                if (!ok) { setD(() => err = 'PIN lama salah!'); return; }
                await StorageService.savePIN(newPin.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN berhasil diubah!'), backgroundColor: Colors.green));
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
    filled: true, fillColor: Colors.white.withOpacity(0.08),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    counterStyle: const TextStyle(color: Colors.white38),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2342),
        title: const Text('Profil Nasabah', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Avatar
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(color: Color(0xFF1565C0), shape: BoxShape.circle),
            child: const Icon(Icons.person, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(_name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text('Nasabah SimBank', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),

          // Info rekening
          _infoCard('Nomor Rekening', _account, Icons.credit_card),
          const SizedBox(height: 10),
          _infoCard('Jenis Rekening', 'Tabungan SimBank', Icons.account_balance),
          const SizedBox(height: 10),
          _infoCard('Status', 'Aktif & Terverifikasi', Icons.verified_user),
          const SizedBox(height: 10),
          _infoCard('Enkripsi Data', 'AES-256-CBC', Icons.enhanced_encryption),
          const SizedBox(height: 10),
          _infoCard('Hash PIN', 'SHA-256', Icons.fingerprint),
          const SizedBox(height: 24),

          // Tombol ganti PIN
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showChangePIN,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), padding: const EdgeInsets.all(14)),
              icon: const Icon(Icons.lock_reset, color: Colors.white),
              label: const Text('Ganti PIN', style: TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await StorageService.clearSession();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.all(14),
              ),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Keluar', style: TextStyle(color: Colors.red, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}
