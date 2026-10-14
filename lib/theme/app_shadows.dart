import 'package:flutter/material.dart';

class AppShadows {
  // Soft shadow for cards
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  // Elevated shadow for floating elements
  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
  ];

  // Pressed shadow (smaller, for pressed state)
  static List<BoxShadow> pressedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  // Glow effect for celestial bodies
  static List<BoxShadow> sunGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.6),
      blurRadius: 30,
      spreadRadius: 10,
    ),
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 60,
      spreadRadius: 20,
    ),
  ];

  static List<BoxShadow> moonGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.4),
      blurRadius: 20,
      spreadRadius: 5,
    ),
    BoxShadow(
      color: color.withOpacity(0.2),
      blurRadius: 40,
      spreadRadius: 10,
    ),
  ];

  // Progress ring glow
  static List<BoxShadow> progressGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.5),
      blurRadius: 12,
      spreadRadius: 2,
    ),
  ];

  // Fire glow for streak animation
  static List<BoxShadow> fireGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.6),
      blurRadius: 15,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 30,
      spreadRadius: 5,
    ),
  ];

  // Subtle inner shadow
  static List<BoxShadow> innerShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
      blurStyle: BlurStyle.inner,
    ),
  ];

  // Dark mode shadows
  static List<BoxShadow> cardShadowDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> elevatedShadowDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}
