import 'package:flutter/material.dart';

/// Design tokens dari KELUARR.dc.html (bagian "SPEC UNTUK IMPLEMENTASI FLUTTER").
class K {
  static const orange = Color(0xFFFF6A13);
  static const orangeDeep = Color(0xFFB0470A);
  static const orangeSoft = Color(0xFFFDEAE0);
  static const orangeMid = Color(0xFFFBA76C);
  static const orangePale = Color(0xFFF5C7AB);
  static const ink = Color(0xFF16181A);
  static const success = Color(0xFF17A867);
  static const successInk = Color(0xFF17845A);
  static const successSoft = Color(0xFFDFF3E8);
  static const warning = Color(0xFFE8A317);
  static const warningInk = Color(0xFFA2740F);
  static const danger = Color(0xFFD14343);
  static const muted = Color(0xFF8A9096);
  static const blue = Color(0xFF3C6DF0);

  static const bgL = Color(0xFFF4F2ED);
  static const cardL = Color(0xFFFFFFFF);
  static const lineL = Color(0xFFE0DBD1);
  static const hairL = Color(0xFFEFEBE3);
  static const dimL = Color(0xFF7A8087);
  static const bodyL = Color(0xFF5C6167);

  static const bgD = Color(0xFF0F1113);
  static const cardD = Color(0xFF1B1F23);
  static const lineD = Color(0xFF2A3035);
  static const dimD = Color(0xFF8B9196);
  static const inkD = Color(0xFFF2F3F4);

  // padding halaman 18 · gap antar kartu 13 · radius kartu 16 · tombol 54
  static const pad = 18.0;
  static const gap = 13.0;
  static const r = 16.0;
  static const btnH = 54.0;

  static const shadowOrange = [
    BoxShadow(color: Color(0x47FF6A13), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

/// Archivo / JetBrains Mono tidak dibundel — pakai sans sistem + monospace sistem.
const _monoFallback = ['JetBrains Mono', 'Consolas', 'monospace', 'Courier New'];

TextStyle mono(double size,
        {Color? color, FontWeight weight = FontWeight.w500, double track = 1.2}) =>
    TextStyle(
      fontFamilyFallback: _monoFallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: track,
      height: 1.3,
    );

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme(
    brightness: b,
    primary: K.orange,
    onPrimary: Colors.white,
    primaryContainer: dark ? const Color(0x29FF6A13) : K.orangeSoft,
    onPrimaryContainer: dark ? const Color(0xFFFF9455) : K.orangeDeep,
    secondary: K.success,
    onSecondary: Colors.white,
    error: K.danger,
    onError: Colors.white,
    surface: dark ? K.bgD : K.bgL,
    onSurface: dark ? K.inkD : K.ink,
    outline: dark ? K.lineD : K.lineL,
    surfaceContainerLowest: dark ? K.cardD : K.cardL,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    textTheme: Typography.material2021(colorScheme: scheme)
        .black
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          displayLarge: TextStyle(
              fontSize: 64, fontWeight: FontWeight.w800, letterSpacing: -3, height: 1),
          headlineLarge: const TextStyle(
              fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1),
          headlineSmall: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6),
          titleLarge: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: dark ? K.dimD : K.bodyL,
              fontWeight: FontWeight.w400),
        ),
  );
}

/// Warna turunan yang bergantung tema — dipakai di semua layar.
extension Tone on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get card => isDark ? K.cardD : K.cardL;
  Color get line => isDark ? K.lineD : K.lineL;
  Color get hair => isDark ? K.lineD : K.hairL;
  Color get dim => isDark ? K.dimD : K.dimL;
  Color get fg => isDark ? K.inkD : K.ink;
  Color get fill => isDark ? const Color(0xFF15181B) : K.bgL;
}
