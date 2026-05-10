import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import 'sms_code_screen.dart';

/// Ввод номера телефона с фиксированным префиксом +7.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _controller = TextEditingController();
  var _restoredDigits = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredDigits) return;
    _restoredDigits = true;
    final saved = context.read<AuthController>().phoneNationalDigits;
    if (saved != null && saved.isNotEmpty) {
      _controller.text = saved;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final digits = auth.phoneNationalDigits ?? '';
    final canSend = digits.length == 10;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Укажите номер телефона',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Мы отправим SMS с кодом подтверждения.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'Номер',
                  hintText: '9XX XXX XX XX',
                  prefixIcon: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+7 ',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  context.read<AuthController>().setPhoneNationalDigits(v);
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: canSend
                    ? () {
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SmsCodeScreen(),
                          ),
                        );
                      }
                    : null,
                child: const Text('Отправить SMS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
