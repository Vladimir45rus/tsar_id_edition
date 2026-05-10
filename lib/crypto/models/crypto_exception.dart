/// Базовая ошибка криптослоя. Не содержит секретов (ключей, PIN, мнемоники).
class TsarCryptoException implements Exception {
  TsarCryptoException(this.code, this.message, {this.cause});

  /// Стабильный машинный код для логики UI/аналитики (без локализации).
  final String code;

  /// Человекочитаемое описание (русский текст допускается в приложении).
  final String message;

  final Object? cause;

  @override
  String toString() => 'TsarCryptoException($code): $message';
}

/// Неверный формат конверта, MAC, версия протокола и т.п.
class TsarCryptoFormatException extends TsarCryptoException {
  TsarCryptoFormatException(super.code, super.message, {super.cause});
}

/// Ошибка KDF (неверные параметры, нехватка ресурсов и т.д.).
class TsarCryptoKdfException extends TsarCryptoException {
  TsarCryptoKdfException(super.code, super.message, {super.cause});
}

/// Ошибка симметричного шифрования (дешифрование не удалось).
class TsarCryptoCipherException extends TsarCryptoException {
  TsarCryptoCipherException(super.code, super.message, {super.cause});
}
