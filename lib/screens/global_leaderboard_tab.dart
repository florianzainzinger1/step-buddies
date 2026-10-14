// lib/screens/global_leaderboard_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/theme_service.dart';

class GlobalLeaderboardTab extends StatefulWidget {
  const GlobalLeaderboardTab({super.key});

  @override
  State<GlobalLeaderboardTab> createState() => _GlobalLeaderboardTabState();
}

class _GlobalLeaderboardTabState extends State<GlobalLeaderboardTab> {
  final _db = FirebaseFirestore.instance;
  final _userId = FirebaseAuth.instance.currentUser?.uid;

  bool _isLoading = true;
  List<_LeaderboardEntry> _topTen = [];
  _LeaderboardEntry? _myEntry;
  int? _myRank;

  // Static cache
  static List<_LeaderboardEntry>? _cachedTopTen;
  static _LeaderboardEntry? _cachedMyEntry;
  static int? _cachedMyRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    // Use cached data immediately
    if (_cachedTopTen != null) {
      setState(() {
        _topTen = _cachedTopTen!;
        _myEntry = _cachedMyEntry;
        _myRank = _cachedMyRank;
        _isLoading = false;
      });
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Get today's steps ordered by steps (descending)
      // Use range query to match how dates are stored
      final stepsSnap = await _db
          .collection('dailySteps')
          .where('date', isGreaterThanOrEqualTo: today)
          .where('date', isLessThan: tomorrow)
          .orderBy('date')
          .orderBy('steps', descending: true)
          .limit(100) // Get top 100 to find user rank too
          .get();

      if (stepsSnap.docs.isEmpty) {
        setState(() {
          _topTen = [];
          _myEntry = null;
          _myRank = null;
          _isLoading = false;
        });
        return;
      }

      // Get all user IDs from steps
      final userIds = stepsSnap.docs
          .map((doc) => doc.data()['userId'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      // Fetch user profiles
      final usersSnap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds.take(10).toList())
          .get();

      // For larger lists, fetch in batches
      Map<String, Map<String, dynamic>> usersMap = {};
      for (final doc in usersSnap.docs) {
        usersMap[doc.id] = doc.data();
      }

      // If more than 10 users, fetch rest
      if (userIds.length > 10) {
        for (int i = 10; i < userIds.length; i += 10) {
          final batch = userIds.skip(i).take(10).toList();
          if (batch.isEmpty) break;
          final batchSnap = await _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          for (final doc in batchSnap.docs) {
            usersMap[doc.id] = doc.data();
          }
        }
      }

      // Build ranked list (only opted-in users)
      final List<_LeaderboardEntry> ranked = [];
      int rank = 0;
      int? myRank;
      _LeaderboardEntry? myEntry;

      for (final doc in stepsSnap.docs) {
        final data = doc.data();
        final odataC = data['userId'] as String?;
        if (odataC == null) continue;

        final userProfile = usersMap[odataC];
        if (userProfile == null) continue;

        // Check if user opted in
        final showOnGlobal = userProfile['showOnGlobalLeaderboard'] ?? true;
        if (!showOnGlobal) continue;

        rank++;
        final entry = _LeaderboardEntry(
          rank: rank,
          userId: odataC,
          username: userProfile['username'] ?? 'Unknown',
          displayName: userProfile['displayName'] ?? '',
          steps: (data['steps'] as num?)?.toInt() ?? 0,
        );

        if (rank <= 10) {
          ranked.add(entry);
        }

        if (odataC == _userId) {
          myRank = rank;
          myEntry = entry;
        }
      }

      // Update cache
      _cachedTopTen = ranked;
      _cachedMyEntry = myEntry;
      _cachedMyRank = myRank;

      if (!mounted) return;
      setState(() {
        _topTen = ranked;
        _myEntry = myEntry;
        _myRank = myRank;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[GlobalLeaderboard] Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading && _cachedTopTen == null
          ? _buildSkeleton()
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: _buildHeader(),
                  ),

                  // Top 10 List
                  _topTen.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final entry = _topTen[index];
                              return _buildLeaderboardItem(entry, isMe: entry.userId == _userId);
                            },
                            childCount: _topTen.length,
                          ),
                        ),

                  // My Rank (if not in top 10)
                  if (_myRank != null && _myRank! > 10 && _myEntry != null)
                    SliverToBoxAdapter(
                      child: _buildMyRankCard(),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSkeleton() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Column(
      children: [
        Container(
          height: 120,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.shimmer,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        ...List.generate(5, (_) => Container(
          height: 70,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: colors.shimmer,
            borderRadius: BorderRadius.circular(16),
          ),
        )),
      ],
    );
  }

  Widget _buildHeader() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Container(
      margin: const EdgeInsets.all(16),
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
          const Icon(Icons.public_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          const Text(
            'Globales Ranking',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Top 10 Läufer heute',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          if (_myRank != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Dein Platz: #$_myRank',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.directions_walk_rounded, size: 48, color: colors.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Noch keine Schritte heute',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Geh ein paar Schritte und erscheine im Ranking!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(_LeaderboardEntry entry, {bool isMe = false}) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;
    final rankWidget = _buildRankBadge(entry.rank);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? colors.primary.withOpacity(0.1) : colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(color: colors.primary, width: 2)
            : Border.all(color: colors.cardBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: themeService.isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          rankWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isMe ? colors.primary : colors.textPrimary,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'DU',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.displayName.isNotEmpty && entry.displayName != entry.username)
                  Text(
                    entry.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatNumber(entry.steps),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isMe ? colors.primary : colors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.directions_walk_rounded, size: 16, color: colors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    if (rank == 1) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade400, Colors.amber.shade600],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Center(
          child: Text('🥇', style: TextStyle(fontSize: 20)),
        ),
      );
    } else if (rank == 2) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade300, Colors.grey.shade500],
          ),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🥈', style: TextStyle(fontSize: 20)),
        ),
      );
    } else if (rank == 3) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade300, Colors.orange.shade600],
          ),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🥉', style: TextStyle(fontSize: 20)),
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.cardSoft,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMyRankCard() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: colors.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Dein Ranking',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: colors.divider)),
            ],
          ),
          const SizedBox(height: 8),
          _buildLeaderboardItem(_myEntry!, isMe: true),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}

class _LeaderboardEntry {
  final int rank;
  final String userId;
  final String username;
  final String displayName;
  final int steps;

  _LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.steps,
  });
}
