import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  String _docIdForDailySteps(String userId, DateTime date) {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return '${userId}_$dateStr';
  }

  Future<void> saveDailySteps({
    required String userId,
    required int steps,
  }) async {
    final now = DateTime.now();
    final docId = _docIdForDailySteps(userId, now);

    await _db.collection('dailySteps').doc(docId).set({
      'userId': userId,
      'date': DateTime(now.year, now.month, now.day),
      'steps': steps,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getTodayStepsForUsers(
    List<String> userIds,
  ) async {
    final now = DateTime.now();

    // wir berechnen für jeden User die Doc-ID von HEUTE
    final docIds = userIds.map((id) => _docIdForDailySteps(id, now)).toList();

    // alle Dokumente parallel laden
    final futures = docIds.map((docId) {
      return _db.collection('dailySteps').doc(docId).get();
    }).toList();

    final snapshots = await Future.wait(futures);

    // nur existierende Dokumente zurückgeben
    final results = snapshots
        .where((snap) => snap.exists)
        .map((snap) => snap.data() as Map<String, dynamic>)
        .toList();

    return results;
  }

  Stream<List<Map<String, dynamic>>> watchTodaySteps() {
    final now = DateTime.now();
    final dateStart = DateTime(now.year, now.month, now.day);
    final dateEnd = dateStart.add(const Duration(days: 1));

    return _db
        .collection('dailySteps')
        .where('date', isGreaterThanOrEqualTo: dateStart)
        .where('date', isLessThan: dateEnd)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data())
              .toList(),
        );
  }

  Future<Map<String, Map<String, dynamic>>> getUsersByIds(
    List<String> userIds,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    final uniqueIds = userIds.toSet().toList();

    for (final uid in uniqueIds) {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          result[uid] = data;
        }
      }
    }

    return result;
  }
}
