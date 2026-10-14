import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/haptic_utils.dart';
import '../theme/app_colors.dart';

class MilestoneCelebration extends StatefulWidget {
  final int milestone; // 25, 50, 75, 100 or step count like 5000, 10000
  final bool isStepMilestone; // true for step counts, false for percentage
  final VoidCallback? onComplete;

  const MilestoneCelebration({
    super.key,
    required this.milestone,
    this.isStepMilestone = false,
    this.onComplete,
  });

  @override
  State<MilestoneCelebration> createState() => _MilestoneCelebrationState();
}

class _MilestoneCelebrationState extends State<MilestoneCelebration>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _badgeController;
  late Animation<double> _badgeScaleAnimation;
  late Animation<double> _badgeOpacityAnimation;
  late List<ConfettiParticle> _particles;

  final math.Random _random = math.Random();
  static const int particleCount = 50;

  @override
  void initState() {
    super.initState();

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _badgeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_badgeController);

    _badgeOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(_badgeController);

    _particles = List.generate(particleCount, (_) => _generateParticle());

    // Trigger haptic feedback
    HapticUtils.celebrationPattern();

    // Start animations
    _confettiController.forward();
    _badgeController.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  ConfettiParticle _generateParticle() {
    return ConfettiParticle(
      x: _random.nextDouble(),
      y: -0.1 - _random.nextDouble() * 0.2,
      vx: (_random.nextDouble() - 0.5) * 0.3,
      vy: 0.3 + _random.nextDouble() * 0.4,
      rotation: _random.nextDouble() * 2 * math.pi,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
      size: 8 + _random.nextDouble() * 8,
      color: _getRandomColor(),
      shape: ConfettiShape.values[_random.nextInt(ConfettiShape.values.length)],
    );
  }

  Color _getRandomColor() {
    final colors = [
      AppColors.purple,
      AppColors.pink,
      AppColors.blue,
      AppColors.gold,
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF5722), // Orange
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Confetti particles
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                ),
              );
            },
          ),
          // Celebration badge
          Center(
            child: AnimatedBuilder(
              animation: _badgeController,
              builder: (context, child) {
                return Opacity(
                  opacity: _badgeOpacityAnimation.value,
                  child: Transform.scale(
                    scale: _badgeScaleAnimation.value,
                    child: _buildBadge(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    final String text;
    final IconData icon;

    if (widget.isStepMilestone) {
      text = '${_formatNumber(widget.milestone)} Schritte!';
      icon = Icons.directions_walk;
    } else {
      text = '${widget.milestone}% erreicht!';
      icon = widget.milestone == 100 ? Icons.emoji_events : Icons.star;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple,
            AppColors.pink,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k';
    }
    return number.toString();
  }
}

enum ConfettiShape { rectangle, circle, triangle }

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double rotationSpeed;
  double size;
  Color color;
  ConfettiShape shape;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.shape,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 0.5 * dt; // Gravity
    rotation += rotationSpeed * dt;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // Update particle position based on progress
      final updatedX = particle.x + particle.vx * progress * 3;
      final updatedY = particle.y + (particle.vy * progress * 3) + (0.5 * progress * progress * 3);
      final updatedRotation = particle.rotation + particle.rotationSpeed * progress * 10;

      // Skip if particle is off screen
      if (updatedY > 1.2) continue;

      final paint = Paint()
        ..color = particle.color.withOpacity((1 - progress).clamp(0, 1));

      canvas.save();
      canvas.translate(
        updatedX * size.width,
        updatedY * size.height,
      );
      canvas.rotate(updatedRotation);

      switch (particle.shape) {
        case ConfettiShape.rectangle:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size,
              height: particle.size * 0.6,
            ),
            paint,
          );
          break;
        case ConfettiShape.circle:
          canvas.drawCircle(Offset.zero, particle.size / 2, paint);
          break;
        case ConfettiShape.triangle:
          final path = Path()
            ..moveTo(0, -particle.size / 2)
            ..lineTo(particle.size / 2, particle.size / 2)
            ..lineTo(-particle.size / 2, particle.size / 2)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Helper widget to trigger celebrations
class CelebrationOverlay extends StatefulWidget {
  final Widget child;

  const CelebrationOverlay({super.key, required this.child});

  static CelebrationOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<CelebrationOverlayState>();
  }

  @override
  State<CelebrationOverlay> createState() => CelebrationOverlayState();
}

class CelebrationOverlayState extends State<CelebrationOverlay> {
  final List<Widget> _celebrations = [];
  int _celebrationKey = 0;

  void celebrate({required int milestone, bool isStepMilestone = false}) {
    final key = _celebrationKey++;
    setState(() {
      _celebrations.add(
        MilestoneCelebration(
          key: ValueKey(key),
          milestone: milestone,
          isStepMilestone: isStepMilestone,
          onComplete: () {
            setState(() {
              _celebrations.removeWhere(
                (w) => (w.key as ValueKey).value == key,
              );
            });
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._celebrations,
      ],
    );
  }
}
