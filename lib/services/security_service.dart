// services/security_service.dart
// ============================================================
// SERVICE KEAMANAN UTAMA
// Kriptografi Klasik: Caesar Cipher (demo pembanding)
// Kriptografi Modern: SHA-256 hashing + AES-256-CBC enkripsi
// ============================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class SecurityService {

  // ----------------------------------------------------------
  // KRIPTOGRAFI KLASIK - Caesar Cipher (LEMAH, hanya demo)
  // ----------------------------------------------------------
  static String caesarEncrypt(String text, int shift) {
    return text.split('').map((char) {
      if (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) {
        return String.fromCharCode((char.codeUnitAt(0) - 65 + shift) % 26 + 65);
      } else if (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122) {
        return String.fromCharCode((char.codeUnitAt(0) - 97 + shift) % 26 + 97);
      }
      return char;
    }).join('');
  }

  static String caesarDecrypt(String text, int shift) =>
      caesarEncrypt(text, 26 - shift);

  // ----------------------------------------------------------
  // KRIPTOGRAFI MODERN - SHA-256 untuk hashing PIN
  // One-way hash: tidak bisa di-reverse
  // ----------------------------------------------------------
  static String hashPIN(String pin) {
    final bytes  = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyPIN(String inputPin, String storedHash) =>
      hashPIN(inputPin) == storedHash;

  // ----------------------------------------------------------
  // KRIPTOGRAFI MODERN - AES-256-CBC untuk enkripsi data
  // Standar enkripsi industri perbankan
  // ----------------------------------------------------------
  static const String _keyStr = 'SimBank2025UTS-ITTS-AES256Key32!';
  static const String _ivStr  = 'SimBankIV2025!16';

  static enc.Key get _key => enc.Key.fromUtf8(_keyStr);
  static enc.IV  get _iv  => enc.IV.fromUtf8(_ivStr);

  static String encryptAES(String plaintext) {
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    return encrypter.encrypt(plaintext, iv: _iv).base64;
  }

  static String decryptAES(String cipherBase64) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(cipherBase64, iv: _iv);
    } catch (_) {
      return '[Gagal mendekripsi]';
    }
  }

  // Validasi input - cegah karakter berbahaya
  static bool isInputSafe(String input) {
    final dangerous = ['<script', 'DROP TABLE', "' OR '", '--', ';--', 'SELECT *'];
    final lower = input.toLowerCase();
    return !dangerous.any((d) => lower.contains(d.toLowerCase()));
  }

  // Validasi nominal uang
  static bool isValidAmount(String input) {
    final amount = double.tryParse(input.replaceAll('.', '').replaceAll(',', ''));
    return amount != null && amount > 0 && amount <= 50000000;
  }
}
