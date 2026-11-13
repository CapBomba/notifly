import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Shadcn Flutter Design System Colors & Palette
// ---------------------------------------------------------------------------

class AppColors {
  AppColors._();

  // Primary brand accent
  static const Color messengerBlue    = Color(0xFF2563EB); // Shadcn Blue (600)
  static const Color messengerViolet  = Color(0xFF4F46E5); // Shadcn Indigo (600)

  // Light Theme Neutrals (Zinc/Slate)
  static const Color lightBackground  = Color(0xFFFAFAFA);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightCard        = Color(0xFFFFFFFF);
  static const Color lightBorder      = Color(0xFFE4E4E7);
  static const Color lightMuted       = Color(0xFFF4F4F5);

  // Dark Theme Neutrals (Zinc/Slate)
  static const Color darkBackground   = Color(0xFF090D16);
  static const Color darkSurface      = Color(0xFF18181B);
  static const Color darkCard         = Color(0xFF1E293B);
  static const Color darkBorder       = Color(0xFF27272A);
  static const Color darkMuted        = Color(0xFF27272A);

  // Bubble colors
  static const Color sentBubble       = messengerBlue;
  static const Color receivedBubbleL  = Color(0xFFF4F4F5);
  static const Color receivedBubbleD  = Color(0xFF27272A);

  // Text
  static const Color lightText        = Color(0xFF09090B);
  static const Color darkText         = Color(0xFFFAFAFA);
  static const Color subtleText       = Color(0xFF71717A);

  static LinearGradient get gradient => const LinearGradient(
    colors: [messengerBlue, messengerViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.lightBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.messengerBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.messengerBlue,
          secondary: AppColors.messengerViolet,
          surface: AppColors.lightSurface,
          surfaceContainerHighest: AppColors.lightMuted,
          outline: AppColors.subtleText,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.lightSurface,
          foregroundColor: AppColors.lightText,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: TextStyle(
            color: AppColors.lightText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.lightBorder, width: 1),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(color: AppColors.lightText),
          bodyMedium: TextStyle(color: AppColors.lightText),
          titleMedium: TextStyle(
            color: AppColors.lightText,
            fontWeight: FontWeight.w600,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.messengerBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12,
          ),
        ),
        dividerColor: AppColors.lightBorder,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.messengerBlue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.messengerBlue,
          secondary: AppColors.messengerViolet,
          surface: AppColors.darkSurface,
          surfaceContainerHighest: AppColors.darkMuted,
          outline: AppColors.subtleText,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkText,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            color: AppColors.darkText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.darkBorder, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.darkBorder, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.darkBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.messengerBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12,
          ),
        ),
        dividerColor: AppColors.darkBorder,
      );
}
