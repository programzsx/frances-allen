import 'package:flutter/material.dart';

class AppTheme {
  // Primary — Indigo 500
  static const primary = Color(0xFF6366F1);
  static const indigo50 = Color(0xFFEEF2FF);
  static const indigo100 = Color(0xFFE0E7FF);
  static const indigo700 = Color(0xFF4F46E5);

  // Surface
  static const bgPrimary = Color(0xFFF8FAFC);   // slate-50
  static const bgCard = Color(0xFFFFFFFF);       // white
  static const bgSection = Color(0xFFF1F5F9);    // slate-100

  // Text
  static const textPrimary = Color(0xFF0F172A);   // slate-900
  static const textSecondary = Color(0xFF64748B); // slate-500
  static const textTertiary = Color(0xFF94A3B8);  // slate-400

  // Semantic
  static const green = Color(0xFF10B981);   // emerald-500
  static const red = Color(0xFFEF4444);     // red-500
  static const orange = Color(0xFFF59E0B);  // amber-500

  // Borders
  static const border = Color(0xFFE2E8F0);  // slate-200

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: bgPrimary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          surface: bgCard,
          background: bgPrimary,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textSecondary,
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: textPrimary,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: bgSection,
          selectedColor: indigo100,
          labelStyle: const TextStyle(color: textPrimary, fontFamily: 'Inter'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
          bodySmall: TextStyle(fontSize: 12, color: textSecondary),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
          labelSmall: TextStyle(fontSize: 11, color: textTertiary),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: bgCard,
          elevation: 8,
          shadowColor: Colors.black.withAlpha(20),
          indicatorColor: indigo50,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontWeight: FontWeight.w600, color: primary, fontFamily: 'Inter', fontSize: 12);
            }
            return const TextStyle(fontWeight: FontWeight.normal, color: textSecondary, fontFamily: 'Inter', fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: primary, size: 24);
            }
            return const IconThemeData(color: textTertiary, size: 22);
          }),
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
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
      );
}
