import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/media/media_intro_service.dart';
import '../../theme/tsar_theme.dart';
import '../widgets/tsar_haptics.dart';

/// Медиа-интро: первый запуск без кнопки «Пропустить» до завершения таймера.
class MediaIntroScreen extends StatefulWidget {
  const MediaIntroScreen({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<MediaIntroScreen> createState() => _MediaIntroScreenState();
}

class _MediaIntroScreenState extends State<MediaIntroScreen> {
  Timer? _t;
  var _progress = 0.0;
  var _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    const total = Duration(seconds: 5);
    const tick = Duration(milliseconds: 50);
    var elapsed = Duration.zero;
    _t = Timer.periodic(tick, (timer) {
      elapsed += tick;
      setState(() {
        _progress = (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
      });
      if (elapsed >= total) {
        timer.cancel();
        _finishIntro();
      }
    });
  }

  Future<void> _finishIntro() async {
    if (_done) return;
    _done = true;
    TsarHaptics.success();
    await context.read<MediaIntroService>().markIntroCompleted();
    await widget.onFinished();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaIntroService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Добро пожаловать'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Царь-ID',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: TsarTheme.gold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              media.videoIntroEnabled && media.audioIntroEnabled
                  ? 'Воспроизведение интро (имитация видео/аудио). Первый запуск нельзя пропустить.'
                  : 'Интро частично отключено в настройках (после входа).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: TsarGlass(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 80,
                        color: TsarTheme.gold.withOpacity(0.8),
                      ),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: _progress,
                        color: TsarTheme.gold,
                        backgroundColor: Colors.white12,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 16),
                          Text('${(_progress * 100).round()}%'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Видео-интро'),
              value: media.videoIntroEnabled,
              onChanged: _done
                  ? (v) {
                      TsarHaptics.tap();
                      media.setVideoEnabled(v);
                    }
                  : null,
            ),
            SwitchListTile(
              title: const Text('Аудио-интро'),
              value: media.audioIntroEnabled,
              onChanged: _done
                  ? (v) {
                      TsarHaptics.tap();
                      media.setAudioEnabled(v);
                    }
                  : null,
            ),
            TextButton(
              onPressed: _done
                  ? () async {
                      TsarHaptics.tap();
                      await media.disableAll();
                    }
                  : null,
              child: const Text('Отключить всё'),
            ),
          ],
        ),
      ),
    );
  }
}
