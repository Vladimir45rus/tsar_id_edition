import 'package:flutter/material.dart';

/// Премиальная тёмная тема: фон #121212, акцент золото #D4AF37.
class TsarTheme {
  static const Color background = Color(0xFF121212);
  static const Color surfaceGlass = Color(0x1AFFFFFF);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDim = Color(0xFFB8960C);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        surface: const Color(0xFF1E1E1E),
        primary: gold,
        onPrimary: Colors.black,
        secondary: goldDim,
        onSecondary: Colors.black,
        error: Colors.redAccent,
        onSurface: Colors.white,
        surfaceContainerHighest: const Color(0xFF2C2C2C),
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: surfaceGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: gold.withOpacity(0.25),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: const DialogTheme(
        backgroundColor: Color(0xFF2A2A2A),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// Длительность кастомных переходов (например [PageRouteBuilder]).
  static const Duration routeDuration = Duration(milliseconds: 300);
}

/// Декорация «стекло» для контейнеров.
class TsarGlass extends StatelessWidget {
  const TsarGlass({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TsarTheme.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: child,
      ),
    );
  }
}
