import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trusted/trusted_contacts_service.dart';

/// Атомарное уничтожение данных (приближение к NIST SP 800-88 Rev. 1 для файлов).
///
/// На смартфоне нет доступа к «сырым секторам» — выполняем несколько проходов
/// случайной перезаписи байт каждого файла, затем удаление и очистка хранилищ ключей.
/// Отзыв облачных сессий и blob — отдельный вызов вашего API (здесь только заглушка-событие).
class AccountWipeService {
  AccountWipeService._();
  static final AccountWipeService instance = AccountWipeService._();

  static const _overwritePasses = 3;

  final _secure = const FlutterSecureStorage();

  Future<void> executeFullWipe({
    TrustedContactsService? trustedContacts,
  }) async {
    await _overwriteAndDeleteTree(await getApplicationDocumentsDirectory());
    await _overwriteAndDeleteTree(await getApplicationSupportDirectory());
    await _overwriteAndDeleteTree(await getTemporaryDirectory());

    await _secure.deleteAll();

    await trustedContacts?.revokeAllTokens();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (kDebugMode) {
      debugPrint('AccountWipeService: локальные данные уничтожены.');
    }
  }

  Future<void> _overwriteAndDeleteTree(Directory root) async {
    if (!await root.exists()) return;

    final files = <File>[];
    final dirs = <Directory>[];

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(entity);
      } else if (entity is Directory) {
        dirs.add(entity);
      }
    }

    for (final f in files) {
      await _secureDeleteFile(f);
    }

    dirs.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final d in dirs) {
      try {
        if (await d.exists()) await d.delete(recursive: false);
      } on Object catch (_) {}
    }
    try {
      if (await root.exists()) await root.delete(recursive: false);
    } on Object catch (_) {}
  }

  Future<void> _secureDeleteFile(File file) async {
    try {
      if (!await file.exists()) return;
      var len = await file.length();
      if (len == 0) {
        await file.delete();
        return;
      }

      final rnd = Random.secure();
      final raf = await file.open(mode: FileMode.writeOnly);

      try {
        for (var pass = 0; pass < _overwritePasses; pass++) {
          await raf.setPosition(0);
          var left = len;
          const chunk = 65536;
          while (left > 0) {
            final n = left > chunk ? chunk : left;
            final buf = Uint8List(n);
            for (var i = 0; i < n; i++) {
              buf[i] = rnd.nextInt(256);
            }
            await raf.writeFrom(buf);
            left -= n;
          }
          await raf.flush();
        }
      } finally {
        await raf.close();
      }

      len = await file.length();
      if (len > 0) {
        final trunc = await file.open(mode: FileMode.writeOnly);
        try {
          await trunc.truncate(0);
        } finally {
          await trunc.close();
        }
      }

      await file.delete();
    } on Object catch (e) {
      debugPrint('_secureDeleteFile: $e');
      try {
        await file.delete();
      } on Object catch (_) {}
    }
  }

  /// Заглушка: сюда добавить вызов API отзыва сессий и облачных копий.
  Future<void> revokeRemoteSessionsStub() async {
    debugPrint('AccountWipeService: revokeRemoteSessionsStub — подключите backend.');
  }
}
