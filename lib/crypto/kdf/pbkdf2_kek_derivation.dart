import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/crypto_exception.dart';
import '../models/kdf_profile.dart';

/// Деривация KEK через PBKDF2-HMAC-SHA256 (резервный/совместимый путь).
class Pbkdf2KekDerivation {
  Pbkdf2KekDerivation({
    required this.profile,
    this.outputLengthBytes = 32,
  });

  final KdfProfile profile;
  final int outputLengthBytes;

  static KdfProfile recommendedProfile2026() {
    return const KdfProfile(
      id: 'pbkdf2-hmac-sha256-v1-2026',
      algorithm: 'pbkdf2-hmac-sha256',
      iterations: 310000,
      memoryKiB: null,
      parallelism: null,
      hashAlgorithm: 'sha256',
    );
  }

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
    if (profile.algorithm != 'pbkdf2-hmac-sha256') {
      throw TsarCryptoKdfException(
        'wrong_profile',
        'Профиль не относится к PBKDF2-HMAC-SHA256.',
      );
    }

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: profile.iterations,
      bits: outputLengthBytes * 8,
    );

    try {
      return await pbkdf2.deriveKeyFromPassword(
        password: secretUtf8,
        nonce: salt,
      );
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        TsarCryptoKdfException(
          'pbkdf2_failed',
          'Не удалось выполнить PBKDF2.',
          cause: e,
        ),
        st,
      );
    }
  }
}
