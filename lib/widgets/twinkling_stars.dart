import 'dart:math' as math;
import 'package:flutter/material.dart';

class TwinklingStars extends StatefulWidget {
  final int starCount;
  final Color starColor;
  final double opacity;

  const TwinklingStars({
    super.key,
    this.starCount = 50,
    this.starColor = Colors.white,
    this.opacity = 1.0,
  });

  @override
  State<TwinklingStars> createState() => _TwinklingStarsState();
}

class _TwinklingStarsState extends State<TwinklingStars>
    with TickerProviderStateMixin {
  late List<StarData> _stars;
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initStars();
  }

  void _initStars() {
    _stars = List.generate(widget.starCount, (index) => _generateStar());
    _controllers = [];
    _animations = [];

    for (int i = 0; i < widget.starCount; i++) {
      final duration = Duration(
        milliseconds: 1000 + _random.nextInt(2000),
      );

      final controller = AnimationController(
        duration: duration,
        vsync: this,
      );

      final animation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );

      _controllers.add(controller);
      _animations.add(animation);

      // Start with random delay for varied twinkling
      Future.delayed(
        Duration(milliseconds: _random.nextInt(2000)),
        () {
          if (mounted) {
            controller.repeat(reverse: true);
          }
        },
      );
    }
  }

  StarData _generateStar() {
    return StarData(
      x: _random.nextDouble(),
      y: _random.nextDouble() * 0.6, // Top 60% of screen
      size: 1 + _random.nextDouble() * 2,
      baseOpacity: 0.5 + _random.nextDouble() * 0.5,
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: List.generate(_stars.length, (index) {
          final star = _stars[index];
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Positioned(
                left: MediaQuery.of(context).size.width * star.x,
                top: MediaQuery.of(context).size.height * star.y,
                child: _StarWidget(
                  size: star.size,
                  color: widget.starColor,
                  opacity: star.baseOpacity *
                      _animations[index].value *
                      widget.opacity,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class StarData {
  final double x;
  final double y;
  final double size;
  final double baseOpacity;

  StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.baseOpacity,
  });
}

class _StarWidget extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _StarWidget({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity * 0.5),
            blurRadius: size * 2,
            spreadRadius: size * 0.5,
          ),
        ],
      ),
    );
  }
}

// Shooting star that can be triggered occasionally
class ShootingStar extends StatefulWidget {
  final VoidCallback? onComplete;

  const ShootingStar({super.key, this.onComplete});

  @override
  State<ShootingStar> createState() => _ShootingStarState();
}

class _ShootingStarState extends State<ShootingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _opacityAnimation;
  final math.Random _random = math.Random();
  late double _startX;
  late double _startY;

  @override
  void initState() {
    super.initState();
    _startX = 0.2 + _random.nextDouble() * 0.6;
    _startY = _random.nextDouble() * 0.3;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _progressAnimation.value;
        final x = _startX + progress * 0.3;
        final y = _startY + progress * 0.2;

        return Positioned(
          left: size.width * x,
          top: size.height * y,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 30,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.8),
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
