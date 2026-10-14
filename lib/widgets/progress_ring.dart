import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_service.dart';

class ProgressRing extends StatefulWidget {
  final int steps;
  final int goal;
  final Duration animationDuration;
  final VoidCallback? onGoalReached;
  final void Function(int milestone)? onMilestoneReached;

  const ProgressRing({
    super.key,
    required this.steps,
    required this.goal,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.onGoalReached,
    this.onMilestoneReached,
  });

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  double _previousProgress = 0;
  int _lastMilestone = 0;

  static const List<int> milestonePercentages = [25, 50, 75, 100];

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController.forward();
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.steps != widget.steps || oldWidget.goal != widget.goal) {
      _previousProgress = _calculateProgress(oldWidget.steps, oldWidget.goal);
      _progressController.forward(from: 0);
      _checkMilestones();
    }
  }

  double _calculateProgress(int steps, int goal) {
    final safeGoal = goal <= 0 ? 1 : goal;
    return (steps / safeGoal).clamp(0.0, 1.0);
  }

  void _checkMilestones() {
    final progress = _calculateProgress(widget.steps, widget.goal);
    final percentage = (progress * 100).floor();

    for (final milestone in milestonePercentages) {
      if (percentage >= milestone && _lastMilestone < milestone) {
        _lastMilestone = milestone;
        widget.onMilestoneReached?.call(milestone);

        if (milestone == 100) {
          widget.onGoalReached?.call();
          _pulseController.repeat(reverse: true);
        }
        break;
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;
    final isDark = themeService.isDarkMode;

    final safeGoal = widget.goal <= 0 ? 1 : widget.goal;
    final targetProgress = (widget.steps / safeGoal).clamp(0.0, 1.0);
    final percentage = (targetProgress * 100).floor();
    final isComplete = percentage >= 100;

    // Check for reduced motion
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_progressController, _pulseController]),
        builder: (context, child) {
          final animatedProgress = reduceMotion
              ? targetProgress
              : Tween<double>(begin: _previousProgress, end: targetProgress)
                  .animate(CurvedAnimation(
                    parent: _progressController,
                    curve: Curves.easeOutCubic,
                  ))
                  .value;

          final scale = isComplete && !reduceMotion ? _pulseAnimation.value : 1.0;

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Custom painted progress ring with gradient
                  CustomPaint(
                    size: const Size(180, 180),
                    painter: GradientProgressRingPainter(
                      progress: animatedProgress,
                      strokeWidth: 14,
                      backgroundColor: isDark
                          ? colors.cardSoft
                          : Colors.grey.shade200,
                      gradientColors: [
                        colors.primary,
                        colors.secondary,
                        colors.accent,
                      ],
                      showGlow: animatedProgress > 0,
                      glowColor: colors.primary,
                    ),
                  ),
                  // Text in the center
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated step count
                      TweenAnimationBuilder<int>(
                        tween: IntTween(
                          begin: 0,
                          end: widget.steps,
                        ),
                        duration: reduceMotion
                            ? Duration.zero
                            : widget.animationDuration,
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            _formatNumber(value),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'von ${_formatNumber(widget.goal)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Animated percentage with color change
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: targetProgress),
                        duration: reduceMotion
                            ? Duration.zero
                            : widget.animationDuration,
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          final animatedPercentage = (value * 100).floor();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? colors.primary.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$animatedPercentage%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isComplete
                                    ? colors.primary
                                    : colors.primary.withOpacity(0.8),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  // Goal reached indicator
                  if (isComplete)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}

class GradientProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final List<Color> gradientColors;
  final bool showGlow;
  final Color glowColor;

  GradientProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.gradientColors,
    this.showGlow = false,
    this.glowColor = Colors.purple,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring - use butt cap to avoid overlap at start
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress <= 0) return;

    final startAngle = -math.pi / 2; // Start from top

    // FIX: Adjust sweep angle to account for rounded caps
    // This prevents color bleeding at the start point
    final cappedProgress = progress.clamp(0.0, 1.0);
    final sweepAngle = 2 * math.pi * cappedProgress;

    // FIX: Use a slightly adjusted start angle for very small progress
    // to prevent the rounded cap from bleeding into the start area
    final adjustedStartAngle = cappedProgress < 0.05
        ? startAngle + (strokeWidth / (2 * radius))
        : startAngle;
    final adjustedSweepAngle = cappedProgress < 0.05
        ? sweepAngle - (strokeWidth / radius)
        : sweepAngle;

    // Create gradient that follows the arc
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [...gradientColors, gradientColors.first],
      stops: _calculateStops(gradientColors.length + 1),
      transform: GradientRotation(startAngle),
    );

    // Progress arc with proper rounded caps
    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw the progress arc
    if (cappedProgress >= 0.02) {
      canvas.drawArc(
        rect,
        adjustedStartAngle,
        adjustedSweepAngle.clamp(0.0, 2 * math.pi),
        false,
        progressPaint,
      );
    }

    // Draw a clean starting cap to cover any bleeding
    if (cappedProgress > 0.02 && cappedProgress < 0.98) {
      final startX = center.dx + radius * math.cos(startAngle);
      final startY = center.dy + radius * math.sin(startAngle);

      final capPaint = Paint()
        ..color = gradientColors.first
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(startX, startY), strokeWidth / 2, capPaint);
    }

    // Glow at endpoint
    if (showGlow && progress > 0.03) {
      final endAngle = startAngle + sweepAngle;
      final glowX = center.dx + radius * math.cos(endAngle);
      final glowY = center.dy + radius * math.sin(endAngle);

      final glowPaint = Paint()
        ..color = glowColor.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      canvas.drawCircle(Offset(glowX, glowY), strokeWidth / 2 + 6, glowPaint);

      // Bright center of glow
      final brightPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(Offset(glowX, glowY), strokeWidth / 3, brightPaint);
    }
  }

  List<double> _calculateStops(int count) {
    if (count <= 1) return [0.0];
    return List.generate(count, (i) => i / (count - 1));
  }

  @override
  bool shouldRepaint(covariant GradientProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.showGlow != showGlow;
  }
}
