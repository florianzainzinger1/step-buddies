// lib/screens/stats_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';
import '../theme/theme_service.dart';
import '../widgets/streak_fire.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _error;

  // Stats
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalSteps = 0;
  int _averageSteps = 0;
  int _bestDay = 0;
  DateTime? _bestDayDate;
  List<_DayStat> _last7Days = [];
  
  // Animation
  late AnimationController _animController;
  late Animation<double> _animation;

  // Static cache
  static List<_DayStat>? _cachedStats;
  static int? _cachedStreak;
  static int? _cachedTotal;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _loadStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    // Use cached data immediately if available
    if (_cachedStats != null) {
      setState(() {
        _last7Days = _cachedStats!;
        _currentStreak = _cachedStreak ?? 0;
        _totalSteps = _cachedTotal ?? 0;
        _isLoading = false;
      });
      _animController.forward();
    }
    
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('Kein eingeloggter User');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(const Duration(days: 29)); // Last 30 days

      final snapshot = await _db
          .collection('dailySteps')
          .where('userId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThanOrEqualTo: today)
          .orderBy('date')
          .get();

      final Map<DateTime, int> byDay = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ts = data['date'] as Timestamp;
        final dt = ts.toDate();
        final day = DateTime(dt.year, dt.month, dt.day);
        final steps = (data['steps'] as num?)?.toInt() ?? 0;
        byDay[day] = steps;
      }

      // Last 7 days for bar chart
      final last7 = <_DayStat>[];
      final weekStart = today.subtract(const Duration(days: 6));
      for (int i = 0; i < 7; i++) {
        final d = weekStart.add(Duration(days: i));
        last7.add(_DayStat(date: d, steps: byDay[d] ?? 0));
      }

      // Calculate stats
      int streak = 0;
      int longestStreak = 0;
      int total = 0;
      int best = 0;
      DateTime? bestDate;
      
      // Current streak (from today backwards)
      for (int i = 0; i <= 29; i++) {
        final d = today.subtract(Duration(days: i));
        if ((byDay[d] ?? 0) > 0) {
          streak++;
        } else {
          break;
        }
      }
      
      // Longest streak and totals
      int tempStreak = 0;
      for (int i = 0; i <= 29; i++) {
        final d = start.add(Duration(days: i));
        final steps = byDay[d] ?? 0;
        total += steps;
        
        if (steps > best) {
          best = steps;
          bestDate = d;
        }
        
        if (steps > 0) {
          tempStreak++;
          if (tempStreak > longestStreak) longestStreak = tempStreak;
        } else {
          tempStreak = 0;
        }
      }
      
      final daysWithData = byDay.values.where((v) => v > 0).length;
      final avg = daysWithData > 0 ? (total / daysWithData).round() : 0;

      // Update cache
      _cachedStats = last7;
      _cachedStreak = streak;
      _cachedTotal = total;

      if (!mounted) return;
      setState(() {
        _last7Days = last7;
        _currentStreak = streak;
        _longestStreak = longestStreak;
        _totalSteps = total;
        _averageSteps = avg;
        _bestDay = best;
        _bestDayDate = bestDate;
        _isLoading = false;
      });
      _animController.forward(from: 0);
    } catch (e, st) {
      debugPrint('Fehler beim Laden der Statistiken: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _error = 'Statistiken konnten nicht geladen werden.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _cachedStats == null) {
      return _buildSkeletonLoading();
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 16),
            ],

            // Hero Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildHeroStats(),
            ),
            
            const SizedBox(height: 20),

            // Weekly Progress Chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildWeeklyChart(),
            ),

            const SizedBox(height: 20),

            // Achievement Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildAchievementCards(),
            ),

            const SizedBox(height: 20),

            // Summary Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildSummaryCard(),
            ),
            
            const SizedBox(height: 80), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // Hero skeleton
          Row(
            children: List.generate(3, (_) => Expanded(
              child: Container(
                height: 100,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: colors.shimmer,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            )),
          ),
          const SizedBox(height: 20),
          // Chart skeleton
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: colors.shimmer,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    return Row(
      children: [
        // Streak with animated fire
        Expanded(
          child: _buildStreakCard(),
        ),
        const SizedBox(width: 8),
        // Total Steps (last 30 days)
        Expanded(
          child: _buildHeroCard(
            icon: Icons.directions_walk,
            value: _formatNumber((_totalSteps * _animation.value).round()),
            label: '30 Tage',
            gradient: [AppColors.purple.withOpacity(0.7), AppColors.purple],
          ),
        ),
        const SizedBox(width: 8),
        // Average
        Expanded(
          child: _buildHeroCard(
            icon: Icons.show_chart,
            value: _formatNumber((_averageSteps * _animation.value).round()),
            label: 'Ø Tag',
            gradient: [Colors.teal.shade300, Colors.teal.shade600],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade300, Colors.deepOrange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.shade400.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 24,
            child: StreakFire(
              streakDays: _currentStreak,
              size: 20,
              animate: _currentStreak > 0,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${(_currentStreak * _animation.value).round()}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            'Serie',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required IconData icon,
    required String value,
    required String label,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

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
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Diese Woche',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_last7Days.fold<int>(0, (sum, d) => sum + d.steps)} Schritte',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _buildAnimatedBars(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAnimatedBars() {
    if (_last7Days.isEmpty) return [];

    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    final maxSteps = _last7Days
        .map((e) => e.steps)
        .fold<int>(1, (max, v) => v > max ? v : max);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _last7Days.map((day) {
      final ratio = day.steps / maxSteps;
      final barHeight = 20 + 100 * ratio * _animation.value;
      final weekday = _weekdayLabel(day.date);
      final isToday = day.date == today;

      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showDayDetails(day, colors);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Step count on top (always show space to keep alignment)
                SizedBox(
                  height: 14,
                  child: day.steps > 0
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatNumber(day.steps),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isToday ? colors.primary : colors.textSecondary,
                          ),
                        ),
                      )
                    : null,
                ),
                const SizedBox(height: 4),
                // Bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: barHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: isToday
                          ? [colors.primary, colors.secondary]
                          : [colors.shimmer, colors.cardBorder],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: isToday ? [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ] : null,
                  ),
                ),
                const SizedBox(height: 8),
                // Weekday label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isToday ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    weekday,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday ? Colors.white : colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _showDayDetails(_DayStat day, ThemeColors colors) {
    final dateStr = DateFormat('EEEE, d. MMMM', 'de_DE').format(day.date);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary.withOpacity(0.1), colors.secondary.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_walk_rounded, color: colors.primary, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    '${day.steps}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Schritte',
                    style: TextStyle(
                      fontSize: 16,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCards() {
    return Row(
      children: [
        // Best Day
        Expanded(
          child: _buildInfoCard(
            icon: Icons.emoji_events,
            iconBgColor: Colors.amber.shade100,
            iconColor: Colors.amber.shade700,
            title: 'Bester Tag',
            value: _formatNumber(_bestDay),
            subtitle: _bestDayDate != null 
                ? DateFormat('dd.MM').format(_bestDayDate!)
                : '-',
          ),
        ),
        const SizedBox(width: 12),
        // Longest Streak
        Expanded(
          child: _buildInfoCard(
            icon: Icons.trending_up,
            iconBgColor: Colors.green.shade100,
            iconColor: Colors.green.shade700,
            title: 'Längste Serie',
            value: '$_longestStreak',
            subtitle: 'Tage',
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: themeService.isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor.withOpacity(themeService.isDarkMode ? 0.2 : 1.0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    final weeklyTotal = _last7Days.fold<int>(0, (sum, d) => sum + d.steps);
    final weeklyAvg = _last7Days.isEmpty ? 0 : (weeklyTotal / 7).round();
    final activeDays = _last7Days.where((d) => d.steps > 0).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withOpacity(0.05),
            colors.primary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: colors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Wochenzusammenfassung',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryItem('Aktive Tage', '$activeDays/7'),
              _buildSummaryItem('Ø pro Tag', _formatNumber(weeklyAvg)),
              _buildSummaryItem('Gesamt', _formatNumber(weeklyTotal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 2),
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

  String _weekdayLabel(DateTime date) {
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final index = (date.weekday - 1).clamp(0, 6);
    return labels[index];
  }
  
  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}

class _DayStat {
  final DateTime date;
  final int steps;

  _DayStat({required this.date, required this.steps});
}
