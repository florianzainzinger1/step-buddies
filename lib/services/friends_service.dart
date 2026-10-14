// lib/services/friends_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Status einer Freundschaftsanfrage
enum FriendRequestStatus { pending, accepted, declined }

/// Modell für eine Freundschaftsanfrage
class FriendRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime createdAt;
  
  // Zusätzliche User-Infos (werden beim Laden gefüllt)
  String? fromUsername;
  String? fromDisplayName;
  String? toUsername;
  String? toDisplayName;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    this.fromUsername,
    this.fromDisplayName,
    this.toUsername,
    this.toDisplayName,
  });

  factory FriendRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FriendRequest(
      id: doc.id,
      fromUserId: data['fromUserId'] as String,
      toUserId: data['toUserId'] as String,
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FriendsService {
  FriendsService._();
  static final instance = FriendsService._();

  final _db = FirebaseFirestore.instance;

  // ===================
  // Suche
  // ===================

  /// Suche User per Username (Prefix-Suche, case-insensitive)
  Future<List<Map<String, dynamic>>> searchUsersByUsername(
    String query, {
    String? excludeUserId,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final snap = await _db
        .collection('users')
        .where('usernameLowercase', isGreaterThanOrEqualTo: q)
        .where('usernameLowercase', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .get();

    final results = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      if (excludeUserId != null && doc.id == excludeUserId) continue;

      final data = doc.data();
      results.add({
        'id': doc.id,
        'username': data['username'] ?? '',
        'displayName': data['displayName'] ?? '',
      });
    }

    return results;
  }

  /// Erweiterte Suche mit Vorschlägen (min. 2 Zeichen)
  /// Gibt zurück: User-Liste mit Status (friend/pending/none)
  Future<List<Map<String, dynamic>>> searchUsersWithStatus(
    String query, {
    required String currentUserId,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];

    // User suchen
    final users = await searchUsersByUsername(q, excludeUserId: currentUserId);
    if (users.isEmpty) return [];

    // Aktuelle Freunde laden
    Set<String> friendIds = {};
    try {
      final userDoc = await _db.collection('users').doc(currentUserId).get();
      friendIds = ((userDoc.data()?['friendIds'] as List?) ?? [])
          .whereType<String>()
          .toSet();
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Fehler beim Laden der Freunde: $e');
    }

    // Pending Anfragen laden (gesendet) - mit Fallback bei Index-Fehler
    Set<String> pendingOutgoing = {};
    try {
      final outgoingSnap = await _db
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      pendingOutgoing = outgoingSnap.docs
          .map((doc) => doc.data()['toUserId'] as String)
          .toSet();
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Fehler beim Laden ausgehender Anfragen: $e');
    }

    // Pending Anfragen (empfangen) - mit Fallback bei Index-Fehler
    Set<String> pendingIncoming = {};
    try {
      final incomingSnap = await _db
          .collection('friendRequests')
          .where('toUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      pendingIncoming = incomingSnap.docs
          .map((doc) => doc.data()['fromUserId'] as String)
          .toSet();
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Fehler beim Laden eingehender Anfragen: $e');
    }

    // Status hinzufügen
    for (final user in users) {
      final id = user['id'] as String;
      if (friendIds.contains(id)) {
        user['status'] = 'friend';
      } else if (pendingOutgoing.contains(id)) {
        user['status'] = 'pending_outgoing';
      } else if (pendingIncoming.contains(id)) {
        user['status'] = 'pending_incoming';
      } else {
        user['status'] = 'none';
      }
    }

    return users;
  }

  /// Freundesvorschläge basierend auf "Freunde von Freunden"
  /// Gibt User zurück, die Freunde deiner Freunde sind, aber nicht deine Freunde
  Future<List<Map<String, dynamic>>> getFriendSuggestions(String userId) async {
    try {
      // 1. Eigene Freunde laden
      final userDoc = await _db.collection('users').doc(userId).get();
      final myFriendIds = ((userDoc.data()?['friendIds'] as List?) ?? [])
          .whereType<String>()
          .toSet();

      if (myFriendIds.isEmpty) return [];

      // 2. Pending Anfragen laden
      Set<String> pendingUserIds = {};
      try {
        final outgoingSnap = await _db
            .collection('friendRequests')
            .where('fromUserId', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .get();
        pendingUserIds.addAll(
          outgoingSnap.docs.map((d) => d.data()['toUserId'] as String),
        );
        
        final incomingSnap = await _db
            .collection('friendRequests')
            .where('toUserId', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .get();
        pendingUserIds.addAll(
          incomingSnap.docs.map((d) => d.data()['fromUserId'] as String),
        );
      } catch (e) {
        // Ignorieren
      }

      // 3. Freunde der Freunde sammeln
      final Map<String, int> friendsOfFriends = {}; 
      
      for (var i = 0; i < myFriendIds.length && i < 30; i += 10) {
        final batch = myFriendIds.skip(i).take(10).toList();
        
        final friendDocs = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final friendDoc in friendDocs.docs) {
          final friendData = friendDoc.data();
          final theirFriends = ((friendData['friendIds'] as List?) ?? [])
              .whereType<String>()
              .toSet();

          for (final potentialSuggestion in theirFriends) {
            if (potentialSuggestion == userId) continue;
            if (myFriendIds.contains(potentialSuggestion)) continue;
            if (pendingUserIds.contains(potentialSuggestion)) continue;

            friendsOfFriends.update(
              potentialSuggestion,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
        }
      }

      if (friendsOfFriends.isEmpty) return [];

      // 4. Nach Anzahl gemeinsamer Freunde sortieren
      final sortedIds = friendsOfFriends.keys.toList()
        ..sort((a, b) => friendsOfFriends[b]!.compareTo(friendsOfFriends[a]!));

      // 5. Top 10 Vorschläge laden
      final topIds = sortedIds.take(10).toList();
      final suggestions = <Map<String, dynamic>>[];

      for (var i = 0; i < topIds.length; i += 10) {
        final batch = topIds.skip(i).take(10).toList();
        final docs = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in docs.docs) {
          final data = doc.data();
          suggestions.add({
            'id': doc.id,
            'username': data['username'] ?? '',
            'displayName': data['displayName'] ?? '',
            'mutualFriends': friendsOfFriends[doc.id] ?? 0,
            'status': 'none',
          });
        }
      }
      
      // Sortieren
      suggestions.sort((a, b) => 
        (b['mutualFriends'] as int).compareTo(a['mutualFriends'] as int));

      return suggestions;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Fehler beim Laden der Freundesvorschläge: $e');
      return [];
    }
  }

  // ===================
  // Freunde
  // ===================

  /// Stream der Freundesliste
  Stream<List<Map<String, dynamic>>> watchFriends(String  userId) {
    return _db.collection('users').doc(userId).snapshots().asyncMap((doc) async {
      final data = doc.data();
      if (data == null) return [];
      
      final friendIds = List<String>.from(data['friendIds'] ?? []);
      if (friendIds.isEmpty) return [];

      // Batched fetch (limitiert auf 10 bei whereIn, aber hier holen wir per ID)
      // Firestore hat kein "getAll" per ID Liste > 10 in einem query
      // Wir müssen splitten oder einzeln holen.
      // Easiest: Splitten in 10er Chunks und whereIn 'FieldPath.documentId'
      
      try {
        if (friendIds.length > 30) {
           // Limitierung für MVP
           friendIds.length = 30; 
        }

        final chunks = <List<String>>[];
        for (var i = 0; i < friendIds.length; i += 10) {
          chunks.add(friendIds.sublist(i, i + 10 > friendIds.length ? friendIds.length : i + 10));
        }
        
        final results = <Map<String,dynamic>>[];
        for (final chunk in chunks) {
          final q = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
          
          for (final d in q.docs) {
            results.add({
              'id': d.id,
              'username': d.data()['username'] ?? '',
              'displayName': d.data()['displayName'] ?? '',
            });
          }
        }
        return results;
      } catch (e) {
        debugPrint('Error watching friends: $e');
        return [];
      }
    });
  }

  /// Live-Stream deiner Friend-IDs
  Stream<List<String>> watchFriendIds(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return <String>[];

      final raw = data['friendIds'];
      if (raw is List) {
        return raw.whereType<String>().toList();
      }
      return <String>[];
    });
  }

  /// Entfernt Freundschaft beidseitig
  Future<void> removeFriend({
    required String userId,
    required String friendId,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final friendRef = _db.collection('users').doc(friendId);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final friendSnap = await tx.get(friendRef);

      final userData = userSnap.data() ?? {};
      final friendData = friendSnap.data() ?? {};

      final userFriends =
          (userData['friendIds'] as List?)?.whereType<String>().toList() ?? [];
      final friendFriends =
          (friendData['friendIds'] as List?)?.whereType<String>().toList() ?? [];

      userFriends.remove(friendId);
      friendFriends.remove(userId);

      tx.update(userRef, {'friendIds': userFriends});
      if (friendSnap.exists) {
        tx.update(friendRef, {'friendIds': friendFriends});
      }
    });
  }

  // ===================
  // Freundschaftsanfragen
  // ===================

  /// Sendet eine Freundschaftsanfrage
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    // Prüfen ob bereits eine Anfrage existiert
    final existing = await _db
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Anfrage bereits gesendet.');
    }

    // Prüfen ob bereits Freunde
    final userDoc = await _db.collection('users').doc(fromUserId).get();
    final friendIds = ((userDoc.data()?['friendIds'] as List?) ?? [])
        .whereType<String>()
        .toSet();
    if (friendIds.contains(toUserId)) {
      throw Exception('Bereits befreundet.');
    }

    // Anfrage erstellen
    await _db.collection('friendRequests').add({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Akzeptiert eine Freundschaftsanfrage
  Future<void> acceptFriendRequest(String requestId) async {
    final requestRef = _db.collection('friendRequests').doc(requestId);
    
    await _db.runTransaction((tx) async {
      final requestSnap = await tx.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Anfrage nicht gefunden.');
      }

      final data = requestSnap.data()!;
      if (data['status'] != 'pending') {
        throw Exception('Anfrage bereits bearbeitet.');
      }

      final fromUserId = data['fromUserId'] as String;
      final toUserId = data['toUserId'] as String;

      final fromRef = _db.collection('users').doc(fromUserId);
      final toRef = _db.collection('users').doc(toUserId);

      final fromSnap = await tx.get(fromRef);
      final toSnap = await tx.get(toRef);

      final fromFriends =
          ((fromSnap.data()?['friendIds'] as List?) ?? [])
              .whereType<String>()
              .toList();
      final toFriends =
          ((toSnap.data()?['friendIds'] as List?) ?? [])
              .whereType<String>()
              .toList();

      if (!fromFriends.contains(toUserId)) {
        fromFriends.add(toUserId);
      }
      if (!toFriends.contains(fromUserId)) {
        toFriends.add(fromUserId);
      }

      tx.update(requestRef, {'status': 'accepted'});
      tx.update(fromRef, {'friendIds': fromFriends});
      tx.update(toRef, {'friendIds': toFriends});
    });
  }

  /// Lehnt eine Freundschaftsanfrage ab
  Future<void> declineFriendRequest(String requestId) async {
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'declined',
    });
  }

  /// Zieht eine gesendete Anfrage zurück
  Future<void> cancelFriendRequest(String requestId) async {
    await _db.collection('friendRequests').doc(requestId).delete();
  }

  /// Stream für eingehende Anfragen
  Stream<List<FriendRequest>> watchIncomingRequests(String userId) {
    return _db
        .collection('friendRequests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final requests = <FriendRequest>[];
      
      for (final doc in snap.docs) {
        final request = FriendRequest.fromFirestore(doc);
        
        // User-Infos laden
        final fromUserDoc = await _db.collection('users').doc(request.fromUserId).get();
        if (fromUserDoc.exists) {
          final data = fromUserDoc.data()!;
          request.fromUsername = data['username'] as String?;
          request.fromDisplayName = data['displayName'] as String?;
        }
        
        requests.add(request);
      }
      
      return requests;
    });
  }

  /// Stream für gesendete Anfragen
  Stream<List<FriendRequest>> watchOutgoingRequests(String userId) {
    return _db
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final requests = <FriendRequest>[];
      
      for (final doc in snap.docs) {
        final request = FriendRequest.fromFirestore(doc);
        
        // User-Infos laden
        final toUserDoc = await _db.collection('users').doc(request.toUserId).get();
        if (toUserDoc.exists) {
          final data = toUserDoc.data()!;
          request.toUsername = data['username'] as String?;
          request.toDisplayName = data['displayName'] as String?;
        }
        
        requests.add(request);
      }
      
      return requests;
    });
  }

  /// Lädt Freunde mit ihren Profil-Daten
  Future<List<Map<String, dynamic>>> getFriendsWithProfiles(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final friendIds = ((userDoc.data()?['friendIds'] as List?) ?? [])
        .whereType<String>()
        .toList();

    if (friendIds.isEmpty) return [];

    final friends = <Map<String, dynamic>>[];
    
    // Firestore erlaubt max 10 IDs per whereIn
    for (var i = 0; i < friendIds.length; i += 10) {
      final batch = friendIds.skip(i).take(10).toList();
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      
      for (final doc in snap.docs) {
        final data = doc.data();
        friends.add({
          'id': doc.id,
          'username': data['username'] ?? '',
          'displayName': data['displayName'] ?? '',
        });
      }
    }

    return friends;
  }

  // Legacy-Methode für Kompatibilität
  @Deprecated('Use sendFriendRequest instead')
  Future<void> addFriend({
    required String userId,
    required String friendId,
  }) async {
    await sendFriendRequest(fromUserId: userId, toUserId: friendId);
  }
}
