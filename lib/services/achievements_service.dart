import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/achievement.dart';

/// Service for managing achievements and progress tracking
class AchievementsService {
  static final AchievementsService instance = AchievementsService._();
  AchievementsService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Cache for user achievements
  Map<String, Achievement> _unlockedAchievements = {};
  int _totalXp = 0;
  bool _initialized = false;

  // Listeners for achievement unlocks
  final List<void Function(Achievement)> _unlockListeners = [];

  void addUnlockListener(void Function(Achievement) listener) {
    _unlockListeners.add(listener);
  }

  void removeUnlockListener(void Function(Achievement) listener) {
    _unlockListeners.remove(listener);
  }

  void _notifyUnlock(Achievement achievement) {
    for (final listener in _unlockListeners) {
      listener(achievement);
    }
  }

  /// Initialize and load user achievements
  Future<void> initialize() async {
    if (_initialized) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Load from Firestore
      final doc = await _db.collection('userAchievements').doc(uid).get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        _totalXp = (data['totalXp'] as num?)?.toInt() ?? 0;

        final unlocked = data['unlocked'] as Map<String, dynamic>? ?? {};
        _unlockedAchievements = {};

        for (final entry in unlocked.entries) {
          final base = AchievementDefinitions.getById(entry.key);
          if (base != null) {
            _unlockedAchievements[entry.key] = Achievement.fromMap(
              entry.value as Map<String, dynamic>,
              base,
            );
          }
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[AchievementsService] Error initializing: $e');
    }
  }

  /// Get user's total XP
  int get totalXp => _totalXp;

  /// Get user's level
  UserLevel get userLevel => UserLevel.fromXp(_totalXp);

  /// Get all achievements with unlock status
  List<Achievement> getAllAchievements() {
    return AchievementDefinitions.all.map((base) {
      return _unlockedAchievements[base.id] ?? base;
    }).toList();
  }

  /// Get only unlocked achievements
  List<Achievement> getUnlockedAchievements() {
    return _unlockedAchievements.values.toList();
  }

  /// Get unlocked achievements for a specific user (for friend profiles)
  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final doc = await _db.collection('userAchievements').doc(userId).get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final unlocked = data['unlocked'] as Map<String, dynamic>? ?? {};

      final achievements = <Achievement>[];
      for (final entry in unlocked.entries) {
        final base = AchievementDefinitions.getById(entry.key);
        if (base != null) {
          achievements.add(Achievement.fromMap(
            entry.value as Map<String, dynamic>,
            base,
          ));
        }
      }

