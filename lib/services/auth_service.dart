import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// OAuth 2.0 Web client ID of the Firebase project, supplied at build time
  /// (see README.md, "Firebase setup").
  static const _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Google Sign-In für Android / iOS (google_sign_in 7.x)
  Future<User?> signInWithGoogleMobile() async {
    // 1. GoogleSignIn mit serverClientId konfigurieren
    await _googleSignIn.initialize(
      serverClientId: _serverClientId,
    );

    // 2. Nutzer authentifizieren (öffnet Google-Auswahl)
    final GoogleSignInAccount googleUser =
    await _googleSignIn.authenticate();

    // 3. Tokens holen
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    if (googleAuth.idToken == null) {
      throw FirebaseAuthException(
        code: 'MISSING_ID_TOKEN',
        message: 'Google Sign-In hat kein ID-Token geliefert.',
      );
    }

    // 4. Firebase-Credential bauen
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // 5. Bei Firebase anmelden
    final userCred = await _auth.signInWithCredential(credential);
    return userCred.user;
  }

  /// Logout (inkl. Google)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignorieren, falls kein Google-User verbunden ist
    }
    await _auth.signOut();
  }
}
