import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CelestialBody extends StatefulWidget {
  final bool isSun;
  final double size;
  final Offset position;

  const CelestialBody({
    super.key,
    required this.isSun,
    this.size = 80,
    this.position = const Offset(0.8, 0.15),
  });

  @override
  State<CelestialBody> createState() => _CelestialBodyState();
}

class _CelestialBodyState extends State<CelestialBody>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rayController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rayAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _rayController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rayAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rayController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate position - position.dx is percentage from left (0.85 = 85% from left = right side)
    final leftPos = screenWidth * widget.position.dx - widget.size;
    final topPos = screenHeight * widget.position.dy;
    
    return Positioned(
      left: leftPos,
      top: topPos,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _rayAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: widget.isSun ? _buildSun() : _buildMoon(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSun() {
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: widget.size * 1.8,
            height: widget.size * 1.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.sunGlow.withOpacity(0.4),
                  AppColors.sunGlow.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.3, 0.6, 1.0],
              ),
            ),
          ),
          // Animated rays
          CustomPaint(
            size: Size(widget.size * 2, widget.size * 2),
            painter: SunRaysPainter(
              rotation: _rayAnimation.value,
              color: AppColors.sunGlow,
            ),
          ),
          // Sun core
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white,
                  AppColors.sunCore,
                  AppColors.sunGlow,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sunGlow.withOpacity(0.6),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoon() {
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: widget.size * 1.4,
            height: widget.size * 1.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.moonGlow.withOpacity(0.3),
                  AppColors.moonGlow.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.4, 0.7, 1.0],
              ),
            ),
          ),
          // Moon core
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white,
                  AppColors.moonCore,
                  AppColors.moonGlow,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.moonGlow.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          // Craters
          ..._buildCraters(),
        ],
      ),
    );
  }

  List<Widget> _buildCraters() {
    return [
      Positioned(
        top: widget.size * 0.3,
        left: widget.size * 0.35,
        child: _buildCrater(widget.size * 0.15),
      ),
      Positioned(
        top: widget.size * 0.55,
        left: widget.size * 0.55,
        child: _buildCrater(widget.size * 0.1),
      ),
      Positioned(
        top: widget.size * 0.45,
        left: widget.size * 0.25,
        child: _buildCrater(widget.size * 0.08),
      ),
    ];
  }

  Widget _buildCrater(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.moonGlow.withOpacity(0.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
  }
}

class SunRaysPainter extends CustomPainter {
  final double rotation;
  final Color color;

  SunRaysPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const rayCount = 12;
    const rayLength = 15.0;
    final innerRadius = size.width / 4;

    for (int i = 0; i < rayCount; i++) {
      final angle = (2 * math.pi * i / rayCount) + rotation;
      final startX = center.dx + innerRadius * math.cos(angle);
      final startY = center.dy + innerRadius * math.sin(angle);
      final endX = center.dx + (innerRadius + rayLength) * math.cos(angle);
      final endY = center.dy + (innerRadius + rayLength) * math.sin(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SunRaysPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
