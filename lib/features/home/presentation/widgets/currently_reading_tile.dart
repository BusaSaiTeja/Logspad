import 'package:flutter/material.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_spacing.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/widgets/rating_stars.dart';
import 'package:my_logs/features/read/domain/models/book_item.dart';

class CurrentlyReadingTile extends StatelessWidget {
  const CurrentlyReadingTile({super.key, required this.book, required this.onTap});
  final BookItem book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.unit * 2),
        padding: const EdgeInsets.all(AppSpacing.gutter),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            if (book.coverUrl != null && book.coverUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: Image.network(
                    book.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surfaceContainerHigh),
                  ),
                ),
              )
            else
              Container(
                width: 48,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.book_outlined, size: 24, color: AppColors.outline),
              ),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(book.author, style: AppTypography.bodyMdOutline()),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      RatingStars(
                        rating: book.rating,
                        starSize: 14,
                        onRatingChanged: null,
                      ),
                      if (book.genres.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            book.genres.first,
                            style: AppTypography.labelMd.copyWith(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
