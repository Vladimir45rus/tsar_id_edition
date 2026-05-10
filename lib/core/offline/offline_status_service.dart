import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class OfflineStatusService extends ChangeNotifier {
  OfflineStatusService() { _init(); }

  bool _offline = false;
  StreamSubscription<dynamic>? _sub;
  bool get isOffline => _offline;

  Future<void> _init() async {
    await _refresh();
    _sub = Connectivity().onConnectivityChanged.listen((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final res = await Connectivity().checkConnectivity();
      // Чисто текстовая проверка - не упадет никогда
      final bool isDisconnected = res.toString().toLowerCase().contains('none');
      if (isDisconnected != _offline) {
        _offline = isDisconnected;
        notifyListeners();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}