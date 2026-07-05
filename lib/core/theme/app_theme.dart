import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Neo-Minimalist Color Palette
  // Background: Warm cream/off-white
  static const Color backgroundLight = Color(0xFFF5F5F0);
  static const Color backgroundDark = Color(0xFF1A1A1A);

  // Surface colors
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2A2A2A);

  // Text colors
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6B6B6B);
  static const Color textPrimaryDark = Color(0xFFF5F5F0);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);

  // Accent: Deep Navy
  static const Color accentColor = Color(0xFF000072);
  static const Color accentLight = Color(0xFF3333A3);

  // Semantic colors (subtle)
  static const Color successColor = Color(0xFF059669);
  static const Color warningColor = Color(0xFFD97706);
  static const Color errorColor = Color(0xFFDC2626);

  // Neutral scale
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFE5E5E5);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral400 = Color(0xFFA3A3A3);
  static const Color neutral500 = Color(0xFF737373);
  static const Color neutral600 = Color(0xFF525252);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral800 = Color(0xFF262626);
  static const Color neutral900 = Color(0xFF171717);

  /// Theme-aware color helpers — use these instead of Colors.grey[xxx]
  /// so dark mode renders correctly.
  static Color bgSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2A2A)
          : const Color(0xFFF5F5F5);

  static Color textSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFB0B0B0)
          : const Color(0xFF6B6B6B);

  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF808080)
          : const Color(0xFF9E9E9E);

  static Color dividerSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFE5E5E5);

  // Light Theme - Neo Minimalist
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundLight,

    // Font - Using Google Fonts
    textTheme: GoogleFonts.poppinsTextTheme(),

    // Color scheme
    colorScheme: const ColorScheme.light(
      primary: accentColor,
      onPrimary: Colors.white,
      secondary: accentLight,
      onSecondary: Colors.white,
      surface: surfaceLight,
      onSurface: textPrimaryLight,
      error: errorColor,
      onError: Colors.white,
    ),

    // AppBar - Clean, minimal
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundLight,
      foregroundColor: textPrimaryLight,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: null,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimaryLight,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(
        color: textPrimaryLight,
        size: 24,
      ),
    ),

    // Cards - Flat, no shadow, minimal border
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide.none,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // Buttons - Minimal, rounded
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: null,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentColor,
        side: const BorderSide(color: accentColor, width: 1.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: null,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: null,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // Input fields - Minimal, clean
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: neutral200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      hintStyle: const TextStyle(
        fontFamily: null,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: neutral400,
      ),
      labelStyle: const TextStyle(
        fontFamily: null,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: neutral500,
      ),
    ),

    // Chips - Pill shape
    chipTheme: ChipThemeData(
      backgroundColor: neutral100,
      selectedColor: accentColor,
      labelStyle: const TextStyle(
        fontFamily: null,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
    ),

    // Bottom navigation - Minimal
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceLight,
      selectedItemColor: accentColor,
      unselectedItemColor: neutral400,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(
        fontFamily: null,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: null,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),

    // Divider - Subtle
    dividerTheme: const DividerThemeData(
      color: neutral200,
      thickness: 1,
      space: 1,
    ),

    // Floating action button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Dialogs - Rounded, clean
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: null,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimaryLight,
      ),
    ),

    // List tiles
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 40,
      iconColor: neutral500,
    ),
  );

  // Dark Theme - Neo Minimalist
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,

    // Font - Using Google Fonts
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),

    colorScheme: const ColorScheme.dark(
      primary: accentLight,
      onPrimary: Colors.white,
      secondary: accentLight,
      onSecondary: Colors.white,
      surface: surfaceDark,
      onSurface: textPrimaryDark,
      error: errorColor,
      onError: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundDark,
      foregroundColor: textPrimaryDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: null,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(
        color: textPrimaryDark,
        size: 24,
      ),
    ),

    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide.none,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentLight,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: null,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentLight,
        side: const BorderSide(color: accentLight, width: 1.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: null,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentLight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: null,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: neutral700, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      hintStyle: const TextStyle(
        fontFamily: null,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: neutral500,
      ),
      labelStyle: const TextStyle(
        fontFamily: null,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: neutral400,
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: neutral800,
      selectedColor: accentLight,
      labelStyle: const TextStyle(
        fontFamily: null,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: accentLight,
      unselectedItemColor: neutral500,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(
        fontFamily: null,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: null,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: neutral700,
      thickness: 1,
      space: 1,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accentLight,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: null,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
      ),
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 40,
      iconColor: neutral400,
    ),
  );
}
