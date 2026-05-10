import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/trusted/trusted_contacts_service.dart';
import '../../theme/tsar_theme.dart';
import '../widgets/tsar_haptics.dart';

/// Доверенные контакты и аварийный токен.
class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TrustedContactsService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Аварийный доступ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'До двух номеров. Сгенерируйте токен и передайте контакту через защищённый канал. '
            'Срок действия — 24 часа, события пишутся в журнал безопасности.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Телефон доверенного лица',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: tc.contacts.length >= 2
                ? null
                : () async {
                    TsarHaptics.tap();
                    await tc.addContact(_phoneCtrl.text);
                    _phoneCtrl.clear();
                  },
            style: FilledButton.styleFrom(
              backgroundColor: TsarTheme.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Добавить контакт'),
          ),
          const Divider(height: 32),
          ...tc.contacts.map(
            (c) => ListTile(
              title: Text(c.label ?? c.phoneDigits),
              subtitle: Text(c.phoneDigits),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  TsarHaptics.tap();
                  await tc.removeContact(c.id);
                },
              ),
            ),
          ),
          const Divider(height: 32),
          FilledButton.icon(
            onPressed: () async {
              TsarHaptics.success();
              final token = await tc.generateEmergencyToken();
              if (!context.mounted) return;
              await Share.share(
                'Царь-ID · аварийный токен\n${token.tokenPublic}\n'
                'Действителен до: ${token.expiresUtc.toIso8601String()}',
              );
            },
            icon: const Icon(Icons.vpn_key),
            label: const Text('Сгенерировать токен (24 ч)'),
            style: FilledButton.styleFrom(
              backgroundColor: TsarTheme.gold,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              TsarHaptics.tap();
              await tc.revokeAllTokens();
            },
            child: const Text('Отозвать все токены'),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Проверка токена (имитация входа контакта)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) async {
              final ok = await tc.redeemTokenForVaultAccess(v.trim());
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Токен принят.' : 'Токен недействителен.')),
              );
            },
          ),
          if (tc.isEmergencyWindowActive)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Аварийное окно активно до ${tc.emergencyUnlockUntil}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
