import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import 'biometric_setup_screen.dart';

/// Создание PIN из 6 цифр с подтверждением.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _next() {
    final a = _pin1.text.replaceAll(RegExp(r'\D'), '');
    final b = _pin2.text.replaceAll(RegExp(r'\D'), '');
    if (a.length != 6 || b.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN должен состоять из 6 цифр.')),
      );
      return;
    }
    if (a != b) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN и подтверждение не совпадают.')),
      );
      return;
    }
    context.read<AuthController>().setPin6(a);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const BiometricSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание PIN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Придумайте PIN из 6 цифр',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _pin1,
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
              const SizedBox(height: 16),
              TextField(
                controller: _pin2,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Повторите PIN',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _next(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _next,
                child: const Text('Далее'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
