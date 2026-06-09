import '../services/security_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/transaction_model.dart';
import 'package:uuid/uuid.dart';
import 'login_screen.dart';
import 'security_demo_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _balance    = 0;
  String _name       = '';
  String _account    = '';
  List<BankTransaction> _transactions = [];
  bool   _isLoading  = true;
  bool   _showBalance = false;

  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() { super.initState(); _loadData(); _checkSession(); }

  Future<void> _checkSession() async {
    // Cek session timeout setiap 30 detik
    while (mounted) {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted) break;
      final valid = await StorageService.isSessionValid();
      if (!valid) {
        await StorageService.clearSession();
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final balance = await StorageService.getBalance();
    final name    = await StorageService.getOwnerName();
    final account = await StorageService.getAccountNumber();
    final txs     = await StorageService.getTransactions();
    setState(() {
      _balance      = balance;
      _name         = name;
      _account      = account;
      _transactions = txs;
      _isLoading    = false;
    });
  }

  void _showTransferDialog() => _showTransactionDialog('transfer');
  void _showTarikDialog()    => _showTransactionDialog('tarik');
  void _showTopUpDialog()    => _showTransactionDialog('topup');

  void _showTransactionDialog(String type) {
    final amountCtrl  = TextEditingController();
    final targetCtrl  = TextEditingController();
    final descCtrl    = TextEditingController();
    String error = '';

    final titles = {'transfer': 'Transfer', 'tarik': 'Tarik Tunai', 'topup': 'Top Up'};
    final colors = {'transfer': Colors.blueAccent, 'tarik': Colors.orange, 'topup': Colors.green};
    final icons  = {'transfer': Icons.send, 'tarik': Icons.atm, 'topup': Icons.add_circle};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF0D2137),
          title: Row(children: [
            Icon(icons[type], color: colors[type], size: 22),
            const SizedBox(width: 8),
            Text(titles[type]!, style: const TextStyle(color: Colors.white, fontSize: 18)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (error.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),

              // Nomor rekening tujuan (khusus transfer)
              if (type == 'transfer') ...[
                _dialogInput(targetCtrl, 'No. Rekening Tujuan (dummy)', TextInputType.number),
                const SizedBox(height: 10),
              ],

              // Nominal
              _dialogInput(amountCtrl, 'Nominal (Rp)', TextInputType.number),
              const SizedBox(height: 10),

              // Keterangan
              _dialogInput(descCtrl, 'Keterangan', TextInputType.text),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colors[type]),
              onPressed: () async {
                // Validasi input
                final amtStr = amountCtrl.text.trim().replaceAll('.', '');
                final target = targetCtrl.text.trim();
                final desc   = descCtrl.text.trim();

                if (!SecurityService.isInputSafe(amtStr) || !SecurityService.isInputSafe(desc)) {
                  setD(() => error = 'Input mengandung karakter berbahaya!');
                  return;
                }
                if (!SecurityService.isValidAmount(amtStr)) {
                  setD(() => error = 'Nominal tidak valid (maks Rp 50.000.000)');
                  return;
                }
                if (type == 'transfer' && (target.isEmpty || target.length < 10)) {
                  setD(() => error = 'No. rekening minimal 10 digit');
                  return;
                }
                if (desc.isEmpty) {
                  setD(() => error = 'Keterangan tidak boleh kosong');
                  return;
                }

                final amount = double.parse(amtStr);
                final currentBalance = await StorageService.getBalance();

                if ((type == 'transfer' || type == 'tarik') && amount > currentBalance) {
                  setD(() => error = 'Saldo tidak mencukupi!');
                  return;
                }

                // Proses transaksi
                double newBalance = currentBalance;
                if (type == 'transfer' || type == 'tarik') {
                  newBalance -= amount;
                } else {
                  newBalance += amount;
                }

                await StorageService.saveBalance(newBalance);
                await StorageService.addTransaction(BankTransaction(
                  id:            const Uuid().v4(),
                  type:          type,
                  amount:        amount,
                  description:   desc,
                  targetAccount: type == 'transfer' ? target : '-',
                  createdAt:     DateTime.now(),
                ));

                Navigator.pop(ctx);
                _loadData();
                _showSuccessSnack(titles[type]!, amount);
              },
              child: Text(titles[type]!, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnack(String type, double amount) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Text('$type ${_fmt.format(amount)} berhasil!'),
      ]),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  void _logout() async {
    await StorageService.clearSession();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: const Color(0xFF0A2342),
                  actions: [
                    IconButton(icon: const Icon(Icons.security, color: Colors.yellowAccent), tooltip: 'Demo Keamanan',
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityDemoScreen())).then((_) => _loadData())),
                    IconButton(icon: const Icon(Icons.person, color: Colors.white70), tooltip: 'Profil',
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _loadData())),
                    IconButton(icon: const Icon(Icons.logout, color: Colors.white70), onPressed: _logout),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Color(0xFF0A2342), Color(0xFF1B4F8A)],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(children: [
                                const Icon(Icons.account_balance, color: Colors.blueAccent, size: 18),
                                const SizedBox(width: 6),
                                const Text('SimBank', style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                                  child: const Row(children: [
                                    Icon(Icons.circle, color: Colors.green, size: 8),
                                    SizedBox(width: 4),
                                    Text('Aktif', style: TextStyle(color: Colors.green, fontSize: 11)),
                                  ]),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              Text('Selamat datang,', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                              Text(_name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Rek: $_account', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                              const SizedBox(height: 12),
                              Row(children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Saldo Rekening', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  _showBalance
                                      ? Text(_fmt.format(_balance), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))
                                      : const Text('Rp ••••••••', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                                ]),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(_showBalance ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                                  onPressed: () => setState(() => _showBalance = !_showBalance),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Menu Transaksi
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      // Tombol aksi
                      Row(children: [
                        _actionBtn(Icons.send, 'Transfer', Colors.blueAccent, _showTransferDialog),
                        const SizedBox(width: 12),
                        _actionBtn(Icons.atm, 'Tarik\nTunai', Colors.orange, _showTarikDialog),
                        const SizedBox(width: 12),
                        _actionBtn(Icons.add_circle, 'Top Up', Colors.green, _showTopUpDialog),
                      ]),
                      const SizedBox(height: 20),

                      // Riwayat Transaksi
                      Row(children: [
                        const Text('Riwayat Transaksi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                          child: const Row(children: [
                            Icon(Icons.lock, color: Colors.greenAccent, size: 12),
                            SizedBox(width: 4),
                            Text('Terenkripsi', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      if (_transactions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text('Belum ada transaksi', style: TextStyle(color: Colors.white38))),
                        )
                      else
                        ..._transactions.take(10).map((tx) => _txCard(tx)),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  Widget _txCard(BankTransaction tx) {
    final isDebit  = tx.type == 'transfer' || tx.type == 'tarik';
    final color    = isDebit ? Colors.red : Colors.green;
    final icon     = tx.type == 'transfer' ? Icons.send : tx.type == 'tarik' ? Icons.atm : Icons.add_circle;
    final typeLabel = tx.type == 'transfer' ? 'Transfer' : tx.type == 'tarik' ? 'Tarik Tunai' : 'Top Up';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(typeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
          Text(tx.description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (tx.targetAccount != '-')
            Text('→ ${tx.targetAccount}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isDebit ? '-' : '+'}${_fmt.format(tx.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(DateFormat('dd/MM HH:mm').format(tx.createdAt),
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ]),
    );
  }

  TextField _dialogInput(TextEditingController ctrl, String hint, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}
