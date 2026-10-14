import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import 'friends_screen.dart';
import '../services/deep_link_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();

  double _goal = 10000;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String get _goalLabel =>
      _goal.toInt() == 0 ? AppStrings.noGoal : AppStrings.stepsCount(_goal.toInt());

  Future<void> _loadProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('Kein eingeloggter User gefunden.');
      }

      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};

      _displayNameController.text = (data['displayName'] as String?) ?? '';
      _usernameController.text = (data['username'] as String?) ?? '';

      final goal = data['dailyStepGoal'];
      if (goal is num) {
        _goal = goal.toDouble().clamp(0, 15000);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Fehler beim Laden des Profils: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppStrings.errorLoadingProfile;
        });
      }
    }
  }

  Future<bool> _isUsernameAvailable(String username) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final query = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return true;

    // eigener Username ist natürlich erlaubt
    return query.docs.first.id == uid;
  }

  Future<void> _save() async {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim();

    setState(() {
      _error = null;
    });

    if (displayName.isEmpty) {
      setState(() {
        _error = AppStrings.displayNameRequired;
      });
      return;
    }

    if (username.isEmpty || username.length < 3) {
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

      final goalInt = _goal.toInt().clamp(0, 15000);

      await _db.collection('users').doc(uid).set({
        'displayName': displayName,
        'username': username,
        'usernameLowercase': username.toLowerCase(),
        'dailyStepGoal': goalInt,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.profileUpdated)));

      // HomeScreen kann das neue Ziel direkt übernehmen
      Navigator.of(context).pop<int>(goalInt);
    } catch (e) {
      // ignore: avoid_print
      print('Fehler beim Speichern des Profils: $e');
      if (mounted) {
        setState(() {
          _error = AppStrings.errorSaving;
        });
      }
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppStrings.profile,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.share),
                                  onPressed: () {
                                    final uid = _auth.currentUser?.uid;
                                    final username = _usernameController.text;
                                    if (uid != null && username.isNotEmpty) {
                                       DeepLinkService.instance.shareProfile(uid, username);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.settings_outlined),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _displayNameController,
                              decoration: InputDecoration(
                                labelText: AppStrings.displayName,
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: AppStrings.usernameLabel,
                                helperText: AppStrings.usernameHelper,
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              AppStrings.dailyStepGoal,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _goalLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.purple,
                              ),
                            ),
                            Slider(
                              value: _goal,
                              min: 0,
                              max: 15000,
                              divisions: 150,
                              label: _goalLabel,
                              onChanged: (value) {
                                setState(() {
                                  _goal = value;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.stepGoalHelper,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Divider
                            Divider(color: AppColors.textSecondary.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            
                            // Onboarding nochmal anzeigen Button
                            // Freunde verwalten Button
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const FriendsScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.people, size: 20),
                              label: Text(
                                '${AppStrings.friends} verwalten',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Onboarding Button
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const OnboardingScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.info_outline, size: 20),
                              label: Text(
                                AppStrings.showOnboardingAgain,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            if (_error != null) ...[
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.purple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        AppStrings.save,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
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
