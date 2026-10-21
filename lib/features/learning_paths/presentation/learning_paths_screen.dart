import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/utils/debouncer.dart';
import 'package:my_logs/core/widgets/empty_state.dart';
import 'package:my_logs/core/widgets/ui_state_views.dart';
import 'package:my_logs/features/learning_paths/application/learning_path_providers.dart';
import 'package:my_logs/features/learning_paths/presentation/widgets/learning_path_card.dart';
import 'package:my_logs/core/widgets/drawer_menu_button.dart';
import 'package:my_logs/core/widgets/feature_more_options_button.dart';

class LearningPathsScreen extends ConsumerWidget {
  const LearningPathsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(workspaceFilteredLearningPathsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: const DrawerMenuButton(tooltip: 'Open menu'),
        title: Text('Learning Paths',
            style: AppTypography.headlineLgMobile.copyWith(color: AppColors.obsidian)),
        centerTitle: false,
        actions: const [
          FeatureMoreOptionsButton(featureName: 'Learning Paths'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'learning_paths_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => SafeTap.run(() => context.push('/learning-paths/add')),
        child: const Icon(Icons.add_rounded),
      ),
      body: pathsAsync.when(
        loading: () => const ShimmerSkeletonList(
          itemCount: 3,
          cardHeight: 110,
        ),
        error: (err, _) => ErrorStateView(
          message: err.toString(),
          onRetry: () => ref.refresh(learningPathListProvider),
        ),
        data: (paths) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(learningPathListProvider),
          child: paths.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.65,
                      child: EmptyState(
                        icon: Icons.school_outlined,
                        title: 'No paths yet',
                        subtitle: 'Create your first learning journey',
                        actionLabel: 'New Path',
                        onAction: () => SafeTap.run(() => context.push('/learning-paths/add')),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  itemCount: paths.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12.0),
                  itemBuilder: (context, i) {
                    final path = paths[i];
                    final progress = ref.watch(pathProgressProvider(path.id));
                    final status = ref.watch(pathStatusProvider(path.id));
                    return LearningPathCard(
                      path: path,
                      progress: progress,
                      status: status,
                      onTap: () => SafeTap.run(() => context.push('/learning-paths/${path.id}')),
                      onDelete: () => ref.read(learningPathListProvider.notifier).delete(path.id),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
