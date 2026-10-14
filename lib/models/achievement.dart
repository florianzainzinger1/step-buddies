import 'package:flutter/material.dart';

/// Achievement types that can be unlocked
enum AchievementType {
  // Streak-based
  streak3Days,
  streak7Days,
  streak14Days,
  streak30Days,
  streak100Days,

  // Daily goal based
  firstGoal,
  goal10Times,
  goal50Times,
  goal100Times,

  // Step milestones
  steps10k,
  steps50k,
  steps100k,
  steps500k,
  steps1m,

  // Social
  firstFriend,
  friends5,
  friends10,

  // Challenges
  firstChallengeJoined,
  firstChallengeWon,
  challengesWon5,
  challengesWon10,

  // Leaderboard
  leaderboardTop10,
  leaderboardTop3,
  leaderboardFirst,

  // Special
  earlyBird,     // Log steps before 7am
  nightOwl,      // Log steps after 10pm
  weekendWarrior, // Goal on both Saturday and Sunday
  perfectWeek,   // Goal 7 days in a row
  marathoner,    // 42,195 steps in one day
}

/// Rarity levels for achievements
enum AchievementRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

class Achievement {
  final AchievementType type;
  final String id;
  final String title;
  final String description;
  final String icon;
  final AchievementRarity rarity;
  final int xpReward;
  final DateTime? unlockedAt;
  final double? progress; // 0.0 to 1.0, null if not trackable

  const Achievement({
    required this.type,
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.rarity,
    required this.xpReward,
    this.unlockedAt,
    this.progress,
  });

  bool get isUnlocked => unlockedAt != null;

  Achievement copyWith({
    DateTime? unlockedAt,
    double? progress,
  }) {
    return Achievement(
      type: type,
      id: id,
      title: title,
      description: description,
      icon: icon,
      rarity: rarity,
      xpReward: xpReward,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
    );
  }

  Color get rarityColor {
    switch (rarity) {
      case AchievementRarity.common:
        return const Color(0xFF9CA3AF);
      case AchievementRarity.uncommon:
        return const Color(0xFF10B981);
      case AchievementRarity.rare:
        return const Color(0xFF3B82F6);
      case AchievementRarity.epic:
        return const Color(0xFF8B5CF6);
      case AchievementRarity.legendary:
        return const Color(0xFFF59E0B);
    }
  }

