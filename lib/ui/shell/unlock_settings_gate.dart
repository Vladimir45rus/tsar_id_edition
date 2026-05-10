import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../core/security/camera_trap_service.dart';
import '../../core/security/duress_mode_service.dart';
import '../../core/security/security_journal_service.dart';
import '../../state/auth_controller.dart';
import '../../state/security_controller.dart';

/// Разблокировка перед открытием «Настроек»: PIN, Panic PIN (duress), биометрия, камера-ловушка.
class UnlockSettingsGate {
  static Future<bool> show(BuildContext context, AuthController auth) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _UnlockSheet(auth: auth),
    );
    return result ?? false;
  }
}

class _UnlockSheet extends StatefulWidget {
  const _UnlockSheet({required this.auth});

  final AuthController auth;

  @override
  State<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<_UnlockSheet> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    final sec = context.read<SecurityController>();
    final trap = context.read<CameraTrapService>();
    final duress = context.read<DuressModeService>();
    final raw = _pinController.text;

    if (widget.auth.validatePin(raw)) {
      duress.deactivate();
      trap.resetFailures();
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    if (sec.matchesPanicPin(raw)) {
      await duress.activate(displayPhone: widget.auth.displayPhone);
      trap.resetFailures();
      await SecurityJournalService.instance.log(
        event: 'panic_pin_used',
        details: const <String, Object?>{},
      );
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    await trap.registerFailure(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный PIN.')),
      );
    }
  }

  Future<void> _biometric() async {
    final trap = context.read<CameraTrapService>();
    final duress = context.read<DuressModeService>();
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Открыть настройки Царь-ID',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (ok) {
        duress.deactivate();
        trap.resetFailures();
        Navigator.of(context).pop(true);
      } else {
        await trap.registerFailure(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Биометрия не подтверждена.')),
          );
        }
      }
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Подтвердите личность',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Настройки доступны после ввода PIN или биометрии.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'PIN (6 цифр)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submitPin(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitPin,
            child: const Text('Войти по PIN'),
          ),
          if (auth.biometricEnabled) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _biometric,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Биометрия'),
            ),
          ],
        ],
      ),
    );
  }
}
