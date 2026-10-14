import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/theme_service.dart';
import '../widgets/animated_sky_background.dart';
import '../services/auth_service.dart';
import '../l10n/app_strings.dart';
import 'sign_in_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showOnGlobalLeaderboard = false;
  bool _isLoadingGlobalPref = true;

  @override
  void initState() {
    super.initState();
    _loadGlobalLeaderboardPref();
  }

  Future<void> _loadGlobalLeaderboardPref() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final showGlobal = doc.data()?['showOnGlobalLeaderboard'] ?? false;

    if (!mounted) return;
    setState(() {
      _showOnGlobalLeaderboard = showGlobal == true;
      _isLoadingGlobalPref = false;
    });
  }

  Future<void> _toggleGlobalLeaderboard(bool value) async {
    setState(() => _showOnGlobalLeaderboard = value);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'showOnGlobalLeaderboard': value,
    });

    // Pop with result to trigger HomeScreen refresh
    if (mounted) {
      Navigator.of(context).pop(true);
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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.settings,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Design / Theme
                    _buildSettingsTile(
                      icon: Icons.palette_outlined,
                      title: AppStrings.design,
                      subtitle: _getThemeLabel(themeService.mode),
                      onTap: _showThemeDialog,
                    ),

                    Divider(height: 1, color: colors.textSecondary.withOpacity(0.2)),

                    // Sprache
                    _buildSettingsTile(
                      icon: Icons.language_outlined,
                      title: AppStrings.language,
                      subtitle: AppStrings.german,
                      onTap: _showLanguageDialog,
                    ),

                    Divider(height: 1, color: colors.textSecondary.withOpacity(0.2)),

                    // Benachrichtigungen
                    _buildSettingsTile(
                      icon: Icons.notifications_outlined,
                      title: AppStrings.notifications,
                      subtitle: AppStrings.notificationsSubtitle,
                      onTap: () => _showComingSoon(AppStrings.notifications),
                    ),

                    Divider(height: 1, color: colors.textSecondary.withOpacity(0.2)),

                    // E-Mail Notifications
                    _buildSettingsTile(
                      icon: Icons.email_outlined,
                      title: AppStrings.emailNotifications,
                      subtitle: AppStrings.emailNotificationsSubtitle,
                      onTap: () => _showComingSoon(AppStrings.emailNotifications),
                    ),
                    Divider(height: 1, color: colors.textSecondary.withOpacity(0.2)),

                    // Global Leaderboard
                    _buildSettingsToggle(
                      icon: Icons.public_outlined,
                      title: 'Globales Leaderboard',
                      subtitle: 'Im weltweiten Ranking erscheinen',
                      value: _showOnGlobalLeaderboard,
                      isLoading: _isLoadingGlobalPref,
                      onChanged: _toggleGlobalLeaderboard,
                    ),

                    Divider(height: 1, color: colors.textSecondary.withOpacity(0.2)),

                    // Health Data
                    _buildSettingsTile(
                      icon: Icons.health_and_safety_outlined,
                      title: AppStrings.healthData,
                      subtitle: AppStrings.healthDataSubtitle,
                      onTap: _showHealthDataInfo,
                    ),

                    Divider(height: 1, color: colors.textSecondary.withOpacity(0.2)),

                    // Legal
                    _buildSettingsTile(
                      icon: Icons.gavel_outlined,
                      title: AppStrings.legal,
                      subtitle: AppStrings.legalSubtitle,
                      onTap: _showLegalMenu,
                    ),

                    Divider(height: 1, color: colors.textSecondary.withOpacity(0.2)),

                    // About
                    _buildSettingsTile(
                      icon: Icons.info_outline,
                      title: AppStrings.about,
                      subtitle: AppStrings.aboutSubtitle,
                      onTap: _showAbout,
                    ),

                    const SizedBox(height: 24),
                    Divider(height: 1, color: colors.textSecondary.withOpacity(0.2)),
                    const SizedBox(height: 8),

                    // Delete Account
                    _buildSettingsTile(
                      icon: Icons.delete_forever_outlined,
                      title: AppStrings.deleteAccount,
                      subtitle: AppStrings.deleteAccountSubtitle,
                      onTap: _showDeleteAccountDialog,
                      isDestructive: true,
                    ),

                    const SizedBox(height: 8),

                    // Logout
                    _buildSettingsTile(
                      icon: Icons.logout,
                      title: AppStrings.signOut,
                      subtitle: 'Aus dem Account ausloggen',
                      onTap: _logout,
                      isDestructive: true,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;
    final color = isDestructive ? Colors.red : colors.textPrimary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDestructive ? Colors.red.shade300 : colors.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? Colors.red.shade300 : colors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSettingsToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLoading = false,
  }) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: colors.primary),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: colors.textSecondary,
        ),
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: value,
              activeColor: colors.primary,
              onChanged: onChanged,
            ),
    );
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.auto:
        return 'Automatisch (Tageszeit)';
      case AppThemeMode.alwaysLight:
        return AppStrings.designLight;
      case AppThemeMode.alwaysDark:
        return AppStrings.designDark;
    }
  }

  void _showThemeDialog() {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(
          '${AppStrings.design} auswahlen',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOptionTile(
              title: 'Automatisch (Tageszeit)',
              subtitle: 'Passt sich an die Uhrzeit an',
              icon: Icons.auto_awesome,
              isSelected: themeService.mode == AppThemeMode.auto,
              onTap: () {
                themeService.setMode(AppThemeMode.auto);
                Navigator.pop(dialogContext);
              },
            ),
            const SizedBox(height: 8),
            _ThemeOptionTile(
              title: AppStrings.designLight,
              subtitle: 'Immer helles Design',
              icon: Icons.light_mode,
              isSelected: themeService.mode == AppThemeMode.alwaysLight,
              onTap: () {
                themeService.setMode(AppThemeMode.alwaysLight);
                Navigator.pop(dialogContext);
              },
            ),
            const SizedBox(height: 8),
            _ThemeOptionTile(
              title: AppStrings.designDark,
              subtitle: 'Immer dunkles Design',
              icon: Icons.dark_mode,
              isSelected: themeService.mode == AppThemeMode.alwaysDark,
              onTap: () {
                themeService.setMode(AppThemeMode.alwaysDark);
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature ${AppStrings.comingSoon}')),
    );
  }

  void _showLanguageDialog() {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(
          '${AppStrings.language} auswahlen',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('\uD83C\uDDE9\uD83C\uDDEA', style: TextStyle(fontSize: 24)),
              title: Text(AppStrings.german, style: TextStyle(color: colors.textPrimary)),
              trailing: Icon(Icons.check, color: colors.primary),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Text('\uD83C\uDDEC\uD83C\uDDE7', style: TextStyle(fontSize: 24)),
              title: Text(AppStrings.english, style: TextStyle(color: colors.textSecondary)),
              subtitle: Text(AppStrings.comingSoon, style: TextStyle(color: colors.textSecondary)),
              enabled: false,
              onTap: null,
            ),
            ListTile(
              leading: const Text('\uD83C\uDDEB\uD83C\uDDF7', style: TextStyle(fontSize: 24)),
              title: Text('Francais', style: TextStyle(color: colors.textSecondary)),
              subtitle: Text(AppStrings.comingSoon, style: TextStyle(color: colors.textSecondary)),
              enabled: false,
              onTap: null,
            ),
            ListTile(
              leading: const Text('\uD83C\uDDEA\uD83C\uDDF8', style: TextStyle(fontSize: 24)),
              title: Text('Espanol', style: TextStyle(color: colors.textSecondary)),
              subtitle: Text(AppStrings.comingSoon, style: TextStyle(color: colors.textSecondary)),
              enabled: false,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  void _showHealthDataInfo() {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(AppStrings.healthData, style: TextStyle(color: colors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.healthDataTitle,
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(AppStrings.healthDataInfo, style: TextStyle(color: colors.textSecondary)),
              const SizedBox(height: 16),
              Text(
                AppStrings.permissionsTitle,
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(AppStrings.permissionsInfo, style: TextStyle(color: colors.textSecondary)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.understood),
          ),
        ],
      ),
    );
  }

  void _showLegalMenu() {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.legal,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.description_outlined, color: colors.textPrimary),
              title: Text(AppStrings.termsAndConditions, style: TextStyle(color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showLegalDocument(AppStrings.termsAndConditions,
                  AppStrings.termsPlaceholder);
              },
            ),
            ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: colors.textPrimary),
              title: Text(AppStrings.privacyPolicy, style: TextStyle(color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showLegalDocument(AppStrings.privacyPolicy,
                  AppStrings.privacyPlaceholder);
              },
            ),
            ListTile(
              leading: Icon(Icons.copyright_outlined, color: colors.textPrimary),
              title: Text(AppStrings.copyright, style: TextStyle(color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showLegalDocument(AppStrings.copyright,
                  AppStrings.copyrightText);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLegalDocument(String title, String content) {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(title, style: TextStyle(color: colors.textPrimary)),
        content: SingleChildScrollView(
          child: Text(content, style: TextStyle(color: colors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.close),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(AppStrings.aboutTitle, style: TextStyle(color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.version, style: TextStyle(color: colors.textPrimary)),
            const SizedBox(height: 12),
            Text(AppStrings.aboutDescription, style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 12),
            Text(
              AppStrings.aboutFooter,
              style: TextStyle(fontStyle: FontStyle.italic, color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.ok),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text('${AppStrings.deleteAccount}?', style: TextStyle(color: colors.textPrimary)),
        content: Text(AppStrings.deleteAccountConfirm, style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${AppStrings.deleteAccount} ${AppStrings.comingSoon}')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Loschen'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final themeService = context.read<ThemeService>();
    final colors = themeService.colors;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text('${AppStrings.signOut}?', style: TextStyle(color: colors.textPrimary)),
        content: Text(AppStrings.signOutConfirm, style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.signOut),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (_) => false,
      );
    }
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withOpacity(0.1) : colors.cardSoft,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: colors.primary, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
