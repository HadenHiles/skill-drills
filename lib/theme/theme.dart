import 'package:flutter/material.dart';

class SkillDrillsTheme {
  SkillDrillsTheme._();

  static final ThemeData lightTheme = ThemeData(
    primaryColor: const Color.fromRGBO(2, 164, 221, 1),
    scaffoldBackgroundColor: const Color(0xffF7F7F7),
    appBarTheme: const AppBarTheme(
      color: Colors.white,
      iconTheme: IconThemeData(
        color: Colors.black87,
      ),
    ),
    cardTheme: const CardTheme(
      color: Colors.white,
    ),
    iconTheme: const IconThemeData(
      color: Colors.black54,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Colors.black87,
      ),
      displayMedium: TextStyle(
        color: Colors.black87,
        fontFamily: "Choplin",
        fontWeight: FontWeight.w700,
      ),
      displaySmall: TextStyle(
        color: Colors.black87,
      ),
      headlineMedium: TextStyle(
        color: Colors.black87,
        fontFamily: "Choplin",
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        color: Colors.black87,
      ),
      titleLarge: TextStyle(
        color: Color.fromRGBO(2, 164, 221, 1),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Colors.black87,
        fontSize: 12,
      ),
    ), colorScheme: const ColorScheme.light(
      primary: Colors.white,
      onPrimary: Colors.black54,
      secondary: Color.fromRGBO(2, 164, 221, 1),
      onSecondary: Colors.white,
      onBackground: Colors.black,
    ).copyWith(secondary: const Color.fromRGBO(2, 164, 221, 1)).copyWith(background: Colors.white),
  );

  static final ThemeData darkTheme = ThemeData(
    primaryColor: const Color.fromRGBO(2, 164, 221, 1),
    scaffoldBackgroundColor: const Color(0xff1A1A1A),
    appBarTheme: const AppBarTheme(
      color: Color(0xff222222),
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    cardTheme: const CardTheme(
      color: Color(0xff1F1F1F),
    ),
    iconTheme: const IconThemeData(
      color: Color.fromRGBO(255, 255, 255, 0.8),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Colors.white,
      ),
      displayMedium: TextStyle(
        color: Colors.white,
        fontFamily: "Choplin",
        fontWeight: FontWeight.w700,
      ),
      displaySmall: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
      ),
      headlineMedium: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
        fontFamily: "Choplin",
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
      ),
      titleLarge: TextStyle(
        color: Color.fromRGBO(2, 164, 221, 1),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 0.8),
        fontSize: 12,
      ),
    ), colorScheme: const ColorScheme.light(
      primary: Color(0xff1A1A1A),
      onPrimary: Color.fromRGBO(255, 255, 255, 0.75),
      secondary: Color.fromRGBO(2, 164, 221, 1),
      onSecondary: Colors.white,
      onBackground: Colors.white,
    ).copyWith(secondary: const Color.fromRGBO(2, 164, 221, 1)).copyWith(background: const Color(0xff222222)),
  );
}
