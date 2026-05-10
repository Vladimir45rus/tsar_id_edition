import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/media/media_intro_service.dart';
import '../../state/legal_consent_store.dart';
import '../auth/phone_auth_screen.dart';
import 'legal_consent_screen.dart';
import 'media_intro_screen.dart';

/// Цепочка: согласия → медиа-интро → экран телефона.
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  Widget _body = const Center(child: CircularProgressIndicator());

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final consent = LegalConsentStore();
    if (!await consent.allAccepted) {
      setState(() {
        _body = LegalConsentScreen(onFinished: _bootstrap);
      });
      return;
    }

    final media = context.read<MediaIntroService>();
    await media.ensureLoaded();
    if (!mounted) return;
    if (!media.introCompleted) {
      setState(() {
        _body = MediaIntroScreen(onFinished: _bootstrap);
      });
      return;
    }

    setState(() {
      _body = const PhoneAuthScreen();
    });
  }

  @override
  Widget build(BuildContext context) => _body;
}
