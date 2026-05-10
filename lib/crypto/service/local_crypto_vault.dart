import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../hierarchy/key_hierarchy.dart';
import '../kdf/argon2id_kek_derivation.dart';
import '../kdf/pbkdf2_kek_derivation.dart';
import '../models/crypto_exception.dart';
import '../models/kdf_profile.dart';
import '../symmetric/aes_256_gcm_service.dart';
import '../utils/secure_buffer.dart';
import 'mnemonic_service.dart';

/// Результат первичной инициализации хранилища на устройстве.
///
/// [deviceMasterKey] необходимо импортировать в Secure Enclave / Keystore и затем
/// удалить из оперативной памяти Dart насколько это возможно.
class VaultBootstrapArtifacts {
  VaultBootstrapArtifacts({
    required this.mnemonic24,
    required this.kekSalt,
    required this.kdfProfile,
    required this.wrappedDeviceMasterKey,
    required this.deviceMasterKey,
    required this.rootKey,
    required this.bip39Seed64,
  });

  /// 24 слова для аварийного восстановления.
  final String mnemonic24;

  /// Соль для KDF PIN → KEK (хранится открыто).
  final Uint8List kekSalt;

  /// Профиль KDF, соответствующий обёртке DMK.
  final KdfProfile kdfProfile;

  /// `AES-256-GCM(KEK, DMK)` в формате [EncryptedBlobEnvelope].
  final Uint8List wrappedDeviceMasterKey;

  /// Распакованный DMK до передачи в Keychain (чувствительные данные!).
  final SecretKey deviceMasterKey;

  /// RK, полученный из BIP39 seed (для восстановления/миграций по политике продукта).
  final SecretKey rootKey;

  /// Сырой BIP39 seed — крайне чувствительный; обычно сразу преобразуют в RK и zeroize.
  final Uint8List bip39Seed64;

  /// Обнуляет временные байты там, где это возможно.
  void zeroizeSensitiveBuffers() {
    zeroizeUint8List(bip39Seed64);
  }
}

/// Локальное шифрование/дешифрование: AES-256-GCM, обёртка ключей, связка с BIP39/PIN.
///
/// Никаких сетевых вызовов. Серверу передаются только уже зашифрованные blob-ы,
/// которые вы сериализуете из этого модуля.
class LocalCryptoVault {
  LocalCryptoVault({
    Aes256GcmService? aes,
    MnemonicService? mnemonicService,
  })  : _aes = aes ?? Aes256GcmService(),
        _mnemonic = mnemonicService ?? MnemonicService();

  final Aes256GcmService _aes;
  final MnemonicService _mnemonic;

  static final Uint8List _aadWrapDmk =
      Uint8List.fromList(utf8.encode('tsar-id|aad|wrap-dmk|v1'));
  static final Uint8List _aadWrapDek =
      Uint8List.fromList(utf8.encode('tsar-id|aad|wrap-dek|v1'));
  static final Uint8List _aadPayloadDefault =
      Uint8List.fromList(utf8.encode('tsar-id|aad|payload|v1'));

  // --- Регистрация / восстановление корня ---

  /// Генерирует мнемонику, seed, RK, случайный DMK и оборачивает DMK в KEK от PIN.
  Future<VaultBootstrapArtifacts> bootstrapNewVaultFromPin({
    required String pinUtf8,
    KdfProfile? kdfProfile,
  }) async {
    final profile = kdfProfile ?? Argon2idKekDerivation.recommendedProfile2026();
    final mnemonic24 = _mnemonic.generateMnemonic24();
    return _bootstrapFromMnemonicAndPin(
      mnemonic24: mnemonic24,
      pinUtf8: pinUtf8,
      kdfProfile: profile,
    );
  }

  /// То же, но мнемоника уже известна (повторная инициализация / тест).
  Future<VaultBootstrapArtifacts> bootstrapFromExistingMnemonicAndPin({
    required String mnemonic24,
    required String pinUtf8,
    KdfProfile? kdfProfile,
  }) async {
    final profile = kdfProfile ?? Argon2idKekDerivation.recommendedProfile2026();
    if (!_mnemonic.validateMnemonic(mnemonic24)) {
      throw TsarCryptoFormatException(
        'invalid_mnemonic',
        'Мнемоника не прошла проверку BIP39.',
      );
    }
    return _bootstrapFromMnemonicAndPin(
      mnemonic24: mnemonic24,
      pinUtf8: pinUtf8,
      kdfProfile: profile,
    );
  }

  Future<VaultBootstrapArtifacts> _bootstrapFromMnemonicAndPin({
    required String mnemonic24,
    required String pinUtf8,
    required KdfProfile kdfProfile,
  }) async {
    final seed = _mnemonic.mnemonicToSeed(mnemonic24);
    try {
      final rk = await deriveRootKeyFromBip39Seed(seed);
      final dmk = await _aes.newDataKey();
      final kekSalt = randomBytes(32);
      final kek = await _deriveKekFromProfile(
        profile: kdfProfile,
        secretUtf8: pinUtf8,
        salt: kekSalt,
      );
      final wrappedDmk = await _aes.encryptToEnvelope(
        key: kek,
        plaintext: await extractRawKey32(dmk),
        aad: _aadWrapDmk,
        kdfProfileId: kdfProfile.id,
      );
      return VaultBootstrapArtifacts(
        mnemonic24: mnemonic24,
        kekSalt: kekSalt,
        kdfProfile: kdfProfile,
        wrappedDeviceMasterKey: wrappedDmk,
        deviceMasterKey: dmk,
        rootKey: rk,
        bip39Seed64: Uint8List.fromList(seed),
      );
    } finally {
      zeroizeUint8List(seed);
    }
  }