      return achievements;
    } catch (e) {
      debugPrint('[AchievementsService] Error getting user achievements: $e');
      return [];
    }
  }

  /// Get user's XP and level info
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final doc = await _db.collection('userAchievements').doc(userId).get();

      if (!doc.exists) {
        return {'totalXp': 0, 'level': UserLevel.fromXp(0)};
      }

      final data = doc.data() ?? {};
      final xp = (data['totalXp'] as num?)?.toInt() ?? 0;

      return {
        'totalXp': xp,
        'level': UserLevel.fromXp(xp),
        'achievementCount': (data['unlocked'] as Map?)?.length ?? 0,
      };
    } catch (e) {
      return {'totalXp': 0, 'level': UserLevel.fromXp(0)};
    }
  }

  /// Check if an achievement is unlocked
  bool isUnlocked(String achievementId) {
    return _unlockedAchievements.containsKey(achievementId);
  }

  /// Unlock an achievement
  Future<bool> unlock(AchievementType type) async {
    final achievement = AchievementDefinitions.getByType(type);
    if (achievement == null) return false;

    // Already unlocked
    if (_unlockedAchievements.containsKey(achievement.id)) return false;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final now = DateTime.now();
      final unlocked = achievement.copyWith(unlockedAt: now);

      _unlockedAchievements[achievement.id] = unlocked;
      _totalXp += achievement.xpReward;

      // Save to Firestore
      await _db.collection('userAchievements').doc(uid).set({
        'totalXp': _totalXp,
        'unlocked': {
          achievement.id: unlocked.toMap(),
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Notify listeners
      _notifyUnlock(unlocked);

      return true;
    } catch (e) {
      debugPrint('[AchievementsService] Error unlocking achievement: $e');
      return false;
    }
  }

  /// Evaluate all achievements based on current user data
  Future<List<Achievement>> evaluateAndUnlock() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final newlyUnlocked = <Achievement>[];

    try {
      // Gather user stats
      final stats = await _gatherUserStats(uid);

      // Check each achievement type
      for (final check in _achievementChecks) {
        if (!isUnlocked(check.achievementId)) {
          if (check.condition(stats)) {
            final unlocked = await unlock(check.type);
            if (unlocked) {
              final achievement = AchievementDefinitions.getByType(check.type);
              if (achievement != null) {
                newlyUnlocked.add(_unlockedAchievements[achievement.id]!);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AchievementsService] Error evaluating achievements: $e');
    }

    return newlyUnlocked;
  }

  /// Gather all user stats needed for achievement evaluation
  Future<Map<String, dynamic>> _gatherUserStats(String uid) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thirtyDaysAgo = today.subtract(const Duration(days: 30));

    // Get daily steps for the last 30 days
    final stepsSnapshot = await _db
        .collection('dailySteps')
        .where('userId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: thirtyDaysAgo)
        .orderBy('date', descending: true)
        .get();

    final Map<DateTime, int> stepsByDay = {};
    int totalSteps = 0;
    int maxDailySteps = 0;

    for (final doc in stepsSnapshot.docs) {
      final data = doc.data();
      final ts = data['date'] as Timestamp;
      final date = DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
      final steps = (data['steps'] as num?)?.toInt() ?? 0;

      stepsByDay[date] = steps;
      totalSteps += steps;
      if (steps > maxDailySteps) maxDailySteps = steps;
    }

    // Calculate current streak
    int currentStreak = 0;
    for (int i = 0; i <= 30; i++) {
      final d = today.subtract(Duration(days: i));
      if ((stepsByDay[d] ?? 0) > 0) {
        currentStreak++;
      } else {
        break;
      }
    }

    // Get user profile for goal
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final dailyGoal = (userData['dailyStepGoal'] as num?)?.toInt() ?? 10000;

    // Calculate goal completions
    int goalCompletions = 0;
    for (final steps in stepsByDay.values) {
      if (steps >= dailyGoal) goalCompletions++;
    }

    // Get all-time stats
    final allTimeStepsDoc = await _db
        .collection('userStats')
        .doc(uid)
        .get();

    int allTimeSteps = totalSteps;
    if (allTimeStepsDoc.exists) {
      allTimeSteps = (allTimeStepsDoc.data()?['totalSteps'] as num?)?.toInt() ?? totalSteps;
    }

    // Get friend count
    final friendsSnapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .get();
    final friendCount = friendsSnapshot.docs.length;

    // Get challenge stats
    final challengesSnapshot = await _db
        .collection('challenges')
        .where('participantIds', arrayContains: uid)
        .get();

    int challengesJoined = challengesSnapshot.docs.length;
    int challengesWon = 0; // Would need additional logic to track wins

    // Check weekend goal (Saturday and Sunday of current week)
    final weekday = now.weekday;
    final saturday = today.subtract(Duration(days: weekday - 6));
    final sunday = today.subtract(Duration(days: weekday - 7));
    final weekendGoal = (stepsByDay[saturday] ?? 0) >= dailyGoal &&
                        (stepsByDay[sunday] ?? 0) >= dailyGoal;

    // Check for early bird / night owl (would need timestamp data)
    // For now, we'll check if any steps were logged today as a proxy

    return {
      'currentStreak': currentStreak,
      'totalSteps': allTimeSteps,
      'maxDailySteps': maxDailySteps,
      'goalCompletions': goalCompletions,
      'dailyGoal': dailyGoal,
      'friendCount': friendCount,
      'challengesJoined': challengesJoined,
      'challengesWon': challengesWon,
      'weekendGoal': weekendGoal,
      'stepsByDay': stepsByDay,
    };
  }

  /// List of achievement checks
  late final List<_AchievementCheck> _achievementChecks = [
    // Streak achievements
    _AchievementCheck(
      type: AchievementType.streak3Days,
      achievementId: 'streak_3',
      condition: (stats) => (stats['currentStreak'] as int) >= 3,
    ),
    _AchievementCheck(
      type: AchievementType.streak7Days,
      achievementId: 'streak_7',
      condition: (stats) => (stats['currentStreak'] as int) >= 7,
    ),
    _AchievementCheck(
      type: AchievementType.streak14Days,
      achievementId: 'streak_14',
      condition: (stats) => (stats['currentStreak'] as int) >= 14,
    ),
    _AchievementCheck(
      type: AchievementType.streak30Days,
      achievementId: 'streak_30',
      condition: (stats) => (stats['currentStreak'] as int) >= 30,
    ),
    _AchievementCheck(
      type: AchievementType.streak100Days,
      achievementId: 'streak_100',
      condition: (stats) => (stats['currentStreak'] as int) >= 100,
    ),

    // Goal achievements
    _AchievementCheck(
      type: AchievementType.firstGoal,
      achievementId: 'goal_first',
      condition: (stats) => (stats['goalCompletions'] as int) >= 1,
    ),
    _AchievementCheck(
      type: AchievementType.goal10Times,
      achievementId: 'goal_10',
      condition: (stats) => (stats['goalCompletions'] as int) >= 10,
    ),
    _AchievementCheck(
      type: AchievementType.goal50Times,
      achievementId: 'goal_50',
      condition: (stats) => (stats['goalCompletions'] as int) >= 50,
    ),
    _AchievementCheck(
      type: AchievementType.goal100Times,
      achievementId: 'goal_100',
      condition: (stats) => (stats['goalCompletions'] as int) >= 100,
    ),

    // Step milestones
    _AchievementCheck(
      type: AchievementType.steps10k,
      achievementId: 'steps_10k',
      condition: (stats) => (stats['totalSteps'] as int) >= 10000,
    ),
    _AchievementCheck(
      type: AchievementType.steps50k,
      achievementId: 'steps_50k',
      condition: (stats) => (stats['totalSteps'] as int) >= 50000,
    ),
    _AchievementCheck(
      type: AchievementType.steps100k,
      achievementId: 'steps_100k',
      condition: (stats) => (stats['totalSteps'] as int) >= 100000,
    ),
    _AchievementCheck(
      type: AchievementType.steps500k,
      achievementId: 'steps_500k',
      condition: (stats) => (stats['totalSteps'] as int) >= 500000,
    ),
    _AchievementCheck(
      type: AchievementType.steps1m,
      achievementId: 'steps_1m',
      condition: (stats) => (stats['totalSteps'] as int) >= 1000000,
    ),

    // Social achievements
    _AchievementCheck(
      type: AchievementType.firstFriend,
      achievementId: 'friend_first',
      condition: (stats) => (stats['friendCount'] as int) >= 1,
    ),
    _AchievementCheck(
      type: AchievementType.friends5,
      achievementId: 'friends_5',
      condition: (stats) => (stats['friendCount'] as int) >= 5,
    ),
    _AchievementCheck(
      type: AchievementType.friends10,
      achievementId: 'friends_10',
      condition: (stats) => (stats['friendCount'] as int) >= 10,
    ),

    // Challenge achievements
    _AchievementCheck(
      type: AchievementType.firstChallengeJoined,
      achievementId: 'challenge_joined',
      condition: (stats) => (stats['challengesJoined'] as int) >= 1,
    ),
    _AchievementCheck(
      type: AchievementType.firstChallengeWon,
      achievementId: 'challenge_won',
      condition: (stats) => (stats['challengesWon'] as int) >= 1,
    ),
    _AchievementCheck(
      type: AchievementType.challengesWon5,
      achievementId: 'challenges_won_5',
      condition: (stats) => (stats['challengesWon'] as int) >= 5,
    ),
    _AchievementCheck(
      type: AchievementType.challengesWon10,
      achievementId: 'challenges_won_10',
      condition: (stats) => (stats['challengesWon'] as int) >= 10,
    ),

    // Special achievements
    _AchievementCheck(
      type: AchievementType.weekendWarrior,
      achievementId: 'weekend_warrior',
      condition: (stats) => stats['weekendGoal'] == true,
    ),
    _AchievementCheck(
      type: AchievementType.perfectWeek,
      achievementId: 'perfect_week',
      condition: (stats) => (stats['currentStreak'] as int) >= 7,
    ),
    _AchievementCheck(
      type: AchievementType.marathoner,
      achievementId: 'marathoner',
      condition: (stats) => (stats['maxDailySteps'] as int) >= 42195,
    ),
  ];
}

class _AchievementCheck {
  final AchievementType type;
  final String achievementId;
  final bool Function(Map<String, dynamic> stats) condition;

  _AchievementCheck({
    required this.type,
    required this.achievementId,
    required this.condition,
  });
}
