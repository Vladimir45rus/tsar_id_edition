import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Криптографически стойкий генератор (ОС / `dart:math` только как запасной путь
/// для чистого Dart без `dart:ffi` — на Flutter используйте `Random.secure()`).
Uint8List randomBytes(int length, {Random? random}) {
  if (length < 0) {
    throw ArgumentError.value(length, 'length', 'Длина должна быть >= 0.');
  }
  final rnd = random ?? Random.secure();
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = rnd.nextInt(256);
  }
  return out;
}

/// Сравнение байтов в постоянном времени (длины должны совпадать).
bool constantTimeBytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Обнуляет буфер (Dart не гарантирует отсутствие копий в памяти GC, но это
/// лучше, чем ничего — особенно для временных ключей в `Uint8List`).
void zeroizeUint8List(Uint8List? buffer) {
  if (buffer == null) {
    return;
  }
  for (var i = 0; i < buffer.length; i++) {
    buffer[i] = 0;
  }
}

/// Извлекает сырой ключ из [SecretKey] (копия материала — обнулите после использования).
Future<Uint8List> extractRawKey32(SecretKey key) async {
  final bytes = await key.extractBytes();
  if (bytes.length != 32) {
    throw StateError('Ожидался ключ 256 бит, получено ${bytes.length} байт.');
  }
  return Uint8List.fromList(bytes);
}
