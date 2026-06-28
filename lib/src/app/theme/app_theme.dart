import 'package:flutter/material.dart';

class AppTheme {
  static const brand = Color(0xFFFE4D00);
  static const brandEnd = Color(0xFFFF9809);
  static const pageBg = Color(0xFFF7F7F7);
  static const textPrimary = Color(0xFF333333);
  static const textSecondary = Color(0xFF666666);

  static const brandGradient = LinearGradient(
    colors: [brand, brandEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: pageBg,
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: brand,
        unselectedItemColor: Color(0xFF7A7E83),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
