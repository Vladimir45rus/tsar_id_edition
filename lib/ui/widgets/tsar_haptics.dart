import 'package:flutter/services.dart';

/// Тактильная отдача на ключевых действиях.
class TsarHaptics {
  static void tap() {
    HapticFeedback.selectionClick();
  }

  static void success() {
    HapticFeedback.mediumImpact();
  }

  static void error() {
    HapticFeedback.heavyImpact();
  }
}
