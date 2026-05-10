import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../crypto/hierarchy/key_hierarchy.dart';
import '../../crypto/kdf/argon2id_kek_derivation.dart';
import '../../crypto/models/kdf_profile.dart';
import '../../crypto/symmetric/aes_256_gcm_service.dart';
import '../../crypto/utils/secure_buffer.dart' show extractRawKey32, randomBytes, zeroizeUint8List;

/// Формат файла `.tsarbackup` (все криптооперации только на устройстве).
///
/// Структура:
/// - [magic] 4 байта: `TSB1`
/// - [u32 BE] длина заголовка JSON (UTF-8)
/// - заголовок JSON: соль KDF (base64), профиль KDF, метаданные экспорта
/// - тело: [EncryptedBlobEnvelope] (AES-256-GCM) поверх ZIP-архива с `payload.json`
///
/// Ключ бэкапа: HKDF-SHA256( RK ‖ KEK , info="tsar-id|backup|master|v1" ),
/// где RK из BIP39 seed, KEK = Argon2id(PIN, salt из заголовка).
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const List<int> magic = [0x54, 0x53, 0x42, 0x01];

  final Aes256GcmService _aes = Aes256GcmService();

  /// Деривирует мастер-ключ архива из мнемоники и PIN (Zero-Knowledge: только локально).
  Future<SecretKey> deriveBackupMasterKey({
    required Uint8List bip39Seed64,
    required String pinUtf8,
    required Uint8List kdfSalt,
    required KdfProfile kdfProfile,
  }) async {
    final rk = await deriveRootKeyFromBip39Seed(bip39Seed64);
    final kek = await Argon2idKekDerivation(profile: kdfProfile).deriveKek(
      secretUtf8: pinUtf8,
      salt: kdfSalt,
    );
    final rkBytes = await rk.extractBytes();
    final kekBytes = await extractRawKey32(kek);
    final concat = Uint8List(rkBytes.length + kekBytes.length);
    concat.setRange(0, rkBytes.length, rkBytes);
    concat.setRange(rkBytes.length, concat.length, kekBytes);
    try {
      final hkdf = Hkdf(
        hmac: Hmac.sha256(),
        outputLength: 32,
      );
      return hkdf.deriveKey(
        secretKey: SecretKey(concat),
        info: Uint8List.fromList(utf8.encode('tsar-id|backup|master|v1')),
      );
    } finally {
      zeroizeUint8List(kekBytes);
    }
  }

  /// Создаёт ZIP с JSON и возвращает байты.
  Uint8List _buildZipPayload(Map<String, dynamic> snapshot) {
    final jsonBytes = utf8.encode(jsonEncode(snapshot));
    final archive = Archive()
      ..addFile(
        ArchiveFile('payload.json', jsonBytes.length, jsonBytes),
      );
    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) {
      throw StateError('Не удалось сжать архив бэкапа');
    }
    return Uint8List.fromList(zipped);
  }

  /// Распаковывает ZIP и парсит JSON.
  Map<String, dynamic> _parseZipPayload(Uint8List zipBytes) {
    final decoded = ZipDecoder().decodeBytes(zipBytes);
    final file = decoded.findFile('payload.json');
    if (file == null) {
      throw const FormatException('В архиве нет payload.json');
    }
    final content = file.content as List<int>;
    return jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
  }

  /// Создать зашифрованный файл бэкапа на диске.
  Future<File> createEncryptedBackupFile({
    required Map<String, dynamic> snapshot,
    required Uint8List bip39Seed64,
    required String pinUtf8,
  }) async {
    final kdfSalt = randomBytes(32);
    final profile = Argon2idKekDerivation.recommendedProfile2026();
    final master = await deriveBackupMasterKey(
      bip39Seed64: bip39Seed64,
      pinUtf8: pinUtf8,
      kdfSalt: kdfSalt,
      kdfProfile: profile,
    );

    final zipBytes = _buildZipPayload(snapshot);
    final header = <String, dynamic>{
      'kdfSaltB64': base64Encode(kdfSalt),
      'kdfProfileId': profile.id,
      'kdfAlgorithm': profile.algorithm,
      'kdfIterations': profile.iterations,
      'kdfMemoryKiB': profile.memoryKiB,
      'kdfParallelism': profile.parallelism,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'app': 'tsar_id',
    };
    final headerUtf8 = utf8.encode(jsonEncode(header));

    final envelope = await _aes.encryptToEnvelope(
      key: master,
      plaintext: zipBytes,
      aad: Uint8List.fromList(headerUtf8),
      kdfProfileId: profile.id,
    );

    final bb = BytesBuilder(copy: false);
    bb.add(magic);
    bb.add(_u32be(headerUtf8.length));
    bb.add(headerUtf8);
    bb.add(envelope);

    final dir = await getApplicationDocumentsDirectory();
    final name =
        'tsar_backup_${DateTime.now().millisecondsSinceEpoch}.tsarbackup';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bb.takeBytes(), flush: true);
    return file;
  }

  /// Расшифровать бэкап и вернуть снимок данных.
  Future<Map<String, dynamic>> decryptBackupFile({
    required File file,
    required Uint8List bip39Seed64,
    required String pinUtf8,
  }) async {
    final raw = await file.readAsBytes();
    if (raw.length < 8) throw const FormatException('Файл слишком короткий');
    for (var i = 0; i < 4; i++) {
      if (raw[i] != magic[i]) throw const FormatException('Неверная сигнатура TSB1');
    }
    final headerLen = (raw[4] << 24) | (raw[5] << 16) | (raw[6] << 8) | raw[7];
    if (raw.length < 8 + headerLen) {
      throw const FormatException('Обрезан заголовок');
    }
    final headerUtf8 = raw.sublist(8, 8 + headerLen);
    final envelope = Uint8List.sublistView(raw, 8 + headerLen);
    final header =
        jsonDecode(utf8.decode(headerUtf8)) as Map<String, dynamic>;

    final salt = base64Decode(header['kdfSaltB64'] as String);
    final profile = KdfProfile(
      id: header['kdfProfileId'] as String? ?? 'argon2id-v1-2026',
      algorithm: header['kdfAlgorithm'] as String? ?? 'argon2id',
      iterations: (header['kdfIterations'] as num?)?.toInt() ?? 3,
      memoryKiB: (header['kdfMemoryKiB'] as num?)?.toInt() ?? 65536,
      parallelism: (header['kdfParallelism'] as num?)?.toInt() ?? 4,
    );

    final master = await deriveBackupMasterKey(
      bip39Seed64: bip39Seed64,
      pinUtf8: pinUtf8,
      kdfSalt: Uint8List.fromList(salt),
      kdfProfile: profile,
    );

    final zipBytes = await _aes.decryptFromEnvelope(
      key: master,
      envelopeBytes: envelope,
    );
    return _parseZipPayload(zipBytes);
  }

  static Uint8List _u32be(int v) {
    return Uint8List(4)
      ..[0] = (v >> 24) & 0xff
      ..[1] = (v >> 16) & 0xff
      ..[2] = (v >> 8) & 0xff
      ..[3] = v & 0xff;
  }
}
