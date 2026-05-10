import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/autofill/autofill_integration.dart';
import '../../core/leaks/leak_audit_service.dart';
import '../../core/media/media_intro_service.dart';
import '../../core/security/geo_security_service.dart';
import '../../state/auth_controller.dart';
import '../../state/security_controller.dart';
import '../../state/vault_repository.dart';
import '../widgets/tsar_haptics.dart';
import 'account_deletion_screen.dart';
import 'backup_export_screen.dart';
import 'restore_backup_screen.dart';
import 'trap_photos_screen.dart';
import 'trusted_contacts_screen.dart';

/// Настройки: телефон, гео-щит, Panic PIN, галерея ловушки.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _panicController = TextEditingController();
  final _whitelistController = TextEditingController();
  var _savingHome = false;
  var _whitelistSynced = false;
  var _leakAuditing = false;

  @override
  void dispose() {
    _panicController.dispose();
    _whitelistController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_whitelistSynced) {
      _whitelistSynced = true;
      final sec = context.read<SecurityController>();
      _whitelistController.text = sec.whitelistCountryCodes.join(',');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final sec = context.watch<SecurityController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.phone_android_outlined),
            title: const Text('Телефон'),
            subtitle: Text(auth.displayPhone),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.public_outlined),
            title: const Text('Гео-защита'),
            subtitle: const Text(
              'Проверка GPS и IP при входе в приложение. В офлайне проверка пропускается.',
            ),
            value: sec.geoShieldEnabled,
            onChanged: (v) async {
              sec.setGeoShieldEnabled(v);
              await sec.persistToStorage();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Радиус доверия от домашней точки',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<double>(
              multiSelectionEnabled: false,
              emptySelectionAllowed: false,
              segments: const [
                ButtonSegment(value: 50, label: Text('50 км')),
                ButtonSegment(value: 100, label: Text('100 км')),
                ButtonSegment(value: 200, label: Text('200 км')),
              ],
              selected: {sec.trustRadiusKm},
              onSelectionChanged: (s) async {
                sec.setTrustRadiusKm(s.first);
                await sec.persistToStorage();
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _whitelistController,
              decoration: const InputDecoration(
                labelText: 'Белый список стран (ISO, через запятую)',
                hintText: 'RU, KZ, BY',
                border: OutlineInputBorder(),
                helperText:
                    'Если текущая страна GPS в списке, «смена страны» не вызовет тревогу',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton(
              onPressed: () async {
                sec.setWhitelistFromCommaSeparated(_whitelistController.text);
                await sec.persistToStorage();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Белый список сохранён.')),
                  );
                }
              },
              child: const Text('Сохранить белый список'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _savingHome
                  ? null
                  : () async {
                      setState(() => _savingHome = true);
                      final ok = await GeoSecurityService.instance
                          .captureHomeBaseline(sec);
                      await sec.persistToStorage();
                      if (mounted) {
                        setState(() => _savingHome = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Домашний регион сохранён.'
                                  : 'Не удалось (сеть, разрешения или GPS).',
                            ),
                          ),
                        );
                      }
                    },
              icon: _savingHome
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.home_outlined),
              label: const Text('Зафиксировать домашний регион'),
            ),
          ),
          if (sec.homeCountryCode != null)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('Текущий «дом»'),
              subtitle: Text(
                '${sec.homeCountryCode} · '
                '${sec.homeLatitude?.toStringAsFixed(4)}, '
                '${sec.homeLongitude?.toStringAsFixed(4)}',
              ),
              trailing: TextButton(
                onPressed: () async {
                  sec.clearHomeRegion();
                  await sec.persistToStorage();
                },
                child: const Text('Сбросить'),
              ),
            ),
          const Divider(),
          ListTile(
            leading: Icon(
              auth.biometricEnabled ? Icons.fingerprint : Icons.pin_outlined,
            ),
            title: const Text('Блокировка'),
            subtitle: Text(
              auth.biometricEnabled ? 'PIN и биометрия' : 'Только PIN',
            ),
          ),
          ListTile(
            leading: Icon(
              auth.accessLevel == AccessLevel.tsar
                  ? Icons.verified_user_outlined
                  : Icons.shield_outlined,
            ),
            title: const Text('Уровень доступа'),
            subtitle: Text(
              auth.accessLevel == AccessLevel.tsar
                  ? 'Царь-режим (Сейф доступен)'
                  : 'Базовый (Пароли и Генератор)',
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Резервные копии и безопасность',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Экспорт зашифрованного бэкапа'),
            subtitle: const Text(
              'Файл .tsarbackup; можно передать в iCloud Drive / Google Drive через «Поделиться».',
            ),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const BackupExportScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Восстановить из бэкапа'),
            subtitle: const Text('Локальная расшифровка: мнемоника 24 слова + PIN.'),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RestoreBackupScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text('Аварийный доступ'),
            subtitle: const Text('Доверенные контакты (1–2 номера) и токен на 24 ч.'),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const TrustedContactsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: _leakAuditing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.security_update_good_outlined),
            title: const Text('Проверить пароли на утечки'),
            subtitle: const Text(
              'Have I Been Pwned (k-anonymity: в сеть уходит только 5 символов SHA-1).',
            ),
            onTap: _leakAuditing
                ? null
                : () async {
                    setState(() => _leakAuditing = true);
                    TsarHaptics.tap();
                    final vault = context.read<VaultRepository>();
                    try {
                      await LeakAuditService.instance.auditVault(vault);
                      if (context.mounted) {
                        TsarHaptics.success();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Проверка завершена. Смотрите индикаторы на вкладке «Пароли».'),
                          ),
                        );
                      }
                    } on Object catch (e) {
                      if (context.mounted) {
                        TsarHaptics.error();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка проверки: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _leakAuditing = false);
                    }
                  },
          ),
          FutureBuilder<bool>(
            future: AutofillIntegration.isProviderRegistered(),
            builder: (context, snap) {
              final reg = snap.data ?? false;
              return ListTile(
                leading: Icon(reg ? Icons.verified_user_outlined : Icons.password_outlined),
                title: const Text('Автозаполнение системы'),
                subtitle: Text(
                  reg
                      ? 'Нативный провайдер зарегистрирован.'
                      : 'Полная интеграция — нативный AutofillService (Android) / Credential Provider (iOS). См. autofill_integration.dart.',
                ),
              );
            },
          ),
          Consumer<MediaIntroService>(
            builder: (context, media, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Медиа при запуске',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.video_library_outlined),
                    title: const Text('Видео-интро'),
                    value: media.videoIntroEnabled,
                    onChanged: (v) => media.setVideoEnabled(v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.graphic_eq_outlined),
                    title: const Text('Аудио-интро'),
                    value: media.audioIntroEnabled,
                    onChanged: (v) => media.setAudioEnabled(v),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: OutlinedButton(
                      onPressed: () => media.disableAll(),
                      child: const Text('Отключить всё'),
                    ),
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
            title: const Text('Удалить аккаунт и все данные'),
            subtitle: const Text('NIST-подобная перезапись файлов, PIN + SMS.'),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const AccountDeletionScreen(),
                ),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Panic PIN (фальшивый сейф)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _panicController,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Panic PIN (6 цифр)',
                hintText: 'например 000000',
                border: OutlineInputBorder(),
                helperText:
                    'При вводе вместо основного PIN — пустые пароли и сейф. Не может совпадать с основным PIN.',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () async {
                    sec.setPanicPin(
                      _panicController.text,
                      mainPin: auth.mainPinDigits,
                    );
                    await sec.persistToStorage();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Panic PIN сохранён.')),
                      );
                    }
                  },
                  child: const Text('Сохранить Panic PIN'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    sec.setPanicPin(null);
                    _panicController.clear();
                    await sec.persistToStorage();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Panic PIN удалён.')),
                      );
                    }
                  },
                  child: const Text('Удалить'),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.camera_front_outlined),
            title: const Text('Фото попыток входа'),
            subtitle: const Text('До 30 зашифрованных снимков'),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const TrapPhotosScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
