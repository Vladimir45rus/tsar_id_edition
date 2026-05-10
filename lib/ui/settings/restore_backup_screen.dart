import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/backup/backup_service.dart';
import '../../state/security_controller.dart';
import '../../state/vault_repository.dart';
import '../../theme/tsar_theme.dart';
import '../widgets/tsar_haptics.dart';

/// Импорт `.tsarbackup` на устройстве (расшифровка локально).
class RestoreBackupScreen extends StatefulWidget {
  const RestoreBackupScreen({super.key});

  @override
  State<RestoreBackupScreen> createState() => _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends State<RestoreBackupScreen> {
  final _mnemonic = TextEditingController();
  final _pin = TextEditingController();
  String? _path;
  var _busy = false;

  @override
  void dispose() {
    _mnemonic.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    TsarHaptics.tap();
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['tsarbackup'],
    );
    if (r != null && r.files.single.path != null) {
      setState(() => _path = r.files.single.path);
    }
  }

  Future<void> _restore() async {
    final path = _path;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите файл .tsarbackup')),
      );
      return;
    }
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
      return;
    }

    setState(() => _busy = true);
    try {
      final seed = bip39.mnemonicToSeed(phrase);
      final file = File(path);
      final map = await BackupService.instance.decryptBackupFile(
        file: file,
        bip39Seed64: seed,
        pinUtf8: pin,
      );
      final settings =
          await context.read<VaultRepository>().importFromSnapshot(map);
      final st = settings;
      if (st != null && context.mounted) {
        final sec = context.read<SecurityController>();
        sec.setGeoShieldEnabled(st['geoShieldEnabled'] as bool? ?? true);
        sec.setTrustRadiusKm((st['trustRadiusKm'] as num?)?.toDouble() ?? 100);
        final wl = st['whitelist'];
        if (wl is List) {
          sec.whitelistCountryCodes.clear();
          for (final c in wl) {
            sec.addWhitelistCountry(c.toString());
          }
        }
        final lat = st['homeLat'] as num?;
        final lng = st['homeLng'] as num?;
        final cc = st['homeCountry'] as String?;
        if (lat != null && lng != null && cc != null) {
          sec.setHomeRegion(
            lat: lat.toDouble(),
            lng: lng.toDouble(),
            countryCode: cc,
          );
        }
        await sec.persistToStorage();
      }
      TsarHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные восстановлены локально.')),
        );
        Navigator.of(context).pop();
      }
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
      appBar: AppBar(title: const Text('Восстановление из бэкапа')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'После SMS-регистрации на новом устройстве выберите файл резервной копии и введите '
            'фразу восстановления + PIN. Сервер расшифровку не выполняет.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.folder_open),
            label: Text(_path == null ? 'Выбрать .tsarbackup' : _path!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mnemonic,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'BIP39 (24 слова)',
              border: OutlineInputBorder(),
            ),
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
          FilledButton(
            onPressed: _busy ? null : _restore,
            style: FilledButton.styleFrom(
              backgroundColor: TsarTheme.gold,
              foregroundColor: Colors.black,
            ),
            child: Text(_busy ? 'Восстановление…' : 'Расшифровать и импорт'),
          ),
        ],
      ),
    );
  }
}
