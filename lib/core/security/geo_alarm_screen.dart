import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../../state/security_controller.dart';

/// Полноэкранная блокировка при гео-тревоге (5 минут).
///
/// Звук: системные сигналы; на iOS в беззвучном режиме громкость может быть
/// ограничена политикой Apple — используем [asAlarm] где поддерживается.
class GeoAlarmScreen extends StatefulWidget {
  const GeoAlarmScreen({
    super.key,
    required this.locationLabel,
  });

  final String locationLabel;

  static Future<void> open(
    BuildContext context, {
    required SecurityController security,
    required String locationLabel,
  }) {
    security.lastGeoAlarmMessage = locationLabel;
    unawaited(security.persistToStorage());
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ChangeNotifierProvider.value(
          value: security,
          child: GeoAlarmScreen(locationLabel: locationLabel),
        ),
      ),
    );
  }

  @override
  State<GeoAlarmScreen> createState() => _GeoAlarmScreenState();
}

class _GeoAlarmScreenState extends State<GeoAlarmScreen> {
  Timer? _tick;
  Timer? _vibe;

  late Duration _left;

  @override
  void initState() {
    super.initState();
    final sec = context.read<SecurityController>();
    final until = sec.geoAlarmLockUntil;
    if (until != null) {
      _left = until.difference(DateTime.now());
      if (_left.isNegative) {
        _left = Duration.zero;
      }
    } else {
      _left = const Duration(minutes: 5);
    }

    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _vibe = Timer.periodic(const Duration(milliseconds: 900), (_) => _pulseVibrate());

    _pulseVibrate();
    unawaited(_startLoopingAlarm());
  }

  /// asAlarm: true — максимально возможное игнорирование беззвучного режима на Android.
  Future<void> _startLoopingAlarm() async {
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.glass,
        looping: true,
        volume: 1,
        asAlarm: true,
      );
    } on Object catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } on Object catch (_) {}
    }
  }

  Future<void> _pulseVibrate() async {
    try {
      final has = await Vibration.hasVibrator();
      if (has == true) {
        await Vibration.vibrate(duration: 400);
      }
    } on Object catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  void _onTick() {
    final sec = context.read<SecurityController>();
    final until = sec.geoAlarmLockUntil;
    if (until == null) {
      _finish();
      return;
    }
    setState(() {
      _left = until.difference(DateTime.now());
    });
    if (_left.isNegative || _left == Duration.zero) {
      _finish();
    }
  }

  Future<void> _finish() async {
    _tick?.cancel();
    _vibe?.cancel();
    try {
      await FlutterRingtonePlayer().stop();
    } on Object catch (_) {}
    final sec = context.read<SecurityController>();
    await sec.clearGeoAlarmLock();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _vibe?.cancel();
    unawaited(FlutterRingtonePlayer().stop());
    super.dispose();
  }

  String _format(Duration d) {
    if (d.isNegative) return '0:00';
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Попытка взлома из',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.locationLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Интерфейс заблокирован. Ожидайте окончания таймера.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                Text(
                  _format(_left),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
