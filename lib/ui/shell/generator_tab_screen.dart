import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/clipboard/clipboard_watchdog.dart';
import '../../state/generator_controller.dart';
import '../widgets/tsar_haptics.dart';

/// Вкладка «Генератор» паролей.
class GeneratorTabScreen extends StatelessWidget {
  const GeneratorTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gen = context.watch<GeneratorController>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Длина: ${gen.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          min: GeneratorController.minLength.toDouble(),
          max: GeneratorController.maxLength.toDouble(),
          divisions: GeneratorController.maxLength - GeneratorController.minLength,
          value: gen.lengthSlider,
          label: '${gen.length}',
          onChanged: (v) => context.read<GeneratorController>().lengthSlider = v,
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Заглавные буквы'),
          value: gen.uppercase,
          onChanged: (v) =>
              context.read<GeneratorController>().setUppercase(v ?? false),
        ),
        CheckboxListTile(
          title: const Text('Строчные буквы'),
          value: gen.lowercase,
          onChanged: (v) =>
              context.read<GeneratorController>().setLowercase(v ?? false),
        ),
        CheckboxListTile(
          title: const Text('Цифры'),
          value: gen.digits,
          onChanged: (v) =>
              context.read<GeneratorController>().setDigits(v ?? false),
        ),
        CheckboxListTile(
          title: const Text('Символы'),
          value: gen.symbols,
          onChanged: (v) =>
              context.read<GeneratorController>().setSymbols(v ?? false),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: gen.hasCharset
              ? () => context.read<GeneratorController>().generateBatch10()
              : null,
          child: const Text('Сгенерировать 10'),
        ),
        if (!gen.hasCharset)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Выберите хотя бы один набор символов.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        if (gen.generatedPasswords.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Результат',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...List.generate(gen.generatedPasswords.length, (i) {
            final pwd = gen.generatedPasswords[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReadOnlyPasswordField(
                label: 'Пароль ${i + 1}',
                password: pwd,
              ),
            );
          }),
        ],
      ],
    );
  }
}

/// Текстовое поле только для чтения с корректным жизненным циклом контроллера.
class _ReadOnlyPasswordField extends StatefulWidget {
  const _ReadOnlyPasswordField({
    required this.label,
    required this.password,
  });

  final String label;
  final String password;

  @override
  State<_ReadOnlyPasswordField> createState() => _ReadOnlyPasswordFieldState();
}

class _ReadOnlyPasswordFieldState extends State<_ReadOnlyPasswordField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.password);

  @override
  void didUpdateWidget(covariant _ReadOnlyPasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.password != widget.password) {
      _controller.text = widget.password;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Копировать',
          onPressed: () {
            TsarHaptics.success();
            Clipboard.setData(ClipboardData(text: widget.password));
            ClipboardWatchdog.scheduleClearSensitive();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Скопировано. Буфер очистится через 30 с.'),
              ),
            );
          },
        ),
      ),
    );
  }
}
