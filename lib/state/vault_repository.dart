import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Одна запись пароля в хранилище (память + JSON в SharedPreferences).
/// В продакшене поле [password] должно храниться только в зашифрованном виде на диске.
class VaultPasswordEntry {
  VaultPasswordEntry({
    required this.id,
    required this.title,
    required this.password,
    this.leaked = false,
    this.lastLeakCheckUtc,
  });

  final String id;
  final String title;
  final String password;
  bool leaked;
  String? lastLeakCheckUtc;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'password': password,
        'leaked': leaked,
        'lastLeakCheckUtc': lastLeakCheckUtc,
      };

  static VaultPasswordEntry fromJson(Map<String, dynamic> j) {
    return VaultPasswordEntry(
      id: j['id'] as String,
      title: j['title'] as String,
      password: j['password'] as String,
      leaked: j['leaked'] as bool? ?? false,
      lastLeakCheckUtc: j['lastLeakCheckUtc'] as String?,
    );
  }
}

/// Репозиторий паролей и метаданных для бэкапа / аудита утечек.
class VaultRepository extends ChangeNotifier {
  static const _prefsKey = 'vault_passwords_json_v1';

  final List<VaultPasswordEntry> _entries = [];

  List<VaultPasswordEntry> get entries => List.unmodifiable(_entries);

  VaultRepository();

  /// Загрузка паролей из SharedPreferences (вызывать один раз при старте приложения).
  Future<void> init() async {
    await _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    // Первый запуск приложения — демо-записи. Пустой JSON [] — после удаления аккаунта, без сидирования.
    if (raw == null) {
      _seedDefaults();
      await _persist();
      return;
    }
    if (raw.isEmpty || raw == '[]') {
      _entries.clear();
      notifyListeners();
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _entries
        ..clear()
        ..addAll(
          list.map((e) => VaultPasswordEntry.fromJson(e as Map<String, dynamic>)),
        );
      notifyListeners();
    } on Object catch (_) {
      _seedDefaults();
    }
  }

  void _seedDefaults() {
    _entries
      ..clear()
      ..addAll([
        VaultPasswordEntry(id: '1', title: 'GitHub', password: 'DemoGitHub#2026'),
        VaultPasswordEntry(id: '2', title: 'СберБанк Онлайн', password: 'DemoBank!99'),
        VaultPasswordEntry(id: '3', title: 'VK ID', password: 'DemoVK_Safe'),
        VaultPasswordEntry(id: '4', title: 'Яндекс', password: 'YndxDemo#1'),
      ]);
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    final raw = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await p.setString(_prefsKey, raw);
  }

  Future<void> addEntry({required String title, required String password}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _entries.add(VaultPasswordEntry(id: id, title: title, password: password));
    await _persist();
    notifyListeners();
  }

  Future<void> updateLeakFlags(Map<String, bool> idToLeaked) async {
    for (final e in _entries) {
      if (idToLeaked.containsKey(e.id)) {
        e.leaked = idToLeaked[e.id]!;
        e.lastLeakCheckUtc = DateTime.now().toUtc().toIso8601String();
      }
    }
    await _persist();
    notifyListeners();
  }

  /// Снимок для шифрованного бэкапа (включает настройки-заглушки).
  Map<String, dynamic> exportSnapshot({
    required Map<String, dynamic> settingsExtras,
  }) {
    return {
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'passwords': _entries.map((e) => e.toJson()).toList(),
      'settings': settingsExtras,
      'documents': <Map<String, dynamic>>[],
    };
  }

  /// Восстановление из расшифрованного JSON (импорт бэкапа).
  /// Возвращает блок `settings` для применения в [SecurityController], если есть.
  Future<Map<String, dynamic>?> importFromSnapshot(Map<String, dynamic> snap) async {
    final list = snap['passwords'] as List<dynamic>? ?? [];
    _entries
      ..clear()
      ..addAll(
        list.map((e) => VaultPasswordEntry.fromJson(e as Map<String, dynamic>)),
      );
    await _persist();
    notifyListeners();
    return snap['settings'] as Map<String, dynamic>?;
  }

  Future<void> clearAll() async {
    _entries.clear();
    await _persist();
    notifyListeners();
  }
}
