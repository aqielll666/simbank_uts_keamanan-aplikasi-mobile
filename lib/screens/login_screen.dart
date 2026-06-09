// screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinCtrl = TextEditingController();
  String _message    = '';
  bool   _isError    = false;
  bool   _isLoading  = false;
  bool   _isPINSetup = false;
  bool   _isLocked   = false;
  int    _attempts   = 0;
  int    _lockSecs   = 0;

  @override
  void initState() { super.initState(); _checkStatus(); }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    await StorageService.initDummyAccount();
    final pinSet  = await StorageService.isPINSet();
    final locked  = await StorageService.isLocked();
    final attempts = await StorageService.getAttempts();
    setState(() {
      _isPINSetup = !pinSet;
      _isLocked   = locked;
      _attempts   = attempts;
      _isLoading  = false;
      if (!pinSet) {
        _message = 'Selamat datang di SimBank!\nBuat PIN 6 digit Anda.';
        _isError = false;
      } else if (locked) {
        _message = 'Akun terkunci sementara.';
        _isError = true;
        _startCountdown();
      } else {
        _message = 'Masukkan PIN 6 digit Anda.';
        _isError = false;
      }
    });
  }

  void _startCountdown() async {
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;
      final rem    = await StorageService.lockRemaining();
      final locked = await StorageService.isLocked();
      setState(() {
        _lockSecs = rem;
        _isLocked = locked;
        if (!locked) {
          _message = 'Masukkan PIN 6 digit Anda.';
          _isError = false;
        } else {
          _message = 'Akun terkunci. Coba lagi dalam $rem detik.';
        }
      });
      if (!locked) break;
    }
  }

  Future<void> _handleSubmit() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 6 || int.tryParse(pin) == null) {
      setState(() { _message = 'PIN harus tepat 6 digit angka.'; _isError = true; });
      return;
    }
    setState(() => _isLoading = true);

    if (_isPINSetup) {
      await StorageService.savePIN(pin);
      await StorageService.startSession();
      setState(() { _message = 'PIN berhasil dibuat!'; _isError = false; _isLoading = false; });
      _pinCtrl.clear();
      await Future.delayed(const Duration(milliseconds: 600));
      _goToDashboard();
    } else {
      if (await StorageService.isLocked()) {
        final rem = await StorageService.lockRemaining();
        setState(() { _message = 'Akun terkunci $rem detik lagi.'; _isError = true; _isLoading = false; _isLocked = true; });
        _startCountdown();
        return;
      }
      final ok = await StorageService.verifyPIN(pin);
      if (ok) {
        await StorageService.resetAttempts();
        await StorageService.startSession();
        setState(() { _isLoading = false; });
        _pinCtrl.clear();
        _goToDashboard();
      } else {
        await StorageService.incrementAttempts();
        final att = await StorageService.getAttempts();
        if (att >= StorageService.maxAttempts) {
          await StorageService.lockAccount();
          setState(() {
            _message  = 'PIN salah 3x! Akun dikunci ${StorageService.lockSeconds} detik.';
            _isError  = true; _attempts = att; _isLocked = true; _isLoading = false;
          });
          _startCountdown();
        } else {
          final sisa = StorageService.maxAttempts - att;
          setState(() { _message = 'PIN salah! Sisa $sisa percobaan.'; _isError = true; _attempts = att; _isLoading = false; });
        }
        _pinCtrl.clear();
      }
    }
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0A2342), Color(0xFF1B4F8A), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Bank
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent, width: 2),
                    ),
                    child: const Icon(Icons.account_balance, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text('SimBank', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
                  const Text('Simulasi Mobile Banking', style: TextStyle(fontSize: 13, color: Colors.white54)),
                  const SizedBox(height: 36),

                  // Card Login
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Column(children: [
                      // Pesan
                      if (_message.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isError ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isError ? Colors.red.withOpacity(0.4) : Colors.green.withOpacity(0.4)),
                          ),
                          child: Row(children: [
                            Icon(_isError ? Icons.warning_amber : Icons.info_outline,
                                color: _isError ? Colors.redAccent : Colors.greenAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_message, style: TextStyle(color: _isError ? Colors.red[200] : Colors.green[200], fontSize: 13))),
                          ]),
                        ),

                      // Input PIN
                      TextField(
                        controller: _pinCtrl,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        enabled: !_isLocked && !_isLoading,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 26, letterSpacing: 12),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '● ● ● ● ● ●',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 20, letterSpacing: 8),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
                        ),
                        onSubmitted: (_) => _handleSubmit(),
                      ),

                      // Dot indikator percobaan
                      if (!_isPINSetup && _attempts > 0) ...[
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('Percobaan: ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ...List.generate(StorageService.maxAttempts, (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _attempts ? Colors.red : Colors.white.withOpacity(0.25),
                            ),
                          )),
                        ]),
                      ],
                      const SizedBox(height: 20),

                      // Tombol
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          onPressed: (_isLocked || _isLoading) ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            disabledBackgroundColor: Colors.grey.withOpacity(0.2),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isPINSetup ? 'Buat PIN' : 'Masuk', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async { await StorageService.clearAll(); _pinCtrl.clear(); _checkStatus(); },
                        child: Text('Reset Data (Demo)', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 24),
                  // Badge keamanan
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      _badge(Icons.fingerprint, 'PIN di-hash SHA-256 (tidak disimpan plaintext)'),
                      _badge(Icons.lock, 'Data rekening terenkripsi AES-256'),
                      _badge(Icons.block, 'Kunci otomatis setelah 3x PIN salah'),
                      _badge(Icons.timer, 'Session timeout ${StorageService.sessionTimeoutMin} menit'),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.blueAccent),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 11))),
    ]),
  );

  @override
  void dispose() { _pinCtrl.dispose(); super.dispose(); }
}
