import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Skill Drills Design Tokens
// See STYLE_GUIDE.md for full documentation.
// ─────────────────────────────────────────────────────────────────────────────
class SkillDrillsColors {
  SkillDrillsColors._();

  // Brand
  static const brandBlue = Color(0xFF02A4DD);
  static const brandBlueDark = Color(0xFF0186B5); // pressed / hover state
  static const energyOrange = Color(0xFFFF6B35); // accent / CTA highlight
  static const energyOrangeDark = Color(0xFFE05520);

  // Semantic
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const errorDark = Color(0xFFFF6B6B);

  // Light-mode neutrals
  static const lightBackground = Color(0xFFF0F4F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightAppBar = Color(0xFFFFFFFF);
  static const lightDivider = Color(0xFFE2E8F0);
  static const lightOnSurface = Color(0xFF1A202C);
  static const lightOnSurfaceMuted = Color(0xFF718096);

  // Dark-mode neutrals
  static const darkBackground = Color(0xFF0E1117);
  static const darkSurface = Color(0xFF161B22);
  static const darkCard = Color(0xFF1C2128);
  static const darkAppBar = Color(0xFF161B22);
  static const darkDivider = Color(0xFF30363D);
  static const darkOnSurface = Color(0xFFE6EDF3);
  static const darkOnSurfaceMuted = Color(0xFF8B949E);
}

class SkillDrillsRadius {
  SkillDrillsRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double full = 100;

  static const BorderRadius xsBorderRadius = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smBorderRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorderRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorderRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius fullBorderRadius = BorderRadius.all(Radius.circular(full));
}

class SkillDrillsSpacing {
  SkillDrillsSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// ─────────────────────────────────────────────────────────────────────────────

class SkillDrillsTheme {
  SkillDrillsTheme._();

  // ── Shared shape ──────────────────────────────────────────────────────────
  static final _buttonShape = RoundedRectangleBorder(
    borderRadius: SkillDrillsRadius.smBorderRadius,
  );

  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 14);

  // ── Light theme ───────────────────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: false,
    primaryColor: SkillDrillsColors.brandBlue,
    scaffoldBackgroundColor: SkillDrillsColors.lightBackground,

    // App bar
    appBarTheme: const AppBarTheme(
      backgroundColor: SkillDrillsColors.lightAppBar,
      foregroundColor: SkillDrillsColors.lightOnSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x1A000000),
      iconTheme: IconThemeData(color: SkillDrillsColors.lightOnSurface),
      actionsIconTheme: IconThemeData(color: SkillDrillsColors.lightOnSurface),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: SkillDrillsColors.lightCard,
      elevation: 2,
      shadowColor: Color(0x18000000),
      shape: RoundedRectangleBorder(
        borderRadius: SkillDrillsRadius.mdBorderRadius,
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: SkillDrillsSpacing.sm,
        vertical: SkillDrillsSpacing.xs,
      ),
    ),

    // Icons
    iconTheme: const IconThemeData(color: SkillDrillsColors.lightOnSurfaceMuted),

    // Divider
    dividerTheme: const DividerThemeData(
      color: SkillDrillsColors.lightDivider,
      thickness: 1,
      space: 1,
    ),

