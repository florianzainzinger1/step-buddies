// lib/services/groups_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final List<String> memberIds;
  final String joinCode;
  final String ownerId;

  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.joinCode,
    required this.ownerId,
  });

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Group(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Unbenannte Gruppe',
      memberIds:
          (data['memberIds'] as List?)?.whereType<String>().toList() ??
          <String>[],
      joinCode: (data['joinCode'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
    );
  }
}

class GroupsService {
  GroupsService._();
  static final instance = GroupsService._();

  final _db = FirebaseFirestore.instance;

  Future<Group> getGroup(String groupId) async {
    final doc = await _db.collection('groups').doc(groupId).get();
    if (!doc.exists) {
      throw Exception('Gruppe nicht gefunden');
    }
    return Group.fromDoc(doc);
  }

  /// Alle Gruppen, in denen der User Mitglied ist
  Stream<List<Group>> watchGroupsForUser(String userId) {
    return _db
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => Group.fromDoc(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Gruppe erstellen und User automatisch als Mitglied + Owner eintragen.
  /// Gibt die erstellte Gruppe zurück.
  Future<Group> createGroup({
    required String name,
    required String ownerId,
  }) async {
    final code = _generateJoinCode();

    final docRef = await _db.collection('groups').add({
      'name': name,
      'ownerId': ownerId,
      'memberIds': [ownerId],
      'joinCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final createdSnap = await docRef.get();
    return Group.fromDoc(createdSnap);
  }

  /// Gruppe per Invite-Code finden und User als Mitglied hinzufügen
  Future<Group> joinGroupByCode({
    required String code,
    required String userId,
  }) async {
    final normalized = code.trim().toUpperCase();

    final query = await _db
        .collection('groups')
        .where('joinCode', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Keine Gruppe mit diesem Code gefunden.');
    }

    final doc = query.docs.first;
    final docRef = doc.reference;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? {};

      final members =
          (data['memberIds'] as List?)?.whereType<String>().toSet() ??
          <String>{};
      members.add(userId);

      tx.update(docRef, {
        'memberIds': members.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final updatedSnap = await docRef.get();
    return Group.fromDoc(updatedSnap);
  }

  /// EINFACHER Code-Generator: 6-stelliger Alphanumerik-Code (z.B. "A9F3KZ")
  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // ohne 0/O/1/I
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> leaveGroup({
    required String userId,
    required String groupId,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final userRef = _db.collection('users').doc(userId);

    // 1) Gruppe laden (kann schon gelöscht sein)
    final groupSnap = await groupRef.get();

    if (!groupSnap.exists) {
      // Gruppe gibt es nicht mehr → nur userDoc aufräumen
      await userRef.set({
        'groupIds': FieldValue.arrayRemove([groupId]),
      }, SetOptions(merge: true));
      return;
    }

    final data = groupSnap.data()!;
    final ownerId = data['ownerId'] as String?;
    final memberIds =
        (data['memberIds'] as List?)?.whereType<String>().toList() ??
        <String>[];

    // Falls der User gar nicht Mitglied ist → nichts tun
    if (!memberIds.contains(userId)) {
      return;
    }

    // 2) User aus der Mitgliederliste entfernen
    memberIds.remove(userId);

    // 3) groupId aus dem user-Dokument entfernen
    await userRef.set({
      'groupIds': FieldValue.arrayRemove([groupId]),
    }, SetOptions(merge: true));

    // 4) Wenn keine Mitglieder mehr übrig sind → Gruppe komplett löschen
    if (memberIds.isEmpty) {
      await groupRef.delete();
      return;
    }

    // 5) Neuer Owner, falls der bisherige Owner die Gruppe verlässt
    final String newOwnerId;
    if (ownerId == null) {
      // zur Sicherheit irgendein Mitglied zum Owner machen
      newOwnerId = memberIds.first;
    } else if (ownerId == userId) {
      // Owner verlässt → jemand anderes übernimmt
      newOwnerId = memberIds.first;
    } else {
      // Owner bleibt
      newOwnerId = ownerId;
    }

    // 6) Gruppe updaten
    await groupRef.set({
      'memberIds': memberIds,
      'ownerId': newOwnerId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
