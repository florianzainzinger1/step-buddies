import 'package:flutter/material.dart';

enum TimePeriod {
  dawn,  // 5:00 - 8:00
  day,   // 8:00 - 17:00
  dusk,  // 17:00 - 20:00
  night, // 20:00 - 5:00
}

class ThemeColors {
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color cardBackground;
  final Color cardSoft;
  final Color cardBorder;
  final Color celestialGlow;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;
  final Color shimmer;
  final List<Color> skyGradient;
  final List<Color> progressGradient;

  // Convenience getter for background (returns backgroundTop)
  Color get background => backgroundTop;

  const ThemeColors({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.cardBackground,
    required this.cardSoft,
    required this.cardBorder,
    required this.celestialGlow,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.shimmer,
    required this.skyGradient,
    required this.progressGradient,
  });

  // Dawn: Warm peach/coral (5:00 - 8:00)
  static const dawn = ThemeColors(
    backgroundTop: Color(0xFFFFD4A8),    // Warm peach
    backgroundBottom: Color(0xFFFFF5EB), // Light cream
    primary: Color(0xFFE07B39),          // Coral orange
    secondary: Color(0xFFF4A261),        // Sandy peach
    accent: Color(0xFFE76F51),           // Burnt sienna
    textPrimary: Color(0xFF3D2914),      // Warm brown
    textSecondary: Color(0xFF8B6914),    // Golden brown
    textTertiary: Color(0xFFAD8B4E),     // Light golden brown
    cardBackground: Color(0xFFFFFBF5),   // Warm white
    cardSoft: Color(0xFFFFF8F0),         // Soft cream
    cardBorder: Color(0xFFE8D4BC),       // Warm border
    celestialGlow: Color(0xFFFFB347),    // Golden sun
    divider: Color(0xFFE8D4BC),          // Warm divider
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFF9800),
    error: Color(0xFFEF5350),
    shimmer: Color(0xFFFFE4C4),
    skyGradient: [
      Color(0xFFFF9A56),  // Sunrise orange
      Color(0xFFFFB88C),  // Peach
      Color(0xFFFDD7AA),  // Light peach
      Color(0xFFFFF5EB),  // Cream
    ],
    progressGradient: [
      Color(0xFFE07B39),
      Color(0xFFF4A261),
      Color(0xFFE76F51),
    ],
  );

  // Day: Light blue (8:00 - 17:00) - Current theme
  static const day = ThemeColors(
    backgroundTop: Color(0xFFE5F0FF),    // Light blue
    backgroundBottom: Color(0xFFFFFFFF), // White
    primary: Color(0xFF8B5CF6),          // Purple
    secondary: Color(0xFFEC4899),        // Pink
    accent: Color(0xFF3B82F6),           // Blue
    textPrimary: Color(0xFF111827),      // Dark gray
    textSecondary: Color(0xFF6B7280),    // Medium gray
    textTertiary: Color(0xFF9CA3AF),     // Light gray
    cardBackground: Color(0xFFFFFFFF),   // White
    cardSoft: Color(0xFFF9FAFB),         // Off-white
    cardBorder: Color(0xFFE5E7EB),       // Light border
    celestialGlow: Color(0xFFFFE066),    // Bright sun
    divider: Color(0xFFE5E7EB),          // Light divider
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    shimmer: Color(0xFFF3F4F6),
    skyGradient: [
      Color(0xFF87CEEB),  // Sky blue
      Color(0xFFB5E3FF),  // Light sky
      Color(0xFFE5F0FF),  // Pale blue
      Color(0xFFFFFFFF),  // White
    ],
    progressGradient: [
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF3B82F6),
    ],
  );

  // Dusk: Lavender/pink sunset (17:00 - 20:00)
  static const dusk = ThemeColors(
    backgroundTop: Color(0xFFE6B8D9),    // Lavender pink
    backgroundBottom: Color(0xFFFFF0F5), // Lavender blush
    primary: Color(0xFF9B59B6),          // Amethyst purple
    secondary: Color(0xFFE74C8C),        // Rose pink
    accent: Color(0xFFFF6B9D),           // Hot pink
    textPrimary: Color(0xFF2D1B30),      // Deep purple
    textSecondary: Color(0xFF6B4F7A),    // Muted purple
    textTertiary: Color(0xFF9B7FAA),     // Light muted purple
    cardBackground: Color(0xFFFFFAFC),   // Soft pink white
    cardSoft: Color(0xFFFFF5F8),         // Blush
    cardBorder: Color(0xFFE8D0E0),       // Pink border
    celestialGlow: Color(0xFFFF8C42),    // Sunset orange
    divider: Color(0xFFE8D0E0),          // Pink divider
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFF9800),
    error: Color(0xFFE91E63),
    shimmer: Color(0xFFF8E8F0),
    skyGradient: [
      Color(0xFFFF6B6B),  // Coral red
      Color(0xFFFFA07A),  // Light salmon
      Color(0xFFDDA0DD),  // Plum
      Color(0xFFE6E6FA),  // Lavender
    ],
    progressGradient: [
      Color(0xFF9B59B6),
      Color(0xFFE74C8C),
      Color(0xFFFF6B9D),
    ],
  );

  // Night: Deep navy/violet (20:00 - 5:00)
  static const night = ThemeColors(
    backgroundTop: Color(0xFF1A1A2E),    // Deep navy
    backgroundBottom: Color(0xFF16213E), // Dark blue
    primary: Color(0xFF7C3AED),          // Violet
    secondary: Color(0xFFA78BFA),        // Light violet
    accent: Color(0xFF60A5FA),           // Sky blue
    textPrimary: Color(0xFFF3F4F6),      // Very light gray - IMPROVED CONTRAST
    textSecondary: Color(0xFFD1D5DB),    // Light gray - IMPROVED CONTRAST
    textTertiary: Color(0xFF9CA3AF),     // Medium gray
    cardBackground: Color(0xFF252547),   // Dark card
    cardSoft: Color(0xFF1F1F3D),         // Darker card
    cardBorder: Color(0xFF3D3D5C),       // Dark border
    celestialGlow: Color(0xFFC4C4E0),    // Moon glow
    divider: Color(0xFF3D3D5C),          // Dark divider
    success: Color(0xFF34D399),          // Bright green for dark mode
    warning: Color(0xFFFBBF24),          // Bright yellow for dark mode
    error: Color(0xFFF87171),            // Bright red for dark mode
    shimmer: Color(0xFF2D2D4D),
    skyGradient: [
      Color(0xFF0F0F23),  // Very dark blue
      Color(0xFF1A1A2E),  // Deep navy
      Color(0xFF16213E),  // Dark blue
      Color(0xFF0F3460),  // Midnight blue
    ],
    progressGradient: [
      Color(0xFF7C3AED),
      Color(0xFFA78BFA),
      Color(0xFF60A5FA),
    ],
  );

  static ThemeColors forPeriod(TimePeriod period) {
    switch (period) {
      case TimePeriod.dawn:
        return dawn;
      case TimePeriod.day:
        return day;
      case TimePeriod.dusk:
        return dusk;
      case TimePeriod.night:
        return night;
    }
  }

  static TimePeriod getCurrentPeriod([DateTime? time]) {
    final hour = (time ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 8) return TimePeriod.dawn;
    if (hour >= 8 && hour < 17) return TimePeriod.day;
    if (hour >= 17 && hour < 20) return TimePeriod.dusk;
    return TimePeriod.night;
  }
}
