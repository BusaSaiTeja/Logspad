import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:my_logs/core/services/auth_service.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_spacing.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/utils/provider_reset_utils.dart';
import 'package:my_logs/core/utils/user_display_utils.dart';
import 'package:my_logs/core/widgets/app_confirmation_dialog.dart';
import 'package:my_logs/core/widgets/app_snackbar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final displayName = UserDisplayUtils.getDisplayName(user);
    final userEmail = UserDisplayUtils.getEmail(user);
    final creationTime = user?.metadata.creationTime != null
        ? DateFormat('MMMM d, y').format(user!.metadata.creationTime!)
        : 'Active Member';

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
          'Profile',
          style: AppTypography.headlineLgMobile.copyWith(color: AppColors.primary),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        children: [
          // ── Hero Gradient Profile Card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1B4B), // Deep Slate Indigo
                  Color(0xFF312E81),
                  Color(0xFF4338CA),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radius2Xl),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF312E81).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          UserDisplayUtils.getInitials(displayName),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4ADE80), // Pulsing green dot
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Cloud Firestore Connected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Synced',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Profile Details Card ──────────────────────────────────────────
          Text('Profile Information', style: AppTypography.labelMdVariant()),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radius2Xl),
              border: Border.all(color: AppColors.surfaceContainerHighest),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildProfileRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member Since',
                  value: creationTime,
                ),
              ],
            ),
          ),
          // ── Settings Action ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined, size: 18, color: AppColors.primary),
              label: const Text(
                'Settings & Preferences',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Log Out Action ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogOut(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
              label: const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFECACA)),
                backgroundColor: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Delete Account Action (Store Requirement) ──────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton.icon(
              onPressed: () => _confirmDeleteAccount(context, ref),
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Color(0xFFDC2626)),
              label: const Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                ),
              ),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Text(
            label,
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogOut(BuildContext context, WidgetRef ref) async {
    await showLogoutConfirmationDialog(
      context: context,
      ref: ref,
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Delete Account',
      icon: Icons.delete_forever_rounded,
      message:
          'Are you sure you want to permanently delete your account and all associated logs, tasks, reminders, and workspaces? This action cannot be undone.',
      confirmLabel: 'Delete Permanently',
      confirmColor: const Color(0xFFDC2626),
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final authService = ref.read(authServiceProvider);
    String? password;

    // Prompt for password re-auth upfront if registered with email/password
    if (authService.isPasswordUser) {
      password = await showPasswordConfirmationDialog(
        context: context,
        title: 'Confirm Password',
        message:
            'For security, please enter your current password to authorize permanent account deletion.',
        confirmLabel: 'Confirm & Delete',
        icon: Icons.lock_outline_rounded,
      );
      if (password == null || password.isEmpty) return;
      if (!context.mounted) return;
    }

    // Show non-dismissible loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Re-authenticate upfront before modifying any user records in Firestore
      if (authService.isPasswordUser && password != null) {
        await authService.reauthenticateWithPassword(password);
      } else if (authService.isGoogleUser) {
        await authService.reauthenticateWithGoogle();
      }

      resetAllDomainProviders(ref);
      await authService.deleteAccount();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      context.go('/');
      AppSnackBar.showSuccess(
        context,
        'Your account and all associated data have been permanently deleted.',
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      if (e.code == 'wrong-password') {
        AppSnackBar.showError(
          context,
          'Incorrect password. Account deletion canceled.',
        );
      } else if (e.code == 'canceled') {
        AppSnackBar.showInfo(
          context,
          'Google re-authentication was canceled. Account deletion aborted.',
        );
      } else if (e.code == 'requires-recent-login') {
        AppSnackBar.showError(
          context,
          'For security, deleting your account requires a recent sign-in. Please log out, sign in again, and retry.',
          duration: const Duration(seconds: 5),
        );
      } else {
        AppSnackBar.showError(
          context,
          'Failed to delete account: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      AppSnackBar.showError(
        context,
        'An unexpected error occurred: $e',
      );
    }
  }
}
