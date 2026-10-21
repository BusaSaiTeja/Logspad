import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/widgets/app_confirmation_dialog.dart';
import 'package:my_logs/core/widgets/drawer_menu_button.dart';
import 'package:my_logs/features/home/presentation/widgets/home_shimmer_skeleton.dart';
import 'package:my_logs/features/home/presentation/widgets/home_stat_card.dart';
import 'package:my_logs/features/notes/application/note_providers.dart';
import 'package:my_logs/features/reminders/application/reminder_providers.dart';
import 'package:my_logs/features/tasks/application/task_providers.dart';
import 'package:my_logs/features/watch/application/media_providers.dart';
import 'package:my_logs/features/workspaces/application/workspace_providers.dart';

/// Minimal dashboard centered on the Bento hero overview.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWs = ref.watch(activeWorkspaceProvider);
    final enabledKeys = activeWs?.enabledFeatures ?? const ['notes', 'tasks', 'reminders'];

    final tasksAsync = ref.watch(taskListProvider);
    final remindersAsync = ref.watch(reminderListProvider);
    final notesAsync = ref.watch(noteListProvider);
    final mediaAsync = ref.watch(mediaListProvider);

    // Initial loading guard: render animated shimmer skeleton rather than blank screen
    final isInitialLoading = (tasksAsync.isLoading && !tasksAsync.hasValue) ||
        (remindersAsync.isLoading && !remindersAsync.hasValue) ||
        (notesAsync.isLoading && !notesAsync.hasValue) ||
        (mediaAsync.isLoading && !mediaAsync.hasValue);

    final allTasks = ref.watch(workspaceFilteredTasksProvider);
    final todayTasks = ref.watch(todayTasksProvider);
    final todayReminders = ref.watch(todayRemindersProvider);

    final notes = ref.watch(workspaceFilteredNotesProvider).valueOrNull ?? [];
    final continueWatching = ref.watch(continueWatchingProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showAppConfirmationDialog(
          context: context,
          title: 'Exit App',
          message: 'Are you sure you want to exit LogsPad?',
          confirmLabel: 'Exit',
          icon: Icons.exit_to_app_rounded,
          confirmColor: AppColors.primary,
          isDestructive: false,
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: const DrawerMenuButton(tooltip: 'Workspace Menu'),
          title: Text(
            'Home',
            style: AppTypography.headlineLgMobile.copyWith(color: AppColors.obsidian),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Reminders',
              color: AppColors.onSurfaceVariant,
              onPressed: () => context.go('/reminders'),
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Profile',
              color: AppColors.onSurfaceVariant,
              onPressed: () => context.push('/profile'),
            ),
          ],
        ),
        body: isInitialLoading
            ? const HomeShimmerSkeleton()
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(taskListProvider);
                  ref.invalidate(reminderListProvider);
                  ref.invalidate(noteListProvider);
                  ref.invalidate(mediaListProvider);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  children: [
                    // ── Asymmetric Bento Hero Overview ─────────────────────────
                    Builder(
                      builder: (context) {
                        final bentoHeight =
                            MediaQuery.textScalerOf(context).scale(150.0).clamp(150.0, 195.0);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hero Focal Card: Today's Focus
                            Expanded(
                              flex: 11,
                              child: SizedBox(
                                height: bentoHeight,
                                child: HomeStatCard(
                                  value: '${todayTasks.length}',
                                  label: todayTasks.isEmpty
                                      ? (allTasks.isEmpty ? 'No tasks yet' : 'All done for today')
                                      : 'Active tasks today',
                                  icon: Icons.check_circle_outline_rounded,
                                  color: AppColors.primaryContainer,
                                  eyebrow: "Today's Focus",
                                  isHero: true,
                                  onTap: () => context.go('/tasks'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Right Stacked Micro Cards
                            Expanded(
                              flex: 9,
                              child: SizedBox(
                                height: bentoHeight,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: HomeStatCard(
                                        value: '${todayReminders.length}',
                                        label: 'Reminders',
                                        icon: Icons.alarm_rounded,
                                        color: AppColors.tertiaryContainer,
                                        onTap: () => context.go('/reminders'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: enabledKeys.contains('watch')
                                          ? HomeStatCard(
                                              value: '${continueWatching.length}',
                                              label: 'Watching',
                                              icon: Icons.movie_outlined,
                                              color: AppColors.secondaryContainer,
                                              onTap: () => context.go('/watch'),
                                            )
                                          : HomeStatCard(
                                              value: '${notes.length}',
                                              label: 'Notes',
                                              icon: Icons.description_outlined,
                                              color: AppColors.secondaryContainer,
                                              onTap: () => context.go('/notes'),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
