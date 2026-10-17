import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_logs/core/services/auth_service.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_spacing.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/utils/user_display_utils.dart';
import 'package:my_logs/core/widgets/app_snackbar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const sectionGap = SizedBox(height: 18.0);
    final user = ref.watch(authStateProvider).valueOrNull;
    final userEmail = UserDisplayUtils.getEmail(user);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.primary,
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          'Settings',
          style: AppTypography.headlineLgMobile.copyWith(color: AppColors.primary),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          _SettingsSection(title: 'Account', tiles: [
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              subtitle: userEmail,
              onTap: () => context.push('/profile'),
            ),
          ]),
          sectionGap,
          _SettingsSection(title: 'Preferences', tiles: [
            _SettingsTile(
              icon: Icons.dark_mode_outlined,
              label: 'Theme',
              subtitle: 'System Default',
              onTap: () {
                AppSnackBar.showInfo(
                  context,
                  'Theme automatically matches your device settings.',
                );
              },
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              subtitle: 'Local reminders & alarm alerts',
              onTap: () => context.go('/reminders'),
            ),
          ]),
          sectionGap,
          _SettingsSection(title: 'Data & Sync', tiles: [
            _SettingsTile(
              icon: Icons.cloud_done_outlined,
              label: 'Cloud Sync',
              subtitle: user != null ? 'Synced with Cloud Firestore' : 'Local Offline Mode',
              onTap: () {
                AppSnackBar.showInfo(
                  context,
                  user != null
                      ? 'All logs are automatically synchronized to your cloud account.'
                      : 'Sign in from Profile to back up your data to the cloud.',
                );
              },
            ),
          ]),
          sectionGap,
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/Logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Logspad', style: AppTypography.headlineMd.copyWith(color: AppColors.primary)),
                const SizedBox(height: 4),
                Text('Version 1.0.0', style: AppTypography.bodyMdOutline()),
                const SizedBox(height: 4),
                Text('Personal productivity & media journal',
                    style: AppTypography.bodyMdOutline()),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.tiles});
  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radius2Xl),
          ),
          child: Column(
            children: tiles.indexed.map((t) {
              final (i, tile) = t;
              return Column(
                children: [
                  tile,
                  if (i < tiles.length - 1)
                    const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.surfaceContainerHighest,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: AppTypography.bodyLg),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTypography.bodyMdOutline())
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.outlineVariant, size: 20),
      onTap: onTap,
    );
  }
}
