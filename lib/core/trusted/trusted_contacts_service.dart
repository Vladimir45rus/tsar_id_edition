import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../security/security_journal_service.dart';
import '../../crypto/utils/secure_buffer.dart';

/// Доверенное лицо (номер в международном формате без + в хранилище или с + в UI).
class TrustedContact {
  TrustedContact({required this.id, required this.phoneDigits, this.label});

  final String id;
  final String phoneDigits;
  final String? label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneDigits': phoneDigits,
        'label': label,
      };

  static TrustedContact fromJson(Map<String, dynamic> j) => TrustedContact(
        id: j['id'] as String,
        phoneDigits: j['phoneDigits'] as String,
        label: j['label'] as String?,
      );
}

/// Активный аварийный токен (AES-256 ключ + метаданные, срок 24 ч).
class EmergencyAccessToken {
  EmergencyAccessToken({
    required this.id,
    required this.tokenPublic,
    required this.createdUtc,
    required this.expiresUtc,
  });

  final String id;

  /// Строка, передаваемая контакту (не хранит открытый ключ сейфа целиком — идентификатор сессии + подпись заглушки).
  final String tokenPublic;
  final DateTime createdUtc;
  final DateTime expiresUtc;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresUtc);
}

/// Сервис доверенных контактов и аварийного доступа к сейфу.
///
/// Реальная выдача прав на расшифровку должна сочетаться с политикой продукта
/// (отдельный wrapped DEK для «аварийного ключа»). Здесь — криптографический
/// токен, журналирование и TTL 24 часа.
class TrustedContactsService extends ChangeNotifier {
  static const _prefsContacts = 'trusted_contacts_json_v1';
  static const _secureTokenPrefix = 'emergency_token_';

  final _secure = const FlutterSecureStorage();
  final _uuid = const Uuid();

  final List<TrustedContact> contacts = [];
  EmergencyAccessToken? _activeToken;
  DateTime? _emergencyUnlockUntil;

  /// Если не null — контакт «вошёл» по токену (локальная симуляция для теста UI).
  DateTime? get emergencyUnlockUntil => _emergencyUnlockUntil;

  bool get isEmergencyWindowActive =>
      _emergencyUnlockUntil != null &&
      DateTime.now().toUtc().isBefore(_emergencyUnlockUntil!);

  EmergencyAccessToken? get activeToken => _activeToken;

  TrustedContactsService() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsContacts);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        contacts
          ..clear()
          ..addAll(
            list.map((e) => TrustedContact.fromJson(e as Map<String, dynamic>)),
          );
      } on Object catch (_) {}
    }
    await _restoreActiveTokenMeta();
    notifyListeners();
  }

  Future<void> _persistContacts() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefsContacts,
      jsonEncode(contacts.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _restoreActiveTokenMeta() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString('emergency_token_active_id');
    final expIso = p.getString('emergency_token_expires');
    final pub = p.getString('emergency_token_public');
    if (id != null && expIso != null && pub != null) {
      final exp = DateTime.tryParse(expIso);
      if (exp != null && DateTime.now().toUtc().isBefore(exp)) {
        _activeToken = EmergencyAccessToken(
          id: id,
          tokenPublic: pub,
          createdUtc: DateTime.now().toUtc(),
          expiresUtc: exp,
        );
        _emergencyUnlockUntil = exp;
      } else {
        await _revokeTokenStorage();
      }
    }
  }

  /// Добавить контакт (не более двух — ограничение ТЗ).
  Future<void> addContact(String phoneRaw, {String? label}) async {
    final digits = phoneRaw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return;
    if (contacts.length >= 2) return;
    contacts.add(TrustedContact(
      id: _uuid.v4(),
      phoneDigits: digits,
      label: label,
    ));
    await _persistContacts();
    notifyListeners();
    await SecurityJournalService.instance.log(
      event: 'trusted_contact_added',
      details: {'digits_len': digits.length},
    );
  }

  Future<void> removeContact(String id) async {
    contacts.removeWhere((c) => c.id == id);
    await _persistContacts();
    notifyListeners();
  }

  /// Генерирует 256-бит материал, сохраняет в SecureStorage, отдаёт публичную строку для SMS / мессенджера.
  Future<EmergencyAccessToken> generateEmergencyToken() async {
    await revokeExpiredTokens();
    final id = _uuid.v4();
    final raw = randomBytes(32);
    final tokenPublic = base64UrlEncode(raw);

    final expires = DateTime.now().toUtc().add(const Duration(hours: 24));
    await _secure.write(
      key: '$_secureTokenPrefix$id',
      value: base64Encode(raw),
    );

    final p = await SharedPreferences.getInstance();
    await p.setString('emergency_token_active_id', id);
    await p.setString('emergency_token_expires', expires.toIso8601String());
    await p.setString('emergency_token_public', tokenPublic);

    _activeToken = EmergencyAccessToken(
      id: id,
      tokenPublic: tokenPublic,
      createdUtc: DateTime.now().toUtc(),
      expiresUtc: expires,
    );
    _emergencyUnlockUntil = expires;

    notifyListeners();
    await SecurityJournalService.instance.log(
      event: 'emergency_token_issued',
      details: {
        'token_id': id,
        'expires': expires.toIso8601String(),
      },
    );

    zeroizeUint8List(raw);
    return _activeToken!;
  }

  /// Имитация принятия токена контактом: открывает окно аварийного доступа до [expiresUtc].
  Future<bool> redeemTokenForVaultAccess(String tokenPublic) async {
    await revokeExpiredTokens();
    final p = await SharedPreferences.getInstance();
    final id = p.getString('emergency_token_active_id');
    final expIso = p.getString('emergency_token_expires');
    final pub = p.getString('emergency_token_public');
    if (id == null || expIso == null || pub == null) return false;
    if (pub != tokenPublic.trim()) return false;
    final exp = DateTime.tryParse(expIso);
    if (exp == null || DateTime.now().toUtc().isAfter(exp)) return false;

    _emergencyUnlockUntil = exp;
    notifyListeners();
    await SecurityJournalService.instance.log(
      event: 'emergency_token_redeemed',
      details: {'token_id': id},
    );
    return true;
  }

  Future<void> revokeAllTokens() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString('emergency_token_active_id');
    if (id != null) {
      await _secure.delete(key: '$_secureTokenPrefix$id');
    }
    await _revokeTokenStorage();
    _activeToken = null;
    _emergencyUnlockUntil = null;
    notifyListeners();
    await SecurityJournalService.instance.log(
      event: 'emergency_tokens_revoked',
      details: const <String, Object?>{},
    );
  }

  Future<void> revokeExpiredTokens() async {
    final t = _activeToken;
    if (t != null && t.isExpired) {
      await revokeAllTokens();
    }
    if (_emergencyUnlockUntil != null &&
        DateTime.now().toUtc().isAfter(_emergencyUnlockUntil!)) {
      _emergencyUnlockUntil = null;
      notifyListeners();
    }
  }

  Future<void> _revokeTokenStorage() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('emergency_token_active_id');
    await p.remove('emergency_token_expires');
    await p.remove('emergency_token_public');
  }

  /// Очистка списка в памяти (после стирания prefs снаружи).
  void clearLocalState() {
    contacts.clear();
    _activeToken = null;
    _emergencyUnlockUntil = null;
    notifyListeners();
  }
}
