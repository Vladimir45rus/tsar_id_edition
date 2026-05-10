import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/security/trap_photo_storage.dart';
import '../../state/auth_controller.dart';

/// Галерея снимков камеры-ловушки (только после ввода основного PIN, не Panic).
class TrapPhotosScreen extends StatefulWidget {
  const TrapPhotosScreen({super.key});

  @override
  State<TrapPhotosScreen> createState() => _TrapPhotosScreenState();
}

class _TrapPhotosScreenState extends State<TrapPhotosScreen> {
  final _pin = TextEditingController();
  var _unlocked = false;
  var _loading = false;
  List<TrapPhotoEntry> _entries = [];

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _tryUnlock() async {
    final auth = context.read<AuthController>();
    if (!auth.validatePin(_pin.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный PIN.')),
      );
      return;
    }
    setState(() {
      _unlocked = true;
      _loading = true;
    });
    final list = await TrapPhotoStorage.instance.listEntries();
    if (mounted) {
      setState(() {
        _entries = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Фото попыток входа'),
      ),
      body: !_unlocked
          ? _buildGate()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildGallery(),
    );
  }

  Widget _buildGate() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Введите основной PIN (не Panic PIN), чтобы просмотреть зашифрованные снимки.',
            style: Theme.of(context).textTheme.bodyLarge,
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
              labelText: 'Мастер-PIN',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _tryUnlock(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _tryUnlock,
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery() {
    if (_entries.isEmpty) {
      return const Center(
        child: Text('Записей камеры-ловушки пока нет.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _entries.length,
      itemBuilder: (context, i) {
        final e = _entries[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.memory(
                  e.jpegBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${e.timestampIso}\n'
                  '${e.latitude != null ? 'GPS: ${e.latitude}, ${e.longitude}' : 'GPS: нет'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