    // Elevated button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SkillDrillsColors.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: _buttonPadding,
        minimumSize: const Size(0, 48),
        shape: _buttonShape,
        textStyle: const TextStyle(
          fontFamily: 'Choplin',
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
      ),
    ),

    // Text button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SkillDrillsColors.brandBlue,
        padding: _buttonPadding,
        minimumSize: const Size(0, 48),
        shape: _buttonShape,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
      ),
    ),

    // Outlined button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SkillDrillsColors.brandBlue,
        side: const BorderSide(color: SkillDrillsColors.brandBlue, width: 1.5),
        padding: _buttonPadding,
        minimumSize: const Size(0, 48),
        shape: _buttonShape,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.lightDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.lightDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.brandBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.error, width: 2),
      ),
      labelStyle: const TextStyle(
        color: SkillDrillsColors.lightOnSurfaceMuted,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: SkillDrillsColors.lightOnSurfaceMuted),
      errorStyle: const TextStyle(color: SkillDrillsColors.error),
    ),

    // Bottom nav
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: SkillDrillsColors.lightSurface,
      selectedItemColor: SkillDrillsColors.brandBlue,
      unselectedItemColor: SkillDrillsColors.lightOnSurfaceMuted,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),

    // Snack bar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SkillDrillsColors.lightOnSurface,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
      ),
      behavior: SnackBarBehavior.floating,
      actionTextColor: SkillDrillsColors.brandBlue,
    ),

    // List tile
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: SkillDrillsColors.lightBackground,
      labelStyle: const TextStyle(color: SkillDrillsColors.lightOnSurface, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: SkillDrillsRadius.xsBorderRadius,
        side: const BorderSide(color: SkillDrillsColors.lightDivider),
      ),
    ),

    // Progress indicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: SkillDrillsColors.brandBlue,
      linearTrackColor: Color(0xFFBEE3F8),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: SkillDrillsColors.lightSurface,
      elevation: 8,
      shadowColor: const Color(0x30000000),
      shape: RoundedRectangleBorder(
        borderRadius: SkillDrillsRadius.lgBorderRadius,
      ),
    ),

    // Text
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: SkillDrillsColors.lightOnSurface,
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w900,
        fontSize: 32,
      ),
      displayMedium: TextStyle(
        color: SkillDrillsColors.lightOnSurface,
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w700,
        fontSize: 28,
      ),
      displaySmall: TextStyle(
        color: SkillDrillsColors.lightOnSurface,
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w700,
        fontSize: 24,
      ),
      headlineMedium: TextStyle(
        color: SkillDrillsColors.lightOnSurface,
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      headlineSmall: TextStyle(
        color: SkillDrillsColors.lightOnSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: SkillDrillsColors.brandBlue,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      titleMedium: TextStyle(
        color: SkillDrillsColors.lightOnSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: SkillDrillsColors.lightOnSurfaceMuted,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        color: SkillDrillsColors.lightOnSurface,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: SkillDrillsColors.lightOnSurfaceMuted,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        color: SkillDrillsColors.lightOnSurfaceMuted,
        fontSize: 12,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: 0.4,
      ),
    ),

    // Text selection / cursor
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: SkillDrillsColors.lightOnSurface,
      selectionColor: Color(0x3302A4DD), // brandBlue ~20% opacity
      selectionHandleColor: SkillDrillsColors.brandBlue,
    ),

    // Color scheme
    colorScheme: const ColorScheme.light(
      primary: SkillDrillsColors.lightAppBar,
      onPrimary: SkillDrillsColors.lightOnSurfaceMuted,
      secondary: SkillDrillsColors.brandBlue,
      onSecondary: Colors.white,
      tertiary: SkillDrillsColors.energyOrange,
      onTertiary: Colors.white,
      error: SkillDrillsColors.error,
      onError: Colors.white,
      surface: SkillDrillsColors.lightSurface,
      onSurface: SkillDrillsColors.lightOnSurface,
    ),
  );

  // ── Dark theme ────────────────────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: false,
    primaryColor: SkillDrillsColors.brandBlue,
    scaffoldBackgroundColor: SkillDrillsColors.darkBackground,

    // App bar
    appBarTheme: const AppBarTheme(
      backgroundColor: SkillDrillsColors.darkAppBar,
      foregroundColor: SkillDrillsColors.darkOnSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x40000000),
      iconTheme: IconThemeData(color: SkillDrillsColors.darkOnSurface),
      actionsIconTheme: IconThemeData(color: SkillDrillsColors.darkOnSurface),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: SkillDrillsColors.darkCard,
      elevation: 2,
      shadowColor: Color(0x50000000),
      shape: RoundedRectangleBorder(
        borderRadius: SkillDrillsRadius.mdBorderRadius,
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: SkillDrillsSpacing.sm,
        vertical: SkillDrillsSpacing.xs,
      ),
    ),

    // Icons
    iconTheme: const IconThemeData(color: SkillDrillsColors.darkOnSurfaceMuted),

    // Divider
    dividerTheme: const DividerThemeData(
      color: SkillDrillsColors.darkDivider,
      thickness: 1,
      space: 1,
    ),

    // Elevated button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SkillDrillsColors.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: _buttonPadding,
        minimumSize: const Size(0, 48),
        shape: _buttonShape,
        textStyle: const TextStyle(
          fontFamily: 'Choplin',
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
      ),
    ),

    // Text button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SkillDrillsColors.brandBlue,
        padding: _buttonPadding,
        minimumSize: const Size(0, 48),
        shape: _buttonShape,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
      ),
    ),

    // Outlined button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SkillDrillsColors.brandBlue,
        side: const BorderSide(color: SkillDrillsColors.brandBlue, width: 1.5),
        padding: _buttonPadding,
        minimumSize: const Size(0, 48),
        shape: _buttonShape,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SkillDrillsColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.darkDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.darkDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.brandBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.errorDark, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
        borderSide: const BorderSide(color: SkillDrillsColors.errorDark, width: 2),
      ),
      labelStyle: const TextStyle(
        color: SkillDrillsColors.darkOnSurfaceMuted,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: SkillDrillsColors.darkOnSurfaceMuted),
      errorStyle: const TextStyle(color: SkillDrillsColors.errorDark),
    ),

    // Bottom nav
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: SkillDrillsColors.darkSurface,
      selectedItemColor: SkillDrillsColors.brandBlue,
      unselectedItemColor: SkillDrillsColors.darkOnSurfaceMuted,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),

    // Snack bar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SkillDrillsColors.darkCard,
      contentTextStyle: const TextStyle(color: SkillDrillsColors.darkOnSurface, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: SkillDrillsRadius.smBorderRadius,
      ),
      behavior: SnackBarBehavior.floating,
      actionTextColor: SkillDrillsColors.brandBlue,
    ),

    // List tile
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: SkillDrillsColors.darkSurface,
      labelStyle: const TextStyle(color: SkillDrillsColors.darkOnSurface, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: SkillDrillsRadius.xsBorderRadius,
        side: const BorderSide(color: SkillDrillsColors.darkDivider),
      ),
    ),

    // Progress indicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: SkillDrillsColors.brandBlue,
      linearTrackColor: Color(0xFF0E3A52),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: SkillDrillsColors.darkCard,
      elevation: 12,
      shadowColor: const Color(0x60000000),
      shape: RoundedRectangleBorder(
        borderRadius: SkillDrillsRadius.lgBorderRadius,
      ),
    ),

    // Text
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: SkillDrillsColors.darkOnSurface,
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w900,
        fontSize: 32,
      ),
      displayMedium: TextStyle(
        color: SkillDrillsColors.darkOnSurface,
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w700,
        fontSize: 28,
      ),
      displaySmall: TextStyle(
        color: SkillDrillsColors.darkOnSurface,
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w700,
        fontSize: 24,
      ),
      headlineMedium: TextStyle(
        color: SkillDrillsColors.darkOnSurface,
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      headlineSmall: TextStyle(
        color: SkillDrillsColors.darkOnSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: SkillDrillsColors.brandBlue,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      titleMedium: TextStyle(
        color: SkillDrillsColors.darkOnSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: SkillDrillsColors.darkOnSurfaceMuted,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        color: SkillDrillsColors.darkOnSurface,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: SkillDrillsColors.darkOnSurfaceMuted,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        color: SkillDrillsColors.darkOnSurfaceMuted,
        fontSize: 12,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Choplin',
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: 0.4,
      ),
    ),

    // Color scheme
    // Text selection / cursor
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: SkillDrillsColors.darkOnSurface,
      selectionColor: Color(0x4402A4DD), // brandBlue ~27% opacity
      selectionHandleColor: SkillDrillsColors.brandBlue,
    ),

    colorScheme: const ColorScheme.dark(
      primary: SkillDrillsColors.darkAppBar,
      onPrimary: SkillDrillsColors.darkOnSurfaceMuted,
      secondary: SkillDrillsColors.brandBlue,
      onSecondary: Colors.white,
      tertiary: SkillDrillsColors.energyOrange,
      onTertiary: Colors.white,
      error: SkillDrillsColors.errorDark,
      onError: Colors.white,
      surface: SkillDrillsColors.darkSurface,
      onSurface: SkillDrillsColors.darkOnSurface,
    ),
  );
}
