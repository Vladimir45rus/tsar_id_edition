import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки медиа-интро и флаг первого запуска (без пропуска до завершения).
class MediaIntroService extends ChangeNotifier {
  static const _kVideo = 'media_intro_video';
  static const _kAudio = 'media_intro_audio';
  static const _kDone = 'media_intro_completed';

  bool videoIntroEnabled = true;
  bool audioIntroEnabled = true;
  bool introCompleted = false;

  Future<void>? _ensureFuture;

  MediaIntroService();

  /// Ожидание загрузки флагов из SharedPreferences (нужно для [AppEntry]).
  Future<void> ensureLoaded() async {
    _ensureFuture ??= _loadFromPrefs();
    await _ensureFuture;
  }

  Future<void> _loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    videoIntroEnabled = p.getBool(_kVideo) ?? true;
    audioIntroEnabled = p.getBool(_kAudio) ?? true;
    introCompleted = p.getBool(_kDone) ?? false;
    notifyListeners();
  }

  Future<void> setVideoEnabled(bool v) async {
    videoIntroEnabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kVideo, v);
    notifyListeners();
  }

  Future<void> setAudioEnabled(bool v) async {
    audioIntroEnabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAudio, v);
    notifyListeners();
  }

  Future<void> disableAll() async {
    await setVideoEnabled(false);
    await setAudioEnabled(false);
  }

  /// Вызывается после просмотра интро на первом запуске.
  Future<void> markIntroCompleted() async {
    introCompleted = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDone, true);
    notifyListeners();
  }
}
