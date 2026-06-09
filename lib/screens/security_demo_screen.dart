// screens/security_demo_screen.dart
import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../services/storage_service.dart';

class SecurityDemoScreen extends StatefulWidget {
  const SecurityDemoScreen({super.key});
  @override State<SecurityDemoScreen> createState() => _SecurityDemoScreenState();
}

class _SecurityDemoScreenState extends State<SecurityDemoScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Tab 1 - Enkripsi
  final _inputCtrl = TextEditingController(text: 'Saldo: Rp 5.000.000 | Rek: 1234-5678-9012-3456');
  String _plain = '', _caesar = '', _aes = '', _aesDecrypted = '';
  bool _hasResult = false;

  // Tab 2 - Storage
  String _rawBalance = '', _rawTx = '';
  bool _loadingStorage = false;

  // Tab 3 - Hashing
  final _pinCtrl    = TextEditingController(text: '123456');
  final _verifyCtrl = TextEditingController();
  String _hash = '', _verifyResult = '';

  // Tab 4 - Validasi Input
  final _inputValCtrl = TextEditingController();
  String _valResult = '';

  @override
  void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); }

  void _runEncryption() {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _plain       = input;
      _caesar      = SecurityService.caesarEncrypt(input, 13);
      _aes         = SecurityService.encryptAES(input);
      _aesDecrypted = SecurityService.decryptAES(_aes);
      _hasResult   = true;
    });
  }

  Future<void> _loadStorage() async {
    setState(() => _loadingStorage = true);
    final bal = await StorageService.getBalanceRaw();
    final tx  = await StorageService.getTransactionsRaw();
    setState(() { _rawBalance = bal; _rawTx = tx; _loadingStorage = false; });
  }

  void _hashDemo() {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) return;
    setState(() { _hash = SecurityService.hashPIN(pin); _verifyResult = ''; _verifyCtrl.clear(); });
  }

  void _verifyDemo() {
    final input    = _verifyCtrl.text.trim();
    final original = _pinCtrl.text.trim();
    final match    = SecurityService.verifyPIN(input, SecurityService.hashPIN(original));
    setState(() {
      _verifyResult = match
          ? '✅ PIN COCOK — Hash identik, akses diterima'
          : '❌ PIN SALAH — Hash berbeda, akses ditolak';
    });
  }

  void _validateInput() {
    final input = _inputValCtrl.text.trim();
    if (input.isEmpty) return;
    final safe   = SecurityService.isInputSafe(input);
    final amount = SecurityService.isValidAmount(input);
    setState(() {
      if (safe && amount) {
        _valResult = '✅ Input AMAN — Nominal valid dan tidak mengandung karakter berbahaya';
      } else if (!safe) {
        _valResult = '❌ Input BERBAHAYA — Terdeteksi karakter/perintah berbahaya (SQL Injection / XSS)';
      } else {
        _valResult = '⚠️ Nominal tidak valid — Harus angka positif maksimal Rp 50.000.000';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2342),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('🔬 Demo Keamanan', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Enkripsi', icon: Icon(Icons.lock, size: 14)),
            Tab(text: 'Storage', icon: Icon(Icons.storage, size: 14)),
            Tab(text: 'Hashing', icon: Icon(Icons.fingerprint, size: 14)),
            Tab(text: 'Validasi', icon: Icon(Icons.shield, size: 14)),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _encryptionTab(),
        _storageTab(),
        _hashingTab(),
        _validationTab(),
      ]),
    );
  }

  // ---- TAB 1 ----
  Widget _encryptionTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Perbandingan Metode Penyimpanan Data'),
      const Text('Bandingkan keamanan: Plaintext vs Caesar Cipher vs AES-256', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 16),
      TextField(controller: _inputCtrl, style: const TextStyle(color: Colors.white), maxLines: 2, decoration: _deco('Data yang akan diuji...')),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _runEncryption,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
        icon: const Icon(Icons.play_arrow, color: Colors.white),
        label: const Text('Jalankan Perbandingan', style: TextStyle(color: Colors.white)),
      )),
      if (_hasResult) ...[
        const SizedBox(height: 16),
        _resultCard('❌ Plaintext (TIDAK AMAN)', 'Data tersimpan apa adanya — siapapun bisa membaca!', _plain, Colors.red, Icons.no_encryption),
        const SizedBox(height: 10),
        _resultCard('⚠️ Caesar Cipher / ROT-13 (LEMAH)', 'Kriptografi klasik — mudah di-brute force dalam hitungan detik!', _caesar, Colors.orange, Icons.history_edu),
        const SizedBox(height: 10),
        _resultCard('✅ AES-256-CBC (AMAN)', 'Kriptografi modern — standar enkripsi perbankan internasional', _aes, Colors.green, Icons.enhanced_encryption),
        const SizedBox(height: 10),
        _resultCard('🔓 Dekripsi AES (verifikasi)', 'Data kembali ke aslinya setelah didekripsi dengan kunci yang benar', _aesDecrypted, Colors.blueAccent, Icons.lock_open),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.yellow.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.yellow.withOpacity(0.3))),
          child: const Text('📌 Kesimpulan: Data perbankan seperti saldo dan nomor rekening HARUS menggunakan AES-256. Caesar Cipher dan Plaintext sangat berbahaya untuk aplikasi keuangan.', style: TextStyle(color: Colors.yellow, fontSize: 12)),
        ),
      ],
    ]),
  );

  // ---- TAB 2 ----
  Widget _storageTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Isi Raw Storage (Terenkripsi)'),
      const Text('Ini adalah data yang tersimpan di storage. Perhatikan bahwa semua data sudah terenkripsi AES-256.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _loadStorage,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: const Text('Lihat Data Storage', style: TextStyle(color: Colors.white)),
      )),
      const SizedBox(height: 14),
      if (_loadingStorage) const Center(child: CircularProgressIndicator())
      else if (_rawBalance.isNotEmpty) ...[
        _rawCard('💰 Raw Data Saldo (Terenkripsi AES-256)', _rawBalance),
        const SizedBox(height: 10),
        _rawCard('📋 Raw Data Transaksi (Terenkripsi AES-256)', _rawTx.length > 300 ? '${_rawTx.substring(0, 300)}...' : _rawTx),
        const SizedBox(height: 14),
        _resultCard('📋 Analisis Keamanan', '', 'Attacker yang berhasil mengakses storage hanya akan melihat ciphertext Base64 AES-256 yang tidak bermakna tanpa kunci dekripsi. Ini membuktikan bahwa enkripsi at-rest (data saat disimpan) berfungsi dengan baik.', Colors.blueAccent, Icons.info_outline),
      ],
    ]),
  );

  // ---- TAB 3 ----
  Widget _hashingTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Demo Hashing PIN dengan SHA-256'),
      const Text('PIN tidak pernah disimpan dalam bentuk aslinya. Hanya hash SHA-256 yang disimpan.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 16),
      TextField(controller: _pinCtrl, keyboardType: TextInputType.number, maxLength: 6, style: const TextStyle(color: Colors.white), decoration: _deco('PIN (contoh: 123456)')),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _hashDemo,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
        icon: const Icon(Icons.tag, color: Colors.white),
        label: const Text('Hash PIN', style: TextStyle(color: Colors.white)),
      )),
      if (_hash.isNotEmpty) ...[
        const SizedBox(height: 14),
        _resultCard('🔐 Hash SHA-256 dari PIN "${_pinCtrl.text}"', 'Ini yang tersimpan di storage — 64 karakter hex, tidak bisa di-reverse!', _hash, Colors.deepPurple, Icons.fingerprint),
        const SizedBox(height: 16),
        _title('Uji Verifikasi PIN'),
        const SizedBox(height: 8),
        TextField(controller: _verifyCtrl, keyboardType: TextInputType.number, maxLength: 6, style: const TextStyle(color: Colors.white), decoration: _deco('Masukkan PIN untuk verifikasi...')),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _verifyDemo,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          icon: const Icon(Icons.verified, color: Colors.white),
          label: const Text('Verifikasi', style: TextStyle(color: Colors.white)),
        )),
        if (_verifyResult.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _verifyResult.contains('✅') ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _verifyResult.contains('✅') ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4)),
            ),
            child: Text(_verifyResult, style: TextStyle(color: _verifyResult.contains('✅') ? Colors.greenAccent : Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    ]),
  );

  // ---- TAB 4 ----
  Widget _validationTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Demo Validasi Input'),
      const Text('Uji input berbahaya (SQL Injection, XSS) dan validasi nominal transaksi.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 16),
      TextField(controller: _inputValCtrl, style: const TextStyle(color: Colors.white), decoration: _deco("Coba ketik: 5000000 atau ' OR '1'='1 atau <script>")),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _validateInput,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
        icon: const Icon(Icons.shield, color: Colors.white),
        label: const Text('Validasi Input', style: TextStyle(color: Colors.white)),
      )),
      if (_valResult.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _valResult.contains('✅') ? Colors.green.withOpacity(0.15) : _valResult.contains('❌') ? Colors.red.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _valResult.contains('✅') ? Colors.green.withOpacity(0.4) : _valResult.contains('❌') ? Colors.red.withOpacity(0.4) : Colors.orange.withOpacity(0.4)),
          ),
          child: Text(_valResult, style: TextStyle(
            color: _valResult.contains('✅') ? Colors.greenAccent : _valResult.contains('❌') ? Colors.redAccent : Colors.orangeAccent,
            fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ],
      const SizedBox(height: 16),
      _title('Contoh Input Berbahaya untuk Diuji:'),
      const SizedBox(height: 8),
      ...[
        "' OR '1'='1",
        '<script>alert("XSS")</script>',
        'DROP TABLE users',
        'SELECT * FROM accounts',
        '-999999',
        '99999999999',
      ].map((e) => GestureDetector(
        onTap: () { _inputValCtrl.text = e; _validateInput(); },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 14),
            const SizedBox(width: 8),
            Text(e, style: const TextStyle(color: Colors.orange, fontSize: 12, fontFamily: 'monospace')),
            const Spacer(),
            const Text('Tap untuk uji', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
        ),
      )),
    ]),
  );

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
  );

  Widget _rawCard(String title, String value) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.4))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.terminal, color: Colors.greenAccent, size: 14), const SizedBox(width: 6), Text(title, style: const TextStyle(color: Colors.greenAccent, fontSize: 12))]),
      const Divider(color: Colors.green),
      Text(value, style: const TextStyle(color: Colors.green, fontSize: 10, fontFamily: 'monospace')),
    ]),
  );

  Widget _resultCard(String label, String sub, String value, Color color, IconData icon) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.4))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 8), Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)))]),
      if (sub.isNotEmpty) ...[const SizedBox(height: 2), Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11))],
      const SizedBox(height: 8),
      Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(6)),
          child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'))),
    ]),
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
    filled: true, fillColor: Colors.white.withOpacity(0.08),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    counterStyle: const TextStyle(color: Colors.white38),
  );

  @override
  void dispose() { _tab.dispose(); _inputCtrl.dispose(); _pinCtrl.dispose(); _verifyCtrl.dispose(); _inputValCtrl.dispose(); super.dispose(); }
}