  List<Color> get rarityGradient {
    switch (rarity) {
      case AchievementRarity.common:
        return [const Color(0xFF9CA3AF), const Color(0xFF6B7280)];
      case AchievementRarity.uncommon:
        return [const Color(0xFF10B981), const Color(0xFF059669)];
      case AchievementRarity.rare:
        return [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
      case AchievementRarity.epic:
        return [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];
      case AchievementRarity.legendary:
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    }
  }

  String get rarityLabel {
    switch (rarity) {
      case AchievementRarity.common:
        return 'Gewöhnlich';
      case AchievementRarity.uncommon:
        return 'Ungewöhnlich';
      case AchievementRarity.rare:
        return 'Selten';
      case AchievementRarity.epic:
        return 'Episch';
      case AchievementRarity.legendary:
        return 'Legendär';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'unlockedAt': unlockedAt?.millisecondsSinceEpoch,
      'progress': progress,
    };
  }

  static Achievement fromMap(Map<String, dynamic> map, Achievement base) {
    return base.copyWith(
      unlockedAt: map['unlockedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['unlockedAt'])
          : null,
      progress: map['progress']?.toDouble(),
    );
  }
}

/// All available achievements with their definitions
class AchievementDefinitions {
  static final List<Achievement> all = [
    // Streak achievements
    const Achievement(
      type: AchievementType.streak3Days,
      id: 'streak_3',
      title: 'Guter Start',
      description: '3 Tage in Folge aktiv',
      icon: '🔥',
      rarity: AchievementRarity.common,
      xpReward: 50,
    ),
    const Achievement(
      type: AchievementType.streak7Days,
      id: 'streak_7',
      title: 'Wochenläufer',
      description: '7 Tage in Folge aktiv',
      icon: '🔥',
      rarity: AchievementRarity.uncommon,
      xpReward: 100,
    ),
    const Achievement(
      type: AchievementType.streak14Days,
      id: 'streak_14',
      title: 'Ausdauernd',
      description: '14 Tage in Folge aktiv',
      icon: '💪',
      rarity: AchievementRarity.rare,
      xpReward: 200,
    ),
    const Achievement(
      type: AchievementType.streak30Days,
      id: 'streak_30',
      title: 'Unaufhaltsam',
      description: '30 Tage in Folge aktiv',
      icon: '⚡',
      rarity: AchievementRarity.epic,
      xpReward: 500,
    ),
    const Achievement(
      type: AchievementType.streak100Days,
      id: 'streak_100',
      title: 'Legende',
      description: '100 Tage in Folge aktiv',
      icon: '👑',
      rarity: AchievementRarity.legendary,
      xpReward: 1000,
    ),

    // Daily goal achievements
    const Achievement(
      type: AchievementType.firstGoal,
      id: 'goal_first',
      title: 'Erster Erfolg',
      description: 'Erreiche dein Tagesziel zum ersten Mal',
      icon: '🎯',
      rarity: AchievementRarity.common,
      xpReward: 25,
    ),
    const Achievement(
      type: AchievementType.goal10Times,
      id: 'goal_10',
      title: 'Zielstrebig',
      description: 'Erreiche dein Tagesziel 10 Mal',
      icon: '🎯',
      rarity: AchievementRarity.uncommon,
      xpReward: 150,
    ),
    const Achievement(
      type: AchievementType.goal50Times,
      id: 'goal_50',
      title: 'Gewohnheit',
      description: 'Erreiche dein Tagesziel 50 Mal',
      icon: '🏆',
      rarity: AchievementRarity.rare,
      xpReward: 300,
    ),
    const Achievement(
      type: AchievementType.goal100Times,
      id: 'goal_100',
      title: 'Meister',
      description: 'Erreiche dein Tagesziel 100 Mal',
      icon: '🌟',
      rarity: AchievementRarity.epic,
      xpReward: 750,
    ),

    // Step milestones
    const Achievement(
      type: AchievementType.steps10k,
      id: 'steps_10k',
      title: 'Erste Schritte',
      description: '10.000 Schritte insgesamt',
      icon: '👟',
      rarity: AchievementRarity.common,
      xpReward: 50,
    ),
    const Achievement(
      type: AchievementType.steps50k,
      id: 'steps_50k',
      title: 'Wanderer',
      description: '50.000 Schritte insgesamt',
      icon: '🚶',
      rarity: AchievementRarity.uncommon,
      xpReward: 100,
    ),
    const Achievement(
      type: AchievementType.steps100k,
      id: 'steps_100k',
      title: 'Läufer',
      description: '100.000 Schritte insgesamt',
      icon: '🏃',
      rarity: AchievementRarity.rare,
      xpReward: 250,
    ),
    const Achievement(
      type: AchievementType.steps500k,
      id: 'steps_500k',
      title: 'Athlet',
      description: '500.000 Schritte insgesamt',
      icon: '🏅',
      rarity: AchievementRarity.epic,
      xpReward: 500,
    ),
    const Achievement(
      type: AchievementType.steps1m,
      id: 'steps_1m',
      title: 'Millionär',
      description: '1.000.000 Schritte insgesamt',
      icon: '💎',
      rarity: AchievementRarity.legendary,
      xpReward: 1000,
    ),

    // Social achievements
    const Achievement(
      type: AchievementType.firstFriend,
      id: 'friend_first',
      title: 'Gesellig',
      description: 'Füge deinen ersten Freund hinzu',
      icon: '🤝',
      rarity: AchievementRarity.common,
      xpReward: 50,
    ),
    const Achievement(
      type: AchievementType.friends5,
      id: 'friends_5',
      title: 'Beliеbt',
      description: '5 Freunde hinzugefügt',
      icon: '👥',
      rarity: AchievementRarity.uncommon,
      xpReward: 100,
    ),
    const Achievement(
      type: AchievementType.friends10,
      id: 'friends_10',
      title: 'Influencer',
      description: '10 Freunde hinzugefügt',
      icon: '⭐',
      rarity: AchievementRarity.rare,
      xpReward: 200,
    ),

    // Challenge achievements
    const Achievement(
      type: AchievementType.firstChallengeJoined,
      id: 'challenge_joined',
      title: 'Herausforderer',
      description: 'Nimm an deiner ersten Challenge teil',
      icon: '⚔️',
      rarity: AchievementRarity.common,
      xpReward: 50,
    ),
    const Achievement(
      type: AchievementType.firstChallengeWon,
      id: 'challenge_won',
      title: 'Sieger',
      description: 'Gewinne deine erste Challenge',
      icon: '🏆',
      rarity: AchievementRarity.uncommon,
      xpReward: 150,
    ),
    const Achievement(
      type: AchievementType.challengesWon5,
      id: 'challenges_won_5',
      title: 'Champion',
      description: 'Gewinne 5 Challenges',
      icon: '🥇',
      rarity: AchievementRarity.rare,
      xpReward: 300,
    ),
    const Achievement(
      type: AchievementType.challengesWon10,
      id: 'challenges_won_10',
      title: 'Ungeschlagen',
      description: 'Gewinne 10 Challenges',
      icon: '👑',
      rarity: AchievementRarity.epic,
      xpReward: 500,
    ),

    // Leaderboard achievements
    const Achievement(
      type: AchievementType.leaderboardTop10,
      id: 'lb_top10',
      title: 'Top 10',
      description: 'Erreiche die Top 10 im globalen Leaderboard',
      icon: '📊',
      rarity: AchievementRarity.rare,
      xpReward: 200,
    ),
    const Achievement(
      type: AchievementType.leaderboardTop3,
      id: 'lb_top3',
      title: 'Podium',
      description: 'Erreiche die Top 3 im globalen Leaderboard',
      icon: '🥉',
      rarity: AchievementRarity.epic,
      xpReward: 400,
    ),
    const Achievement(
      type: AchievementType.leaderboardFirst,
      id: 'lb_first',
      title: 'Nummer Eins',
      description: 'Sei #1 im globalen Leaderboard',
      icon: '🥇',
      rarity: AchievementRarity.legendary,
      xpReward: 1000,
    ),

    // Special achievements
    const Achievement(
      type: AchievementType.earlyBird,
      id: 'early_bird',
      title: 'Frühaufsteher',
      description: 'Erreiche 1000 Schritte vor 7 Uhr morgens',
      icon: '🌅',
      rarity: AchievementRarity.uncommon,
      xpReward: 75,
    ),
    const Achievement(
      type: AchievementType.nightOwl,
      id: 'night_owl',
      title: 'Nachteule',
      description: 'Erreiche 1000 Schritte nach 22 Uhr',
      icon: '🌙',
      rarity: AchievementRarity.uncommon,
      xpReward: 75,
    ),
    const Achievement(
      type: AchievementType.weekendWarrior,
      id: 'weekend_warrior',
      title: 'Wochenend-Krieger',
      description: 'Erreiche dein Ziel an Samstag und Sonntag',
      icon: '🎉',
      rarity: AchievementRarity.uncommon,
      xpReward: 100,
    ),
    const Achievement(
      type: AchievementType.perfectWeek,
      id: 'perfect_week',
      title: 'Perfekte Woche',
      description: 'Erreiche dein Ziel 7 Tage hintereinander',
      icon: '✨',
      rarity: AchievementRarity.rare,
      xpReward: 250,
    ),
    const Achievement(
      type: AchievementType.marathoner,
      id: 'marathoner',
      title: 'Marathonläufer',
      description: '42.195 Schritte an einem Tag (~Marathon Distanz)',
      icon: '🏅',
      rarity: AchievementRarity.legendary,
      xpReward: 1000,
    ),
  ];

  static Achievement? getById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  static Achievement? getByType(AchievementType type) {
    try {
      return all.firstWhere((a) => a.type == type);
    } catch (_) {
      return null;
    }
  }
}

/// User's level based on XP
class UserLevel {
  final int level;
  final int currentXp;
  final int xpForCurrentLevel;
  final int xpForNextLevel;

  const UserLevel({
    required this.level,
    required this.currentXp,
    required this.xpForCurrentLevel,
    required this.xpForNextLevel,
  });

  double get progressToNextLevel {
    final xpInLevel = currentXp - xpForCurrentLevel;
    final xpNeeded = xpForNextLevel - xpForCurrentLevel;
    if (xpNeeded <= 0) return 1.0;
    return (xpInLevel / xpNeeded).clamp(0.0, 1.0);
  }

  int get xpToNextLevel => xpForNextLevel - currentXp;

  static UserLevel fromXp(int totalXp) {
    // XP curve: each level requires more XP
    // Level 1: 0-100, Level 2: 100-250, Level 3: 250-500, etc.
    int level = 1;
    int xpForCurrentLevel = 0;
    int xpForNextLevel = 100;

    while (totalXp >= xpForNextLevel) {
      level++;
      xpForCurrentLevel = xpForNextLevel;
      // Increase by 150 XP per level
      xpForNextLevel = xpForCurrentLevel + 100 + (level - 1) * 50;
    }

    return UserLevel(
      level: level,
      currentXp: totalXp,
      xpForCurrentLevel: xpForCurrentLevel,
      xpForNextLevel: xpForNextLevel,
    );
  }

  String get title {
    if (level >= 50) return 'Legende';
    if (level >= 40) return 'Meister';
    if (level >= 30) return 'Experte';
    if (level >= 20) return 'Profi';
    if (level >= 15) return 'Fortgeschritten';
    if (level >= 10) return 'Erfahren';
    if (level >= 5) return 'Enthusiast';
    return 'Anfänger';
  }
}
