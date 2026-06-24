import 'package:flutter/material.dart';

const kSpring = Cubic(0.22, 1.0, 0.36, 1.0);
const kSmooth = Curves.easeOutCubic;

// ─── Color Tokens ────────────────────────────────────────────────

class C {
  static const black = Color(0xFF000000); // true black
  static const grey9 = Color(0xFF1A1A1A);
  static const grey7 = Color(0xFF3A3A3A);
  static const grey5 = Color(0xFF8A8A8A);
  static const grey3 = Color(0xFF555555);
  static const grey1 = Color(0xFF252525);
  static const grey05 = Color(0xFF0D0D0D);
  static const white = Color(0xFFFFFFFF);

  static const dkBg = Color(0xFF000000);
  static const dkSurf = Color(0xFF0D0D0D);
  static const dkCard = Color(0xFF171717);
  static const dkBorder = Color(0xFF252525);

  static const paid = Color(0xFF22C55E);
  static const paidBg = Color(0xFF0C2016);
  static const overdue = Color(0xFFEF4444);
  static const overdueBg = Color(0xFF200C0C);
  static const pending = Color(0xFFF59E0B);
  static const pendingBg = Color(0xFF1F1600);
  static const draft = Color(0xFF666666);
  static const draftBg = Color(0xFF1A1A1A);

  static const wa = Color(0xFF25D366);
  static const waBg = Color(0xFF0C1F15);
  static const chartLine = Color(0xFF4ADE80);

  static const avatarColors = [
    Color(0xFF1E3A2F),
    Color(0xFF2C1E3A),
    Color(0xFF1E2C3A),
    Color(0xFF3A2C1E),
    Color(0xFF1E3A3A),
  ];
}

class T {
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      dark(context) ? C.dkBg : const Color(0xFFF4F5F7);

  static Color surface(BuildContext context) =>
      dark(context) ? C.dkSurf : const Color(0xFFFFFFFF);

  static Color card(BuildContext context) =>
      dark(context) ? C.dkCard : const Color(0xFFFFFFFF);

  static Color raised(BuildContext context) =>
      dark(context) ? const Color(0xFF101010) : const Color(0xFFFFFFFF);

  static Color subtle(BuildContext context) =>
      dark(context) ? const Color(0xFF111111) : const Color(0xFFF0F2F5);

  static Color border(BuildContext context) =>
      dark(context) ? C.dkBorder : const Color(0xFFE0E3E8);

  static Color divider(BuildContext context) =>
      dark(context) ? const Color(0x14FFFFFF) : const Color(0xFFE9ECEF);

  static Color text(BuildContext context) =>
      dark(context) ? C.white : const Color(0xFF111111);

  static Color muted(BuildContext context) =>
      dark(context) ? C.grey5 : const Color(0xFF6F7682);

  static Color faint(BuildContext context) =>
      dark(context) ? C.grey3 : const Color(0xFF9AA1AB);

  static Color inverse(BuildContext context) =>
      dark(context) ? C.white : const Color(0xFF111111);

  static Color onInverse(BuildContext context) =>
      dark(context) ? C.black : C.white;

  static List<BoxShadow> shadow(BuildContext context) => dark(context)
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 22,
            offset: Offset(0, -4),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ];
}

// ─── Theme ───────────────────────────────────────────────────────

ThemeData buildTheme(bool dark) {
  final base = dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);
  return base.copyWith(
    brightness: dark ? Brightness.dark : Brightness.light,
    textTheme: base.textTheme.apply(
      bodyColor: dark ? C.white : C.black,
      displayColor: dark ? C.white : C.black,
    ),
    scaffoldBackgroundColor: dark ? Colors.black : const Color(0xFFF4F5F7),
    colorScheme: dark
        ? const ColorScheme.dark(primary: C.white, surface: C.dkSurf)
        : const ColorScheme.light(
            primary: C.black,
            surface: C.white,
            surfaceContainerHighest: Color(0xFFF0F2F5),
            outline: Color(0xFFE0E3E8),
          ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? Colors.black : C.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: dark ? C.white : C.black,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: dark ? C.white : C.black,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: dark ? C.dkBorder : const Color(0xFFE0E3E8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: dark ? C.dkBorder : const Color(0xFFE0E3E8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? C.white : C.black, width: 1.5),
      ),
      filled: true,
      fillColor: dark ? C.dkCard : C.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(
          color: dark ? C.grey3 : const Color(0xFF9AA1AB), fontSize: 14),
    ),
    dividerColor: dark ? C.dkBorder : const Color(0xFFE9ECEF),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? C.white : C.black,
      contentTextStyle: TextStyle(
        color: dark ? C.black : C.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: dark ? C.white : C.black,
        foregroundColor: dark ? C.black : C.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

// ─── Invoice Templates ───────────────────────────────────────────

class InvTemplate {
  final String name;
  final String description;
  final Color primary, bg, accent, text;
  final bool dark;
  const InvTemplate({
    required this.name,
    required this.description,
    required this.primary,
    required this.bg,
    required this.accent,
    required this.text,
    this.dark = false,
  });
}

const kTemplates = [
  InvTemplate(
      name: 'Classic',
      description: 'Bold header, formal table',
      primary: Color(0xFF111111),
      bg: Color(0xFFFFFFFF),
      accent: Color(0xFF444444),
      text: Color(0xFF111111)),
  InvTemplate(
      name: 'Minimal',
      description: 'Airy, border-light layout',
      primary: Color(0xFF2563EB),
      bg: Color(0xFFFFFFFF),
      accent: Color(0xFFDBEAFE),
      text: Color(0xFF111111)),
  InvTemplate(
      name: 'Ledger',
      description: 'Boxed business invoice',
      primary: Color(0xFF111827),
      bg: Color(0xFFFFFFFF),
      accent: Color(0xFFE5E7EB),
      text: Color(0xFF111111)),
  InvTemplate(
      name: 'Compact',
      description: 'Physical bill style',
      primary: Color(0xFF111111),
      bg: Color(0xFFFFFFFF),
      accent: Color(0xFFF3F4F6),
      text: Color(0xFF111111)),
];

InvTemplate tplOf(String name) =>
    kTemplates.firstWhere((t) => t.name == name, orElse: () => kTemplates[0]);

// ─── Routes ──────────────────────────────────────────────────────

Route<R> slideRoute<R>(Widget page) => PageRouteBuilder<R>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      transitionsBuilder: (_, a, __, child) {
        final curved = CurvedAnimation(
          parent: a,
          curve: kSmooth,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween(begin: 0.0, end: 1.0).animate(curved),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

Route<R> slideUpRoute<R>(Widget page) => PageRouteBuilder<R>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      transitionsBuilder: (_, a, __, child) {
        final curved = CurvedAnimation(
          parent: a,
          curve: kSmooth,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween(begin: 0.0, end: 1.0).animate(curved),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
