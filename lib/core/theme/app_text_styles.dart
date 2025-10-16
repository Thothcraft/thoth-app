import 'package:flutter/material.dart';

/// Apple-inspired typography system
class AppTextStyles {
  // Font Family
  static const String _defaultFontFamily = 'SF Pro Display';
  
  // Hero Titles (Landing Pages)
  static const TextStyle heroTitle = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w600,
    letterSpacing: -2.24,
    height: 1.1,
    fontFamily: _defaultFontFamily,
  );
  
  static const TextStyle heroTitleMobile = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.6,
    height: 1.1,
    fontFamily: _defaultFontFamily,
  );
  
  // Hero Subtitles
  static const TextStyle heroSubtitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.22,
    height: 1.4,
    fontFamily: _defaultFontFamily,
  );
  
  // Section Titles
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.2,
    fontFamily: _defaultFontFamily,
  );
  
  static const TextStyle sectionTitleMobile = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.64,
    height: 1.2,
    fontFamily: _defaultFontFamily,
  );
  
  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.64,
    height: 1.25,
    fontFamily: _defaultFontFamily,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.56,
    height: 1.3,
    fontFamily: _defaultFontFamily,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.48,
    height: 1.3,
    fontFamily: _defaultFontFamily,
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.4,
    fontFamily: _defaultFontFamily,
  );
  
  // Body Text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.18,
    height: 1.6,
    fontFamily: _defaultFontFamily,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.16,
    height: 1.5,
    fontFamily: _defaultFontFamily,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.14,
    height: 1.5,
    fontFamily: _defaultFontFamily,
  );
  
  // Labels
  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.16,
    height: 1.4,
    fontFamily: _defaultFontFamily,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.14,
    height: 1.4,
    fontFamily: _defaultFontFamily,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.12,
    height: 1.4,
    fontFamily: _defaultFontFamily,
  );
  
  // Button Text
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.16,
    height: 1.2,
    fontFamily: _defaultFontFamily,
  );
  
  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.12,
    height: 1.4,
    fontFamily: _defaultFontFamily,
  );
}
