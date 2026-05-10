import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../state/security_controller.dart';
import 'security_journal_service.dart';

/// Результат проверки гео-щита.
enum GeoShieldVerdict {
  /// Нет сети — проверка пропущена (офлайн).
  skippedOffline,

  /// Гео-щит выключен пользователем.
  skippedDisabled,

  /// Домашний регион ещё не зафиксирован — тревогу не поднимаем.
  skippedNoBaseline,

  /// Текущая позиция/страна в пределах доверия.
  ok,

  /// Сработала тревога (дистанция или смена страны относительно «дома»).
  alarm,
}

/// Сервис гео-защиты. В этой сборке плагины геолокации отключены — проверка по GPS не выполняется.
class GeoSecurityService {
  GeoSecurityService._();
  static final GeoSecurityService instance = GeoSecurityService._();

  /// Проверка при старте или перед защищённым действием.
  Future<GeoCheckResult> evaluate(SecurityController sec) async {
    if (!sec.geoShieldEnabled) {
      return const GeoCheckResult(verdict: GeoShieldVerdict.skippedDisabled);
    }

    final online = await _hasNetworkRoute();
    if (!online) {
      await SecurityJournalService.instance.log(
        event: 'geo_check_skipped',
        details: {'reason': 'offline'},
      );
      return const GeoCheckResult(verdict: GeoShieldVerdict.skippedOffline);
    }

    if (sec.homeLatitude == null ||
        sec.homeLongitude == null ||
        sec.homeCountryCode == null) {
      return const GeoCheckResult(verdict: GeoShieldVerdict.skippedNoBaseline);
    }

    await SecurityJournalService.instance.log(
      event: 'geo_check_skipped',
      details: {'reason': 'no_geolocation_plugin'},
    );
    return const GeoCheckResult(verdict: GeoShieldVerdict.ok);
  }

  /// Первая верификация: сохранить текущее положение как «дом» (нужны плагины геолокации).
  Future<bool> captureHomeBaseline(SecurityController sec) async {
    final online = await _hasNetworkRoute();
    if (!online) return false;
    debugPrint('captureHomeBaseline: геолокация недоступна в этой сборке');
    return false;
  }

  Future<bool> _hasNetworkRoute() async {
    final r = await Connectivity().checkConnectivity();
    final onlyNone =
        r == ConnectivityResult.none;
    return !onlyNone;
  }
}

/// Детальный результат проверки (для оверлея тревоги).
class GeoCheckResult {
  const GeoCheckResult({
    required this.verdict,
    this.message,
    this.distanceKm,
  });

  final GeoShieldVerdict verdict;
  final String? message;
  final double? distanceKm;
}
