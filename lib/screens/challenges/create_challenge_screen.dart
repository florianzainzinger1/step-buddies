import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:step_buddies/services/challenges_service.dart';
import 'package:step_buddies/services/friends_service.dart';
import 'package:step_buddies/models/challenge.dart';
import '../../l10n/app_strings.dart';
import '../../theme/theme_colors.dart';
import '../../theme/theme_service.dart';
import '../../widgets/race_track.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  // Step 1: Basics
  final _titleController = TextEditingController();
  int _durationDays = 7;
  // Startdatum standardmäßig auf HEUTE 00:00 setzen
  DateTime _startDate = DateTime(
    DateTime.now().year, 
    DateTime.now().month, 
    DateTime.now().day,
  );

  // Step 2: Participants
  final List<String> _selectedFriendIds = [];
  final Map<String, String> _friendNames = {}; // ID -> Name Cache

  // Step 3: Teams
  List<ChallengeTeam> _teams = [];
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.createChallenge,
          style: TextStyle(color: colors.textPrimary),
        ),
        backgroundColor: colors.cardBackground,
        elevation: 0,
        foregroundColor: colors.textPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildStepIndicator(colors),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Basics(colors, themeService.isDarkMode),
                  _buildStep2Participants(colors, themeService.isDarkMode),
                  _buildStep3Teams(colors, themeService.isDarkMode),
                ],
              ),
            ),
            _buildBottomBar(colors, themeService.isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: colors.cardBackground,
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? colors.success
                        : isCurrent
                            ? colors.primary
                            : colors.cardSoft,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: colors.primary.withOpacity(0.3), width: 3)
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : colors.textTertiary,
                            ),
                          ),
                  ),
                ),
                if (index < _totalSteps - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isCompleted ? colors.success : colors.cardSoft,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar(ThemeColors colors, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentStep--);
              },
              icon: Icon(Icons.arrow_back_rounded, color: colors.textSecondary, size: 20),
              label: Text(AppStrings.back, style: TextStyle(color: colors.textSecondary)),
            )
          else
            const SizedBox(width: 100),

          GestureDetector(
            onTap: _isLoading ? null : () {
              HapticFeedback.lightImpact();
              _onNextPressed();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isLoading
                      ? [colors.shimmer, colors.shimmer]
                      : [colors.primary, colors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: colors.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentStep == _totalSteps - 1 ? AppStrings.save : AppStrings.next,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentStep == _totalSteps - 1
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _onNextPressed() async {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    if (_currentStep == 0) {
      if (_titleController.text.isEmpty) {
        _showErrorSnackbar('Bitte Titel eingeben', colors);
        return;
      }
    } else if (_currentStep == 1) {
      if (_selectedFriendIds.isEmpty) {
        _showErrorSnackbar('Wähle mindestens einen Freund aus', colors);
        return;
      }
      if (_teams.isEmpty) {
        _initializeTeams();
      }
    } else if (_currentStep == 2) {
      await _saveChallenge();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep++);
  }

  void _showErrorSnackbar(String message, ThemeColors colors) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: colors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ================= Step 1: Basics =================

  Widget _buildStep1Basics(ThemeColors colors, bool isDarkMode) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Section
          _buildSectionHeader('Titel', Icons.title_rounded, colors),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _titleController,
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'z.B. Office Race',
                hintStyle: TextStyle(color: colors.textTertiary),
                prefixIcon: Icon(Icons.emoji_events_rounded, color: colors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Duration Section
          _buildSectionHeader('Dauer', Icons.timer_rounded, colors),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_durationDays',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tage',
                      style: TextStyle(
                        fontSize: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.cardSoft,
                    thumbColor: colors.primary,
                    overlayColor: colors.primary.withOpacity(0.2),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _durationDays.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _durationDays = val.toInt());
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 Tag', style: TextStyle(fontSize: 12, color: colors.textTertiary)),
                    Text('30 Tage', style: TextStyle(fontSize: 12, color: colors.textTertiary)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Start Date Section
          _buildSectionHeader('Startdatum', Icons.calendar_today_rounded, colors),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: colors.primary,
                        onPrimary: Colors.white,
                        surface: colors.cardBackground,
                        onSurface: colors.textPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _startDate = DateTime(picked.year, picked.month, picked.day);
                });
              }
            },
            child: Container(
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
                    child: Icon(Icons.calendar_today_rounded, color: colors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE', 'de_DE').format(_startDate),
                          style: TextStyle(fontSize: 13, color: colors.textSecondary),
                        ),
                        Text(
                          DateFormat('dd. MMMM yyyy', 'de_DE').format(_startDate),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_rounded, color: colors.textTertiary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeColors colors) {
    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ================= Step 2: Participants =================

  Widget _buildStep2Participants(ThemeColors colors, bool isDarkMode) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) return const SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FriendsService.instance.watchFriends(myId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colors.primary));
        }

        final friends = snapshot.data ?? [];
        for (var f in friends) {
          _friendNames[f['id']] = f['username'] ?? 'Unbekannt';
        }

        if (friends.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.people_outline_rounded, size: 48, color: colors.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Noch keine Freunde',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Füge zuerst Freunde hinzu, um eine Challenge zu starten.',
                    style: TextStyle(fontSize: 14, color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Selection counter
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedFriendIds.length} Teilnehmer ausgewählt',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  final id = friend['id'];
                  final isSelected = _selectedFriendIds.contains(id);
                  final username = friend['username'] ?? 'Unbekannt';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? colors.primary : colors.cardBorder.withOpacity(0.5),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _selectedFriendIds.remove(id);
                            } else {
                              _selectedFriendIds.add(id);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(colors: [colors.primary, colors.secondary])
                                      : null,
                                  color: isSelected ? null : colors.cardSoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    username[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  username,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected ? colors.primary : colors.cardSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ================= Step 3: Teams =================

  // Track selected animals per team
  Map<String, RaceAnimal> _teamAnimals = {};

  void _initializeTeams() {
    final myId = FirebaseAuth.instance.currentUser!.uid;
    final allIds = [myId, ..._selectedFriendIds];

    final mid = (allIds.length / 2).ceil();
    final team1Ids = allIds.sublist(0, mid);
    final team2Ids = allIds.sublist(mid);

    _teams = [
      ChallengeTeam(id: 'team_1', name: 'Team Alpha', memberIds: team1Ids, colorIndex: 0),
      ChallengeTeam(id: 'team_2', name: 'Team Beta', memberIds: team2Ids, colorIndex: 1),
    ];

    // Assign default animals
    _teamAnimals = {
      'team_1': RaceAnimal.rabbit,
      'team_2': RaceAnimal.cheetah,
    };
  }

  void _shuffleTeams() {
    final myId = FirebaseAuth.instance.currentUser!.uid;
    final allIds = [myId, ..._selectedFriendIds]..shuffle();

    final mid = (allIds.length / 2).ceil();
    final team1Ids = allIds.sublist(0, mid);
    final team2Ids = allIds.sublist(mid);

    setState(() {
      _teams = [
        ChallengeTeam(id: 'team_1', name: 'Team Alpha', memberIds: team1Ids, colorIndex: 0),
        ChallengeTeam(id: 'team_2', name: 'Team Beta', memberIds: team2Ids, colorIndex: 1),
      ];
    });
  }

  Widget _buildStep3Teams(ThemeColors colors, bool isDarkMode) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    String getName(String id) {
      if (id == myId) return 'Du';
      return _friendNames[id] ?? 'Unbekannt';
    }

    final teamColors = [colors.primary, colors.secondary, colors.accent, colors.success];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Shuffle button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _shuffleTeams();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.cardBorder.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shuffle_rounded, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.shuffleTeams,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Teams
          ..._teams.asMap().entries.map((entry) {
            final index = entry.key;
            final team = entry.value;
            final teamColor = teamColors[index % teamColors.length];
            final animal = _teamAnimals[team.id] ?? RaceAnimal.values[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: teamColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Team header with animal
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: teamColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(19),
                        topRight: Radius.circular(19),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Animal avatar
                        GestureDetector(
                          onTap: () => _showAnimalPicker(team.id, colors),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: teamColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: teamColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(animal.emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                team.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                '${team.memberIds.length} Mitglieder',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_rounded, color: colors.textTertiary, size: 20),
                          onPressed: () => _editTeamName(team, colors),
                        ),
                      ],
                    ),
                  ),

                  // Members
                  ...team.memberIds.map((memberId) => Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: colors.cardBorder.withOpacity(0.3)),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.cardSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            getName(memberId)[0].toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        getName(memberId),
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.swap_horiz_rounded, color: colors.primary, size: 22),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _moveMember(memberId, index);
                        },
                        tooltip: 'Team wechseln',
                      ),
                    ),
                  )),
                ],
              ),
            );
          }),

          // Tip
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: colors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tippe auf das Tier-Icon um das Team-Maskottchen zu ändern',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAnimalPicker(String teamId, ThemeColors colors) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Maskottchen wählen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            AnimalSelector(
              selected: _teamAnimals[teamId],
              onSelect: (animal) {
                HapticFeedback.selectionClick();
                setState(() => _teamAnimals[teamId] = animal);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _editTeamName(ChallengeTeam team, ThemeColors colors) {
    final controller = TextEditingController(text: team.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Team umbenennen', style: TextStyle(color: colors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Neuer Name',
            hintStyle: TextStyle(color: colors.textTertiary),
            filled: true,
            fillColor: colors.cardSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  final idx = _teams.indexWhere((t) => t.id == team.id);
                  if (idx >= 0) {
                    _teams[idx] = ChallengeTeam(
                      id: team.id,
                      name: controller.text,
                      memberIds: team.memberIds,
                      colorIndex: team.colorIndex,
                    );
                  }
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _moveMember(String memberId, int currentTeamIndex) {
    // Einfache Logik: Verschiebe in das nächste Team (bei 2 Teams einfach das andere)
    final nextTeamIndex = (currentTeamIndex + 1) % _teams.length;
    
    setState(() {
      _teams[currentTeamIndex].memberIds.remove(memberId);
      _teams[nextTeamIndex].memberIds.add(memberId);
    });
  }

  // ================= Save =================

  Future<void> _saveChallenge() async {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    setState(() => _isLoading = true);
    try {
      final myId = FirebaseAuth.instance.currentUser!.uid;

      await ChallengesService.instance.createChallenge(
        title: _titleController.text,
        adminId: myId,
        startDate: _startDate,
        durationDays: _durationDays,
        teams: _teams,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text(AppStrings.challengeCreated),
            ],
          ),
          backgroundColor: colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Fehler: $e', colors);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
