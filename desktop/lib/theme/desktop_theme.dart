import 'package:flutter/material.dart';

class DesktopTheme {
  static const primary = Color(0xFF6366F1);
  static const indigo50 = Color(0xFFEEF2FF);
  static const indigo100 = Color(0xFFE0E7FF);
  static const bgPrimary = Color(0xFFF8FAFC);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgSection = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textTertiary = Color(0xFF94A3B8);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);
  static const border = Color(0xFFE2E8F0);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Microsoft YaHei',
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
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: border, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            textStyle: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textSecondary,
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            textStyle: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 13),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: textPrimary,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: bgSection,
          selectedColor: indigo100,
          labelStyle: const TextStyle(color: textPrimary, fontFamily: 'Microsoft YaHei', fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
          titleTextStyle: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
          contentTextStyle: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 14, color: textPrimary),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 14, color: textPrimary, fontFamily: 'Microsoft YaHei'),
          bodyMedium: TextStyle(fontSize: 13, color: textPrimary, fontFamily: 'Microsoft YaHei'),
          bodySmall: TextStyle(fontSize: 12, color: textSecondary, fontFamily: 'Microsoft YaHei'),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary, fontFamily: 'Microsoft YaHei'),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary, fontFamily: 'Microsoft YaHei'),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary, fontFamily: 'Microsoft YaHei'),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary, fontFamily: 'Microsoft YaHei'),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary, fontFamily: 'Microsoft YaHei'),
          labelSmall: TextStyle(fontSize: 11, color: textTertiary, fontFamily: 'Microsoft YaHei'),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: bgCard,
          elevation: 2,
          indicatorColor: indigo50,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontWeight: FontWeight.w600, color: primary, fontFamily: 'Microsoft YaHei', fontSize: 13);
            }
            return const TextStyle(fontWeight: FontWeight.normal, color: textSecondary, fontFamily: 'Microsoft YaHei', fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: primary, size: 22);
            }
            return const IconThemeData(color: textTertiary, size: 20);
          }),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: bgCard,
          elevation: 1,
          selectedIconTheme: const IconThemeData(color: primary, size: 22),
          unselectedIconTheme: const IconThemeData(color: textTertiary, size: 20),
          selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: primary, fontFamily: 'Microsoft YaHei', fontSize: 13),
          unselectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.normal, color: textSecondary, fontFamily: 'Microsoft YaHei', fontSize: 12),
          indicatorColor: indigo50,
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        tabBarTheme: TabBarThemeData(
          labelColor: primary,
          unselectedLabelColor: textSecondary,
          indicatorColor: primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 13),
          dividerColor: border,
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(bgSection),
          dataTextStyle: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 13),
        ),
      );
}
