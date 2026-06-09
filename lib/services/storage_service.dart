// services/storage_service.dart
// ============================================================
// SERVICE PENYIMPANAN DATA TERENKRIPSI
// Semua data sensitif disimpan terenkripsi AES-256
// ============================================================

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import 'security_service.dart';

class StorageService {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys
  static const _pinKey          = 'bank_pin_hash';
  static const _balanceKey      = 'bank_balance';
  static const _accountKey      = 'bank_account_number';
  static const _ownerKey        = 'bank_owner_name';
  static const _transactionsKey = 'bank_transactions';
  static const _attemptsKey     = 'login_attempts';
  static const _lockKey         = 'lock_until';
  static const _sessionKey      = 'session_active';

  static const int maxAttempts       = 3;
  static const int lockSeconds       = 60;
  static const int sessionTimeoutMin = 5; // session timeout 5 menit

  // ----------------------------------------------------------
  // SETUP AKUN AWAL (data dummy)
  // ----------------------------------------------------------
  static Future<void> initDummyAccount() async {
    final exists = await _secure.read(key: _accountKey);
    if (exists != null) return;

    // Simpan data dummy terenkripsi
    await _secure.write(key: _accountKey, value: SecurityService.encryptAES('1234-5678-9012-3456'));
    await _secure.write(key: _ownerKey,   value: SecurityService.encryptAES('Budi Santoso'));
    await _secure.write(key: _balanceKey, value: SecurityService.encryptAES('5000000'));
  }

  // ----------------------------------------------------------
  // MANAJEMEN PIN
  // ----------------------------------------------------------
  static Future<void> savePIN(String pin) async {
    await _secure.write(key: _pinKey, value: SecurityService.hashPIN(pin));
  }

  static Future<bool> isPINSet() async {
    final h = await _secure.read(key: _pinKey);
    return h != null && h.isNotEmpty;
  }

  static Future<bool> verifyPIN(String pin) async {
    final stored = await _secure.read(key: _pinKey);
    if (stored == null) return false;
    return SecurityService.verifyPIN(pin, stored);
  }

  // ----------------------------------------------------------
  // PEMBATASAN LOGIN (Rate Limiting)
  // ----------------------------------------------------------
  static Future<int>  getAttempts() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_attemptsKey) ?? 0;
  }

  static Future<void> incrementAttempts() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_attemptsKey, (p.getInt(_attemptsKey) ?? 0) + 1);
  }

  static Future<void> resetAttempts() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_attemptsKey, 0);
    await p.remove(_lockKey);
  }

  static Future<void> lockAccount() async {
    final p = await SharedPreferences.getInstance();
    final until = DateTime.now().add(Duration(seconds: lockSeconds)).millisecondsSinceEpoch;
    await p.setInt(_lockKey, until);
  }

  static Future<bool> isLocked() async {
    final p = await SharedPreferences.getInstance();
    final until = p.getInt(_lockKey);
    if (until == null) return false;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  static Future<int> lockRemaining() async {
    final p = await SharedPreferences.getInstance();
    final until = p.getInt(_lockKey);
    if (until == null) return 0;
    final rem = until - DateTime.now().millisecondsSinceEpoch;
    return rem > 0 ? (rem / 1000).ceil() : 0;
  }

  // ----------------------------------------------------------
  // SESSION MANAGEMENT
  // ----------------------------------------------------------
  static Future<void> startSession() async {
    final p = await SharedPreferences.getInstance();
    final expiry = DateTime.now().add(Duration(minutes: sessionTimeoutMin)).millisecondsSinceEpoch;
    await p.setInt(_sessionKey, expiry);
  }

  static Future<bool> isSessionValid() async {
    final p = await SharedPreferences.getInstance();
    final expiry = p.getInt(_sessionKey);
    if (expiry == null) return false;
    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  static Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_sessionKey);
  }

  // ----------------------------------------------------------
  // DATA REKENING (terenkripsi AES-256)
  // ----------------------------------------------------------
  static Future<String> getAccountNumber() async {
    final enc = await _secure.read(key: _accountKey) ?? '';
    return enc.isEmpty ? '' : SecurityService.decryptAES(enc);
  }

  static Future<String> getOwnerName() async {
    final enc = await _secure.read(key: _ownerKey) ?? '';
    return enc.isEmpty ? '' : SecurityService.decryptAES(enc);
  }

  static Future<double> getBalance() async {
    final enc = await _secure.read(key: _balanceKey) ?? '';
    if (enc.isEmpty) return 0;
    final decrypted = SecurityService.decryptAES(enc);
    return double.tryParse(decrypted) ?? 0;
  }

  static Future<void> saveBalance(double balance) async {
    await _secure.write(key: _balanceKey, value: SecurityService.encryptAES(balance.toString()));
  }

  // Baca saldo RAW (terenkripsi) untuk demo pengujian
  static Future<String> getBalanceRaw() async {
    return await _secure.read(key: _balanceKey) ?? '(kosong)';
  }

  // ----------------------------------------------------------
  // RIWAYAT TRANSAKSI (terenkripsi AES-256)
  // ----------------------------------------------------------
  static Future<List<BankTransaction>> getTransactions() async {
    final raw = await _secure.read(key: _transactionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) {
        final decrypted = {
          'id':            item['id'],
          'type':          SecurityService.decryptAES(item['type']),
          'amount':        SecurityService.decryptAES(item['amount']),
          'description':   SecurityService.decryptAES(item['description']),
          'targetAccount': SecurityService.decryptAES(item['targetAccount']),
          'createdAt':     item['createdAt'],
        };
        return BankTransaction.fromMap(decrypted);
      }).toList();
    } catch (_) { return []; }
  }

  static Future<void> addTransaction(BankTransaction tx) async {
    final existing = await getTransactions();
    existing.insert(0, tx);

    final encList = existing.map((t) => {
      'id':            t.id,
      'type':          SecurityService.encryptAES(t.type),
      'amount':        SecurityService.encryptAES(t.amount.toString()),
      'description':   SecurityService.encryptAES(t.description),
      'targetAccount': SecurityService.encryptAES(t.targetAccount),
      'createdAt':     t.createdAt.toIso8601String(),
    }).toList();

    await _secure.write(key: _transactionsKey, value: jsonEncode(encList));
  }

  static Future<String> getTransactionsRaw() async {
    return await _secure.read(key: _transactionsKey) ?? '(kosong)';
  }

  static Future<void> clearAll() async {
    await _secure.deleteAll();
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}
