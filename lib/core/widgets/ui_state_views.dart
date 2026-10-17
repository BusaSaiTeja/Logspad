import 'package:flutter/material.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_spacing.dart';
import 'package:my_logs/core/theme/app_typography.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Shimmer Skeleton Placeholder for Lists & Grids
/// Uses an internal repeating AnimationController for zero external dependencies.
/// ─────────────────────────────────────────────────────────────────────────────
class ShimmerSkeletonList extends StatefulWidget {
  const ShimmerSkeletonList({
    super.key,
    this.itemCount = 6,
    this.cardHeight = 76.0,
    this.isGrid = false,
    this.gridCrossAxisCount = 2,
  });

  final int itemCount;
  final double cardHeight;
  final bool isGrid;
  final int gridCrossAxisCount;

  @override
  State<ShimmerSkeletonList> createState() => _ShimmerSkeletonListState();
}

class _ShimmerSkeletonListState extends State<ShimmerSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _shimmerAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Widget _buildSkeletonCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        final opacity = _shimmerAnim.value;
        return Container(
          height: widget.cardHeight,
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, highlightColor, opacity),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 14,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 220,
                height: 10,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGrid) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.gridCrossAxisCount,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 0.85,
        ),
        itemCount: widget.itemCount,
        itemBuilder: (_, index) => _buildSkeletonCard(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      separatorBuilder: (_, index) => const SizedBox(height: 10.0),
      itemBuilder: (_, index) => _buildSkeletonCard(),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Search / Filter Empty State View
/// Shown when active query or status filter returns zero results.
/// ─────────────────────────────────────────────────────────────────────────────
class SearchEmptyView extends StatelessWidget {
  const SearchEmptyView({
    super.key,
    required this.query,
    this.onClear,
  });

  final String query;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              ),
              child: const Center(
                child: Icon(Icons.search_off_rounded, size: 28, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No matches found',
              style: AppTypography.headlineMd.copyWith(
                color: AppColors.obsidian,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                query.isNotEmpty
                    ? 'No items matched "$query". Try searching for another keyword.'
                    : 'No items match the currently selected filter.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Clear Filter / Search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Error State View with Interactive Retry
/// Friendly human message with a retry callback.
/// ─────────────────────────────────────────────────────────────────────────────
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
              ),
              child: const Center(
                child: Icon(Icons.cloud_off_rounded, size: 28, color: Color(0xFFDC2626)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Unable to Load Data',
              style: AppTypography.headlineMd.copyWith(
                color: AppColors.obsidian,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Text(
                message.contains('SocketException') || message.contains('network')
                    ? 'Check your internet connection and try again.'
                    : 'Something went wrong while syncing. Please tap below to retry.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
