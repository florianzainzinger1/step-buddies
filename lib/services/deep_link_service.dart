import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:step_buddies/screens/friends_search_screen.dart';
import 'package:step_buddies/screens/group_detail_screen.dart';
import 'package:step_buddies/l10n/app_strings.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // 1. Initial Link checken (wenn App geschlossen war)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }
    } catch (e) {
      debugPrint('Deep Link Error (Initial): $e');
    }

    // 2. Stream abonnieren (wenn App im Hintergrund war)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleLink(uri);
      },
      onError: (err) {
        debugPrint('Deep Link Error (Stream): $err');
      },
    );
  }

  void _handleLink(Uri uri) {
    debugPrint('Deep Link empfangen: $uri');
    
    // stepbuddies://profile?id=xyz
    // stepbuddies://group?id=xyz
    
    if (uri.host == 'profile') {
      final userId = uri.queryParameters['id'];
      if (userId != null) {
        _navigateToProfile(userId);
      }
    } else if (uri.host == 'group') {
      final groupId = uri.queryParameters['id'];
      if (groupId != null) {
        _navigateToGroup(groupId);
      }
    }
  }

  void _navigateToProfile(String userId) {
    // Navigiere zum FriendsSearchScreen und suche nach diesem User
    // (Oder direkt Profil anzeigen, aber FriendsSearch ist einfacher da wir keine ID->User Auflösung hier haben)
    // "Hack": Wir nutzen den Search Screen und füllen ihn evtl vor? 
    // Besser: Wir öffnen den FriendsSearchScreen und zeigen direkt "Vorschläge" von diesem User?
    // Oder wir bauen einen neuen "UserProfileScreen" den man per ID öffnet.
    // Für jetzt: Öffne FriendsSearchScreen, user muss noch suchen. 
    // WARTE: Das ist uncool. Wir wollen direkt den User sehen.
    // Da wir aber keinen "UserProfileScreen" haben, der nur eine ID nimmt (UserCompare braucht Auth),
    // nutzen wir den FriendsSearchScreen und übergeben einen "initialSearchTerm"?
    
    // Da wir keine Daten vom Link haben außer der ID, ist es schwer den Namen zu raten.
    // Wir navigieren einfach zum FriendsSearchScreen.
    
    _navigatorKey?.currentState?.push(
      MaterialPageRoute(
        builder: (_) => FriendsSearchScreen(initialSearchId: userId),
      ),
    );
  }

  void _navigateToGroup(String groupId) {
    _navigatorKey?.currentState?.push(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(groupId: groupId),
      ),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  // ======================
  // Sharing Actions
  // ======================

  Future<void> shareProfile(String userId, String username) async {
    final link = 'stepbuddies://profile?id=$userId';
    await Share.share(AppStrings.shareProfileText(username, link));
  }

  Future<void> shareGroup(String groupId, String groupName) async {
    final link = 'stepbuddies://group?id=$groupId';
    await Share.share(AppStrings.shareGroupText(groupName, link));
  }
}
