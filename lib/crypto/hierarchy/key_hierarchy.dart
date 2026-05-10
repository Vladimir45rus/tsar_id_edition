library key_hierarchy;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Документация и доменные метки для иерархии ключей «Царь-ID».
///
/// ## Назначение уровней (Zero-Knowledge)
///
/// 1. **Мнемоника BIP39 (24 слова)** — единственный человекочитаемый «аварийный корень».
///    Из неё детерминированно получают криптографическое семя (64 байта через PBKDF2
///    в стандарте BIP39). Это семя **никогда** не покидает устройство в открытом виде.
///
/// 2. **RK (Root Key)** — ключ 256 бит, полученный из BIP39-seed через HKDF с
///    фиксированной меткой [hkdfInfoRoot]. Используется как корень для восстановления
///    остальных ключей при потере локальной обёртки (но не заменяет защиту KEK/PIN на
///    повседневной основе — это отдельное продуктовое решение).
///
/// 3. **DMK (Device Master Key)** — случайный 256-битный ключ, создаётся на устройстве.
///    Хранится только внутри Secure Enclave / Android Keystore / StrongBox (вне этого
///    Dart-модуля). В Dart мы оперируем им только как `SecretKey` в оперативной памяти
///    во время unwrap.
///
/// 4. **KEK (Key Encryption Key)** — выводится из PIN/биометрически защищённого секрета
///    через Argon2id или PBKDF2. KEK **не** является DMK: он используется, чтобы
///    зашифровать копию DMK для хранения в SQLCipher/файле (wrapped DMK).
///
/// 5. **DEK (Data Encryption Key)** — уникальный ключ на документ/запись/вложение.
///    Шифрует полезную нагрузку (AES-256-GCM). Сам DEK хранится только в форме
///    `WrappedDEK = AES-GCM(DMK, DEK)` либо `AES-GCM(RK, DEK)` (если вы выбрали
///    схему восстановления без DMK — это нужно зафиксировать на уровне продукта).
///
/// ## Потоки (кратко)
///
/// - **Повседневное открытие:** PIN/biometric → KEK → unwrap DMK → unwrap DEK → данные.
/// - **Восстановление на новом устройстве:** мнемоника → seed → RK → (опционально)
///   восстановить DMK или перешифровать DEK-и — в зависимости от выбранной политики.
///
/// > Важно: этот файл описывает криптографический смысл. Фактическое хранение DMK в
/// > Keychain/Keystore реализуется нативными плагинами (блок 2+ ТЗ).

/// Инфо-строка HKDF для получения RK из BIP39 seed.
final Uint8List hkdfInfoRoot = Uint8List.fromList(utf8.encode('tsar-id|hkdf|root|v1'));

/// Инфо-строка HKDF для получения ключа обёртки мнемоники (если решите шифровать
/// саму мнемонику локально — отдельная политика).
final Uint8List hkdfInfoMnemonicWrap =
    Uint8List.fromList(utf8.encode('tsar-id|hkdf|mnemonic-wrap|v1'));

/// Деривация RK из 64-байтового BIP39 seed через HKDF-SHA256 (экстракт+расширение).
Future<SecretKey> deriveRootKeyFromBip39Seed(Uint8List bip39Seed64) async {
  if (bip39Seed64.length != 64) {
    throw ArgumentError.value(
      bip39Seed64.length,
      'bip39Seed64',
      'BIP39 seed должен быть 64 байта.',
    );
  }
  final hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );
  return hkdf.deriveKey(
    secretKey: SecretKey(bip39Seed64),
    info: hkdfInfoRoot,
  );
}
