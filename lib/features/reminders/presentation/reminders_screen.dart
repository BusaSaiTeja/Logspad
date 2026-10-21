import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/utils/debouncer.dart';
import 'package:my_logs/core/widgets/empty_state.dart';
import 'package:my_logs/core/widgets/ui_state_views.dart';
import 'package:my_logs/features/reminders/application/reminder_providers.dart';
import 'package:my_logs/features/reminders/presentation/widgets/reminder_tile.dart';
import 'package:my_logs/core/widgets/drawer_menu_button.dart';
import 'package:my_logs/core/widgets/feature_more_options_button.dart';
import 'package:my_logs/core/widgets/app_snackbar.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(reminderListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: const DrawerMenuButton(tooltip: 'Open menu'),
        title: Text(
          'Reminders',
          style: AppTypography.headlineLgMobile.copyWith(color: AppColors.obsidian),
        ),
        centerTitle: false,
        actions: const [
          FeatureMoreOptionsButton(featureName: 'Reminders'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'reminders_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => SafeTap.run(() => context.push('/reminders/add')),
        child: const Icon(Icons.add_rounded),
      ),
      body: remindersAsync.when(
        loading: () => const ShimmerSkeletonList(
          itemCount: 4,
          cardHeight: 76,
        ),
        error: (err, _) => ErrorStateView(
          message: err.toString(),
          onRetry: () => ref.refresh(reminderListProvider),
        ),
        data: (reminders) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(reminderListProvider),
          child: reminders.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.65,
                      child: EmptyState(
                        icon: Icons.alarm_rounded,
                        title: 'No reminders set',
                        subtitle: 'Set reminders for your daily routines & tasks',
                        actionLabel: 'Add Reminder',
                        onAction: () => SafeTap.run(() => context.push('/reminders/add')),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  itemCount: reminders.length,
                  itemBuilder: (context, i) {
                    final r = reminders[i];
                    return ReminderTile(
                      reminder: r,
                      onToggle: () async {
                        try {
                          await ref.read(reminderListProvider.notifier).toggle(r.id);
                          if (context.mounted) {
                            AppSnackBar.showSuccess(
                              context,
                              r.isEnabled ? 'Reminder turned off' : 'Reminder turned on',
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackBar.showError(context, 'Failed to update reminder: $e');
                          }
                        }
                      },
                      onTap: () => SafeTap.run(() => context.push('/reminders/${r.id}/edit')),
                      onDelete: () async {
                        try {
                          await ref.read(reminderListProvider.notifier).delete(r.id);
                          if (context.mounted) {
                            AppSnackBar.showSuccess(context, 'Reminder deleted');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackBar.showError(context, 'Failed to delete reminder: $e');
                          }
                        }
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}
