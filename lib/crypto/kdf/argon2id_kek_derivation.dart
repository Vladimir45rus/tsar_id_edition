import 'dart:typed_data';

import 'package:argon2/argon2.dart';
import 'package:cryptography/cryptography.dart';

import '../models/crypto_exception.dart';
import '../models/kdf_profile.dart';
import '../utils/secure_buffer.dart';

/// Деривация ключа шифрования ключей (KEK) из PIN/пароля через Argon2id.
///
/// Соль должна быть уникальной на устройство/пользователя и храниться открыто
/// рядом с обёрткой ключа (соль не секрет).
class Argon2idKekDerivation {
  Argon2idKekDerivation({
    required this.profile,
    this.outputLengthBytes = 32,
  });

  final KdfProfile profile;
  final int outputLengthBytes;

  static KdfProfile recommendedProfile2026() {
    return const KdfProfile(
      id: 'argon2id-v1-2026',
      algorithm: 'argon2id',
      iterations: 3,
      memoryKiB: 65536,
      parallelism: 4,
      hashAlgorithm: null,
    );
  }

  /// Возвращает [SecretKey] длиной [outputLengthBytes] (по умолчанию 32 = AES-256).
  Future<SecretKey> deriveKek({
    required String secretUtf8,
    required Uint8List salt,
  }) async {
    if (salt.length < 16) {
      throw TsarCryptoKdfException(
        'salt_too_short',
        'Рекомендуется соль не короче 16 байт.',
      );
    }
    if (profile.algorithm != 'argon2id') {
      throw TsarCryptoKdfException(
        'wrong_profile',
        'Профиль не относится к Argon2id.',
      );
    }
    final mem = profile.memoryKiB;
    final lanes = profile.parallelism;
    if (mem == null || lanes == null) {
      throw TsarCryptoKdfException(
        'argon2_params_missing',
        'Для Argon2id укажите memoryKiB и parallelism в KdfProfile.',
      );
    }

    final params = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      iterations: profile.iterations,
      memory: mem,
      lanes: lanes,
      version: Argon2Parameters.ARGON2_VERSION_13,
    );

    final generator = Argon2BytesGenerator()..init(params);
    final converted = params.converter.convert(secretUtf8);
    final passwordBytes = Uint8List.fromList(converted);
    try {
      final out = Uint8List(outputLengthBytes);
      generator.generateBytes(passwordBytes, out, 0, out.length);
      return SecretKey(out);
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        TsarCryptoKdfException(
          'argon2_failed',
          'Не удалось выполнить Argon2id.',
          cause: e,
        ),
        st,
      );
    } finally {
      zeroizeUint8List(passwordBytes);
    }
  }
}
