import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:step_buddies/models/challenge.dart';
import 'package:step_buddies/services/challenges_service.dart';
import '../../l10n/app_strings.dart';
import '../../theme/theme_colors.dart';
import '../../theme/theme_service.dart';
import '../../widgets/race_track.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final _service = ChallengesService.instance;
  final _userId = FirebaseAuth.instance.currentUser?.uid;

  // Cache for smooth navigation
  Challenge? _cachedChallenge;
  Map<String, int>? _cachedScores;

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    if (_userId == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: Text('Error', style: TextStyle(color: colors.textPrimary))),
      );
    }

    return StreamBuilder<Challenge>(
      stream: _service.watchChallenge(widget.challengeId),
      builder: (context, snapshot) {
        // Use cached data while loading
        if (snapshot.hasData) {
          _cachedChallenge = snapshot.data;
        }

        final challenge = _cachedChallenge ?? snapshot.data;

        // Only show loading if no cached data
        if (challenge == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: colors.background,
              body: Center(child: CircularProgressIndicator(color: colors.primary)),
            );
          }
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(backgroundColor: colors.cardBackground),
            body: Center(
              child: Text('Challenge nicht gefunden', style: TextStyle(color: colors.textPrimary)),
            ),
          );
        }

        final isAdmin = challenge.adminId == _userId;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: Text(challenge.title),
            backgroundColor: colors.cardBackground,
            elevation: 0,
            foregroundColor: colors.textPrimary,
            actions: [
              if (isAdmin)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.error),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _confirmDelete(context);
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusCard(challenge, colors, themeService.isDarkMode),
                const SizedBox(height: 24),

                // Race Track for active challenges
                if (challenge.isActive || (challenge.isStarted && !challenge.isEnded))
                  FutureBuilder<Map<String, int>>(
                    future: _service.getChallengeScores(challenge),
                    builder: (context, scoreSnap) {
                      if (scoreSnap.hasData) {
                        _cachedScores = scoreSnap.data;
                      }
                      final scores = _cachedScores ?? scoreSnap.data ?? {};

                      if (scores.isEmpty && !scoreSnap.hasData) {
                        return _buildRaceTrackSkeleton(colors);
                      }

                      return RaceTrack(
                        teams: challenge.teams,
                        scores: scores,
                        totalGoal: challenge.durationDays * 10000, // Estimate
                        isActive: challenge.isActive,
                      );
                    },
                  ),

                if (challenge.isActive || (challenge.isStarted && !challenge.isEnded))
                  const SizedBox(height: 24),

                // Score Visualization Header
                Row(
                  children: [
                    Icon(Icons.leaderboard_rounded, color: colors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.leaderboard,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                FutureBuilder<Map<String, int>>(
                  future: _service.getChallengeScores(challenge),
                  builder: (context, scoreSnap) {
                    // Use cached scores if available
                    if (scoreSnap.hasData) {
                      _cachedScores = scoreSnap.data;
                    }
                    final scores = _cachedScores ?? scoreSnap.data ?? {};
                    final isLoading = !scoreSnap.hasData && _cachedScores == null;

                    // Sort Teams by Score
                    final sortedTeams = List<ChallengeTeam>.from(challenge.teams);
                    if (!isLoading && scores.isNotEmpty) {
                      sortedTeams.sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));
                    }

                    return Column(
                      children: sortedTeams.asMap().entries.map((entry) {
                        final index = entry.key;
                        final team = entry.value;
                        final score = scores[team.id] ?? 0;
                        final isLeader = !isLoading && sortedTeams.isNotEmpty && sortedTeams.first.id == team.id && score > 0;

                        return _buildCoolTeamCard(team, score, isLeader, index + 1, colors, themeService.isDarkMode, isLoading: isLoading);
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.people_rounded, color: colors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.challengeDetails,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...challenge.teams.map((team) => _buildMemberDetails(team, colors, themeService.isDarkMode)),

                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRaceTrackSkeleton(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: colors.shimmer,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: colors.shimmer,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Challenge challenge, ThemeColors colors, bool isDarkMode) {
    final now = DateTime.now();
    String statusText;
    Color statusColor;
    String timeText;
    IconData statusIcon;

    if (challenge.isActive) {
      statusText = AppStrings.activeChallenges;
      statusColor = colors.success;
      statusIcon = Icons.directions_run_rounded;
      final daysLeft = challenge.endDate.difference(now).inDays + 1;
      timeText = AppStrings.daysLeft(daysLeft);
    } else if (challenge.isEnded) {
      statusText = AppStrings.completedChallenges;
      statusColor = colors.textTertiary;
      statusIcon = Icons.flag_rounded;
      timeText = '${AppStrings.challengeEndedAt} ${DateFormat('dd.MM.yyyy').format(challenge.endDate)}';
    } else {
      statusText = AppStrings.pendingChallenges;
      statusColor = colors.warning;
      statusIcon = Icons.schedule_rounded;
      timeText = '${AppStrings.challengeStart} ${DateFormat('dd.MM.yyyy').format(challenge.startDate)}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    if (challenge.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.success.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timeText,
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCoolTeamCard(ChallengeTeam team, int score, bool isLeader, int rank, ThemeColors colors, bool isDarkMode, {bool isLoading = false}) {
    final teamColors = [colors.primary, colors.secondary, colors.accent, colors.success];
    final teamColor = teamColors[(rank - 1) % teamColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          if (isLeader)
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
        border: isLeader
            ? Border.all(color: Colors.amber, width: 2)
            : Border.all(color: colors.cardBorder.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isLeader
                  ? LinearGradient(colors: [Colors.amber.shade400, Colors.amber.shade600])
                  : null,
              color: isLeader ? null : colors.cardSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isLeader
                  ? const Text('👑', style: TextStyle(fontSize: 20))
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colors.textPrimary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      team.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isLeader) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Führt',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                isLoading
                    ? Container(
                        height: 14,
                        width: 100,
                        decoration: BoxDecoration(
                          color: colors.shimmer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : Row(
                        children: [
                          Icon(Icons.directions_walk_rounded, size: 14, color: teamColor),
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.challengeSteps(score),
                            style: TextStyle(fontSize: 14, color: colors.textSecondary),
                          ),
                        ],
                      ),
              ],
            ),
          ),
          // Score highlight
          if (!isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: teamColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _formatNumber(score),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: teamColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  Widget _buildMemberDetails(ChallengeTeam team, ThemeColors colors, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: colors.primary.withOpacity(0.1),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            team.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.group_rounded, size: 20, color: colors.primary),
          ),
          trailing: Icon(Icons.expand_more_rounded, color: colors.textTertiary),
          iconColor: colors.textTertiary,
          children: team.memberIds.map((memberId) => ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.cardSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_rounded, size: 16, color: colors.textTertiary),
            ),
            title: FutureBuilder<String>(
              future: _fetchUserName(memberId),
              builder: (context, snap) => Text(
                snap.data ?? '...',
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  // Quick helper, besser in Service
  Future<String> _fetchUserName(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data();
      if (data == null) return 'Unbekannt';
      return data['username'] ?? data['displayName'] ?? 'Unbekannt';
    } catch (e) {
      return 'Fehler';
    }
  }

  void _confirmDelete(BuildContext context) async {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline_rounded, color: colors.error, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Löschen?',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Willst du diese Challenge wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abbrechen', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteChallenge(widget.challengeId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
