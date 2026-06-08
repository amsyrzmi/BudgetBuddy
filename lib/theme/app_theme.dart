import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brandGreen = Color(0xFF1D9E75);
  static const background = Color(0xFFF9FAFB);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandGreen,
          primary: brandGreen,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 70,
          backgroundColor: Colors.white,
          indicatorColor: brandGreen.withAlpha(26),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12),
          ),
        ),
      );
}