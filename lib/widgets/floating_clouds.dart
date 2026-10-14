import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatingClouds extends StatefulWidget {
  final int cloudCount;
  final Color cloudColor;
  final double opacity;

  const FloatingClouds({
    super.key,
    this.cloudCount = 5,
    this.cloudColor = Colors.white,
    this.opacity = 0.6,
  });

  @override
  State<FloatingClouds> createState() => _FloatingCloudsState();
}

class _FloatingCloudsState extends State<FloatingClouds>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<CloudData> _clouds;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _clouds = List.generate(widget.cloudCount, (index) => _generateCloud(index));
  }

  CloudData _generateCloud(int index) {
    return CloudData(
      x: _random.nextDouble(),
      y: 0.05 + _random.nextDouble() * 0.3, // Top 35% of screen
      scale: 0.5 + _random.nextDouble() * 0.5,
      speed: 0.02 + _random.nextDouble() * 0.03,
      opacity: 0.3 + _random.nextDouble() * 0.4,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: _clouds.map((cloud) {
              final xOffset = (cloud.x + _controller.value * cloud.speed) % 1.2 - 0.1;
              return Positioned(
                left: MediaQuery.of(context).size.width * xOffset,
                top: MediaQuery.of(context).size.height * cloud.y,
                child: Opacity(
                  opacity: cloud.opacity * widget.opacity,
                  child: Transform.scale(
                    scale: cloud.scale,
                    child: _CloudShape(color: widget.cloudColor),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class CloudData {
  final double x;
  final double y;
  final double scale;
  final double speed;
  final double opacity;

  CloudData({
    required this.x,
    required this.y,
    required this.scale,
    required this.speed,
    required this.opacity,
  });
}

class _CloudShape extends StatelessWidget {
  final Color color;

  const _CloudShape({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 60),
      painter: CloudPainter(color: color),
    );
  }
}

class CloudPainter extends CustomPainter {
  final Color color;

  CloudPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw fluffy cloud shape using overlapping circles
    final circles = [
      Offset(size.width * 0.3, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.4),
      Offset(size.width * 0.7, size.height * 0.55),
      Offset(size.width * 0.4, size.height * 0.5),
      Offset(size.width * 0.6, size.height * 0.45),
    ];

    final radii = [
      size.width * 0.2,
      size.width * 0.25,
      size.width * 0.18,
      size.width * 0.22,
      size.width * 0.2,
    ];

    for (int i = 0; i < circles.length; i++) {
      canvas.drawCircle(circles[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CloudPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
