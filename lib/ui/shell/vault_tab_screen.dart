import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/security/duress_mode_service.dart';
import '../../state/auth_controller.dart';
import '../../state/vault_documents_repository.dart';

/// Вкладка «Сейф»: KYC для уровня 2 и добавление документа с камеры.
class VaultTabScreen extends StatelessWidget {
  const VaultTabScreen({super.key});

  Future<void> _openCamera(BuildContext context) async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (!context.mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Съёмка отменена.')),
        );
        return;
      }

      // Показываем диалог для ввода названия и категории
      if (!context.mounted) return;
      await _showSaveDialog(context, File(file.path));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Камера недоступна: $e')),
      );
    }
  }

  Future<void> _showSaveDialog(BuildContext context, File file) async {
    final titleController = TextEditingController();
    String selectedCategory = 'passport';

    final categories = {
      'passport': 'Паспорт',
      'inn': 'ИНН',
      'snils': 'СНИЛС',
      'driver': 'Водительские права',
      'diploma': 'Диплом',
      'other': 'Другое',
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Сохранить документ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Название документа',
                  hintText: 'Например: Паспорт РФ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Категория:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: categories.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedCategory = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      // Сохраняем через VaultDocumentsRepository
      final vault = context.read<VaultDocumentsRepository>();
      final success = await vault.saveDocument(
        file: file,
        title: titleController.text.trim(),
        category: selectedCategory,
      );

      if (!context.mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Документ сохранён в сейф'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Ошибка сохранения документа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final duress = context.watch<DuressModeService>();
    final vault = context.watch<VaultDocumentsRepository>();
    final unlocked = auth.accessLevel == AccessLevel.tsar;

    if (duress.isActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Документов нет.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    if (!unlocked) {
      return _KycLockBody(
        onPassport: () => context.read<AuthController>().completeKycStub(),
        onGosuslugi: () => context.read<AuthController>().completeKycStub(),
      );
    }

    // Если документов нет
    if (vault.documents.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Text(
              'Документов пока нет.\nНажмите «+», чтобы снять скан.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: FloatingActionButton(
              onPressed: () => _openCamera(context),
              tooltip: 'Добавить документ',
              child: const Icon(Icons.add),
            ),
          ),
        ],
      );
    }

    // Список документов
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vault.documents.length,
          itemBuilder: (context, index) {
            final doc = vault.documents[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  _getCategoryIcon(doc.category),
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  doc.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(_getCategoryName(doc.category)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context, doc.id),
                ),
                onTap: () => _viewDocument(context, doc),
              ),
            );
          },
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton(
            onPressed: () => _openCamera(context),
            tooltip: 'Добавить документ',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'passport':
        return Icons.badge;
      case 'inn':
        return Icons.numbers;
      case 'snils':
        return Icons.credit_card;
      case 'driver':
        return Icons.directions_car;
      case 'diploma':
        return Icons.school;
      default:
        return Icons.description;
    }
  }

  String _getCategoryName(String category) {
    const names = {
      'passport': 'Паспорт',
      'inn': 'ИНН',
      'snils': 'СНИЛС',
      'driver': 'Водительские права',
      'diploma': 'Диплом',
      'other': 'Другое',
    };
    return names[category] ?? category;
  }

  void _viewDocument(BuildContext context, dynamic doc) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Просмотр: ${doc.title}')),
    );
    // TODO: Открыть просмотр зашифрованного файла
  }

  void _confirmDelete(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить документ?'),
        content: const Text('Документ будет безвозвратно удалён из сейфа.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final vault = context.read<VaultDocumentsRepository>();
      await vault.deleteDocument(id);
    }
  }
}

class _KycLockBody extends StatelessWidget {
  const _KycLockBody({
    required this.onPassport,
    required this.onGosuslugi,
  });

  final VoidCallback onPassport;
  final VoidCallback onGosuslugi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Сейф недоступен',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Царь-режим и раздел «Сейф» откроются после верификации личности.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onPassport,
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Загрузить паспорт'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onGosuslugi,
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text('Подтвердить через Госуслуги'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}