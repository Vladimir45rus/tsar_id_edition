import 'dart:async';

import 'package:flutter/services.dart';

/// Автоочистка буфера обмена через 30 секунд после копирования пароля.
class ClipboardWatchdog {
  ClipboardWatchdog._();
  static Timer? _timer;

  /// Запланировать очистку буфера (если снова копируют — таймер сбрасывается).
  static void scheduleClearSensitive() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 30), () async {
      try {
        await Clipboard.setData(const ClipboardData(text: ''));
      } on Object catch (_) {}
      _timer = null;
    });
  }

  static void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
