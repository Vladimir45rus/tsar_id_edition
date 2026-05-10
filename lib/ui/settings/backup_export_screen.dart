import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/backup/backup_service.dart';
import '../../state/security_controller.dart';
import '../../state/vault_repository.dart';
import '../../theme/tsar_theme.dart';
import '../widgets/tsar_haptics.dart';

/// Экспорт зашифрованного `.tsarbackup` (ZIP+AES, ключ из BIP39+PIN).
class BackupExportScreen extends StatefulWidget {
  const BackupExportScreen({super.key});

  @override
  State<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends State<BackupExportScreen> {
  final _mnemonic = TextEditingController();
  final _pin = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _mnemonic.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final phrase = _mnemonic.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final pin = _pin.text.replaceAll(RegExp(r'\D'), '');
    if (!bip39.validateMnemonic(phrase)) {
      TsarHaptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверная BIP39-фраза.')),
      );
      return;
    }
    if (pin.length != 6) {
      TsarHaptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN — 6 цифр.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final seed = bip39.mnemonicToSeed(phrase);
      try {
        final vault = context.read<VaultRepository>();
        final sec = context.read<SecurityController>();
        final snap = vault.exportSnapshot(
          settingsExtras: {
            'geoShieldEnabled': sec.geoShieldEnabled,
            'trustRadiusKm': sec.trustRadiusKm,
            'whitelist': sec.whitelistCountryCodes.toList(),
            'homeLat': sec.homeLatitude,
            'homeLng': sec.homeLongitude,
            'homeCountry': sec.homeCountryCode,
          },
        );
        final file = await BackupService.instance.createEncryptedBackupFile(
          snapshot: snap,
          bip39Seed64: seed,
          pinUtf8: pin,
        );
        TsarHaptics.success();
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Резервная копия Царь-ID (зашифрована). Храните файл и фразу отдельно.',
        );
      } finally {
        // seed чувствителен — обнуляем буфер list нельзя гарантировать, но не держим ссылку
      }
    } on Object catch (e) {
      TsarHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Экспорт бэкапа')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Архив шифруется только на устройстве. Укажите ту же BIP39-фразу (24 слова), '
            'что была при создании кошелька, и PIN.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mnemonic,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Recovery Phrase (24 слова)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt),
            label: Text(_busy ? 'Создание…' : 'Создать .tsarbackup'),
            style: FilledButton.styleFrom(
              backgroundColor: TsarTheme.gold,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Загрузка в iCloud Drive / Google Drive: через меню «Поделиться» после создания файла '
            '(системный диалог). Прямая интеграция API облака — отдельные нативные модули.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
