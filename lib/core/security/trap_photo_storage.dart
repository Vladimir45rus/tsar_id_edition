import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../crypto/symmetric/aes_256_gcm_service.dart';

/// Хранение снимков «камеры-ловушки».
///
/// Важно: каталог `lib/core/trap_photos/` в исходниках **не используется** — на
/// устройстве запись возможна только в sandbox приложения. Файлы пишутся в
/// [getApplicationDocumentsDirectory]/trap_photos/ в зашифрованном виде.
class TrapPhotoStorage {
  TrapPhotoStorage._();
  static final TrapPhotoStorage instance = TrapPhotoStorage._();

  static const _secureKeyName = 'tsar_trap_aes_key';
  static const _dirName = 'trap_photos';
  static const int maxFiles = 30;

  static const _magic = [0x54, 0x52, 0x41, 0x50, 0x4D, 0x45, 0x54, 0x41];

  final _secure = const FlutterSecureStorage();
  final _aes = Aes256GcmService();

  Future<Directory> _dir() async {
    final root = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(root.path, _dirName));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  Future<SecretKey> _loadOrCreateKey() async {
    final existing = await _secure.read(key: _secureKeyName);
    if (existing != null && existing.length == 64) {
      final bytes = List<int>.generate(
        32,
        (i) => int.parse(existing.substring(i * 2, i * 2 + 2), radix: 16),
      );
      return SecretKey(Uint8List.fromList(bytes));
    }
    final key = await _aes.newDataKey();
    final raw = await key.extractBytes();
    final hex = raw.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _secure.write(key: _secureKeyName, value: hex);
    return key;
  }

  /// Сохранить JPEG + метаданные (шифрование AES-256-GCM).
  Future<void> saveCapture({
    required Uint8List jpegBytes,
    required DateTime timestampUtc,
    double? latitude,
    double? longitude,
  }) async {
    final key = await _loadOrCreateKey();
    final meta = <String, Object?>{
      'ts': timestampUtc.toUtc().toIso8601String(),
      'lat': latitude,
      'lng': longitude,
      'size': jpegBytes.length,
    };
    final metaBytes = utf8.encode(jsonEncode(meta));
    final plain = Uint8List(metaBytes.length + _magic.length + jpegBytes.length);
    plain.setRange(0, metaBytes.length, metaBytes);
    plain.setRange(metaBytes.length, metaBytes.length + _magic.length, _magic);
    plain.setRange(
      metaBytes.length + _magic.length,
      plain.length,
      jpegBytes,
    );

    final envelope = await _aes.encryptToEnvelope(
      key: key,
      plaintext: plain,
      aad: Uint8List.fromList(utf8.encode('tsar-id|trap|v1')),
      kdfProfileId: 'trap-local',
    );

    final dir = await _dir();
    final id = timestampUtc.millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'trap_$id.enc'));
    await file.writeAsBytes(envelope, flush: true);

    await _trimOld();
  }

  Future<void> _trimOld() async {
    final dir = await _dir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.enc'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    while (files.length > maxFiles) {
      try {
        await files.first.delete();
      } on Object catch (_) {}
      files.removeAt(0);
    }
  }

  /// Список записей (новые в конце), без расшифровки изображения.
  Future<List<TrapPhotoEntry>> listEntries() async {
    final dir = await _dir();
    if (!await dir.exists()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.enc'))
        .toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final out = <TrapPhotoEntry>[];
    final key = await _loadOrCreateKey();
    for (final f in files) {
      try {
        final enc = await f.readAsBytes();
        final plain = await _aes.decryptFromEnvelope(key: key, envelopeBytes: enc);
        final split = _splitMetaAndJpeg(plain);
        if (split == null) continue;
        final meta = jsonDecode(utf8.decode(split.$1)) as Map<String, dynamic>;
        out.add(TrapPhotoEntry(
          filePath: f.path,
          timestampIso: meta['ts'] as String? ?? '',
          latitude: (meta['lat'] as num?)?.toDouble(),
          longitude: (meta['lng'] as num?)?.toDouble(),
          jpegBytes: split.$2,
        ));
      } on Object catch (e) {
        debugPrint('TrapPhotoStorage list parse: $e');
      }
    }
    return out;
  }

  (Uint8List, Uint8List)? _splitMetaAndJpeg(Uint8List plain) {
    for (var i = 0; i <= plain.length - _magic.length; i++) {
      var ok = true;
      for (var j = 0; j < _magic.length; j++) {
        if (plain[i + j] != _magic[j]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        final meta = Uint8List.sublistView(plain, 0, i);
        final jpeg = Uint8List.sublistView(plain, i + _magic.length);
        return (meta, jpeg);
      }
    }
    return null;
  }
}

class TrapPhotoEntry {
  TrapPhotoEntry({
    required this.filePath,
    required this.timestampIso,
    required this.jpegBytes,
    this.latitude,
    this.longitude,
  });

  final String filePath;
  final String timestampIso;
  final double? latitude;
  final double? longitude;
  final Uint8List jpegBytes;
}
