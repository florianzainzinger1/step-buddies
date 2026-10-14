import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'theme/theme_service.dart';
import 'services/deep_link_service.dart';

// Global Key für Navigation (für Deep Links)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize DeepLinks
  DeepLinkService.instance.init(navigatorKey);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _hasUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Step Buddies',
          debugShowCheckedModeBanner: false,
          theme: themeService.buildThemeData(),
          home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = authSnapshot.data;

          // 1) Noch nicht eingeloggt → Login-Screen
          if (user == null) {
            return const SignInScreen();
          }

          // 2) Eingeloggt → schauen, ob Profil existiert
          return FutureBuilder<bool>(
            future: _hasUserProfile(user.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (profileSnapshot.hasError) {
                return const Scaffold(
                  body: Center(
                    child: Text('Fehler beim Laden des Profils'),
                  ),
                );
              }

              final hasProfile = profileSnapshot.data ?? false;

              if (!hasProfile) {
                // 3) Noch kein Profil → Benutzername wählen
                return const OnboardingScreen();
              }

              // 4) Alles da → Home
              return const HomeScreen();
            },
          );
        },
      ),
        );
      },
    );
  }
}
