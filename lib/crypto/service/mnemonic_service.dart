import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;

import '../models/crypto_exception.dart';

/// Генерация и проверка мнемонической фразы BIP39 (24 слова = 256 бит энтропии).
///
/// Фраза показывается пользователю один раз; в сеть не отправляется.
class MnemonicService {
  /// Создаёт новую мнемонику из криптостойкой энтропии (24 слова).
  String generateMnemonic24() {
    return bip39.generateMnemonic(strength: 256);
  }

  /// Проверяет контрольную сумму BIP39 и словарь.
  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  /// Детерминированно превращает мнемонику в 64-байтовое seed (BIP39 PBKDF2).
  ///
  /// [passphrase] — опциональная «соль» пользователя (BIP39 passphrase).
  Uint8List mnemonicToSeed(String mnemonic, {String passphrase = ''}) {
    if (!validateMnemonic(mnemonic)) {
      throw TsarCryptoFormatException(
        'invalid_mnemonic',
        'Мнемоника не прошла проверку BIP39.',
      );
    }
    return bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
  }
}
