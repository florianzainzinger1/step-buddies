// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/theme_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/progress_ring.dart';
import '../widgets/leaderboard.dart';
import '../widgets/animated_sky_background.dart';
import '../widgets/greeting_header.dart';
import '../widgets/milestone_celebration.dart';
import '../services/steps_service.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'stats_tab.dart';
import 'rewards_tab.dart';
import '../services/groups_service.dart';
import 'friends_search_screen.dart';
import '../services/friends_service.dart';
import 'group_detail_screen.dart';
import 'user_compare_screen.dart';
import 'challenges/challenges_list_screen.dart';
import '../services/background_sync_service.dart';
import 'global_leaderboard_tab.dart';

enum TodayMode { friends, groups }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _stepsService = StepsService();
  final _firestore = FirestoreService.instance;
  final _auth = FirebaseAuth.instance;
  final _groupsService = GroupsService.instance;
  final _friendsService = FriendsService.instance;
  final _celebrationKey = GlobalKey<CelebrationOverlayState>();

  late final String _userId;

  int _steps = 0;
  int _goal = 10000;
  bool _isLoading = true;
  String? _stepError; // Fehlermeldung bei Permission/Sensor-Problemen
  String? _displayName; // User's display name for greeting

  TodayMode _todayMode = TodayMode.friends;
  int _selectedTabIndex = 0; // 0 = Home, 1 = Challenges, 2 = Global (if enabled), 3 = Stats
  bool _showGlobalLeaderboard = false; // Loaded from user profile
  
  // Static variable to persist tab state across re-initializations (simple fix for navigation issue)
  // Ideally this would be in a Provider/Riverpod, but for explicit Stateful widget:
  static int _persistedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Restore last tab
    _selectedTabIndex = _persistedTabIndex;

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception(
        'Kein Firebase-User vorhanden. Wurde Auth in main() initialisiert?',
      );
    }
    _userId = uid;

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Initialize Background Sync for step tracking
    BackgroundSyncService.instance.initialize(_userId);
    
    await _loadUserGoal();
    await _loadStepsOnOpen();
  }

  Future<void> _loadUserGoal() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      final data = doc.data();
      final goal = data?['dailyStepGoal'];
      final showGlobalLb = data?['showOnGlobalLeaderboard'] ?? false;
      final displayName = data?['displayName'] as String?;
      final username = data?['username'] as String?;

      if (!mounted) return;

      setState(() {
        if (goal is num) {
          _goal = goal.toInt().clamp(0, 15000);
        } else {
          // falls Feld noch gar nicht existiert → "kein Ziel"
          _goal = 0;
        }
        _showGlobalLeaderboard = showGlobalLb == true;
        _displayName = displayName ?? username;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Fehler beim Laden des Schrittziels: $e');
    }
  }

  Future<void> _loadStepsOnOpen() async {
    try {
      // ignore: avoid_print
      print('[_loadStepsOnOpen] gestartet');

      final result = await _stepsService.getTodayStepsWithStatus();
      // ignore: avoid_print
      print('[_loadStepsOnOpen] Ergebnis: ${result.status}, steps=${result.steps}');

      if (result.isSuccess) {
        await _firestore.saveDailySteps(userId: _userId, steps: result.steps);
        // ignore: avoid_print
        print('[_loadStepsOnOpen] eigene Schritte in Firestore gespeichert');
      }

      if (!mounted) return;
      setState(() {
        _steps = result.steps;
        _stepError = result.isSuccess ? null : result.errorMessage;
        _isLoading = false;
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('[_loadStepsOnOpen] FEHLER: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      setState(() {
        _steps = 0;
        _stepError = AppStrings.errorLoadingSteps;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshSteps() async {
    try {
      final result = await _stepsService.getTodayStepsWithStatus();
      
      if (result.isSuccess) {
        await _firestore.saveDailySteps(userId: _userId, steps: result.steps);
      }

      if (!mounted) return;
      setState(() {
        _steps = result.steps;
        _stepError = result.isSuccess ? null : result.errorMessage;
      });
    } catch (e) {
      // ignore: avoid_print
      print('[_refreshSteps] Fehler: $e');
    }
  }
  // Static cache for leaderboard to prevent reload
  static List<Map<String, dynamic>>? _cachedLeaderboardData;

  Widget _buildFriendsLeaderboard(List<String> friendIds) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestore.watchTodaySteps(),
      builder: (context, snapshot) {
        // Use cached data if available
        if (snapshot.hasData) {
          _cachedLeaderboardData = snapshot.data;
        }
        
        final data = _cachedLeaderboardData ?? snapshot.data ?? [];
        final isLoading = !snapshot.hasData && _cachedLeaderboardData == null;
        
        // Show skeleton only on first load (no cache)
        if (isLoading) {
          return _buildLeaderboardSkeleton(3);
        }

        if (snapshot.hasError && data.isEmpty) {
          return Text(
            '${AppStrings.error}: ${AppStrings.leaderboard}',
            style: const TextStyle(color: Colors.red),
          );
        }

        if (data.isEmpty) {
          return const Text('Noch keine ${AppStrings.steps} für heute 😴');
        }

        // 👇 Nur Freunde + du selbst
        final allowedIds = <String>{_userId, ...friendIds};

        final filtered = data.where((doc) {
          final userId = doc['userId'] as String?;
          return userId != null && allowedIds.contains(userId);
        }).toList();

        if (filtered.isEmpty) {
          return const Text(
            'Noch keine Schritte von dir oder deinen Freunden heute 😴',
          );
        }

        final userIds = filtered
            .map((doc) => doc['userId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();

        return FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: _firestore.getUsersByIds(userIds),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return const Text(
                'Fehler beim Laden der Benutzerdaten',
                style: TextStyle(color: Colors.red),
              );
            }

            final userMap = userSnapshot.data ?? {};

            final List<LeaderboardEntry> entries = filtered.map((doc) {
              final userId = doc['userId'] as String;
              final steps = (doc['steps'] as num).toInt();

              final profile = userMap[userId];
              final username = profile?['username'] as String?;
              final displayName = profile?['displayName'] as String?;

              String nameToShow;
              if (userId == _userId) {
                nameToShow = 'Du';
              } else if (username != null && username.isNotEmpty) {
                nameToShow = username;
              } else if (displayName != null && displayName.isNotEmpty) {
                nameToShow = displayName;
              } else {
                nameToShow = 'Unbekannt';
              }

              return LeaderboardEntry(
                userId: userId,
                name: nameToShow,
                steps: steps,
                isMe: userId == _userId,
              );
            }).toList();

            return LeaderboardSection(
              entries: entries,
              onEntryTap: (entry) {
                // Auf sich selbst tippen macht nix
                if (entry.userId == _userId) return;

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        UserCompareScreen(
                          otherUserId: entry.userId,
                          otherName: entry.name,
                        ),
                  ),
                );
              } 
            );
          },
        );
      },
    );
  }

  // Skeleton placeholder for leaderboard while loading
  Widget _buildLeaderboardSkeleton(int count) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Column(
      children: List.generate(count, (index) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.cardSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Rank circle skeleton
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.shimmer,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Name skeleton
            Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: colors.shimmer,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            // Steps skeleton
            Container(
              width: 60,
              height: 14,
              decoration: BoxDecoration(
                color: colors.shimmer,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      )),
    );
  }

  // --- Gruppenliste (Heute-Tab → Modus "Gruppen") ---
  Widget _buildGroupsSection() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Obere Button-Leiste: Gruppe erstellen / Mit Code beitreten
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _showCreateGroupDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text(
                    'Gruppe erstellen',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _showJoinGroupDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.group_outlined),
                  label: const Text(
                    'Gruppe beitreten',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Darunter: eigentliche Gruppenliste
        StreamBuilder<List<Group>>(
          stream: _groupsService.watchGroupsForUser(_userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator(color: colors.primary)),
              );
            }

            if (snapshot.hasError) {
              return Text(
                'Fehler beim Laden der Gruppen',
                style: TextStyle(color: colors.error),
              );
            }

            final groups = snapshot.data ?? [];

            if (groups.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: themeService.isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deine Gruppen',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Du bist noch in keiner Gruppe.\n'
                      'Erstelle eine Gruppe oder tritt mit einem Code bei.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: themeService.isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deine Gruppen',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final g = groups[index];
                      final memberCount = g.memberIds.length;
                      final isOwner = g.ownerId == _userId;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GroupDetailScreen(
                                group: g,
                                currentUserId: _userId,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colors.cardSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$memberCount Mitglieder',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    if (isOwner && g.joinCode.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Code: ${g.joinCode}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // --- Inhalte der drei Tabs ---

  Widget _buildHomeTab() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return RefreshIndicator(
      onRefresh: _refreshSteps,
      color: colors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Personalized greeting
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GreetingHeader(userName: _displayName),
              ),
              Center(
                child: _isLoading
                    ? SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator(color: colors.primary)),
                      )
                    : (_goal <= 0
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _steps.toString(),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary, // Fixed: use theme color
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'heutige Schritte',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.textSecondary, // Fixed: use theme color
                                  ),
                                ),
                              ],
                            )
                          : ProgressRing(
                              steps: _steps,
                              goal: _goal,
                              onMilestoneReached: (milestone) {
                                _celebrationKey.currentState?.celebrate(
                                  milestone: milestone,
                                );
                              },
                            )),
              ),
              
              // Fehlermeldung bei Permission/Sensor-Problemen
              if (_stepError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, 
                           color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _stepError!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Toggle: Freunde / Gruppen
              _buildTodayToggle(),
              const SizedBox(height: 16),

              if (_todayMode == TodayMode.friends) ...[
                StreamBuilder<List<String>>(
                  stream: _friendsService.watchFriendIds(_userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 80,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Text(
                        'Fehler beim Laden deiner Freunde',
                        style: TextStyle(color: Colors.red),
                      );
                    }

                    final friendIds = snapshot.data ?? [];

                    return _buildFriendsLeaderboard(friendIds);
                  },
                ),
              ] else ...[
                _buildGroupsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CelebrationOverlay(
        key: _celebrationKey,
        child: AnimatedSkyBackground(
          child: SafeArea(
          child: Column(
            children: [
              // 🔝 Obere Leiste: Logo + App-Name + Profil + Suche + Glocke
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: themeService.isDarkMode
                        ? colors.cardBackground.withOpacity(0.6)
                        : colors.textPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      // Logo
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [colors.primary, colors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_walk_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),

                      const Spacer(),

                      // Profil-Avatar (öffnet Menü mit Settings / Logout)
                      GestureDetector(
                        onTap: _openProfileMenu,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: colors.primary.withOpacity(0.2),
                          child: Icon(
                            Icons.person_rounded,
                            color: colors.primary,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      IconButton(
                        icon: Icon(
                          Icons.search_rounded,
                          color: colors.textSecondary,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FriendsSearchScreen(),
                            ),
                          );
                        },
                      ),

                      IconButton(
                        icon: Icon(
                          Icons.notifications_none_rounded,
                          color: colors.textSecondary,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Benachrichtigungen kommen später 🔔',
                              ),
                              backgroundColor: colors.cardBackground,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Inhalt des aktuell ausgewählten Tabs (IndexedStack preserves state)
              Expanded(
                child: IndexedStack(
                  index: _selectedTabIndex,
                  children: [
                    _buildHomeTab(),
                    const ChallengesListScreen(),
                    const RewardsTab(),
                    if (_showGlobalLeaderboard) const GlobalLeaderboardTab(),
                    const StatsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),

      // 🚀 Neue Bottom-Navigation mit verbessertem Design
      bottomNavigationBar: _CustomBottomNav(
        selectedIndex: _selectedTabIndex,
        onTap: _onTabTapped,
        showGlobalLeaderboard: _showGlobalLeaderboard,
      ),
    );
  }

  Widget _buildTodayToggle() {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: themeService.isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _TodayToggleButton(
            label: 'Freunde',
            isSelected: _todayMode == TodayMode.friends,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _todayMode = TodayMode.friends;
              });
            },
          ),
          _TodayToggleButton(
            label: 'Gruppen',
            isSelected: _todayMode == TodayMode.groups,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _todayMode = TodayMode.groups;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openProfileMenu() async {
    // Direkt zum Profil-Screen navigieren (wie Search-Tab)
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    
    // Reload user preferences (goal and global leaderboard setting) when returning
    if (mounted) {
      await _loadUserGoal();
      // If returned with specific goal, use it
      if (result is int) {
        setState(() {
          _goal = result;
        });
      }
    }
  }

  Future<void> _showCreateGroupDialog() async {
    final controller = TextEditingController();

    // 1) Namen im Dialog abfragen
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Neue Gruppe erstellen'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Gruppenname'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.of(ctx).pop(value);
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    );

    // Wichtig: KEIN controller.dispose() hier -> sonst der rote Fehler

    if (!mounted || name == null || name.trim().isEmpty) return;

    try {
      // 2) Gruppe in Firestore anlegen
      final group = await _groupsService.createGroup(
        name: name.trim(),
        ownerId: _userId,
      );

      if (!mounted) return;

      // 3) Optional Info-Dialog mit Beitrittscode anzeigen
      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Gruppe erstellt'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('„${group.name}“ wurde erstellt.'),
                const SizedBox(height: 8),
                const Text('Beitrittscode:'),
                const SizedBox(height: 4),
                SelectableText(
                  group.joinCode,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Teile diesen Code mit deinen Freunden, damit sie beitreten können.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Weiter'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      // 4) Sicherstellen, dass der "Heute"-Modus auf Gruppen steht
      setState(() {
        _todayMode = TodayMode.groups;
      });

      // 5) Direkt in die Gruppendetail-Ansicht navigieren
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(
            group: group,
            currentUserId: _userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Erstellen der Gruppe: $e')),
      );
    }
  }

  Future<void> _showJoinGroupDialog() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Gruppe beitreten'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Beitrittscode',
              hintText: 'z.B. A9F3KZ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.of(ctx).pop(value);
              },
              child: const Text('Beitreten'),
            ),
          ],
        );
      },
    );

    if (!mounted || code == null || code.trim().isEmpty) return;

    try {
      final group = await _groupsService.joinGroupByCode(
        code: code,
        userId: _userId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gruppe „${group.name}“ beigetreten ✅')),
      );
      // StreamBuilder aktualisiert sich automatisch
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Beitreten fehlgeschlagen: $e')));
    }
  }


  void _onTabTapped(int index) {
    setState(() {
      _selectedTabIndex = index;
      _persistedTabIndex = index;
    });
  }
}

