import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../l10n/app_strings.dart';
import '../../models/challenge.dart';
import '../../services/challenges_service.dart';
import '../../theme/theme_service.dart';
import 'create_challenge_screen.dart';
import 'challenge_detail_screen.dart';

class ChallengesListScreen extends StatefulWidget {
  const ChallengesListScreen({super.key});

  @override
  State<ChallengesListScreen> createState() => _ChallengesListScreenState();
}

class _ChallengesListScreenState extends State<ChallengesListScreen> with AutomaticKeepAliveClientMixin {
  final _service = ChallengesService.instance;
  final _userId = FirebaseAuth.instance.currentUser?.uid;
  
  // STATIC caches to persist across rebuilds and navigation
  static List<Challenge>? _cachedChallenges;
  static final Map<String, Map<String, int>> _scoresCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    if (_userId == null) {
      return Center(child: Text(AppStrings.noLoggedInUser, style: TextStyle(color: colors.textPrimary)));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Challenge>>(
        stream: _service.watchMyChallenges(_userId),
        builder: (context, snapshot) {
          // Use cached data if available while new data loads
          if (snapshot.hasData) {
            _cachedChallenges = snapshot.data;
          }

          final challenges = _cachedChallenges ?? snapshot.data ?? [];

          // Only show loading on first load (no cache)
          if (challenges.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colors.primary));
          }
          if (snapshot.hasError && challenges.isEmpty) {
            return Center(child: Text('Fehler: ${snapshot.error}', style: TextStyle(color: colors.error)));
          }

          if (challenges.isEmpty) {
            return _buildEmptyState();
          }

          // Sortieren und Filtern basierend auf Datum & Zeit
          final now = DateTime.now();

          final active = <Challenge>[];
          final pending = <Challenge>[];
          final completed = <Challenge>[];

          for (var c in challenges) {
            if (c.isEnded) {
              completed.add(c);
            } else if (c.isStarted || c.startDate.day == now.day && c.startDate.month == now.month && c.startDate.year == now.year) {
              active.add(c);
            } else {
              pending.add(c);
            }
          }

          // Sortierung
          active.sort((a, b) => a.endDate.compareTo(b.endDate)); // Bald endende zuerst
          pending.sort((a, b) => a.startDate.compareTo(b.startDate)); // Bald startende zuerst
          completed.sort((a, b) => b.endDate.compareTo(a.endDate)); // Kürzlich beendete zuerst

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (active.isNotEmpty) ...[
                _buildHeader(AppStrings.activeChallenges),
                _buildList(active),
              ],
              if (pending.isNotEmpty) ...[
                _buildHeader(AppStrings.pendingChallenges),
                _buildList(pending),
              ],
              if (completed.isNotEmpty) ...[
                _buildHeader(AppStrings.completedChallenges),
                _buildList(completed),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)), // Platz für FAB
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateChallengeScreen()),
          );
        },
        label: const Text(AppStrings.createChallenge),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emoji_events_rounded, size: 64, color: colors.primary.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.noChallenges,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Erstelle eine Challenge und tritt gegen deine Freunde an!',
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateChallengeScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(AppStrings.startChallenge),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Challenge> challenges) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final challenge = challenges[index];
          // Progress berechnen
          final now = DateTime.now();
          final totalMillis = challenge.endDate.difference(challenge.startDate).inMilliseconds;
          final elapsedMillis = now.difference(challenge.startDate).inMilliseconds;

          double progress = 0.0;
          if (totalMillis > 0) {
             progress = (elapsedMillis / totalMillis).clamp(0.0, 1.0);
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: themeService.isDarkMode
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChallengeDetailScreen(challengeId: challenge.id),
                    ),
                  );
                },
                child: Column(
                  children: [
                    // Progress Bar oben
                    if (!challenge.isEnded && progress > 0)
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary, colors.secondary],
                            stops: [0, progress],
                          ),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                        ),
                      ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title Row
                          Row(
                            children: [
                              Expanded(child: Text(
                                challenge.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: colors.textPrimary,
                                ),
                              )),
                              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Meta Info
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 14, color: colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${challenge.durationDays} Tage',
                                style: TextStyle(color: colors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.group_rounded, size: 14, color: colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${challenge.teams.length} Teams',
                                style: TextStyle(color: colors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),

                          // Mini Bar Chart Preview
                          if (!challenge.isEnded && challenge.teams.length <= 4) ...[
                            const SizedBox(height: 16),
                            FutureBuilder<Map<String, int>>(
                             future: ChallengesService.instance.getChallengeScores(challenge),
                             builder: (context, snapshot) {
                               // Use cached scores if available
                               if (snapshot.hasData) {
                                 _scoresCache[challenge.id] = snapshot.data!;
                               }
                               final scores = _scoresCache[challenge.id] ?? snapshot.data ?? {};
                               final maxScore = scores.values.isEmpty ? 0 : scores.values.reduce(max);
                               final isLoading = !snapshot.hasData && !_scoresCache.containsKey(challenge.id);

                               return Column(
                                 children: challenge.teams.asMap().entries.map((entry) {
                                   final idx = entry.key;
                                   final team = entry.value;
                                   final score = scores[team.id] ?? 0;
                                   final double ratio = isLoading ? 0.5 : (maxScore > 0 ? (score / maxScore) : 0);

                                   // Team colors
                                   final teamColors = [
                                     colors.primary,
                                     colors.secondary,
                                     colors.accent,
                                     colors.success,
                                   ];
                                   final teamColor = teamColors[idx % teamColors.length];

                                   return Padding(
                                     padding: const EdgeInsets.only(bottom: 8),
                                     child: Row(
                                       children: [
                                         // Bar (skeleton or real)
                                         Expanded(
                                           flex: 2,
                                           child: Align(
                                             alignment: Alignment.centerLeft,
                                             child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 500),
                                                curve: Curves.easeOutCubic,
                                                height: 12,
                                                width: isLoading ? 80 : (120 * ratio + 20),
                                                decoration: BoxDecoration(
                                                  color: isLoading
                                                    ? colors.shimmer
                                                    : teamColor.withOpacity(0.3 + (ratio * 0.7)),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                             ),
                                           ),
                                         ),
                                         const SizedBox(width: 12),
                                         // Team Name & Score
                                         Expanded(
                                           flex: 3,
                                           child: Row(
                                             children: [
                                               Expanded(
                                                 child: Text(
                                                   team.name,
                                                   style: TextStyle(
                                                     fontWeight: FontWeight.bold,
                                                     fontSize: 12,
                                                     color: colors.textPrimary,
                                                   ),
                                                   overflow: TextOverflow.ellipsis,
                                                 ),
                                               ),
                                               const SizedBox(width: 8),
                                               Text(
                                                 isLoading ? '...' : '$score',
                                                 style: TextStyle(
                                                   fontSize: 12,
                                                   color: colors.textSecondary,
                                                 ),
                                               )
                                             ],
                                           ),
                                         ),
                                       ],
                                     ),
                                   );
                                 }).toList(),
                               );
                             },
                          ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: challenges.length,
      ),
    );
  }
}
