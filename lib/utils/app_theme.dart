import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color navyPrimary = Color(0xFF00426E);
  static const Color navySecondary = Color(0xFF003258);
  static const Color greenPrimary = Color(0xFF0CAA4E);
  static const Color greenSecondary = Color(0xFF09933F);
  static const Color lightGreen = Color(0xFF5FDEA0);
  static const Color yellow = Color(0xFFEAB308);
  static const Color red = Color(0xFFEF4444);
  static const Color background = Color(0xFFF8FAFC);
  
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyPrimary, navySecondary],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenPrimary, greenSecondary],
  );

  // Text Styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: navyPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: navyPrimary,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 14,
    color: Colors.grey,
    height: 1.5,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 12,
    color: Colors.blueAccent,
  );
}
