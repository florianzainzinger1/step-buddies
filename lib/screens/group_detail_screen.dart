// lib/screens/group_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_compare_screen.dart';
import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';
import '../services/groups_service.dart';
import '../services/firestore_service.dart';
import '../widgets/leaderboard.dart';
import '../services/deep_link_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group? group;
  final String? groupId;
  final String? currentUserId;

  const GroupDetailScreen({
    super.key,
    this.group,
    this.groupId,
    this.currentUserId,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _groupsService = GroupsService.instance;
  final _firestore = FirestoreService.instance;
  final _auth = FirebaseAuth.instance;

  Group? _group;
  bool _isLoading = true;
  String? _myUserId;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _myUserId = widget.currentUserId ?? _auth.currentUser?.uid;
    
    if (widget.group != null) {
      _group = widget.group;
      _isLoading = false;
    } else if (widget.groupId != null) {
      _loadGroup(widget.groupId!);
    } else {
      // Fehlerfall
      _isLoading = false;
    }
  }

  Future<void> _loadGroup(String groupId) async {
    try {
      final group = await _groupsService.getGroup(groupId);
      if (mounted) {
        setState(() {
          _group = group;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Gruppe: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_group == null || _myUserId == null) {
       return Scaffold(
         appBar: AppBar(title: const Text('Fehler')),
         body: const Center(child: Text('Gruppe nicht gefunden oder nicht eingeloggt.')),
       );
    }

    final group = _group!;
    final isOwner = group.ownerId == _myUserId;
    final memberCount = group.memberIds.length;

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
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () {
                              DeepLinkService.instance.shareGroup(group.id, group.name);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Info-Karte
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gruppenübersicht',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$memberCount ${AppStrings.members}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (isOwner && group.joinCode.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${AppStrings.inviteCode}:',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                group.joinCode,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.purple,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Heute – ${AppStrings.leaderboard}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      _buildGroupLeaderboard(),

                      const SizedBox(height: 24),

                      // Gruppe verlassen
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _isLeaving ? null : _leaveGroup,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          icon: _isLeaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.redAccent,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.exit_to_app,
                                  color: Colors.redAccent,
                                ),
                          label: Text(
                            AppStrings.leaveGroup,
                            style: const TextStyle(
                              color: Colors.redAccent,
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

  Widget _buildGroupLeaderboard() {
    final memberIds = _group!.memberIds.toSet();

    if (memberIds.isEmpty) {
      return const Text(
        'Noch keine Mitglieder in dieser Gruppe.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestore.watchTodaySteps(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Text(
            AppStrings.errorLoadingSteps,
            style: const TextStyle(color: Colors.red),
          );
        }

        final data = snapshot.data ?? [];

        // nur Dokumente von Gruppenmitgliedern
        final filtered = data.where((doc) {
          final userId = doc['userId'] as String?;
          return userId != null && memberIds.contains(userId);
        }).toList();

        if (filtered.isEmpty) {
          return const Text(
            'Heute noch keine Schritte von Gruppenmitgliedern 😴',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          );
        }

        final userIds = filtered
            .map((doc) => doc['userId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();

        return FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: _firestore.getUsersByIds(userIds),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return Text(
                AppStrings.errorLoadingProfile,
                style: const TextStyle(color: Colors.red),
              );
            }

            final userMap = userSnapshot.data ?? {};

            final entries = filtered.map((doc) {
              final userId = doc['userId'] as String;
              final steps = (doc['steps'] as num).toInt();

              final profile = userMap[userId];
              final username = profile?['username'] as String?;
              final displayName = profile?['displayName'] as String?;

              String nameToShow;
              if (userId == _myUserId) {
                nameToShow = 'Du';
              } else if (username != null && username.isNotEmpty) {
                nameToShow = username;
              } else if (displayName != null && displayName.isNotEmpty) {
                nameToShow = displayName;
              } else {
                nameToShow = 'Unbekannt';
              }

              return LeaderboardEntry(
                userId: userId,
                name: nameToShow,
                steps: steps,
                isMe: userId == _myUserId,
              );
            }).toList();

            return LeaderboardSection(
              entries: entries,
              onEntryTap: (entry) {
                if (entry.userId == _myUserId) return;

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserCompareScreen(
                      otherUserId: entry.userId,
                      otherName: entry.name,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _leaveGroup() async {
    if (_isLeaving) return;

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text('${AppStrings.leaveGroup}?'),
              content: const Text(
                'Du verlässt diese Gruppe. Deine bisherigen Statistiken bleiben, '
                'aber du wirst hier nicht mehr im Leaderboard auftauchen.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(AppStrings.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Verlassen'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() {
      _isLeaving = true;
    });

    try {
      await _groupsService.leaveGroup(
        groupId: _group!.id,
        userId: _myUserId!,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // zurück zur Gruppenliste
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.error}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLeaving = false;
        });
      }
    }
  }
}
