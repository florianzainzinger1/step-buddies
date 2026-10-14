import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_service.dart';
import '../models/challenge.dart';

/// Animal avatars for the race
enum RaceAnimal {
  rabbit,
  turtle,
  cheetah,
  eagle,
  dolphin,
  wolf,
}

extension RaceAnimalExtension on RaceAnimal {
  String get emoji {
    switch (this) {
      case RaceAnimal.rabbit:
        return '🐰';
      case RaceAnimal.turtle:
        return '🐢';
      case RaceAnimal.cheetah:
        return '🐆';
      case RaceAnimal.eagle:
        return '🦅';
      case RaceAnimal.dolphin:
        return '🐬';
      case RaceAnimal.wolf:
        return '🐺';
    }
  }

  String get name {
    switch (this) {
      case RaceAnimal.rabbit:
        return 'Hase';
      case RaceAnimal.turtle:
        return 'Schildkröte';
      case RaceAnimal.cheetah:
        return 'Gepard';
      case RaceAnimal.eagle:
        return 'Adler';
      case RaceAnimal.dolphin:
        return 'Delfin';
      case RaceAnimal.wolf:
        return 'Wolf';
    }
  }
}

/// Race track visualization for challenges
class RaceTrack extends StatefulWidget {
  final List<ChallengeTeam> teams;
  final Map<String, int> scores;
  final int totalGoal;
  final bool isActive;

  const RaceTrack({
    super.key,
    required this.teams,
    required this.scores,
    required this.totalGoal,
    this.isActive = true,
  });

  @override
  State<RaceTrack> createState() => _RaceTrackState();
}

class _RaceTrackState extends State<RaceTrack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(RaceTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scores != widget.scores) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    if (widget.teams.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate max score for scaling
    final maxScore = widget.scores.values.isEmpty
        ? 1
        : widget.scores.values.reduce((a, b) => a > b ? a : b);

    // Get team colors
    final teamColors = [
      colors.primary,
      colors.secondary,
      colors.accent,
      colors.success,
    ];

    // Sort teams by score for ranking
    final sortedTeams = [...widget.teams];
    sortedTeams.sort((a, b) {
      final scoreA = widget.scores[a.id] ?? 0;
      final scoreB = widget.scores[b.id] ?? 0;
      return scoreB.compareTo(scoreA);
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: themeService.isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🏁', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rennen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (widget.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Race tracks
          ...sortedTeams.asMap().entries.map((entry) {
            final index = entry.key;
            final team = entry.value;
            final score = widget.scores[team.id] ?? 0;
            final progress = maxScore > 0 ? score / maxScore : 0.0;
            final teamColor = teamColors[widget.teams.indexOf(team) % teamColors.length];
            final animal = RaceAnimal.values[widget.teams.indexOf(team) % RaceAnimal.values.length];
            final isLeader = index == 0 && score > 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _RaceLane(
                team: team,
                score: score,
                progress: progress,
                color: teamColor,
                animal: animal,
                isLeader: isLeader,
                animation: _animation,
                rank: index + 1,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RaceLane extends StatelessWidget {
  final ChallengeTeam team;
  final int score;
  final double progress;
  final Color color;
  final RaceAnimal animal;
  final bool isLeader;
  final Animation<double> animation;
  final int rank;

  const _RaceLane({
    required this.team,
    required this.score,
    required this.progress,
    required this.color,
    required this.animal,
    required this.isLeader,
    required this.animation,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final animatedProgress = progress * animation.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team name and score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: rank == 1
                            ? Colors.amber.withOpacity(0.2)
                            : colors.cardSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          rank == 1 ? '👑' : '$rank',
                          style: TextStyle(
                            fontSize: rank == 1 ? 12 : 11,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      team.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isLeader) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Führt',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  _formatNumber(score),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Track
            Stack(
              children: [
                // Track background
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.cardSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.cardBorder.withOpacity(0.3),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Track lines
                      Positioned.fill(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            5,
                            (i) => Container(
                              width: 1,
                              color: colors.cardBorder.withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                      // Finish flag
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Text(
                            '🏁',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textTertiary.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress fill
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animatedProgress.clamp(0.0, 1.0),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.3),
                          color.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                // Animal avatar
                Positioned(
                  left: (MediaQuery.of(context).size.width - 80) *
                      animatedProgress.clamp(0.0, 0.92) *
                      0.8,
                  top: 0,
                  bottom: 0,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      // Bounce effect when moving
                      final bounce = animation.status == AnimationStatus.forward
                          ? (1 + 0.1 * (1 - (animation.value * 2 - 1).abs()))
                          : 1.0;
                      return Transform.scale(
                        scale: bounce,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          animal.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}

/// Animal selector for choosing team avatar
class AnimalSelector extends StatelessWidget {
  final RaceAnimal? selected;
  final ValueChanged<RaceAnimal> onSelect;

  const AnimalSelector({
    super.key,
    this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: RaceAnimal.values.map((animal) {
        final isSelected = animal == selected;

        return GestureDetector(
          onTap: () => onSelect(animal),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected ? colors.primary.withOpacity(0.15) : colors.cardSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? colors.primary : colors.cardBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  animal.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                Text(
                  animal.name,
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected ? colors.primary : colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
