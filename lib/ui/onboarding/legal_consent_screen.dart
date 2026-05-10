import 'package:flutter/material.dart';

import '../../state/legal_consent_store.dart';
import '../../theme/tsar_theme.dart';
import '../widgets/tsar_haptics.dart';

/// Юридические согласия до регистрации: прокрутка до конца + все чекбоксы.
class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key, required this.onFinished});

  /// После сохранения согласий — переход к следующему шагу (медиа-интро / телефон).
  final Future<void> Function() onFinished;

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  final _scroll = ScrollController();
  final _store = LegalConsentStore();

  var _scrolledToEnd = false;
  var _pd = false;
  var _geo = false;
  var _bio = false;
  var _trap = false;
  var _cam = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 32) {
      if (!_scrolledToEnd) {
        setState(() => _scrolledToEnd = true);
      }
    }
  }

  bool get _allChecked => _pd && _geo && _bio && _trap && _cam;

  Future<void> _accept() async {
    if (!_scrolledToEnd || !_allChecked) {
      TsarHaptics.error();
      return;
    }
    await _store.setPersonalData(true);
    await _store.setGeolocation(true);
    await _store.setBiometric(true);
    await _store.setCameraTrap(true);
    await _store.setCameraDocs(true);
    TsarHaptics.success();
    await widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final canAccept = _scrolledToEnd && _allChecked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Согласия'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Перед регистрацией ознакомьтесь с условиями',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: TsarTheme.gold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TsarGlass(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section(
                            'Персональные данные',
                            'Мы обрабатываем номер телефона и технические данные устройства '
                            'для аутентификации. Криптографические ключи и содержимое сейфа '
                            'остаются на устройстве (Zero-Knowledge).',
                          ),
                          _section(
                            'Геолокация',
                            'Гео-защита использует координаты и данные сети для обнаружения '
                            'подозрительного доступа. Без сети проверка откладывается.',
                          ),
                          _section(
                            'Биометрия',
                            'Отпечаток или Face ID используются только через API ОС и не '
                            'передаются на сервер.',
                          ),
                          _section(
                            'Фото-ловушка',
                            'После серии неверных попыток PIN на активном экране может быть '
                            'сделан снимок фронтальной камерой для журнала безопасности.',
                          ),
                          _section(
                            'Камера (документы)',
                            'Доступ к камере нужен для сканирования документов в разделе «Сейф».',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      value: _pd,
                      onChanged: (v) {
                        TsarHaptics.tap();
                        setState(() => _pd = v ?? false);
                      },
                      title: const Text('Согласен на обработку ПД'),
                    ),
                    CheckboxListTile(
                      value: _geo,
                      onChanged: (v) {
                        TsarHaptics.tap();
                        setState(() => _geo = v ?? false);
                      },
                      title: const Text('Согласен на использование геолокации'),
                    ),
                    CheckboxListTile(
                      value: _bio,
                      onChanged: (v) {
                        TsarHaptics.tap();
                        setState(() => _bio = v ?? false);
                      },
                      title: const Text('Согласен на использование биометрии'),
                    ),
                    CheckboxListTile(
                      value: _trap,
                      onChanged: (v) {
                        TsarHaptics.tap();
                        setState(() => _trap = v ?? false);
                      },
                      title: const Text('Согласен на работу фото-ловушки'),
                    ),
                    CheckboxListTile(
                      value: _cam,
                      onChanged: (v) {
                        TsarHaptics.tap();
                        setState(() => _cam = v ?? false);
                      },
                      title: const Text('Согласен на доступ к камере для документов'),
                    ),
                    if (!_scrolledToEnd)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Прокрутите текст соглашений до конца.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: canAccept ? _accept : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: TsarTheme.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Принять'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: TsarTheme.gold,
            ),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
