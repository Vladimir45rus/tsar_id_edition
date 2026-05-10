import 'dart:io';

import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

/// Инициализация нативных библиотек SQLCipher на Android (только с dart:io).
Future<void> initSqlcipherIfNeeded() async {
  if (Platform.isAndroid) {
    try {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    } on Object catch (_) {}
  }
}
