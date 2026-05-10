import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/security/duress_mode_service.dart';
import '../../core/trusted/trusted_contacts_service.dart';
import '../../core/wipe/account_wipe_service.dart';
import '../../state/auth_controller.dart';
import '../../state/security_controller.dart';
import '../../state/vault_repository.dart';
import '../onboarding/app_entry.dart';
import '../widgets/tsar_haptics.dart';

/// Атомарное удаление аккаунта: PIN + SMS (заглушка), затем перезапись и очистка.
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _pin = TextEditingController();
  final _sms = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _sms.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final auth = context.read<AuthController>();
    if (!auth.validatePin(_pin.text)) {
      TsarHaptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный PIN.')),
      );
      return;
    }
    final sms = _sms.text.replaceAll(RegExp(r'\D'), '');
    if (sms.length < 4 || sms.length > 6) {
      TsarHaptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите код из SMS (демо: любой 4–6 цифр).')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить безвозвратно?'),
        content: const Text(
          'Все локальные данные будут перезаписаны и удалены. '
          'Облачные сессии отзовите через API (заглушка в сервисе).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AccountWipeService.instance.revokeRemoteSessionsStub();
      final trusted = context.read<TrustedContactsService>();
      await AccountWipeService.instance.executeFullWipe(trustedContacts: trusted);

      await context.read<VaultRepository>().clearAll();
      auth.resetAfterWipe();
      await context.read<SecurityController>().hardResetToDefaults();
      trusted.clearLocalState();
      context.read<DuressModeService>().reset();

      TsarHaptics.success();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const AppEntry(),
        ),
        (route) => false,
      );
    } on Object catch (e) {
      TsarHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Удаление аккаунта')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Соответствие практикам NIST SP 800-88 (файлы): несколько проходов случайной '
            'перезаписи перед удалением, затем очистка ключей и настроек.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'PIN',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sms,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Код из SMS',
              border: OutlineInputBorder(),
              helperText: 'Демо: любой код 4–6 цифр',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _delete,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_busy ? 'Удаление…' : 'Удалить аккаунт и все данные'),
          ),
        ],
      ),
    );
  }
}
