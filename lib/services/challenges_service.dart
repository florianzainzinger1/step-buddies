import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge.dart';

class ChallengesService {
  ChallengesService._();
  static final instance = ChallengesService._();

  final _db = FirebaseFirestore.instance;

  // Collection Reference
  CollectionReference<Map<String, dynamic>> get _challenges =>
      _db.collection('challenges');

  /// Neue Challenge erstellen
  Future<String> createChallenge({
    required String title,
    required String adminId,
    required DateTime startDate,
    required int durationDays,
    required List<ChallengeTeam> teams,
  }) async {
    // Alle Teilnehmer IDs sammeln
    final allParticipants = teams.expand((t) => t.memberIds).toSet().toList();
    if (!allParticipants.contains(adminId)) {
      // Admin sollte wohl auch Teilnehmer sein? 
      // Nicht zwingend, aber meistens schon. Wir fügen ihn nicht automatisch hinzu, 
      // das muss im UI passieren. Aber wir speichern ihn in participantIds nur wenn er im Team ist.
      // Halt: participantIds ist für Queries wichtig ("Zeig mir meine Challenges").
      // Wenn Admin nur zuschaut, sollte er sie vllt trotzdem sehen.
      // Wir fügen Admin ID sicherheitshalber zu participantIds hinzu, damit er sie sieht.
      allParticipants.add(adminId);
    }

    final docRef = await _challenges.add({
      'title': title,
      'adminId': adminId,
      'startDate': Timestamp.fromDate(startDate),
      'durationDays': durationDays,
      'status': ChallengeStatus.pending.name,
      'teams': teams.map((t) => t.toMap()).toList(),
      'participantIds': allParticipants,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Meine Challenges laden (als Stream)
  Stream<List<Challenge>> watchMyChallenges(String userId) {
    return _challenges
        .where('participantIds', arrayContains: userId)
        // .orderBy('startDate', descending: true) // Braucht Index, vllt erst später
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Challenge.fromDoc(doc)).toList());
  }

  /// Einzelne Challenge laden
  Stream<Challenge> watchChallenge(String challengeId) {
    return _challenges.doc(challengeId).snapshots().map((doc) {
      if (!doc.exists) throw Exception('Challenge not found');
      return Challenge.fromDoc(doc);
    });
  }

  /// Challenge aktualisieren (nur Admin & Status Pending/Active)
  Future<void> updateChallengeTeams(String challengeId, List<ChallengeTeam> newTeams) async {
    final allParticipants = newTeams.expand((t) => t.memberIds).toSet().toList();
    
    // Admin ID muss erhalten bleiben in der Participants Liste für Sichtbarkeit
    // Wir holen kurz das Doc um die Admin ID zu checken? 
    // Oder wir vertrauen darauf dass der Aufrufer aufpasst?
    // Besser: Wir machen ein Transaction update oder merge.
    // Einfacher: Wir holen die alte Admin ID nicht, sondern nutzen arrayUnion? 
    // Nein `participantIds` ist ein Array. Wir überschreiben es komplett.
    // Wir müssen sicherstellen, dass wir niemanden "aussperren".
    
    // Quick fix: Wir laden current doc.
    final doc = await _challenges.doc(challengeId).get();
    final adminId = doc.data()?['adminId'] ?? '';
    if (!allParticipants.contains(adminId) && adminId.isNotEmpty) {
      allParticipants.add(adminId);
    }

    await _challenges.doc(challengeId).update({
      'teams': newTeams.map((t) => t.toMap()).toList(),
      'participantIds': allParticipants,
    });
  }

  /// Status ändern
  Future<void> updateStatus(String challengeId, ChallengeStatus status) async {
    await _challenges.doc(challengeId).update({
      'status': status.name,
    });
  }

  /// Löschen
  Future<void> deleteChallenge(String challengeId) async {
    await _challenges.doc(challengeId).delete();
  }

  /// Berechnet die Scores (Gesamtschritte) für eine Challenge pro Team
  Future<Map<String, int>> getChallengeScores(Challenge challenge) async {
    // Wenn Challenge noch nicht gestartet, alles 0
    if (!challenge.isStarted) {
      return {for (var t in challenge.teams) t.id: 0};
    }

    final scores = <String, int>{};
    // Startdatum normalisieren auf Mitternacht (00:00:00)
    final startMidnight = DateTime(challenge.startDate.year, challenge.startDate.month, challenge.startDate.day);
    
    // Enddatum: Wir wollen Steps BIS ZUM Enddatum (Ende des Tages)
    // Wenn Challenge bis 20.12 läuft, wollen wir Steps vom 20.12 noch haben.
    // Also query <= 20.12 23:59:59 oder < 21.12 00:00:00
    // Da DailySteps 'date' immer 00:00:00 sind: <= 20.12 00:00:00 ist KORREKT für das Doc vom 20.12.
    // Aber wir nehmen sicherheitshalber endDate (was startDate + duration ist).
    // Wenn duration 7 Tage. Start 17.12. End 24.12.
    // Challenge läuft: 17, 18, 19, 20, 21, 22, 23. (7 Tage).
    // 24.12. ist der Tag der das Ende markiert (exklusiv oder inklusiv?)
    // Normalerweise startDate + 7 Tage = gleicher Wochentag nächste Woche.
    // Das heißt 24.12 00:00 ist der Zeitpunkt des Endes. Also 23.12 war letzter voller Tag.
    // User sagt "last day and challenge was active".
    // Wir nehmen an durationDays sind VOLLE Tage.
    // Wir inkludieren bis 'endDate' exklusive? Oder inklusive?
    // Im UI: "Noch 3 Tage".
    // Checken wir Challenge.endDate getter: startDate.add(Duration(days: durationDays));
    // Wenn Start: 17.12 00:00. End: 24.12 00:00.
    // User läuft am 17.12. Doc hat 17.12 00:00. -> Query >= 17.12 passt.
    // User läuft am 23.12. Doc hat 23.12 00:00. -> Query < 24.12 passt.
    // StartMidnight ist sicher.
    
    final endMidnight = DateTime(challenge.endDate.year, challenge.endDate.month, challenge.endDate.day);
    // Wir cappen das Query-Ende auf "Morgen", damit wir nicht unnötig in die Zukunft fragen, 
    // aber wir müssen sichergehen, dass wir ALLES bis zum EndMidnight kriegen.
    // Firestore Query: date >= startMidnight AND date < endMidnight
    // Halt: Wenn EndMidnight 24.12 00:00, ist 23.12 00:00 < 24.12 00:00. Passt.
    
    // Wir holen Steps für alle Member
    // Performance Optimierung: Wir holen alle Steps für alle Member in Range?
    // Firestore hat 'in' Operator für max 10/30 Items.
    // Lieber pro Member queryen (wie bisher), ist sicherer bei vielen Freunden.
    
    for (final team in challenge.teams) {
      int teamSteps = 0;
      
      for (final memberId in team.memberIds) {
        try {
          final snap = await _db.collection('dailySteps')
             .where('userId', isEqualTo: memberId)
             .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startMidnight))
             .where('date', isLessThan: Timestamp.fromDate(endMidnight)) 
             .get();
             
          for (final doc in snap.docs) {
             teamSteps += (doc.data()['steps'] as num? ?? 0).toInt(); 
          }
        } catch (e) {
          debugPrint('Error fetching steps for $memberId: $e');
        }
      }
      scores[team.id] = teamSteps;
    }
    
    return scores;
  }
  
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
