import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';
import 'onboarding_screen.dart';
import 'step_goal_screen.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSigningIn = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // erst nach dem ersten Frame navigieren
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goToNextScreen(user);
      });
    }
  }

  Future<void> _goToNextScreen(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    final username = data?['username'] as String?;
    final goal = data?['dailyStepGoal'];

    // 1) Kein Profil / kein Username → Onboarding
    if (!doc.exists || username == null || username.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // 2) Username da, aber kein sinnvolles Ziel → StepGoal
    if (goal is! num || goal <= 0) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StepGoalScreen()),
      );
      return;
    }

    // 3) Alles da → Home
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _error = null;
    });

    try {
      User? user;

      if (kIsWeb) {
        // Web: wie bisher über signInWithPopup
        final provider = GoogleAuthProvider();
        final cred = await FirebaseAuth.instance.signInWithPopup(provider);
        user = cred.user;
      } else {
        // Mobile (Android / iOS): über google_sign_in
        user = await AuthService.instance.signInWithGoogleMobile();
      }

      if (user == null) {
        // User hat z.B. den Dialog abgebrochen
        setState(() {
          _error = 'Anmeldung abgebrochen.';
        });
        return;
      }

      // Weiter in deinen bestehenden Flow
      await _goToNextScreen(user);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'operation-not-allowed':
          message =
          'Google-Login ist für dieses Projekt noch nicht korrekt eingerichtet.';
          break;
        case 'popup-closed-by-user':
        case 'canceled':
          message = 'Anmeldung abgebrochen.';
          break;
        default:
          message =
          'Die Anmeldung ist fehlgeschlagen. Bitte versuch es später nochmal.';
      }

      // ignore: avoid_print
      print('FirebaseAuthException: ${e.code} – ${e.message}');

      setState(() {
        _error = message;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Unbekannter Fehler: $e');
      setState(() {
        _error = AppStrings.unknownError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }


  void _onAppleSignInPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${AppStrings.signInWithApple} ${AppStrings.comingSoon}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        AppStrings.welcomeTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.welcomeSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isSigningIn ? null : _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.login),
                          label: _isSigningIn
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  AppStrings.signInWithGoogle,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _onAppleSignInPressed,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            '${AppStrings.signInWithApple} (${AppStrings.comingSoon})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
