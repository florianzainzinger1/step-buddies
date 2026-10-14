// lib/screens/friends_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';
import '../services/friends_service.dart';
import 'friends_search_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _friendsService = FriendsService.instance;

  late TabController _tabController;
  late String _userId;

  List<Map<String, dynamic>> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];

  bool _isLoadingFriends = true;
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userId = _auth.currentUser?.uid ?? '';
    _loadData();
    _setupStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendsService.getFriendsWithProfiles(_userId);
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  void _setupStreams() {
    // Eingehende Anfragen
    _friendsService.watchIncomingRequests(_userId).listen(
      (requests) {
        if (mounted) {
          setState(() {
            _incomingRequests = requests;
            _isLoadingRequests = false;
          });
        }
      },
      onError: (e) {
        // ignore: avoid_print
        print('Fehler beim Laden eingehender Anfragen: $e');
        if (mounted) {
          setState(() {
            _isLoadingRequests = false;
          });
        }
      },
    );

    // Ausgehende Anfragen
    _friendsService.watchOutgoingRequests(_userId).listen(
      (requests) {
        if (mounted) {
          setState(() {
            _outgoingRequests = requests;
          });
        }
      },
      onError: (e) {
        // ignore: avoid_print
        print('Fehler beim Laden ausgehender Anfragen: $e');
      },
    );
  }

  Future<void> _removeFriend(String friendId, String friendName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.removeFriendTitle),
        content: Text(
          AppStrings.removeFriendConfirm(friendName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.remove),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _friendsService.removeFriend(userId: _userId, friendId: friendId);
      await _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.friendWasRemoved(friendName))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    try {
      await _friendsService.acceptFriendRequest(request.id);
      await _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${request.fromUsername ?? "Anfrage"} angenommen! 🎉',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    }
  }

  Future<void> _declineRequest(FriendRequest request) async {
    try {
      await _friendsService.declineFriendRequest(request.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    }
  }

  Future<void> _cancelRequest(FriendRequest request) async {
    try {
      await _friendsService.cancelFriendRequest(request.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestCount = _incomingRequests.length;

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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.friends,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    // Suche Button
                    IconButton(
                      icon: const Icon(Icons.person_add_outlined),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FriendsSearchScreen(),
                          ),
                        ).then((_) => _loadFriends());
                      },
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.purple,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tabs: [
                    Tab(
                      child: Text(
                        '${AppStrings.friends} (${_friends.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Anfragen',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (requestCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.purple,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$requestCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFriendsList(),
                    _buildRequestsList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.noFriendsYet,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FriendsSearchScreen(),
                  ),
                ).then((_) => _loadFriends());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.person_add),
              label: Text(AppStrings.searchFriends),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final friendId = friend['id'] as String;
          final username = friend['username'] as String? ?? '';
          final displayName = friend['displayName'] as String? ?? '';
          final name = username.isNotEmpty ? username : displayName;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.purple.withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (displayName.isNotEmpty && username.isNotEmpty)
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  color: Colors.red.shade300,
                  onPressed: () => _removeFriend(friendId, name),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_incomingRequests.isEmpty && _outgoingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Keine Anfragen',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Eingehende Anfragen
        if (_incomingRequests.isNotEmpty) ...[
          const Text(
            'Eingehende Anfragen',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ..._incomingRequests.map((request) => _buildIncomingRequestTile(request)),
          const SizedBox(height: 16),
        ],

        // Ausgehende Anfragen
        if (_outgoingRequests.isNotEmpty) ...[
          const Text(
            'Gesendete Anfragen',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ..._outgoingRequests.map((request) => _buildOutgoingRequestTile(request)),
        ],
      ],
    );
  }

  Widget _buildIncomingRequestTile(FriendRequest request) {
    final name = request.fromUsername ?? request.fromDisplayName ?? AppStrings.unknown;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.purple.withOpacity(0.2),
            child: const Icon(Icons.person_add, color: AppColors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  AppStrings.wantsToBeYourFriend,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Accept
          IconButton(
            icon: const Icon(Icons.check_circle),
            color: Colors.green,
            iconSize: 28,
            onPressed: () => _acceptRequest(request),
          ),
          // Decline
          IconButton(
            icon: const Icon(Icons.cancel),
            color: Colors.red.shade300,
            iconSize: 28,
            onPressed: () => _declineRequest(request),
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingRequestTile(FriendRequest request) {
    final name = request.toUsername ?? request.toDisplayName ?? AppStrings.unknown;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.textSecondary.withOpacity(0.2),
            child: const Icon(Icons.hourglass_empty, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  AppStrings.waitingForResponse,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _cancelRequest(request),
            child: Text(
              AppStrings.cancelRequest,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
