import 'package:shared_preferences/shared_preferences.dart';

/// Юридические согласия до регистрации (отдельные флаги по темам).
class LegalConsentStore {
  static const _kPd = 'consent_personal_data';
  static const _kGeo = 'consent_geolocation';
  static const _kBio = 'consent_biometric';
  static const _kTrap = 'consent_camera_trap';
  static const _kCam = 'consent_camera_docs';

  Future<bool> get personalData async =>
      (await SharedPreferences.getInstance()).getBool(_kPd) ?? false;

  Future<bool> get geolocation async =>
      (await SharedPreferences.getInstance()).getBool(_kGeo) ?? false;

  Future<bool> get biometric async =>
      (await SharedPreferences.getInstance()).getBool(_kBio) ?? false;

  Future<bool> get cameraTrap async =>
      (await SharedPreferences.getInstance()).getBool(_kTrap) ?? false;

  Future<bool> get cameraDocs async =>
      (await SharedPreferences.getInstance()).getBool(_kCam) ?? false;

  Future<void> setPersonalData(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kPd, v);

  Future<void> setGeolocation(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kGeo, v);

  Future<void> setBiometric(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kBio, v);

  Future<void> setCameraTrap(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kTrap, v);

  Future<void> setCameraDocs(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kCam, v);

  Future<bool> get allAccepted async {
    final p = await SharedPreferences.getInstance();
    return (p.getBool(_kPd) ?? false) &&
        (p.getBool(_kGeo) ?? false) &&
        (p.getBool(_kBio) ?? false) &&
        (p.getBool(_kTrap) ?? false) &&
        (p.getBool(_kCam) ?? false);
  }
}
