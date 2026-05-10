import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Глобальные настройки и состояние подсистем безопасности (Блок 3).
class SecurityController extends ChangeNotifier {
  static const _prefsGeo = 'sec_geo_shield';
  static const _prefsTrust = 'sec_trust_km';
  static const _prefsWl = 'sec_whitelist';
  static const _prefsHomeLat = 'sec_home_lat';
  static const _prefsHomeLng = 'sec_home_lng';
  static const _prefsHomeCc = 'sec_home_cc';
  static const _prefsLockUntil = 'sec_geo_lock_until';
  static const _prefsAlarmMsg = 'sec_geo_alarm_msg';
  static const _securePanic = 'sec_panic_pin';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// Гео-щит: при выключении проверки и тревоги не выполняются.
  bool geoShieldEnabled = true;

  /// Радиус доверия от «домашней» точки (км): 50 / 100 / 200.
  double trustRadiusKm = 100;

  /// Коды стран ISO 3166-1 alpha-2 в белом списке (например RU, KZ).
  final Set<String> whitelistCountryCodes = <String>{};

  /// Зафиксированный «дом» (первая успешная верификация или ручное сохранение).
  double? homeLatitude;
  double? homeLongitude;
  String? homeCountryCode;

  /// Блокировка UI после гео-тревоги (до этого момента).
  DateTime? geoAlarmLockUntil;

  /// Текст для оверлея тревоги (и при возобновлении блокировки после перезапуска).
  String? lastGeoAlarmMessage;

  /// Panic PIN (duress): при совпадении с основным PIN не задаётся.
  String? _panicPin;

  String? get panicPin => _panicPin;

  Future<void> restoreFromStorage() async {
    final p = await SharedPreferences.getInstance();
    geoShieldEnabled = p.getBool(_prefsGeo) ?? true;
    final rawTrust = p.getDouble(_prefsTrust) ?? 100;
    trustRadiusKm = _snapTrustRadius(rawTrust.clamp(50.0, 200.0));

    whitelistCountryCodes.clear();
    final wl = p.getString(_prefsWl) ?? '';
    for (final part in wl.split(',')) {
      final c = part.trim().toUpperCase();
      if (c.length == 2) whitelistCountryCodes.add(c);
    }

    homeLatitude = p.getDouble(_prefsHomeLat);
    homeLongitude = p.getDouble(_prefsHomeLng);
    homeCountryCode = p.getString(_prefsHomeCc);

    final lockIso = p.getString(_prefsLockUntil);
    geoAlarmLockUntil =
        lockIso != null ? DateTime.tryParse(lockIso) : null;
    lastGeoAlarmMessage = p.getString(_prefsAlarmMsg);

    _panicPin = await _secure.read(key: _securePanic);
    notifyListeners();
  }

  Future<void> persistToStorage() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefsGeo, geoShieldEnabled);
    await p.setDouble(_prefsTrust, trustRadiusKm);
    await p.setString(_prefsWl, whitelistCountryCodes.join(','));

    if (homeLatitude != null) {
      await p.setDouble(_prefsHomeLat, homeLatitude!);
    } else {
      await p.remove(_prefsHomeLat);
    }
    if (homeLongitude != null) {
      await p.setDouble(_prefsHomeLng, homeLongitude!);
    } else {
      await p.remove(_prefsHomeLng);
    }
    if (homeCountryCode != null && homeCountryCode!.isNotEmpty) {
      await p.setString(_prefsHomeCc, homeCountryCode!);
    } else {
      await p.remove(_prefsHomeCc);
    }

    if (geoAlarmLockUntil != null) {
      await p.setString(_prefsLockUntil, geoAlarmLockUntil!.toIso8601String());
    } else {
      await p.remove(_prefsLockUntil);
    }
    if (lastGeoAlarmMessage != null && lastGeoAlarmMessage!.isNotEmpty) {
      await p.setString(_prefsAlarmMsg, lastGeoAlarmMessage!);
    } else {
      await p.remove(_prefsAlarmMsg);
    }

    if (_panicPin != null && _panicPin!.isNotEmpty) {
      await _secure.write(key: _securePanic, value: _panicPin!);
    } else {
      await _secure.delete(key: _securePanic);
    }
  }

  void setGeoShieldEnabled(bool value) {
    geoShieldEnabled = value;
    notifyListeners();
  }

  void setTrustRadiusKm(double km) {
    if (km <= 0) return;
    trustRadiusKm = _snapTrustRadius(km);
    notifyListeners();
  }

  static double _snapTrustRadius(double v) {
    const opts = <double>[50, 100, 200];
    return opts.reduce(
      (a, b) => (a - v).abs() <= (b - v).abs() ? a : b,
    );
  }

  void addWhitelistCountry(String code) {
    final c = code.trim().toUpperCase();
    if (c.length == 2) {
      whitelistCountryCodes.add(c);
      notifyListeners();
    }
  }

  void removeWhitelistCountry(String code) {
    whitelistCountryCodes.remove(code.toUpperCase());
    notifyListeners();
  }

  void setWhitelistFromCommaSeparated(String text) {
    whitelistCountryCodes.clear();
    for (final part in text.split(',')) {
      final c = part.trim().toUpperCase();
      if (c.length == 2) whitelistCountryCodes.add(c);
    }
    notifyListeners();
  }

  void setHomeRegion({
    required double lat,
    required double lng,
    required String countryCode,
  }) {
    homeLatitude = lat;
    homeLongitude = lng;
    homeCountryCode = countryCode.toUpperCase();
    notifyListeners();
  }

  void clearHomeRegion() {
    homeLatitude = null;
    homeLongitude = null;
    homeCountryCode = null;
    notifyListeners();
  }

  void startGeoAlarmLock({Duration duration = const Duration(minutes: 5)}) {
    geoAlarmLockUntil = DateTime.now().add(duration);
    notifyListeners();
  }

  void clearGeoAlarmLockIfExpired() {
    final until = geoAlarmLockUntil;
    if (until != null && DateTime.now().isAfter(until)) {
      geoAlarmLockUntil = null;
      notifyListeners();
    }
  }

  Future<void> clearGeoAlarmLock() async {
    geoAlarmLockUntil = null;
    notifyListeners();
    await persistToStorage();
  }

  bool get isGeoAlarmActive {
    final until = geoAlarmLockUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void setPanicPin(String? pin, {String? mainPin}) {
    if (pin == null || pin.isEmpty) {
      _panicPin = null;
      notifyListeners();
      return;
    }
    final p = pin.replaceAll(RegExp(r'\D'), '');
    if (p.length != 6) return;
    final main = mainPin?.replaceAll(RegExp(r'\D'), '');
    if (main != null && main.isNotEmpty && p == main) {
      return;
    }
    _panicPin = p;
    notifyListeners();
  }

  bool matchesPanicPin(String raw) {
    final p = raw.replaceAll(RegExp(r'\D'), '');
    return _panicPin != null && p.length == 6 && _panicPin == p;
  }

  /// Сброс в состояние «как после установки» (память + запись в prefs).
  Future<void> hardResetToDefaults() async {
    geoShieldEnabled = true;
    trustRadiusKm = 100;
    whitelistCountryCodes.clear();
    homeLatitude = null;
    homeLongitude = null;
    homeCountryCode = null;
    geoAlarmLockUntil = null;
    lastGeoAlarmMessage = null;
    setPanicPin(null);
    notifyListeners();
    await persistToStorage();
  }
}
