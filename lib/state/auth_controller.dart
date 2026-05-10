import 'package:flutter/foundation.dart';

/// Уровень доступа после SMS и KYC.
enum AccessLevel {
  /// Уровень 1: «Пароли» и «Генератор».
  basic,

  /// Уровень 2: разблокирован «Сейф».
  tsar,
}

/// Сессия авторизации и KYC (без сетевого бэкенда — заглушки под продакшен).
class AuthController extends ChangeNotifier {
  /// Только цифры после +7 (10 шт., например 9XXXXXXXXX).
  String? _phoneNationalDigits;

  bool smsVerified = false;

  AccessLevel accessLevel = AccessLevel.basic;

  /// PIN из 6 цифр (в прототипе в памяти; в проде — только хэш в защищённом хранилище).
  String? _pin;

  bool biometricEnabled = false;

  String? get phoneNationalDigits => _phoneNationalDigits;

  String get displayPhone {
    final d = _phoneNationalDigits;
    if (d == null || d.isEmpty) return '+7';
    if (d.length <= 3) return '+7 $d';
    if (d.length <= 6) {
      return '+7 ${d.substring(0, 3)} ${d.substring(3)}';
    }
    if (d.length <= 8) {
      return '+7 ${d.substring(0, 3)} ${d.substring(3, 6)}-${d.substring(6)}';
    }
    return '+7 ${d.substring(0, 3)} ${d.substring(3, 6)}-${d.substring(6, 8)}-${d.substring(8)}';
  }

  void setPhoneNationalDigits(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    var national = clean;
    if (national.startsWith('8') && national.length >= 11) {
      national = national.substring(1);
    }
    if (national.startsWith('7')) {
      national = national.substring(1);
    }
    national = national.length > 10 ? national.substring(0, 10) : national;
    _phoneNationalDigits = national.isEmpty ? null : national;
    notifyListeners();
  }

  /// Заглушка: любой код из 4–6 цифр считается верным.
  bool verifySmsCode(String code) {
    final c = code.replaceAll(RegExp(r'\D'), '');
    if (c.length < 4 || c.length > 6) return false;
    smsVerified = true;
    accessLevel = AccessLevel.basic;
    notifyListeners();
    return true;
  }

  void setPin6(String pin) {
    final p = pin.replaceAll(RegExp(r'\D'), '');
    if (p.length != 6) return;
    _pin = p;
    notifyListeners();
  }

  bool validatePin(String pin) {
    final p = pin.replaceAll(RegExp(r'\D'), '');
    return _pin != null && _pin == p && p.length == 6;
  }

  bool get isPinSet => _pin != null && _pin!.length == 6;

  /// Только для внутренних проверок (например Panic PIN в настройках). Не отображать в UI.
  String? get mainPinDigits => _pin;

  void setBiometricEnabled(bool value) {
    biometricEnabled = value;
    notifyListeners();
  }

  /// Заглушка KYC: «паспорт» или «Госуслуги».
  void completeKycStub() {
    accessLevel = AccessLevel.tsar;
    notifyListeners();
  }

  void resetForDebug() {
    _phoneNationalDigits = null;
    smsVerified = false;
    accessLevel = AccessLevel.basic;
    _pin = null;
    biometricEnabled = false;
    notifyListeners();
  }

  /// После полного стирания данных (удаление аккаунта).
  void resetAfterWipe() {
    resetForDebug();
  }
}