class _TodayToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TodayToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: isSelected ? colors.primary : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom bottom navigation bar with improved design and indicator
class _CustomBottomNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool showGlobalLeaderboard;

  const _CustomBottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.showGlobalLeaderboard,
  });

  @override
  State<_CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<_CustomBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _indicatorController;

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(_CustomBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _indicatorController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    // Build tab items dynamically based on showGlobalLeaderboard
    final items = <_NavItem>[
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
      _NavItem(Icons.bolt_outlined, Icons.bolt_rounded, 'Challenges'),
      _NavItem(Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Rewards'),
      if (widget.showGlobalLeaderboard)
        _NavItem(Icons.public_outlined, Icons.public_rounded, 'Global'),
      _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Stats'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: themeService.isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = widget.selectedIndex == index;

              return Expanded(
                child: _NavButton(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onTap(index);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItem(this.icon, this.activeIcon, this.label);
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? colors.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with animated indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          widget.isSelected ? widget.activeIcon : widget.icon,
                          key: ValueKey(widget.isSelected),
                          size: 24,
                          color: widget.isSelected
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Label
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isSelected
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                    child: Text(widget.label),
                  ),
                  // Indicator dot
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: widget.isSelected ? 20 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: widget.isSelected
                          ? LinearGradient(
                              colors: [colors.primary, colors.secondary],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(2),
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
}
