import 'package:flutter/painting.dart';

/// Silkscreen text styles sized so font pixels land on LCD pixels
/// (Silkscreen is drawn on an 8-unit em: 40 px → 1 font px = 5 px = 1 LCD px).
abstract final class LcdText {
  static const family = 'Silkscreen';

  /// Body / HUD / menus: 1 font px = 1 LCD px.
  static TextStyle body(Color color) => TextStyle(
    fontFamily: family,
    fontSize: 40,
    height: 1,
    letterSpacing: 0,
    color: color,
  );

  /// Title logo: 1 font px = 2 LCD px.
  static TextStyle title(Color color) =>
      body(color).copyWith(fontSize: 80, fontWeight: FontWeight.w700);

  /// Top score number: 1 font px = 3 LCD px.
  static TextStyle big(Color color) =>
      body(color).copyWith(fontSize: 120, fontWeight: FontWeight.w700);
}

/// Zero-padded to 5 digits, Snake style (`00123`).
String pad5(int value) => value.toString().padLeft(5, '0');
