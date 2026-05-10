import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/crypto_exception.dart';
import '../models/encrypted_blob_envelope.dart';
import '../utils/secure_buffer.dart';

/// Симметричное шифрование AES-256-GCM поверх пакета `cryptography`.
///
/// Ключ 32 байта, nonce 12 байт (генерируется криптостойко на каждую операцию).
class Aes256GcmService {
  Aes256GcmService({AesGcm? algorithm}) : _algo = algorithm ?? AesGcm.with256bits();

  final AesGcm _algo;

  static const int keyLength = 32;
  static const int nonceLength = 12;

  /// Генерирует случайный ключ данных (DEK).
  Future<SecretKey> newDataKey() async {
    return SecretKey(randomBytes(keyLength));
  }

  /// Шифрует открытый текст, возвращает упакованный конверт.
  Future<Uint8List> encryptToEnvelope({
    required SecretKey key,
    required List<int> plaintext,
    Uint8List? aad,
    String kdfProfileId = '',
  }) async {
    final aadBytes = aad ?? _empty;
    await _assertKey256(key);
    final nonce = randomBytes(nonceLength);
    SecretBox box;
    try {
      box = await _algo.encrypt(
        plaintext,
        secretKey: key,
        nonce: nonce,
        aad: aadBytes,
      );
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        TsarCryptoCipherException(
          'encrypt_failed',
          'Ошибка AES-256-GCM при шифровании.',
          cause: e,
        ),
        st,
      );
    }

    return EncryptedBlobEnvelope.seal(
      box: box,
      suiteId: EncryptedBlobEnvelope.suiteAes256Gcm,
      aad: aadBytes,
      kdfProfileId: kdfProfileId,
    );
  }

  /// Расшифровывает конверт, проверяя MAC/AAD.
  Future<Uint8List> decryptFromEnvelope({
    required SecretKey key,
    required Uint8List envelopeBytes,
  }) async {
    await _assertKey256(key);
    final env = EncryptedBlobEnvelope.parse(envelopeBytes);
    if (env.suiteId != EncryptedBlobEnvelope.suiteAes256Gcm) {
      throw TsarCryptoCipherException(
        'unsupported_suite',
        'Неизвестный suite в конверте.',
      );
    }

    final box = env.toSecretBox();
    try {
      final clear = await _algo.decrypt(
        box,
        secretKey: key,
        aad: env.aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError catch (e, st) {
      Error.throwWithStackTrace(
        TsarCryptoCipherException(
          'auth_failed',
          'Неверный ключ, AAD или повреждённый конверт.',
          cause: e,
        ),
        st,
      );
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        TsarCryptoCipherException(
          'decrypt_failed',
          'Ошибка AES-256-GCM при дешифровании.',
          cause: e,
        ),
        st,
      );
    }
  }

  Future<void> _assertKey256(SecretKey key) async {
    final raw = await key.extractBytes();
    if (raw.length != keyLength) {
      throw TsarCryptoCipherException(
        'bad_key_length',
        'Для AES-256 нужен ключ длиной $keyLength байт.',
      );
    }
  }

  static final Uint8List _empty = Uint8List(0);
}
