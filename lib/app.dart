import 'package:flutter/material.dart';

import 'theme/tsar_theme.dart';
import 'ui/onboarding/app_entry.dart';

class TsarIdApp extends StatelessWidget {
  const TsarIdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Царь-ID',
      theme: TsarTheme.dark(),
      home: const AppEntry(),
    );
  }
}
