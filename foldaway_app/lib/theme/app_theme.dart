import 'package:flutter/material.dart';

class FoldawayColors {
  static const ink = Color(0xFF090909);
  static const paper = Color(0xFFFAF9F4);
  static const white = Color(0xFFFFFFFF);

  static const muted = Color(0xFF74726C);
  static const line = Color(0xFFE4E0D6);

  static const sand = Color(0xFFE9E0CC);
  static const sage = Color(0xFFB7C2A1);
  static const olive = Color(0xFF70765F);
  static const rust = Color(0xFF9B4F32);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: FoldawayColors.paper,
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: const ['Arial', 'Roboto', 'sans-serif'],
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: FoldawayColors.ink,
        secondary: FoldawayColors.olive,
        surface: FoldawayColors.paper,
        error: FoldawayColors.rust,
        onPrimary: FoldawayColors.white,
        onSecondary: FoldawayColors.ink,
        onSurface: FoldawayColors.ink,
      ),

      textTheme: base.textTheme
          .apply(
            bodyColor: FoldawayColors.ink,
            displayColor: FoldawayColors.ink,
            fontFamily: 'Helvetica Neue',
          )
          .copyWith(
            displayLarge: const TextStyle(
              fontSize: 64,
              height: 0.88,
              letterSpacing: -4,
              fontWeight: FontWeight.w900,
            ),
            headlineLarge: const TextStyle(
              fontSize: 38,
              height: 0.95,
              letterSpacing: -2,
              fontWeight: FontWeight.w900,
            ),
            headlineMedium: const TextStyle(
              fontSize: 28,
              height: 1,
              letterSpacing: -1.4,
              fontWeight: FontWeight.w900,
            ),
            titleLarge: const TextStyle(
              fontSize: 18,
              letterSpacing: -0.4,
              fontWeight: FontWeight.w800,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
            labelLarge: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w800,
            ),
          ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: FoldawayColors.paper,
        foregroundColor: FoldawayColors.ink,
        titleTextStyle: TextStyle(
          color: FoldawayColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),

      cardTheme: CardTheme(
        color: FoldawayColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: FoldawayColors.line),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FoldawayColors.white,
        labelStyle: const TextStyle(color: FoldawayColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: FoldawayColors.ink),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: FoldawayColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(
            color: FoldawayColors.ink,
            width: 1.4,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FoldawayColors.ink,
          foregroundColor: FoldawayColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FoldawayColors.ink,
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: FoldawayColors.ink,
        foregroundColor: FoldawayColors.white,
        shape: CircleBorder(),
      ),

      dialogTheme: DialogTheme(
        backgroundColor: FoldawayColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: FoldawayColors.ink),
        ),
        titleTextStyle: const TextStyle(
          color: FoldawayColors.ink,
          fontSize: 24,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return FoldawayColors.ink;
          }
          return FoldawayColors.white;
        }),
        checkColor: MaterialStateProperty.all(FoldawayColors.white),
        side: const BorderSide(color: FoldawayColors.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: FoldawayColors.line,
        thickness: 1,
        space: 1,
      ),
    );
  }
}