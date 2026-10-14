import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_service.dart';
import 'interactive_card.dart';

class LeaderboardEntry {
  final String userId;
  final String name;
  final int steps;
  final bool isMe;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.steps,
    this.isMe = false,
  });
}

class LeaderboardSection extends StatefulWidget {
  final List<LeaderboardEntry> entries;
  final void Function(LeaderboardEntry entry)? onEntryTap;

  const LeaderboardSection({super.key, required this.entries, this.onEntryTap});

  @override
  State<LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<LeaderboardSection> {

  String _formatSteps(int value) {
    // 15678 -> "15.678"
    final s = value.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }
    final reversed = buffer.toString().split('').reversed.join();
    return reversed;
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    if (widget.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final avgSteps =
        widget.entries.map((e) => e.steps).reduce((a, b) => a + b) ~/ widget.entries.length;

    final sorted = [...widget.entries]..sort((a, b) => b.steps.compareTo(a.steps));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeService.isDarkMode ? 0.3 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFFACC15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Leaderboard',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Durchschnitt: ${_formatSteps(avgSteps)} Schritte',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Einträge with staggered animation
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = sorted[index];
              final rank = index + 1;

              return StaggeredAnimation(
                index: index,
                delay: const Duration(milliseconds: 60),
                child: _LeaderboardRow(
                  rank: rank,
                  name: entry.name,
                  steps: _formatSteps(entry.steps),
                  isMe: entry.isMe,
                  onTap: widget.onEntryTap != null ? () => widget.onEntryTap!(entry) : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final String steps;
  final bool isMe;
  final VoidCallback? onTap;

  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.steps,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Rank badge with animation for top 3
          _RankBadge(rank: rank),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),

          // Steps
          Text(
            steps,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),

          // Chevron if tappable
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colors.textSecondary.withOpacity(0.5),
            ),
          ],
        ],
      ),
    );

    return InteractiveCard(
      onTap: onTap,
      pressScale: onTap != null ? 0.98 : 1.0,
      borderRadius: BorderRadius.circular(18),
      backgroundColor: isMe ? colors.cardSoft : colors.cardBackground,
      shadow: [
        BoxShadow(
          color: isMe
              ? colors.accent.withOpacity(0.15)
              : Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: isMe
              ? Border.all(color: colors.accent.withOpacity(0.4), width: 1.2)
              : null,
        ),
        child: rowContent,
      ),
    );
  }
}

class _RankBadge extends StatefulWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  State<_RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<_RankBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.1), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.rank <= 3) {
      Future.delayed(Duration(milliseconds: 100 * widget.rank), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _rankCircleColor() {
    switch (widget.rank) {
      case 1:
        return AppColors.gold;
      case 2:
        return AppColors.silver;
      case 3:
        return AppColors.bronze;
      default:
        return AppColors.cardSoft;
    }
  }

  Color _rankTextColor() {
    switch (widget.rank) {
      case 1:
      case 3:
        return Colors.white;
      case 2:
        return AppColors.textPrimary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = widget.rank <= 3;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _rankCircleColor(),
              boxShadow: isTop3
                  ? [
                      BoxShadow(
                        color: _rankCircleColor().withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              widget.rank.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _rankTextColor(),
              ),
            ),
          ),
        );
      },
    );
  }
}