  /// Восстанавливает DMK в память из PIN и сохранённой обёртки.
  Future<SecretKey> unwrapDeviceMasterKeyFromPin({
    required String pinUtf8,
    required Uint8List kekSalt,
    required KdfProfile kdfProfile,
    required Uint8List wrappedDeviceMasterKey,
  }) async {
    final kek = await _deriveKekFromProfile(
      profile: kdfProfile,
      secretUtf8: pinUtf8,
      salt: kekSalt,
    );
    try {
      final raw = await _aes.decryptFromEnvelope(
        key: kek,
        envelopeBytes: wrappedDeviceMasterKey,
      );
      if (raw.length != Aes256GcmService.keyLength) {
        throw TsarCryptoCipherException(
          'bad_dmk_plaintext',
          'Распакованный DMK имеет неверную длину.',
        );
      }
      return SecretKey(raw);
    } finally {
      // kek — SecretKey внутри cryptography; явный zeroize недоступен, полагаемся на GC.
    }
  }

  /// Восстанавливает RK из мнемоники (офлайн).
  Future<SecretKey> deriveRootKeyFromMnemonic(
    String mnemonic24, {
    String bip39Passphrase = '',
  }) async {
    final seed = _mnemonic.mnemonicToSeed(mnemonic24, passphrase: bip39Passphrase);
    try {
      return await deriveRootKeyFromBip39Seed(seed);
    } finally {
      zeroizeUint8List(seed);
    }
  }

  // --- Обёртка DEK ↔ DMK (или другим ключом-хранителем) ---

  /// Генерирует новый DEK для записи/документа.
  Future<SecretKey> newDataEncryptionKey() => _aes.newDataKey();

  /// Упаковывает DEK для хранения в SQLCipher: `AES-GCM(DMK, rawDEK)`.
  Future<Uint8List> wrapDataKey({
    required SecretKey masterKey,
    required SecretKey dataKey,
    Uint8List? aad,
    String kdfProfileId = '',
  }) async {
    final raw = await extractRawKey32(dataKey);
    try {
      return _aes.encryptToEnvelope(
        key: masterKey,
        plaintext: raw,
        aad: aad ?? _aadWrapDek,
        kdfProfileId: kdfProfileId,
      );
    } finally {
      zeroizeUint8List(raw);
    }
  }

  /// Извлекает DEK из обёртки.
  Future<SecretKey> unwrapDataKey({
    required SecretKey masterKey,
    required Uint8List wrappedDataKey,
  }) async {
    final raw = await _aes.decryptFromEnvelope(
      key: masterKey,
      envelopeBytes: wrappedDataKey,
    );
    if (raw.length != Aes256GcmService.keyLength) {
      throw TsarCryptoCipherException(
        'bad_dek_plaintext',
        'Распакованный DEK имеет неверную длину.',
      );
    }
    return SecretKey(raw);
  }

  // --- Полезная нагрузка ---

  /// Шифрует произвольные байты DEK-ом (контент для сервера/локальной БД).
  Future<Uint8List> encryptPayload({
    required SecretKey dataKey,
    required List<int> plaintext,
    Uint8List? aad,
    String kdfProfileId = '',
  }) {
    return _aes.encryptToEnvelope(
      key: dataKey,
      plaintext: plaintext,
      aad: aad ?? _aadPayloadDefault,
      kdfProfileId: kdfProfileId,
    );
  }

  /// Дешифрует полезную нагрузку.
  Future<Uint8List> decryptPayload({
    required SecretKey dataKey,
    required Uint8List envelope,
  }) {
    return _aes.decryptFromEnvelope(
      key: dataKey,
      envelopeBytes: envelope,
    );
  }

  // --- Утилита: альтернативный KDF ---

  Future<SecretKey> deriveKekWithPbkdf2({
    required String secretUtf8,
    required Uint8List salt,
    KdfProfile? profile,
  }) async {
    final p = profile ?? Pbkdf2KekDerivation.recommendedProfile2026();
    return Pbkdf2KekDerivation(profile: p).deriveKek(
      secretUtf8: secretUtf8,
      salt: salt,
    );
  }

  Future<SecretKey> _deriveKekFromProfile({
    required KdfProfile profile,
    required String secretUtf8,
    required Uint8List salt,
  }) async {
    switch (profile.algorithm) {
      case 'argon2id':
        return Argon2idKekDerivation(profile: profile).deriveKek(
          secretUtf8: secretUtf8,
          salt: salt,
        );
      case 'pbkdf2-hmac-sha256':
        return Pbkdf2KekDerivation(profile: profile).deriveKek(
          secretUtf8: secretUtf8,
          salt: salt,
        );
      default:
        throw TsarCryptoKdfException(
          'unsupported_kdf',
          'Неизвестный алгоритм KDF в профиле: ${profile.algorithm}',
        );
    }
  }
}
