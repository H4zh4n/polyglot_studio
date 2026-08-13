import 'package:flutter/material.dart';

/// Clean, understated, premium monochrome & charcoal design system.
/// Inspired by high-end developer tools (Linear, Raycast, Apple Pro).
class AppTheme {
  // Deep matte neutral charcoal surfaces (no synth blue/cyan tint)
  static const Color background = Color(0xFF0D0F12);
  static const Color surface = Color(0xFF15181E);
  static const Color surfaceElevated = Color(0xFF1E222A);
  static const Color surfaceHighlight = Color(0xFF282D37);
  static const Color borderSubtle = Color(0x1AFFFFFF); // Clean 10% white border
  static const Color borderStrong = Color(0x33FFFFFF); // 20% white border for active items

  // Timeless monochrome primary with subtle restrained status accents
  static const Color primary = Color(0xFFFFFFFF);       // Crisp Solid White CTA
  static const Color primaryDark = Color(0xFFE5E7EB);   // Silver White
  static const Color accent = Color(0xFF34D399);        // Muted Sage Green for confirmed states
  static const Color warning = Color(0xFFFBBF24);       // Muted Warm Amber
  static const Color danger = Color(0xFFF87171);        // Muted Coral Red
  static const Color neutralTag = Color(0xFF374151);    // Neutral Slate Tag

  // Typographic hierarchy
  static const Color textPrimary = Color(0xFFF9FAFB);   // Pure crisp white
  static const Color textSecondary = Color(0xFF9CA3AF); // Neutral silver gray
  static const Color textMuted = Color(0xFF6B7280);     // Subtle slate gray

  // Typographic tracking
  static const double trackingTight = -0.4;
  static const double trackingHeader = -0.6;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: primary,
        secondary: accent,
        error: danger,
      ),
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: trackingTight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF0D0F12),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
