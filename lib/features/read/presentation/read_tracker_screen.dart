import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_spacing.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/utils/debouncer.dart';
import 'package:my_logs/core/widgets/empty_state.dart';
import 'package:my_logs/core/widgets/pill_tab_bar.dart';
import 'package:my_logs/core/widgets/ui_state_views.dart';
import 'package:my_logs/features/read/application/book_providers.dart';
import 'package:my_logs/features/read/domain/models/book_item.dart';
import 'package:my_logs/features/read/presentation/widgets/book_card.dart';
import 'package:my_logs/core/widgets/drawer_menu_button.dart';
import 'package:my_logs/core/widgets/feature_more_options_button.dart';

class ReadTrackerScreen extends ConsumerStatefulWidget {
  const ReadTrackerScreen({super.key});

  @override
  ConsumerState<ReadTrackerScreen> createState() => _ReadTrackerScreenState();
}

class _ReadTrackerScreenState extends ConsumerState<ReadTrackerScreen> {
  int _selectedTab = 0;
  String _searchQuery = '';
  final PageController _pageController = PageController();

  static const _tabs = ['Reading', 'Read', 'To Read', 'Collection'];
  static const _statuses = [
    BookStatus.reading,
    BookStatus.read,
    BookStatus.toRead,
    BookStatus.collection,
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
    final bookListAsync = ref.watch(bookListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: const DrawerMenuButton(tooltip: 'Open menu'),
        title: Text('Read Tracker',
            style: AppTypography.headlineLgMobile.copyWith(color: AppColors.obsidian)),
        centerTitle: false,
        actions: const [
          FeatureMoreOptionsButton(featureName: 'Read Tracker'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'read_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => SafeTap.run(() => context.push('/read/add')),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search books by title or author...',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.outline),
              ),
              style: AppTypography.bodyLg,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerPadding, AppSpacing.stackGap, AppSpacing.containerPadding, 0),
            child: PillTabBar(
              tabs: _tabs,
              selectedIndex: _selectedTab,
              onTabSelected: _onTabSelected,
            ),
          ),
          const SizedBox(height: AppSpacing.stackGap),
          Expanded(
            child: bookListAsync.when(
              loading: () => const ShimmerSkeletonList(
                itemCount: 5,
                cardHeight: 96,
              ),
              error: (err, _) => ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.refresh(bookListProvider),
              ),
              data: (_) => RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.refresh(bookListProvider),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _statuses.length,
                  onPageChanged: (i) => setState(() => _selectedTab = i),
                  itemBuilder: (context, tabIdx) {
                    final status = _statuses[tabIdx];
                    final books = ref.watch(booksByStatusProvider(status));
                    final filtered = _searchQuery.isEmpty
                        ? books
                        : books
                            .where((b) =>
                                b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                b.author.toLowerCase().contains(_searchQuery.toLowerCase()))
                            .toList();

                    if (filtered.isEmpty) {
                      if (_searchQuery.isNotEmpty) {
                        return SearchEmptyView(
                          query: _searchQuery,
                          onClear: () => setState(() => _searchQuery = ''),
                        );
                      }
                      return EmptyState(
                        icon: Icons.book_outlined,
                        title: 'No ${_tabs[tabIdx].toLowerCase()} books',
                        subtitle: 'Add your first book to your library',
                        actionLabel: 'Add Book',
                        onAction: () => SafeTap.run(() => context.push('/read/add')),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: BookCard(
                          book: filtered[i],
                          onTap: () => SafeTap.run(() => context.push('/read/${filtered[i].id}')),
                          onDelete: () => ref.read(bookListProvider.notifier).delete(filtered[i].id),
                        ),
                      ),
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
}
