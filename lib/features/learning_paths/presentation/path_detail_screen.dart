import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_spacing.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/widgets/app_confirmation_dialog.dart';
import 'package:my_logs/core/widgets/app_snackbar.dart';
import 'package:my_logs/core/widgets/empty_state.dart';
import 'package:my_logs/core/widgets/ui_state_views.dart';
import 'package:my_logs/features/learning_paths/application/learning_path_providers.dart';
import 'package:my_logs/features/learning_paths/domain/models/learning_path.dart';
import 'package:my_logs/features/learning_paths/presentation/widgets/path_progress_card.dart';
import 'package:my_logs/features/learning_paths/presentation/widgets/path_step_tile.dart';

class PathDetailScreen extends ConsumerWidget {
  const PathDetailScreen({super.key, required this.pathId});
  final String pathId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathListProvider);
    final path = ref.watch(learningPathByIdProvider(pathId));
    final progress = ref.watch(pathProgressProvider(pathId));

    if (pathsAsync.isLoading && path == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.primary,
            onPressed: () => context.canPop() ? context.pop() : context.go('/learning-paths'),
          ),
        ),
        body: const ShimmerSkeletonList(itemCount: 3, cardHeight: 120),
      );
    }

    if (path == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.primary,
            onPressed: () => context.canPop() ? context.pop() : context.go('/learning-paths'),
          ),
        ),
        body: Center(
          child: EmptyState(
            icon: Icons.school_outlined,
            title: 'Learning Path not found',
            subtitle: 'This path may have been removed or moved.',
            actionLabel: 'Go to Learning Paths',
            onAction: () => context.canPop() ? context.pop() : context.go('/learning-paths'),
          ),
        ),
      );
    }

    final sortedSteps = List<PathStep>.from(path.steps)..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    final completedCount = sortedSteps.where((s) => s.isCompleted).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.primary,
          onPressed: () => context.canPop() ? context.pop() : context.go('/learning-paths'),
        ),
        title: Text(
          'Learning Path',
          style: AppTypography.headlineLgMobile.copyWith(color: AppColors.primary),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.error,
            onPressed: () async {
              final confirm = await showAppConfirmationDialog(
                context: context,
                title: 'Delete Learning Path',
                message: 'Are you sure you want to delete this learning path?',
                confirmLabel: 'Delete',
                icon: Icons.delete_outline_rounded,
                confirmColor: AppColors.error,
              );
              if (confirm == true && context.mounted) {
                try {
                  await ref.read(learningPathListProvider.notifier).delete(pathId);
                  if (context.mounted) {
                    AppSnackBar.showSuccess(context, 'Learning path deleted');
                    context.canPop() ? context.pop() : context.go('/learning-paths');
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBar.showError(context, 'Failed to delete learning path: $e');
                  }
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.primary,
            onPressed: () => context.push('/learning-paths/$pathId/edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          Text(path.title, style: AppTypography.display),
          if (path.description != null) ...[
            const SizedBox(height: 8),
            Text(path.description!, style: AppTypography.bodyLgVariant()),
          ],
          const SizedBox(height: AppSpacing.groupGap),
          // Progress overview
          PathProgressCard(
            completedCount: completedCount,
            totalCount: path.steps.length,
            progress: progress,
          ),
          const SizedBox(height: AppSpacing.groupGap),
          Text('Steps', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.stackGap),
          ...sortedSteps.map((step) => PathStepTile(
                step: step,
                onToggle: () async {
                  try {
                    await ref.read(learningPathListProvider.notifier).toggleStep(pathId, step.id);
                    if (context.mounted) {
                      AppSnackBar.showSuccess(
                        context,
                        step.isCompleted ? 'Step marked as incomplete' : 'Step completed!',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackBar.showError(context, 'Failed to update step: $e');
                    }
                  }
                },
              )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
