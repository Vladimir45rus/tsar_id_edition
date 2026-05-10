import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import '../shell/main_shell_screen.dart';

/// Предложение включить биометрию после установки PIN.
class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final _localAuth = LocalAuthentication();
  bool _checking = true;
  bool _canCheck = false;

  @override
  void initState() {
    super.initState();
    _initBio();
  }

  Future<void> _initBio() async {
    try {
      final can = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _canCheck = can && supported;
          _checking = false;
        });
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _canCheck = false;
          _checking = false;
        });
      }
    }
  }

  Future<void> _enableBiometric() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Включить вход по биометрии для Царь-ID',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (ok) {
        context.read<AuthController>().setBiometricEnabled(true);
        _goHome();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Биометрия не подтверждена.')),
        );
      }
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка биометрии: $e')),
      );
    }
  }

  void _skip() {
    context.read<AuthController>().setBiometricEnabled(false);
    _goHome();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MainShellScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Биометрия'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Быстрый вход',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                _canCheck
                    ? 'Включите отпечаток или Face ID для разблокировки приложения и раздела «Настройки». '
                        'Вы всегда сможете использовать PIN.'
                    : 'На этом устройстве биометрия недоступна. Используйте PIN.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              if (_canCheck) ...[
                FilledButton.icon(
                  onPressed: _enableBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Включить биометрию'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: _skip,
                child: Text(_canCheck ? 'Только PIN' : 'Продолжить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
