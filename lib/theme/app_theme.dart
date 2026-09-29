import 'package:flutter/material.dart';

/// Production High-Contrast Light Application Style
/// Retro soft-cream canvas matched with stark, heavy black geometric typography
/// and dynamic neon-cyan & alarm-orange indicators.
class AppTheme {
  // Brand Palette Constants
  static const Color creamCanvas = Color(0xFFFAF6EE);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color panelCream = Color(0xFFF2ECE1);
  static const Color panelDark = Color(0xFF14161B);
  static const Color starkBlack = Color(0xFF000000);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color alarmOrange = Color(0xFFFF5722);
  static const Color warningAmber = Color(0xFFFF9500);
  static const Color successGreen = Color(0xFF00C853);
  static const Color textMuted = Color(0xFF5A5852);
  static const Color textLight = Color(0xFF8E8A82);

  // Geometric Slab Border Constants
  static final Border solidBorder = Border.all(color: starkBlack, width: 2.0);
  static final Border solidBorderThick = Border.all(color: starkBlack, width: 3.0);
  static const double defaultRadius = 12.0;

  // High-Contrast Neo-Brutalist Panel Decoration
  static BoxDecoration panelDecoration({
    Color color = cardWhite,
    bool withShadow = true,
    double radius = defaultRadius,
    Border? border,
    Color shadowColor = starkBlack,
    Offset shadowOffset = const Offset(4, 4),
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? solidBorder,
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: shadowColor,
                offset: shadowOffset,
                blurRadius: 0,
              ),
            ]
          : null,
    );
  }

  // Geometric Slab-Serif Typography Architecture
  static const TextStyle slabHero = TextStyle(
    fontFamily: 'serif',
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
    color: starkBlack,
  );

  static const TextStyle slabHeadline = TextStyle(
    fontFamily: 'serif',
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
    color: starkBlack,
  );

  static const TextStyle slabTitle = TextStyle(
    fontFamily: 'serif',
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: starkBlack,
  );

  static const TextStyle slabSubtitle = TextStyle(
    fontFamily: 'serif',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: starkBlack,
  );

  static const TextStyle slabLabel = TextStyle(
    fontFamily: 'serif',
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: starkBlack,
  );

  static const TextStyle errorStream = TextStyle(
    fontFamily: 'serif',
    fontSize: 13,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.0,
    color: alarmOrange,
  );

  static const TextStyle cyanStream = TextStyle(
    fontFamily: 'serif',
    fontSize: 13,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.0,
    color: neonCyan,
  );

  // Complete Application ThemeData
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: creamCanvas,
      canvasColor: creamCanvas,
      cardColor: cardWhite,
      primaryColor: neonCyan,
      colorScheme: const ColorScheme.light(
        primary: starkBlack,
        secondary: alarmOrange,
        tertiary: neonCyan,
        surface: cardWhite,
        onSurface: starkBlack,
        error: alarmOrange,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: creamCanvas,
        foregroundColor: starkBlack,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: slabHeadline,
        iconTheme: IconThemeData(color: starkBlack),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: creamCanvas,
        selectedItemColor: starkBlack,
        unselectedItemColor: textMuted,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontFamily: 'serif',
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'serif',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(defaultRadius),
          side: const BorderSide(color: starkBlack, width: 2.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: starkBlack,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: starkBlack, width: 2.0),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: starkBlack,
          side: const BorderSide(color: starkBlack, width: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: starkBlack, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: starkBlack, width: 2.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: starkBlack, width: 2.5),
        ),
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: textLight,
          fontSize: 13,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: starkBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: starkBlack, width: 2.0),
        ),
      ),
    );
  }
}
