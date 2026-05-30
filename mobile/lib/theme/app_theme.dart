import 'package:flutter/material.dart';

class AppTheme {
  // ── Red Palette (Alan Perlis style) ──────────────────
  static const primary   = Color(0xFFE53935); // Red 600
  static const primaryBg = Color(0xFFFFEBEE); // Red 50
  static const surface   = Color(0xFFFFFFFF);
  static const bg        = Color(0xFFF5F5F5);
  static const textMain  = Color(0xFF212121);
  static const textSoft  = Color(0xFF757575);
  static const textHint  = Color(0xFFBDBDBD);
  static const accent    = Color(0xFFFFA000); // amber
  static const danger    = Color(0xFFD32F2F);
  static const success   = Color(0xFF43A047);
  static const divider   = Color(0xFFEEEEEE);
  static const bgSection = Color(0xFFF1F5F9);

  // ── 兼容旧代码的别名 ──────────────────────────────────
  static const indigo50  = Color(0xFFFFEBEE); // → red 50
  static const indigo100 = Color(0xFFFFCDD2); // → red 100
  static const indigo700 = Color(0xFFD32F2F); // → red 700

  static const bgPrimary     = bg;
  static const bgCard        = surface;
  static const textPrimary   = textMain;
  static const textSecondary = textSoft;
  static const textTertiary  = textHint;
  static const border        = divider;
  static const green         = success;
  static const red           = danger;
  static const orange        = accent;

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: primary,
    scaffoldBackgroundColor: bg,
    fontFamily: null,

    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textMain,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textMain,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textHint, fontSize: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textSoft,
        side: const BorderSide(color: divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: CircleBorder(),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: primary,
      labelStyle: const TextStyle(fontSize: 12),
      secondaryLabelStyle: const TextStyle(fontSize: 12, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      side: BorderSide.none,
    ),

    dividerTheme: const DividerThemeData(
      color: divider,
      thickness: 0.5,
      space: 0,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textMain,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        color: textSoft,
      ),
      elevation: 8,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primary,
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: bgSection,
      thumbColor: primary,
      overlayColor: primary.withAlpha(30),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 8,
      shadowColor: Colors.black.withAlpha(20),
      indicatorColor: primaryBg,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontWeight: FontWeight.w600,
            color: primary,
            fontSize: 12,
          );
        }
        return const TextStyle(
          fontWeight: FontWeight.normal,
          color: textSoft,
          fontSize: 12,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primary, size: 24);
        }
        return const IconThemeData(color: textHint, size: 22);
      }),
    ),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, color: textMain),
      bodyMedium: TextStyle(fontSize: 14, color: textMain),
      bodySmall: TextStyle(fontSize: 12, color: textSoft),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textMain,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textMain,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textMain,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textMain,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSoft,
      ),
      labelSmall: TextStyle(fontSize: 11, color: textHint),
    ),
  );
}
