import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../state/vault_repository.dart';

/// Проверка паролей через Have I Been Pwned (k-anonymity, только 5 символов SHA-1).
///
/// В сеть уходит только префикс хэша; полный пароль и полный хэш не передаются.
/// Документация API: https://haveibeenpwned.com/API/v3#PwnedPasswords
class LeakAuditService {
  LeakAuditService._();
  static final LeakAuditService instance = LeakAuditService._();

  static const _baseUrl = 'https://api.pwnedpasswords.com/range/';

  /// Возвращает `true`, если хвост SHA-1 найден в базе утечек (пароль скомпрометирован).
  Future<bool> isPasswordPwned(String password) async {
    if (password.isEmpty) return false;
    final bytes = utf8.encode(password);
    final digest = sha1.convert(bytes);
    final hex = digest.toString().toUpperCase();
    if (hex.length != 40) return false;
    final prefix = hex.substring(0, 5);
    final suffix = hex.substring(5);

    final uri = Uri.parse('$_baseUrl$prefix');
    try {
      final res = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'Tsar-ID-Mobile/1.0',
              'Add-Padding': 'true',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        debugPrint('LeakAuditService: HTTP ${res.statusCode}');
        return false;
      }

      final body = res.body;
      final suffixLower = suffix.toLowerCase();
      for (final line in body.split('\n')) {
        if (line.isEmpty) continue;
        final idx = line.indexOf(':');
        final hashTail = idx > 0 ? line.substring(0, idx).trim() : line.trim();
        if (hashTail.toLowerCase() == suffixLower) {
          return true;
        }
      }
      return false;
    } on Object catch (e) {
      debugPrint('LeakAuditService: $e');
      return false;
    }
  }

  /// Проверяет все записи в [VaultRepository] и обновляет флаги [VaultPasswordEntry.leaked].
  Future<void> auditVault(VaultRepository vault) async {
    final results = <String, bool>{};
    for (final e in vault.entries) {
      final bad = await isPasswordPwned(e.password);
      results[e.id] = bad;
    }
    await vault.updateLeakFlags(results);
  }
}
