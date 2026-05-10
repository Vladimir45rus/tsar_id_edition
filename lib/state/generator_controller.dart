import 'dart:math';

import 'package:flutter/foundation.dart';

/// Состояние вкладки «Генератор»; сбрасывается при смене вкладки нижней навигации.
class GeneratorController extends ChangeNotifier {
  static const int minLength = 8;
  static const int maxLength = 24;

  double _length = 16;
  bool uppercase = true;
  bool lowercase = true;
  bool digits = true;
  bool symbols = true;

  final List<String> generatedPasswords = [];

  int get length => _length.round().clamp(minLength, maxLength);

  set lengthSlider(double v) {
    _length = v.clamp(minLength.toDouble(), maxLength.toDouble());
    notifyListeners();
  }

  double get lengthSlider => _length.clamp(minLength.toDouble(), maxLength.toDouble());

  bool get hasCharset =>
      uppercase || lowercase || digits || symbols;

  void setUppercase(bool value) {
    uppercase = value;
    notifyListeners();
  }

  void setLowercase(bool value) {
    lowercase = value;
    notifyListeners();
  }

  void setDigits(bool value) {
    digits = value;
    notifyListeners();
  }

  void setSymbols(bool value) {
    symbols = value;
    notifyListeners();
  }

  /// Очистка списка сгенерированных паролей (вызывается из навигации вкладок).
  void clearPasswords() {
    if (generatedPasswords.isEmpty) return;
    generatedPasswords.clear();
    notifyListeners();
  }

  /// Генерирует 10 паролей с текущими настройками.
  void generateBatch10() {
    if (!hasCharset) return;
    final len = length;
    generatedPasswords
      ..clear()
      ..addAll(List.generate(10, (_) => _randomPassword(len)));
    notifyListeners();
  }

  String _randomPassword(int len) {
    final pool = <int>[];
    if (uppercase) pool.addAll('ABCDEFGHJKLMNPQRSTUVWXYZ'.codeUnits);
    if (lowercase) pool.addAll('abcdefghijkmnopqrstuvwxyz'.codeUnits);
    if (digits) pool.addAll('23456789'.codeUnits);
    if (symbols) pool.addAll(r'!@#$%&*-_=+?'.codeUnits);

    if (pool.isEmpty) return '';

    final rnd = Random.secure();
    final requiredSets = <List<int>>[];
    if (uppercase) requiredSets.add('ABCDEFGHJKLMNPQRSTUVWXYZ'.codeUnits);
    if (lowercase) requiredSets.add('abcdefghijkmnopqrstuvwxyz'.codeUnits);
    if (digits) requiredSets.add('23456789'.codeUnits);
    if (symbols) requiredSets.add(r'!@#$%&*-_=+?'.codeUnits);

    final out = List<int>.filled(len, pool[rnd.nextInt(pool.length)]);
    for (var i = 0; i < requiredSets.length && i < len; i++) {
      final set = requiredSets[i];
      out[i] = set[rnd.nextInt(set.length)];
    }
    for (var i = 0; i < len; i++) {
      out[i] = pool[rnd.nextInt(pool.length)];
    }
    for (var i = out.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final t = out[i];
      out[i] = out[j];
      out[j] = t;
    }
    return String.fromCharCodes(out);
  }
}
