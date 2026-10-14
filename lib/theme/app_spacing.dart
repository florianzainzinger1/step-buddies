import 'package:flutter/material.dart';

class AppSpacing {
  // Base spacing unit
  static const double unit = 4.0;

  // Spacing values
  static const double xxs = unit;       // 4
  static const double xs = unit * 2;    // 8
  static const double sm = unit * 3;    // 12
  static const double md = unit * 4;    // 16
  static const double lg = unit * 6;    // 24
  static const double xl = unit * 8;    // 32
  static const double xxl = unit * 12;  // 48

  // Padding
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);

  // Horizontal padding
  static const EdgeInsets paddingHorizontalSM = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMD = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLG = EdgeInsets.symmetric(horizontal: lg);

  // Vertical padding
  static const EdgeInsets paddingVerticalSM = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMD = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLG = EdgeInsets.symmetric(vertical: lg);

  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  // Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  // Border radius
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusRound = 100.0;

  static BorderRadius borderRadiusSM = BorderRadius.circular(radiusSM);
  static BorderRadius borderRadiusMD = BorderRadius.circular(radiusMD);
  static BorderRadius borderRadiusLG = BorderRadius.circular(radiusLG);
  static BorderRadius borderRadiusXL = BorderRadius.circular(radiusXL);

  // Animation durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationVerySlow = Duration(milliseconds: 1000);
}
