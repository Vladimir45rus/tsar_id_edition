import 'package:flutter/services.dart';

/// Интеграция с системным автозаполнением паролей (Android Autofill / iOS Password AutoFill).
///
/// ## Важно (ограничения ОС)
/// Полноценное объявление приложения как **поставщика** паролей требует **нативного кода**:
///
/// **Android**
/// 1. Подкласс `android.service.autofill.AutofillService` в модуле `android/`.
/// 2. Регистрация в `AndroidManifest.xml`: `<service android:name=".TsarAutofillService" ...>`.
/// 3. XML `autofill_service_configuration.xml` со ссылкой на `android:autofillService`.
/// 4. Связка с `AssistStructure` / `FillRequest` — передача полей логина и пароля из вашей БД.
///
/// **iOS**
/// 1. Включить **Associated Domains** / **Password AutoFill** в Xcode.
/// 2. Опционально: расширение **Credential Provider** (отдельный target).
/// 3. Соответствие доменам приложения и `apple-app-site-association`.
///
/// На уровне Flutter достаточно помечать поля подсказками ([AutofillHints.username],
/// [AutofillHints.password]) — это уже сделано на экранах входа. Чтобы «Царь-ID»
/// отображался в настройках как источник, нужны шаги выше.
///
/// Ниже — канал для будущей связи с нативным сервисом (заглушка).
class AutofillIntegration {
  AutofillIntegration._();
  static const MethodChannel _channel = MethodChannel('tsar_id/autofill');

  /// Зарезервировано: нативный слой вернёт true, если сервис автозаполнения зарегистрирован.
  static Future<bool> isProviderRegistered() async {
    try {
      final v = await _channel.invokeMethod<bool>('isRegistered');
      return v ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Зарезервировано: передать учётные данные в нативный AutofillService после успешного входа.
  static Future<void> publishCredentialStub({
    required String serviceId,
    required String username,
    required String password,
  }) async {
    try {
      await _channel.invokeMethod<void>('saveCredential', {
        'serviceId': serviceId,
        'username': username,
        'password': password,
      });
    } on MissingPluginException catch (_) {}
  }
}
