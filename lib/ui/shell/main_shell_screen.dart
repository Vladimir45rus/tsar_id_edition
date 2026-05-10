import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';

import '../../core/offline/offline_status_service.dart';
import '../../core/security/geo_alarm_screen.dart';
import '../../core/security/geo_security_service.dart';
import '../../state/auth_controller.dart';
import '../../state/generator_controller.dart';
import '../../state/security_controller.dart';
import '../../theme/tsar_theme.dart';
import '../settings/settings_screen.dart';
import '../widgets/tsar_haptics.dart';
import 'unlock_settings_gate.dart';
import 'vault_tab_screen.dart';
import 'passwords_tab_screen.dart';
import 'generator_tab_screen.dart';

/// Основная оболочка с нижней навигацией и AppBar.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _tabIndex = 0;
  var _geoFlowStarted = false;
  DateTime? _lastProtectedGeoCheck;

  static const _titles = ['Сейф', 'Пароли', 'Генератор'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runGeoShieldFlow();
      _setScreenshotProtection(true);
    });
  }

  @override
  void dispose() {
    unawaited(_setScreenshotProtection(false));
    super.dispose();
  }

  /// FLAG_SECURE (Android) / ограничение записи экрана (iOS) на защищённых вкладках.
  Future<void> _setScreenshotProtection(bool enable) async {
    if (kIsWeb) return;
    try {
      if (enable) {
        await ScreenProtector.preventScreenshotOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
      }
    } on Object catch (_) {}
  }

  /// Гео-щит: офлайн — пропуск; без «дома» — попытка зафиксировать; затем оценка.
  Future<void> _runGeoShieldFlow() async {
    if (_geoFlowStarted || !mounted) return;
    _geoFlowStarted = true;

    final sec = context.read<SecurityController>();
    sec.clearGeoAlarmLockIfExpired();
    await sec.persistToStorage();

    if (!mounted) return;

    if (sec.isGeoAlarmActive) {
      await GeoAlarmScreen.open(
        context,
        security: sec,
        locationLabel: sec.lastGeoAlarmMessage ?? 'Неизвестная локация',
      );
      return;
    }

    if (!sec.geoShieldEnabled) return;

    if (sec.homeLatitude == null) {
      await GeoSecurityService.instance.captureHomeBaseline(sec);
      await sec.persistToStorage();
    }

    if (!mounted) return;

    final result = await GeoSecurityService.instance.evaluate(sec);
    if (!mounted) return;

    if (result.verdict == GeoShieldVerdict.alarm) {
      sec.startGeoAlarmLock();
      sec.lastGeoAlarmMessage =
          result.message ?? 'Подозрительная геолокация / сеть';
      await sec.persistToStorage();
      await GeoAlarmScreen.open(
        context,
        security: sec,
        locationLabel: sec.lastGeoAlarmMessage!,
      );
    }
  }

  /// Повторная проверка при входе в защищённые вкладки (Сейф, Пароли).
  Future<void> _geoRecheckProtected() async {
    final sec = context.read<SecurityController>();
    if (!sec.geoShieldEnabled || !mounted) return;
    if (sec.homeLatitude == null) return;

    final now = DateTime.now();
    if (_lastProtectedGeoCheck != null &&
        now.difference(_lastProtectedGeoCheck!) < const Duration(seconds: 60)) {
      return;
    }
    _lastProtectedGeoCheck = now;

    final result = await GeoSecurityService.instance.evaluate(sec);
    if (!mounted) return;
    if (result.verdict == GeoShieldVerdict.alarm) {
      sec.startGeoAlarmLock();
      sec.lastGeoAlarmMessage =
          result.message ?? 'Подозрительная геолокация / сеть';
      await sec.persistToStorage();
      await GeoAlarmScreen.open(
        context,
        security: sec,
        locationLabel: sec.lastGeoAlarmMessage!,
      );
    }
  }

  void _onTabChanged(int index) {
    if (index == _tabIndex) return;
    TsarHaptics.tap();
    context.read<GeneratorController>().clearPasswords();
    setState(() => _tabIndex = index);
    if (index == 0 || index == 1) {
      unawaited(_geoRecheckProtected());
    }
  }

  Future<void> _openSettings() async {
    final auth = context.read<AuthController>();
    final unlocked = await UnlockSettingsGate.show(context, auth);
    if (!mounted || !unlocked) return;

    await _setScreenshotProtection(false);
    try {
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          transitionDuration: TsarTheme.routeDuration,
          reverseTransitionDuration: TsarTheme.routeDuration,
          pageBuilder: (_, __, ___) => const SettingsScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } finally {
      await _setScreenshotProtection(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineStatusService>().isOffline;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabIndex]),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offline)
            Material(
              color: Colors.amber.shade900,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Text(
                  'Оффлайн — синхронизация и гео-проверка отложены',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.amber.shade50,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: const [
                VaultTabScreen(),
                PasswordsTabScreen(),
                GeneratorTabScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Сейф',
          ),
          NavigationDestination(
            icon: Icon(Icons.key_outlined),
            selectedIcon: Icon(Icons.vpn_key),
            label: 'Пароли',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Генератор',
          ),
        ],
      ),
    );
  }
}
