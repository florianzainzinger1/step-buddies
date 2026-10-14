import 'dart:math' as math;
import 'package:flutter/material.dart';

class StreakFire extends StatefulWidget {
  final int streakDays;
  final double size;
  final bool animate;

  const StreakFire({
    super.key,
    required this.streakDays,
    this.size = 40,
    this.animate = true,
  });

  @override
  State<StreakFire> createState() => _StreakFireState();
}

class _StreakFireState extends State<StreakFire>
    with TickerProviderStateMixin {
  late AnimationController _flameController;
  late AnimationController _emberController;
  late List<EmberParticle> _embers;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    _flameController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _emberController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _embers = List.generate(8, (_) => _generateEmber());

    if (widget.animate) {
      _flameController.repeat(reverse: true);
      _emberController.repeat();
    }
  }

  EmberParticle _generateEmber() {
    return EmberParticle(
      x: 0.3 + _random.nextDouble() * 0.4,
      startY: 0.9,
      size: 2 + _random.nextDouble() * 3,
      speed: 0.3 + _random.nextDouble() * 0.4,
      drift: (_random.nextDouble() - 0.5) * 0.3,
      delay: _random.nextDouble(),
    );
  }

  @override
  void dispose() {
    _flameController.dispose();
    _emberController.dispose();
    super.dispose();
  }

  // Scale fire size based on streak length
  double get _scaleMultiplier {
    if (widget.streakDays >= 30) return 1.3;
    if (widget.streakDays >= 14) return 1.2;
    if (widget.streakDays >= 7) return 1.1;
    return 1.0;
  }

  // Fire intensity based on streak
  Color get _innerColor {
    if (widget.streakDays >= 30) return const Color(0xFFFFFFFF);
    if (widget.streakDays >= 14) return const Color(0xFFFFFF88);
    return const Color(0xFFFFCC00);
  }

  Color get _middleColor {
    if (widget.streakDays >= 30) return const Color(0xFFFFDD00);
    if (widget.streakDays >= 14) return const Color(0xFFFF9500);
    return const Color(0xFFFF6600);
  }

  Color get _outerColor {
    if (widget.streakDays >= 30) return const Color(0xFFFF4500);
    if (widget.streakDays >= 14) return const Color(0xFFCC3300);
    return const Color(0xFF991100);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final scaledSize = widget.size * _scaleMultiplier;

    if (reduceMotion || !widget.animate) {
      return _buildStaticFlame(scaledSize);
    }

    return RepaintBoundary(
      child: SizedBox(
        width: scaledSize,
        height: scaledSize * 1.3,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Ember particles
            AnimatedBuilder(
              animation: _emberController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(scaledSize, scaledSize * 1.3),
                  painter: EmberPainter(
                    embers: _embers,
                    progress: _emberController.value,
                    color: _middleColor,
                  ),
                );
              },
            ),
            // Animated flame
            AnimatedBuilder(
              animation: _flameController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(scaledSize, scaledSize * 1.2),
                  painter: FlamePainter(
                    flicker: _flameController.value,
                    innerColor: _innerColor,
                    middleColor: _middleColor,
                    outerColor: _outerColor,
                  ),
                );
              },
            ),
            // Glow effect
            Positioned(
              bottom: 0,
              child: Container(
                width: scaledSize * 0.8,
                height: scaledSize * 0.4,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _middleColor.withOpacity(0.4),
                      _middleColor.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticFlame(double size) {
    return Icon(
      Icons.local_fire_department,
      size: size,
      color: _middleColor,
    );
  }
}

class FlamePainter extends CustomPainter {
  final double flicker;
  final Color innerColor;
  final Color middleColor;
  final Color outerColor;

  FlamePainter({
    required this.flicker,
    required this.innerColor,
    required this.middleColor,
    required this.outerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height;
    final flickerOffset = flicker * 0.05;

    // Outer flame
    final outerPath = _createFlamePath(
      centerX: centerX,
      baseY: baseY,
      width: size.width * (0.8 + flickerOffset),
      height: size.height * (0.9 + flickerOffset * 0.5),
      tipOffset: flickerOffset * size.width * 0.2,
    );

    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [outerColor, outerColor.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(outerPath, outerPaint);

    // Middle flame
    final middlePath = _createFlamePath(
      centerX: centerX,
      baseY: baseY,
      width: size.width * (0.55 + flickerOffset * 0.8),
      height: size.height * (0.75 + flickerOffset * 0.3),
      tipOffset: -flickerOffset * size.width * 0.15,
    );

    final middlePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [middleColor, middleColor.withOpacity(0.3)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(middlePath, middlePaint);

    // Inner flame (brightest)
    final innerPath = _createFlamePath(
      centerX: centerX,
      baseY: baseY,
      width: size.width * (0.3 + flickerOffset * 0.5),
      height: size.height * (0.5 + flickerOffset * 0.2),
      tipOffset: flickerOffset * size.width * 0.1,
    );

    final innerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [innerColor, innerColor.withOpacity(0.5)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(innerPath, innerPaint);
  }

  Path _createFlamePath({
    required double centerX,
    required double baseY,
    required double width,
    required double height,
    required double tipOffset,
  }) {
    final path = Path();

    final left = centerX - width / 2;
    final right = centerX + width / 2;
    final top = baseY - height;

    path.moveTo(left, baseY);

    // Left curve
    path.quadraticBezierTo(
      left - width * 0.1,
      baseY - height * 0.4,
      centerX + tipOffset,
      top,
    );

    // Right curve
    path.quadraticBezierTo(
      right + width * 0.1,
      baseY - height * 0.4,
      right,
      baseY,
    );

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant FlamePainter oldDelegate) {
    return oldDelegate.flicker != flicker;
  }
}

class EmberParticle {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double drift;
  final double delay;

  EmberParticle({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.drift,
    required this.delay,
  });
}

class EmberPainter extends CustomPainter {
  final List<EmberParticle> embers;
  final double progress;
  final Color color;

  EmberPainter({
    required this.embers,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ember in embers) {
      final adjustedProgress = (progress + ember.delay) % 1.0;
      final y = ember.startY - adjustedProgress * ember.speed * 2;
      final x = ember.x + math.sin(adjustedProgress * math.pi * 2) * ember.drift;

      // Fade out as ember rises
      final opacity = (1 - adjustedProgress).clamp(0.0, 1.0);

      if (y < 0 || y > 1) continue;

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ember.size * 0.5);

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        ember.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EmberPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
