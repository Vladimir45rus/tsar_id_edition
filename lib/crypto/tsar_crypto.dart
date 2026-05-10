/// Публичная точка входа криптомодуля «Царь-ID».
///
/// Сервер никогда не получает отсюда ни ключи, ни открытый текст — только
/// готовые зашифрованные конверты и метаданные, которые вы передаёте по сети сами.
library tsar_crypto;

export 'hierarchy/key_hierarchy.dart';
export 'kdf/argon2id_kek_derivation.dart';
export 'kdf/pbkdf2_kek_derivation.dart';
export 'models/crypto_exception.dart';
export 'models/encrypted_blob_envelope.dart';
export 'models/kdf_profile.dart';
export 'service/local_crypto_vault.dart';
export 'service/mnemonic_service.dart';
export 'symmetric/aes_256_gcm_service.dart';
export 'utils/secure_buffer.dart';
