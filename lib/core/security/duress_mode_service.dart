import 'package:flutter/foundation.dart';

import 'security_journal_service.dart';

/// Режим принуждения (фальшивый сейф): флаг в памяти + запись в журнал.
///
/// Настоящие данные не удаляются — UI просто показывает пустые списки.
class DuressModeService extends ChangeNotifier {
  bool _active = false;

  bool get isActive => _active;

  /// Войти в duress (Panic PIN прошёл проверку).
  Future<void> activate({String? displayPhone}) async {
    if (_active) return;
    _active = true;
    notifyListeners();
    await SecurityJournalService.instance.log(
      event: 'duress_mode_activated',
      details: {
        if (displayPhone != null) 'phone': displayPhone,
      },
    );
  }

  /// Выйти из duress (успешный обычный PIN).
  void deactivate() {
    if (!_active) return;
    _active = false;
    notifyListeners();
  }

  /// Сброс при выходе из аккаунта / отладке.
  void reset() {
    _active = false;
    notifyListeners();
  }
}
