import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_exception.dart';

/// Версионированный бинарный конверт для AES-256-GCM.
///
/// Формат (все целые без знака, порядок байт big-endian):
/// - `magic` (4 байта): `0x54 0x53 0x52 0x01` («TSR» + версия файла формата 1)
/// - `suite` (1 байт): 1 = AES-256-GCM (пакет `cryptography`)
/// - `kdfProfileIdLen` (1 байт): длина UTF-8 строки профиля KDF (0..255)
/// - `kdfProfileId` (переменная): идентификатор профиля KDF (опционально, для аудита)
/// - `aadLen` (2 байта): длина дополнительных аутентифицируемых данных (0..65535)
/// - `aad` (переменная)
/// - `nonce` (12 байт) — IV для GCM
/// - `cipherLen` (4 байта): длина шифротекста без тега
/// - `cipher` (переменная)
/// - `mac` (16 байт) — тег аутентификации GCM
///
/// Сервер хранит/пересылает только такие байты — без ключей.
class EncryptedBlobEnvelope {
  EncryptedBlobEnvelope._({
    required this.suiteId,
    required this.kdfProfileIdUtf8,
    required this.aad,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  /// Идентификатор набора алгоритмов в конверте.
  static const int suiteAes256Gcm = 1;

  static const int _magic0 = 0x54;
  static const int _magic1 = 0x53;
  static const int _magic2 = 0x52;
  static const int _formatVersion = 0x01;

  final int suiteId;

  /// Может быть пустым, если конверт не привязан к профилю KDF.
  final Uint8List kdfProfileIdUtf8;

  /// Additional Authenticated Data (не секрет, но целостность защищается MAC).
  final Uint8List aad;

  final Uint8List nonce;

  final Uint8List ciphertext;

  final Uint8List mac;

  /// Собирает [SecretBox] для пакета `cryptography`.
  SecretBox toSecretBox() {
    return SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );
  }

  /// Упаковывает открытый текст в конверт (сырые байты на выходе — для SQLCipher/TLS-тела).
  static Uint8List seal({
    required SecretBox box,
    int suiteId = suiteAes256Gcm,
    Uint8List? aad,
    String kdfProfileId = '',
  }) {
    final aadBytes = aad ?? _emptyAad;
    if (suiteId != suiteAes256Gcm) {
      throw TsarCryptoFormatException(
        'unsupported_suite',
        'Поддерживается только suiteAes256Gcm.',
      );
    }
    if (box.nonce.length != 12) {
      throw TsarCryptoFormatException(
        'bad_nonce_length',
        'Для AES-GCM ожидается nonce длиной 12 байт.',
      );
    }
    if (box.mac.bytes.length != 16) {
      throw TsarCryptoFormatException(
        'bad_mac_length',
        'Ожидается MAC длиной 16 байт.',
      );
    }
    final profileBytes = Uint8List.fromList(kdfProfileId.codeUnits);
    if (profileBytes.length > 255) {
      throw TsarCryptoFormatException(
        'kdf_profile_too_long',
        'kdfProfileId не может быть длиннее 255 байт в UTF-8.',
      );
    }
    if (aadBytes.length > 65535) {
      throw TsarCryptoFormatException(
        'aad_too_long',
        'AAD не может быть длиннее 65535 байт.',
      );
    }

    final bb = BytesBuilder(copy: false);
    bb.addByte(_magic0);
    bb.addByte(_magic1);
    bb.addByte(_magic2);
    bb.addByte(_formatVersion);
    bb.addByte(suiteId & 0xff);
    bb.addByte(profileBytes.length & 0xff);
    bb.add(profileBytes);
    bb.add(_u16Big(aadBytes.length));
    bb.add(aadBytes);
    bb.add(box.nonce);
    bb.add(_u32Big(box.cipherText.length));
    bb.add(box.cipherText);
    bb.add(box.mac.bytes);

    return bb.takeBytes();
  }

  static EncryptedBlobEnvelope parse(Uint8List raw) {
    var offset = 0;
    void need(int n) {
      if (offset + n > raw.length) {
        throw TsarCryptoFormatException(
          'truncated_envelope',
          'Конверт обрезан или повреждён.',
        );
      }
    }

    need(4);
    if (raw[offset] != _magic0 ||
        raw[offset + 1] != _magic1 ||
        raw[offset + 2] != _magic2 ||
        raw[offset + 3] != _formatVersion) {
      throw TsarCryptoFormatException(
        'bad_magic',
        'Неизвестный формат конверта (magic/version).',
      );
    }
    offset += 4;

    need(1);
    final suite = raw[offset];
    offset += 1;

    need(1);
    final profileLen = raw[offset];
    offset += 1;

    need(profileLen);
    final profileId = Uint8List.sublistView(raw, offset, offset + profileLen);
    offset += profileLen;

    need(2);
    final aadLen = (raw[offset] << 8) | raw[offset + 1];
    offset += 2;

    need(aadLen);
    final aad = Uint8List.sublistView(raw, offset, offset + aadLen);
    offset += aadLen;

    need(12);
    final nonce = Uint8List.sublistView(raw, offset, offset + 12);
    offset += 12;

    need(4);
    final ctLen = (raw[offset] << 24) |
        (raw[offset + 1] << 16) |
        (raw[offset + 2] << 8) |
        raw[offset + 3];
    offset += 4;
    if (ctLen < 0) {
      throw TsarCryptoFormatException('bad_cipher_len', 'Некорректная длина шифротекста.');
    }

    need(ctLen);
    final ct = Uint8List.sublistView(raw, offset, offset + ctLen);
    offset += ctLen;

    need(16);
    final mac = Uint8List.sublistView(raw, offset, offset + 16);
    offset += 16;

    if (offset != raw.length) {
      throw TsarCryptoFormatException(
        'trailing_garbage',
        'В конце конверта обнаружены лишние байты.',
      );
    }

    return EncryptedBlobEnvelope._(
      suiteId: suite,
      kdfProfileIdUtf8: profileId,
      aad: aad,
      nonce: nonce,
      ciphertext: ct,
      mac: mac,
    );
  }

  static final Uint8List _emptyAad = Uint8List(0);

  static Uint8List _u16Big(int v) {
    return Uint8List(2)
      ..[0] = (v >> 8) & 0xff
      ..[1] = v & 0xff;
  }

  static Uint8List _u32Big(int v) {
    return Uint8List(4)
      ..[0] = (v >> 24) & 0xff
      ..[1] = (v >> 16) & 0xff
      ..[2] = (v >> 8) & 0xff
      ..[3] = v & 0xff;
  }
}
