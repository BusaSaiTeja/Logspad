import 'package:flutter/material.dart';
import 'package:my_logs/core/theme/app_spacing.dart';

/// Shimmer skeleton matching the exact Bento hero and grouped surface layout of the dashboard.
/// Prevents layout vibration and jarring blank states during initial data load.
class HomeShimmerSkeleton extends StatefulWidget {
  const HomeShimmerSkeleton({super.key});

  @override
  State<HomeShimmerSkeleton> createState() => _HomeShimmerSkeletonState();
}

class _HomeShimmerSkeletonState extends State<HomeShimmerSkeleton>
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

  Widget _shimmerBox({
    required double width,
    required double height,
    double radius = 8.0,
    BorderRadius? customRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        final opacity = _shimmerAnim.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, highlightColor, opacity),
            borderRadius: customRadius ?? BorderRadius.circular(radius),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        // ── Bento Hero Overview Skeleton ──────────────────────────────────────
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Focal Card Skeleton
              Expanded(
                flex: 11,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _shimmerBox(width: 90, height: 12, radius: 4),
                      _shimmerBox(width: 48, height: 36, radius: 6),
                      _shimmerBox(width: 120, height: 14, radius: 4),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Stacked Micro Cards Skeleton
              Expanded(
                flex: 9,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _shimmerBox(width: 28, height: 20, radius: 4),
                                const SizedBox(height: 4),
                                _shimmerBox(width: 60, height: 10, radius: 3),
                              ],
                            ),
                            _shimmerBox(width: 24, height: 24, radius: 12),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _shimmerBox(width: 28, height: 20, radius: 4),
                                const SizedBox(height: 4),
                                _shimmerBox(width: 60, height: 10, radius: 3),
                              ],
                            ),
                            _shimmerBox(width: 24, height: 24, radius: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
