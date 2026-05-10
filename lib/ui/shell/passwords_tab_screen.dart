import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/clipboard/clipboard_watchdog.dart';
import '../../core/security/duress_mode_service.dart';
import '../../state/vault_repository.dart';
import '../../theme/tsar_theme.dart';
import '../widgets/tsar_haptics.dart';

/// Вкладка «Пароли»: данные из [VaultRepository], индикатор утечки, копирование с таймером очистки буфера.
class PasswordsTabScreen extends StatelessWidget {
  const PasswordsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final duress = context.watch<DuressModeService>();
    final vault = context.watch<VaultRepository>();

    if (duress.isActive) {
      return Center(
        child: Text(
          'Нет сохранённых паролей.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    if (vault.entries.isEmpty) {
      return const Center(child: Text('Список пуст. Импортируйте бэкап или добавьте записи.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: vault.entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = vault.entries[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                e.leaked ? Colors.red.shade900 : TsarTheme.gold.withOpacity(0.3),
            child: Text(
              e.title.isNotEmpty ? e.title[0].toUpperCase() : '?',
              style: TextStyle(
                color: e.leaked ? Colors.white : Colors.black,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(child: Text(e.title)),
              if (e.leaked) ...[
                const Icon(Icons.warning_amber, color: Colors.redAccent, size: 22),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Утечка',
                    style: TextStyle(color: Colors.redAccent.shade100, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '•' * (e.password.length.clamp(6, 16)),
            style: const TextStyle(letterSpacing: 2),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (e.leaked)
                IconButton(
                  tooltip: 'Сгенерировать новый в Генераторе',
                  icon: const Icon(Icons.bolt_outlined, color: TsarTheme.gold),
                  onPressed: () {
                    TsarHaptics.tap();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Откройте вкладку «Генератор» и создайте новый пароль.'),
                      ),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Копировать',
                onPressed: () {
                  TsarHaptics.success();
                  Clipboard.setData(ClipboardData(text: e.password));
                  ClipboardWatchdog.scheduleClearSensitive();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Скопировано. Буфер очистится через 30 с.'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
