import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/achievement.dart';
import '../services/achievements_service.dart';
import '../theme/theme_colors.dart';
import '../theme/theme_service.dart';
import '../widgets/themed_components.dart';

class RewardsTab extends StatefulWidget {
  const RewardsTab({super.key});

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _achievementsService = AchievementsService.instance;
  late AnimationController _animController;
  late Animation<double> _animation;

  bool _isLoading = true;
  List<Achievement> _achievements = [];
  int _totalXp = 0;
  UserLevel _level = UserLevel.fromXp(0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _loadAchievements();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    await _achievementsService.initialize();

    // Evaluate achievements
    final newlyUnlocked = await _achievementsService.evaluateAndUnlock();

    if (mounted) {
      setState(() {
        _achievements = _achievementsService.getAllAchievements();
        _totalXp = _achievementsService.totalXp;
        _level = _achievementsService.userLevel;
        _isLoading = false;
      });
      _animController.forward();

      // Show celebration for newly unlocked
      for (final achievement in newlyUnlocked) {
        _showUnlockCelebration(achievement);
      }
    }
  }

  void _showUnlockCelebration(Achievement achievement) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(achievement.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Erfolg freigeschaltet!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(achievement.title),
                ],
              ),
            ),
            Text(
              '+${achievement.xpReward} XP',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: achievement.rarityColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    if (_isLoading) {
      return _buildSkeleton(colors);
    }

    final unlocked = _achievements.where((a) => a.isUnlocked).toList();
    final locked = _achievements.where((a) => !a.isUnlocked).toList();

    return RefreshIndicator(
      onRefresh: _loadAchievements,
      color: colors.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Level Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildLevelCard(colors),
            ),
          ),

          // Stats Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatsRow(colors, unlocked.length),
            ),
          ),

          // Unlocked Section
          if (unlocked.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _buildSectionHeader(
                  'Freigeschaltet',
                  '${unlocked.length}',
                  colors,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _AchievementCard(
                    achievement: unlocked[index],
                    animation: _animation,
                    index: index,
                  ),
                  childCount: unlocked.length,
                ),
              ),
            ),
          ],

          // Locked Section
          if (locked.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _buildSectionHeader(
                  'Noch gesperrt',
                  '${locked.length}',
                  colors,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _AchievementCard(
                    achievement: locked[index],
                    animation: _animation,
                    index: unlocked.length + index,
                    isLocked: true,
                  ),
                  childCount: locked.length,
                ),
              ),
            ),
          ],

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildSkeleton(ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ThemedSkeleton(width: double.infinity, height: 160, borderRadius: 24),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ThemedSkeleton(width: 100, height: 80, borderRadius: 16)),
              const SizedBox(width: 12),
              Expanded(child: ThemedSkeleton(width: 100, height: 80, borderRadius: 16)),
              const SizedBox(width: 12),
              Expanded(child: ThemedSkeleton(width: 100, height: 80, borderRadius: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(ThemeColors colors) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + 0.1 * _animation.value,
          child: Opacity(
            opacity: _animation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Level badge
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${_level.level}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _level.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_totalXp XP gesammelt',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Level ${_level.level + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            '${_level.xpToNextLevel} XP',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _level.progressToNextLevel * _animation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(ThemeColors colors, int unlockedCount) {
    final totalCount = _achievements.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.emoji_events,
            value: '$unlockedCount',
            label: 'Erfolge',
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.stars,
            value: '${(progress * 100).toInt()}%',
            label: 'Fortschritt',
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.bolt,
            value: '$_totalXp',
            label: 'XP',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String count, ThemeColors colors) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeService.isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final Animation<double> animation;
  final int index;
  final bool isLocked;

  const _AchievementCard({
    required this.achievement,
    required this.animation,
    required this.index,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    final delay = index * 0.05;
    final adjustedValue = ((animation.value - delay) / (1 - delay)).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + 0.2 * adjustedValue,
          child: Opacity(
            opacity: adjustedValue,
            child: GestureDetector(
              onTap: () => _showDetails(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLocked
                      ? colors.cardSoft
                      : colors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: isLocked
                      ? Border.all(color: colors.cardBorder)
                      : Border.all(
                          color: achievement.rarityColor.withOpacity(0.3),
                          width: 2,
                        ),
                  boxShadow: isLocked
                      ? null
                      : [
                          BoxShadow(
                            color: achievement.rarityColor.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: isLocked
                            ? null
                            : LinearGradient(colors: achievement.rarityGradient),
                        color: isLocked ? colors.shimmer : null,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isLocked
                            ? Icon(
                                Icons.lock,
                                color: colors.textTertiary,
                                size: 24,
                              )
                            : Text(
                                achievement.icon,
                                style: const TextStyle(fontSize: 24),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Title
                    Text(
                      achievement.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isLocked
                            ? colors.textTertiary
                            : colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Rarity badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isLocked
                                ? colors.textTertiary
                                : achievement.rarityColor)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isLocked
                            ? '${achievement.xpReward} XP'
                            : achievement.rarityLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isLocked
                              ? colors.textTertiary
                              : achievement.rarityColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetails(BuildContext context) {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: isLocked
                    ? null
                    : LinearGradient(colors: achievement.rarityGradient),
                color: isLocked ? colors.shimmer : null,
                shape: BoxShape.circle,
                boxShadow: isLocked
                    ? null
                    : [
                        BoxShadow(
                          color: achievement.rarityColor.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
              ),
              child: Center(
                child: isLocked
                    ? Icon(Icons.lock, color: colors.textTertiary, size: 36)
                    : Text(achievement.icon, style: const TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              achievement.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            // Rarity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: achievement.rarityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                achievement.rarityLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: achievement.rarityColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              achievement.description,
              style: TextStyle(
                fontSize: 15,
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // XP Reward
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${achievement.xpReward} XP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            if (achievement.isUnlocked) ...[
              const SizedBox(height: 12),
              Text(
                'Freigeschaltet am ${_formatDate(achievement.unlockedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
