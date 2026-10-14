import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_service.dart';
import '../theme/theme_colors.dart';
import 'celestial_body.dart';
import 'floating_clouds.dart';
import 'twinkling_stars.dart';

class AnimatedSkyBackground extends StatefulWidget {
  final Widget child;
  final bool showCelestialBody;
  final bool showDecorations;

  const AnimatedSkyBackground({
    super.key,
    required this.child,
    this.showCelestialBody = true,
    this.showDecorations = true,
  });

  @override
  State<AnimatedSkyBackground> createState() => _AnimatedSkyBackgroundState();
}

class _AnimatedSkyBackgroundState extends State<AnimatedSkyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _transitionController;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check for reduced motion preference
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final colors = themeService.colors;
        final period = themeService.currentPeriod;

        return Stack(
          children: [
            // Animated gradient background
            RepaintBoundary(
              child: AnimatedContainer(
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors.skyGradient,
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Stars (night/dusk only)
            if (widget.showDecorations && themeService.showStars && !reduceMotion)
              TwinklingStars(
                starCount: period == TimePeriod.night ? 50 : 20,
                opacity: period == TimePeriod.night ? 1.0 : 0.5,
              ),

            // Clouds (dawn/day only)
            if (widget.showDecorations && themeService.showClouds && !reduceMotion)
              FloatingClouds(
                cloudCount: period == TimePeriod.dawn ? 4 : 5,
                cloudColor: Colors.white,
                opacity: period == TimePeriod.dawn ? 0.7 : 0.6,
              ),

            // Sun (dawn/day/dusk)
            if (widget.showCelestialBody && themeService.showSun && !reduceMotion)
              CelestialBody(
                isSun: true,
                size: _getSunSize(period),
                position: _getSunPosition(period),
              ),

            // Moon (night only)
            if (widget.showCelestialBody && themeService.showMoon && !reduceMotion)
              const CelestialBody(
                isSun: false,
                size: 60,
                position: Offset(0.85, 0.1),
              ),

            // Main content
            widget.child,
          ],
        );
      },
    );
  }

  double _getSunSize(TimePeriod period) {
    switch (period) {
      case TimePeriod.dawn:
        return 70;
      case TimePeriod.day:
        return 80;
      case TimePeriod.dusk:
        return 90; // Larger for sunset effect
      case TimePeriod.night:
        return 0;
    }
  }

  Offset _getSunPosition(TimePeriod period) {
    switch (period) {
      case TimePeriod.dawn:
        return const Offset(0.85, 0.25); // Rising sun
      case TimePeriod.day:
        return const Offset(0.85, 0.12); // High sun
      case TimePeriod.dusk:
        return const Offset(0.85, 0.3); // Setting sun
      case TimePeriod.night:
        return const Offset(0.85, 0.5); // Below horizon
    }
  }
}

// Simple gradient background without animations (for screens that don't need full sky)
class SimpleGradientBackground extends StatelessWidget {
  final Widget child;

  const SimpleGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final colors = themeService.colors;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.backgroundTop,
                colors.backgroundBottom,
              ],
            ),
          ),
          child: child,
        );
      },
    );
  }
}
