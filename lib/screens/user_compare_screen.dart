import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';

class UserCompareScreen extends StatefulWidget {
  final String otherUserId;
  final String otherName;

  const UserCompareScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
  });

  @override
  State<UserCompareScreen> createState() => _UserCompareScreenState();
}

class _UserStats {
  final int today;
  final int yesterday;
  final int last7Days;
  final int bestDay;
  final int bestWeek;

  const _UserStats({
    required this.today,
    required this.yesterday,
    required this.last7Days,
    required this.bestDay,
    required this.bestWeek,
  });
}

class _UserCompareScreenState extends State<UserCompareScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _error;

  _UserStats? _me;
  _UserStats? _other;

  final String _meName = 'Du';
  late String _otherName;

  @override
  void initState() {
    super.initState();
    _otherName = widget.otherName;
    _loadData();
  }

  Future<void> _loadData() async {
    final me = _auth.currentUser;
    if (me == null) {
      setState(() {
        _error = AppStrings.noLoggedInUser;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateStart = today.subtract(const Duration(days: 90));

      final meFuture = _db
          .collection('dailySteps')
          .where('userId', isEqualTo: me.uid)
          .where('date', isGreaterThanOrEqualTo: dateStart)
          .orderBy('date')
          .get();

      final otherFuture = _db
          .collection('dailySteps')
          .where('userId', isEqualTo: widget.otherUserId)
          .where('date', isGreaterThanOrEqualTo: dateStart)
          .orderBy('date')
          .get();

      final otherUserFuture = _db
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      final results = await Future.wait([
        meFuture,
        otherFuture,
        otherUserFuture,
      ]);

      final meSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final otherSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final otherUserDoc = results[2] as DocumentSnapshot<Map<String, dynamic>>;

      final meStats = _computeStats(meSnap.docs);
      final otherStats = _computeStats(otherSnap.docs);

      // schöneren Namen für den anderen holen
      String otherName = _otherName;
      final otherData = otherUserDoc.data();
      if (otherData != null) {
        final username = (otherData['username'] as String?) ?? '';
        final displayName = (otherData['displayName'] as String?) ?? '';
        if (username.isNotEmpty) {
          otherName = username;
        } else if (displayName.isNotEmpty) {
          otherName = displayName;
        }
      }

      if (!mounted) return;
      setState(() {
        _me = meStats;
        _other = otherStats;
        _otherName = otherName;
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Fehler beim Laden des Vergleichs: $e');
      if (!mounted) return;
      setState(() {
        _error = AppStrings.errorLoadingData;
        _isLoading = false;
      });
    }
  }

  _UserStats _computeStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return const _UserStats(
        today: 0,
        yesterday: 0,
        last7Days: 0,
        bestDay: 0,
        bestWeek: 0,
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7Start = today.subtract(const Duration(days: 6));

    final Map<DateTime, int> byDay = {};

    for (final doc in docs) {
      final raw = doc.data()['date'];
      DateTime date;

      if (raw is Timestamp) {
        date = raw.toDate();
      } else if (raw is DateTime) {
        date = raw;
      } else {
        continue;
      }

      final dayKey = DateTime(date.year, date.month, date.day);
      final steps = (doc.data()['steps'] as num?)?.toInt() ?? 0;

      byDay.update(dayKey, (old) => old + steps, ifAbsent: () => steps);
    }

    int todaySteps = byDay[today] ?? 0;
    int yesterdaySteps = byDay[yesterday] ?? 0;

    int last7 = 0;
    int bestDay = 0;

    final Map<DateTime, int> byWeek = {};

    byDay.forEach((day, steps) {
      if (day.isAfter(last7Start.subtract(const Duration(days: 1))) &&
          !day.isAfter(today)) {
        last7 += steps;
      }

      if (steps > bestDay) bestDay = steps;

      // Wochenstart (Montag)
      final weekStart = day.subtract(Duration(days: day.weekday - 1));
      byWeek.update(weekStart, (old) => old + steps, ifAbsent: () => steps);
    });

    int bestWeek = 0;
    for (final v in byWeek.values) {
      if (v > bestWeek) bestWeek = v;
    }

    return _UserStats(
      today: todaySteps,
      yesterday: yesterdaySteps,
      last7Days: last7,
      bestDay: bestDay,
      bestWeek: bestWeek,
    );
  }

  String _formatSteps(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final meStats = _me;
    final otherStats = _other;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    Text(
                      AppStrings.comparison,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Avatare + VS
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.purple,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _meName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: const [
                          Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.pink,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _otherName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (_isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  )
                else if (meStats != null && otherStats != null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${AppStrings.stats} im Vergleich',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Header-Zeile der "Tabelle"
                            _buildRowHeader(_meName, _otherName),
                            const Divider(),
                            _buildRow(
                              label: '${AppStrings.steps} heute',
                              left: _formatSteps(meStats.today),
                              right: _formatSteps(otherStats.today),
                            ),
                            _buildRow(
                              label: '${AppStrings.steps} gestern',
                              left: _formatSteps(meStats.yesterday),
                              right: _formatSteps(otherStats.yesterday),
                            ),
                            _buildRow(
                              label: 'Letzte 7 Tage',
                              left: _formatSteps(meStats.last7Days),
                              right: _formatSteps(otherStats.last7Days),
                            ),
                            _buildRow(
                              label: 'Bester Tag',
                              left: _formatSteps(meStats.bestDay),
                              right: _formatSteps(otherStats.bestDay),
                            ),
                            _buildRow(
                              label: 'Beste Woche',
                              left: _formatSteps(meStats.bestWeek),
                              right: _formatSteps(otherStats.bestWeek),
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
    );
  }

  Widget _buildRowHeader(String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Metrik',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String left,
    required String right,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
