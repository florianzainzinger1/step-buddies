import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeStatus {
  pending, // In Vorbereitung (noch bearbeitbar)
  active,  // Läuft
  completed // Beendet
}

class ChallengeTeam {
  final String id;
  final String name;
  final List<String> memberIds;
  final int colorIndex; // Index für eine vordefinierte Farbpalette

  ChallengeTeam({
    required this.id,
    required this.name,
    required this.memberIds,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'memberIds': memberIds,
      'colorIndex': colorIndex,
    };
  }

  factory ChallengeTeam.fromMap(Map<String, dynamic> map) {
    return ChallengeTeam(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Team',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      colorIndex: map['colorIndex'] ?? 0,
    );
  }
}

class Challenge {
  final String id;
  final String title;
  final String adminId;
  final DateTime startDate;
  final int durationDays;
  final ChallengeStatus status;
  final List<ChallengeTeam> teams;
  
  // Cache für Gesamtteilnehmer (für einfache Queries)
  final List<String> participantIds;

  Challenge({
    required this.id,
    required this.title,
    required this.adminId,
    required this.startDate,
    required this.durationDays,
    required this.status,
    required this.teams,
    required this.participantIds,
  });
  
  DateTime get endDate => startDate.add(Duration(days: durationDays));
  
  bool get isStarted {
    final now = DateTime.now();
    // Startet heute oder früher
    return now.isAfter(startDate) || (now.day == startDate.day && now.month == startDate.month && now.year == startDate.year);
  }
  
  bool get isEnded {
    final now = DateTime.now();
    // Enddatum vorbei (wir nehmen Ende des Tages an, aber hier einfache Logic)
    // Besser: endDate ist start + duration.
    return now.isAfter(endDate);
  }
  
  bool get isActive => isStarted && !isEnded;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'adminId': adminId,
      'startDate': Timestamp.fromDate(startDate),
      'durationDays': durationDays,
      'status': status.name,
      'teams': teams.map((t) => t.toMap()).toList(),
      'participantIds': participantIds,    };
  }

  factory Challenge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Challenge(
      id: doc.id,
      title: data['title'] ?? 'Challenge',
      adminId: data['adminId'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 7,
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ChallengeStatus.pending,
      ),
      teams: (data['teams'] as List<dynamic>?)
              ?.map((t) => ChallengeTeam.fromMap(t))
              .toList() ??
          [],
      participantIds: List<String>.from(data['participantIds'] ?? []),
    );
  }
}
