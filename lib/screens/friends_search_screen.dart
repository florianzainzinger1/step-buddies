// lib/screens/friends_search_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';
import '../services/friends_service.dart';

class FriendsSearchScreen extends StatefulWidget {
  final String? initialSearchId;

  const FriendsSearchScreen({super.key, this.initialSearchId});

  @override
  State<FriendsSearchScreen> createState() => _FriendsSearchScreenState();
}

class _FriendsSearchScreenState extends State<FriendsSearchScreen> {
  final _auth = FirebaseAuth.instance;
  final _friendsService = FriendsService.instance;
  
  final _searchController = TextEditingController();
  final _debouncer = _Debouncer(milliseconds: 300);

  bool _isSearching = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoadingSuggestions = true;
  String? _myUserId;

  // Tracks which users have pending actions
  final Set<String> _pendingActions = {};

  @override
  void initState() {
    super.initState();
    _myUserId = _auth.currentUser?.uid;
    
    // Live-Suche beim Tippen
    _searchController.addListener(_onSearchChanged);
    
    // Initial ID Search (aus Deep Link)
    if (widget.initialSearchId != null) {
      _searchById(widget.initialSearchId!);
    } else {
      // Vorschläge laden nur wenn keine Initiale Suche
      _loadSuggestions();
    }
  }

  Future<void> _searchById(String userId) async {
    setState(() => _isSearching = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final user = {
          'id': userDoc.id,
          'username': data['username'] ?? '',
          'displayName': data['displayName'] ?? '',
          'status': 'none', 
        };
        
        if (mounted) {
           setState(() {
             _results = [user];
             _isSearching = false; 
           });
        }
      }
    } catch (e) {
      debugPrint('Deep Link Search Error: $e');
    }
    
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _loadSuggestions() async {
    if (_myUserId == null) return;
    
    try {
      final suggestions = await _friendsService.getFriendSuggestions(_myUserId!);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    if (query.length < 2) {
      if (_results.isNotEmpty) {
        setState(() {
          _results = [];
          _error = null;
        });
      }
      return;
    }

    _debouncer.run(() => _search());
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2 || _myUserId == null) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _friendsService.searchUsersWithStatus(
        query,
        currentUserId: _myUserId!,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Fehler bei der Freundesuche: $e');
      if (mounted) {
        setState(() {
          _error = AppStrings.searchFailed;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendRequest(String userId) async {
    if (_myUserId == null || _pendingActions.contains(userId)) return;

    setState(() {
      _pendingActions.add(userId);
    });

    try {
      await _friendsService.sendFriendRequest(
        fromUserId: _myUserId!,
        toUserId: userId,
      );

      // Update status in results
      if (mounted) {
        setState(() {
          for (final user in _results) {
            if (user['id'] == userId) {
              user['status'] = 'pending_outgoing';
              break;
            }
          }
          _pendingActions.remove(userId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anfrage gesendet! ✉️')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pendingActions.remove(userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    }
  }

  Future<void> _acceptRequest(String userId) async {
    if (_myUserId == null || _pendingActions.contains(userId)) return;

    setState(() {
      _pendingActions.add(userId);
    });

    try {
      // Find the request from this user
      final requests = await _friendsService.watchIncomingRequests(_myUserId!).first;
      final request = requests.firstWhere(
        (r) => r.fromUserId == userId,
        orElse: () => throw Exception('Anfrage nicht gefunden'),
      );

      await _friendsService.acceptFriendRequest(request.id);

      if (mounted) {
        setState(() {
          for (final user in _results) {
            if (user['id'] == userId) {
              user['status'] = 'friend';
              break;
            }
          }
          _pendingActions.remove(userId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anfrage angenommen! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pendingActions.remove(userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      AppStrings.searchFriends,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Suchfeld
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: AppStrings.searchPlaceholder,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _results = [];
                                  });
                                },
                              )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Hinweis oder Vorschläge
              if (_searchController.text.isEmpty) ...[
                if (_isLoadingSuggestions)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_suggestions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.peopleYouMayKnow,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        return _buildSuggestionTile(_suggestions[index]);
                      },
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      AppStrings.searchHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),

              // Ergebnisse
              Expanded(
                child: _results.isEmpty && !_isSearching && _searchController.text.length >= 2
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.noResults,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return _buildUserTile(user);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final username = (user['username'] as String?) ?? '';
    final displayName = (user['displayName'] as String?) ?? '';
    final status = user['status'] as String? ?? 'none';
    final isPending = _pendingActions.contains(userId);

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
            backgroundColor: _getAvatarColor(status),
            child: Icon(
              _getAvatarIcon(status),
              color: _getAvatarIconColor(status),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username.isNotEmpty ? username : displayName,
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
          _buildActionButton(userId, status, isPending),
        ],
      ),
    );
  }

  Widget _buildActionButton(String userId, String status, bool isPending) {
    if (isPending) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (status) {
      case 'friend':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check, size: 16, color: Colors.green),
              SizedBox(width: 4),
              Text(
                'Freund',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case 'pending_outgoing':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Angefragt',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        );

      case 'pending_incoming':
        return ElevatedButton(
          onPressed: () => _acceptRequest(userId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Annehmen', style: TextStyle(fontSize: 13)),
        );

      default: // none
        return ElevatedButton(
          onPressed: () => _sendRequest(userId),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Anfragen', style: TextStyle(fontSize: 13)),
        );
    }
  }

  Color _getAvatarColor(String status) {
    switch (status) {
      case 'friend':
        return Colors.green.withOpacity(0.2);
      case 'pending_outgoing':
      case 'pending_incoming':
        return AppColors.purple.withOpacity(0.2);
      default:
        return AppColors.cardSoft;
    }
  }

  IconData _getAvatarIcon(String status) {
    switch (status) {
      case 'friend':
        return Icons.people;
      case 'pending_outgoing':
        return Icons.hourglass_empty;
      case 'pending_incoming':
        return Icons.person_add;
      default:
        return Icons.person;
    }
  }

  Color _getAvatarIconColor(String status) {
    switch (status) {
      case 'friend':
        return Colors.green;
      case 'pending_outgoing':
      case 'pending_incoming':
        return AppColors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildSuggestionTile(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final username = (user['username'] as String?) ?? '';
    final displayName = (user['displayName'] as String?) ?? '';
    final mutualFriends = user['mutualFriends'] as int? ?? 0;
    final isPending = _pendingActions.contains(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purple.withOpacity(0.2),
          width: 1,
        ),
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
            backgroundColor: AppColors.purple.withOpacity(0.15),
            child: const Icon(
              Icons.person_add_outlined,
              color: AppColors.purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username.isNotEmpty ? username : displayName,
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
                Text(
                  AppStrings.mutualFriends(mutualFriends),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.purple.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isPending)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton(
              onPressed: () => _sendRequest(userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppStrings.sendRequest, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// Simple debouncer for search
class _Debouncer {
  final int milliseconds;
  _Debouncer({required this.milliseconds});

  VoidCallback? _action;
  bool _isDisposed = false;

  void run(VoidCallback action) {
    _action = action;
    Future.delayed(Duration(milliseconds: milliseconds), () {
      if (!_isDisposed && _action != null) {
        _action!();
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    _action = null;
  }
}
