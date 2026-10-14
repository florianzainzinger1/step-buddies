import 'package:flutter/services.dart';

class HapticUtils {
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  static void vibrate() {
    HapticFeedback.vibrate();
  }

  // Celebration haptic pattern for milestones
  static Future<void> celebrationPattern() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
  }

  // Short success feedback
  static void success() {
    HapticFeedback.mediumImpact();
  }

  // Subtle feedback for interactions
  static void subtle() {
    HapticFeedback.selectionClick();
  }
}
