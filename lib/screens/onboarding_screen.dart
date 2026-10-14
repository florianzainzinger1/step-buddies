import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../theme/theme_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/animated_sky_background.dart';
import 'step_goal_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _usernameController = TextEditingController();

  bool _isSaving = false;
  String? _error;
  bool _showOnGlobalLeaderboard = true; // Default on

  String? _firstName;
  String? _lastName;
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _initFromCurrentUser();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _initFromCurrentUser() {
    final user = _auth.currentUser;
    final displayName = user?.displayName ?? '';
    final email = user?.email ?? '';

    String? first;
    String? last;
    String? fullName;

    if (displayName.isNotEmpty) {
      fullName = displayName;
      final parts = displayName.split(' ');
      if (parts.length >= 2) {
        first = parts.first;
        last = parts.sublist(1).join(' ');
      } else {
        first = displayName;
      }
    }

    if (first == null || first.isEmpty) {
      if (email.isNotEmpty) {
        final emailName = email.split('@').first;
        first = emailName;
      }
    }

    _firstName = first;
    _lastName = last;
    _fullName = fullName ?? '${first ?? ''} ${last ?? ''}'.trim();

    final suggestion = _buildUsernameSuggestion(first ?? '', last ?? '', email);
    _usernameController.text = suggestion;
  }

  String _buildUsernameSuggestion(String first, String last, String email) {
    String normalize(String value) {
      var v = value.trim().toLowerCase();
      v = v
          .replaceAll('ä', 'ae')
          .replaceAll('ö', 'oe')
          .replaceAll('ü', 'ue')
          .replaceAll('ß', 'ss');
      v = v.replaceAll(RegExp(r'[^a-z0-9]+'), '.');
      v = v.replaceAll(RegExp(r'\.+'), '.');
      v = v.replaceAll(RegExp(r'^\.+|\.+$'), '');
      return v;
    }

    if (first.isNotEmpty && last.isNotEmpty) {
      return '${normalize(first)}.${normalize(last)}';
    }

    if (first.isNotEmpty) {
      return normalize(first);
    }

    if (email.isNotEmpty) {
      final emailName = email.split('@').first;
      return normalize(emailName);
    }

    return '';
  }

  Future<bool> _isUsernameAvailable(String username) async {
    final query = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();

    setState(() {
      _error = null;
    });

    if (username.isEmpty) {
      setState(() {
        _error = 'Bitte einen ${AppStrings.usernameLabel} eingeben.';
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _error = AppStrings.usernameTooShort;
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('Kein eingeloggter User gefunden.');
      }

      final available = await _isUsernameAvailable(username);
      if (!available) {
        setState(() {
          _error = AppStrings.usernameTaken;
          _isSaving = false;
        });
        return;
      }

      final first = _firstName ?? '';
      final last = _lastName ?? '';
      final displayName = _fullName?.isNotEmpty == true
          ? _fullName!
          : '$first $last'.trim();

      await _db.collection('users').doc(uid).set({
        'firstName': first,
        'lastName': last,
        'displayName': displayName,
        'username': username,
        'usernameLowercase': username.toLowerCase(),
        'showOnGlobalLeaderboard': _showOnGlobalLeaderboard,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      // 👉 nach Username geht es zum Schrittziel-Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StepGoalScreen()),
      );
    } catch (e) {
      setState(() {
        _error = '${AppStrings.errorSaving}: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SimpleGradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Welcome Icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.primary, colors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_walk_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Text(
                        AppStrings.onboardingTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.onboardingSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Username field
                      Container(
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: themeService.isDarkMode
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _usernameController,
                          style: TextStyle(color: colors.textPrimary),
                          decoration: InputDecoration(
                            labelText: AppStrings.usernameLabel,
                            helperText: AppStrings.usernameHelper,
                            labelStyle: TextStyle(color: colors.textSecondary),
                            helperStyle: TextStyle(color: colors.textTertiary, fontSize: 12),
                            prefixIcon: Icon(Icons.alternate_email_rounded, color: colors.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Global Leaderboard Toggle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.public_rounded, color: colors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Globales Leaderboard',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Im weltweiten Ranking erscheinen',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _showOnGlobalLeaderboard,
                              activeColor: colors.primary,
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                setState(() => _showOnGlobalLeaderboard = value);
                              },
                            ),
                          ],
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: colors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Submit button
                      GestureDetector(
                        onTap: _isSaving ? null : () {
                          HapticFeedback.lightImpact();
                          _submit();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isSaving
                                  ? [colors.shimmer, colors.shimmer]
                                  : [colors.primary, colors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _isSaving
                                ? null
                                : [
                                    BoxShadow(
                                      color: colors.primary.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        AppStrings.next,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
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
