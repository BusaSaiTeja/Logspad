import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/utils/debouncer.dart';
import 'package:my_logs/core/widgets/empty_state.dart';
import 'package:my_logs/core/widgets/pill_tab_bar.dart';
import 'package:my_logs/core/widgets/ui_state_views.dart';
import 'package:my_logs/features/watch/application/media_providers.dart';
import 'package:my_logs/features/watch/domain/models/media_item.dart';
import 'package:my_logs/features/watch/presentation/widgets/media_card.dart';

class MediaListScreen extends ConsumerStatefulWidget {
  const MediaListScreen({super.key, required this.category});
  final MediaCategory category;

  @override
  ConsumerState<MediaListScreen> createState() => _MediaListScreenState();
}

class _MediaListScreenState extends ConsumerState<MediaListScreen> {
  int _selectedTab = 0;
  String _searchQuery = '';
  final PageController _pageController = PageController();

  static const _tabs = ['Plan to Watch', 'Watching', 'Completed', 'On Hold', 'Dropped'];
  static const _statuses = [
    MediaStatus.planToWatch,
    MediaStatus.watching,
    MediaStatus.completed,
    MediaStatus.onHold,
    MediaStatus.dropped,
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _addRoute => switch (widget.category) {
        MediaCategory.movie => '/watch/movies/add',
        MediaCategory.animatedMovie => '/watch/animated/add',
        MediaCategory.anime => '/watch/anime/add',
      };

  String _detailRoute(String id) => switch (widget.category) {
        MediaCategory.movie => '/watch/movies/$id',
        MediaCategory.animatedMovie => '/watch/animated/$id',
        MediaCategory.anime => '/watch/anime/$id',
      };

  void _onTabSelected(int index) {
    setState(() => _selectedTab = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaListAsync = ref.watch(mediaListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.primary,
          onPressed: () => context.canPop() ? context.pop() : context.go('/watch'),
        ),
        title: Text(widget.category.label,
            style: AppTypography.headlineLgMobile.copyWith(color: AppColors.primary)),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'media_list_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => SafeTap.run(() => context.push(_addRoute)),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.category.label.toLowerCase()}...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.outline),
                    ),
                    style: AppTypography.bodyLg,
                  ),
                ),
              ],
            ),
          ),
          // ── Tab bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: PillTabBar(
              tabs: _tabs,
              selectedIndex: _selectedTab,
              onTabSelected: _onTabSelected,
            ),
          ),
          // ── Swipeable PageView List ───────────────────────────────────────
          Expanded(
            child: mediaListAsync.when(
              loading: () => _buildGridShimmer(),
              error: (err, _) => ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.refresh(mediaListProvider),
              ),
              data: (_) => RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.refresh(mediaListProvider),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _statuses.length,
                  onPageChanged: (i) => setState(() => _selectedTab = i),
                  itemBuilder: (context, tabIdx) {
                    final status = _statuses[tabIdx];
                    final items = ref.watch(mediaByCategoryAndStatus((widget.category, status)));
                    final filtered = _searchQuery.isEmpty
                        ? items
                        : items
                            .where((m) =>
                                m.title.toLowerCase().contains(_searchQuery.toLowerCase()))
                            .toList();

                    if (filtered.isEmpty) {
                      if (_searchQuery.isNotEmpty) {
                        return SearchEmptyView(
                          query: _searchQuery,
                          onClear: () => setState(() => _searchQuery = ''),
                        );
                      }
                      return EmptyState(
                        icon: Icons.movie_outlined,
                        title: 'No ${_tabs[tabIdx].toLowerCase()} items',
                        subtitle: 'Add your first ${widget.category.label.toLowerCase()}',
                        actionLabel: 'Add',
                        onAction: () => SafeTap.run(() => context.push(_addRoute)),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width > 600 ? 5 : 3;
                        final totalSpacing = (crossAxisCount - 1) * 12.0;
                        final itemWidth = (width - 32.0 - totalSpacing) / crossAxisCount;
                        final textScaler = MediaQuery.textScalerOf(context);
                        final metadataHeight = textScaler.scale(48.0);
                        final posterHeight = itemWidth * 1.48; // standard 2:3 aspect ratio
                        final itemHeight = posterHeight + 6.0 + metadataHeight;
                        final childAspectRatio = itemWidth / itemHeight;

                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 80.0),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final item = filtered[i];
                            return MediaCard(
                              item: item,
                              onTap: () => SafeTap.run(() => context.push(_detailRoute(item.id))),
                              onDelete: () =>
                                  ref.read(mediaListProvider.notifier).delete(item.id),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridShimmer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 600 ? 5 : 3;
        final totalSpacing = (crossAxisCount - 1) * 12.0;
        final itemWidth = (width - 32.0 - totalSpacing) / crossAxisCount;
        final textScaler = MediaQuery.textScalerOf(context);
        final metadataHeight = textScaler.scale(48.0);
        final posterHeight = itemWidth * 1.48;
        final itemHeight = posterHeight + 6.0 + metadataHeight;
        final childAspectRatio = itemWidth / itemHeight;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 80.0),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 16.0,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: 6,
      itemBuilder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 70,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
