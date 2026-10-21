import 'package:flutter/material.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_spacing.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/widgets/media_letter_placeholder.dart';
import 'package:my_logs/features/watch/domain/models/media_item.dart';

class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({super.key, required this.item, required this.onTap});
  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: AppColors.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                      ? Image.network(
                          item.posterUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) => MediaLetterPlaceholder(
                            title: item.title,
                            fontSize: 36,
                          ),
                        )
                      : MediaLetterPlaceholder(
                          title: item.title,
                          fontSize: 36,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                if (item.year != null) ...[
                  Text(
                    '${item.year}',
                    style: AppTypography.labelMdOutline().copyWith(fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                ],
                if (item.rating != null) ...[
                  const Icon(Icons.star_rounded, size: 12, color: AppColors.starAmber),
                  const SizedBox(width: 2),
                  Text(
                    item.rating!.toStringAsFixed(1),
                    style: AppTypography.labelMd.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
