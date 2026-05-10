import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Локальный журнал событий безопасности (только на устройстве).
///
/// Формат строк: JSON Lines (одна запись = одна строка).
class SecurityJournalService {
  SecurityJournalService._();
  static final SecurityJournalService instance = SecurityJournalService._();

  static const _fileName = 'security_journal.jsonl';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Добавить запись (время UTC).
  Future<void> log({
    required String event,
    Map<String, Object?> details = const {},
  }) async {
    try {
      final f = await _file();
      final line = jsonEncode({
        'ts': DateTime.now().toUtc().toIso8601String(),
        'event': event,
        ...details,
      });
      await f.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } on Object catch (e, st) {
      debugPrint('SecurityJournalService.log failed: $e\n$st');
    }
  }

  /// Последние [maxLines] записей (новые в конце).
  Future<List<Map<String, dynamic>>> readRecent({int maxLines = 200}) async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final text = await f.readAsString();
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final slice = lines.length > maxLines ? lines.sublist(lines.length - maxLines) : lines;
      return slice
          .map((l) => jsonDecode(l) as Map<String, dynamic>)
          .toList();
    } on Object {
      return [];
    }
  }
}
