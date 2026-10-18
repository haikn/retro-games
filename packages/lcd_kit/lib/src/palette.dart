import 'dart:ui';

/// The two LCD tones plus the bezel around the panel (spec: Visuals).
class LcdPalette {
  const LcdPalette({
    required this.lcd,
    required this.ink,
    required this.bezel,
    this.gridOpacity = 0.06,
  });

  /// Pale green backlight; "off" pixels.
  final Color lcd;

  /// Every "on" pixel.
  final Color ink;

  /// Letterbox bars around the panel.
  final Color bezel;

  /// Opacity of the faint LCD grid lines (0 disables them).
  final double gridOpacity;

  static const green = LcdPalette(
    lcd: Color(0xFFC7F0D8),
    ink: Color(0xFF43523D),
    bezel: Color(0xFF1E2219),
  );

  /// Stricter black-and-white alternative (not a user setting in v1).
  static const mono = LcdPalette(
    lcd: Color(0xFFE0E6D8),
    ink: Color(0xFF1A1A1A),
    bezel: Color(0xFF0E0F0C),
  );

  /// Palette the app ships with.
  static const active = green;
}
