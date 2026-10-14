import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_colors.dart';

enum AppThemeMode {
  auto,        // Time-based
  alwaysLight, // Always day theme
  alwaysDark,  // Always night theme
}

class ThemeService extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode';

  AppThemeMode _mode = AppThemeMode.auto;
  TimePeriod _currentPeriod = ThemeColors.getCurrentPeriod();
  Timer? _periodCheckTimer;
  bool _initialized = false;

  ThemeService() {
    _init();
  }

  Future<void> _init() async {
    await _loadPreferences();
    _startPeriodChecker();
    _initialized = true;
    notifyListeners();
  }

  bool get isInitialized => _initialized;

  AppThemeMode get mode => _mode;

  TimePeriod get currentPeriod {
    switch (_mode) {
      case AppThemeMode.auto:
        return _currentPeriod;
      case AppThemeMode.alwaysLight:
        return TimePeriod.day;
      case AppThemeMode.alwaysDark:
        return TimePeriod.night;
    }
  }

  ThemeColors get colors => ThemeColors.forPeriod(currentPeriod);

  bool get isDarkMode => currentPeriod == TimePeriod.night;

  bool get isNightOrDusk =>
      currentPeriod == TimePeriod.night || currentPeriod == TimePeriod.dusk;

  bool get showStars => isNightOrDusk;

  bool get showClouds =>
      currentPeriod == TimePeriod.dawn || currentPeriod == TimePeriod.day;

  bool get showSun =>
      currentPeriod == TimePeriod.dawn ||
      currentPeriod == TimePeriod.day ||
      currentPeriod == TimePeriod.dusk;

  bool get showMoon => currentPeriod == TimePeriod.night;

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_prefsKey) ?? 0;
    _mode = AppThemeMode.values[modeIndex.clamp(0, AppThemeMode.values.length - 1)];
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, mode.index);
  }

  void _startPeriodChecker() {
    // Check every minute for period changes
    _periodCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updatePeriod();
    });
  }

  void _updatePeriod() {
    final newPeriod = ThemeColors.getCurrentPeriod();
    if (newPeriod != _currentPeriod) {
      _currentPeriod = newPeriod;
      if (_mode == AppThemeMode.auto) {
        notifyListeners();
      }
    }
  }

  // For testing or manual override
  void simulatePeriod(TimePeriod period) {
    _currentPeriod = period;
    notifyListeners();
  }

  ThemeData buildThemeData() {
    final themeColors = colors;
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;

    return ThemeData(
      fontFamily: 'Roboto',
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: themeColors.primary,
        onPrimary: isDarkMode ? Colors.white : Colors.white,
        secondary: themeColors.secondary,
        onSecondary: Colors.white,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: themeColors.cardBackground,
        onSurface: themeColors.textPrimary,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      cardColor: themeColors.cardBackground,
      dividerColor: themeColors.textSecondary.withOpacity(0.2),
      useMaterial3: true,
    );
  }

  @override
  void dispose() {
    _periodCheckTimer?.cancel();
    super.dispose();
  }
}
