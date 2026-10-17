import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/widgets/media_letter_placeholder.dart';
import 'package:my_logs/features/watch/domain/models/media_item.dart';

/// Letterboxd-style cinematic poster card designed for multi-column grids.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onDelete,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasPoster = item.posterUrl != null && item.posterUrl!.trim().isNotEmpty;

    return Semantics(
      button: true,
      label: '${item.title}, ${item.year ?? ''}, ${item.category.label}',
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 2:3 Cinematic Poster with Overlays ───────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color: AppColors.surfaceContainerLow,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x180F172A),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Poster Image / Placeholder
                      if (hasPoster)
                        CachedNetworkImage(
                          imageUrl: item.posterUrl!.trim(),
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _PosterPlaceholder(title: item.title),
                          errorWidget: (_, _, _) => _PosterPlaceholder(title: item.title),
                        )
                      else
                        _PosterPlaceholder(title: item.title),

                      // Subtle crisp border overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                              width: 0.75,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),

                      // Rating Badge Overlay (Letterboxd-style top-left glass badge)
                      if (item.rating != null && item.rating! > 0)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xCC0F172A),
                              borderRadius: BorderRadius.circular(5.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.starAmber,
                                  size: 11,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  item.rating!.toStringAsFixed(1),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Total Episodes Badge for series/anime (e.g. "12 eps" or "24 eps")
                      if (item.totalEpisodes != null && item.totalEpisodes! > 0)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xCC0F172A),
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            child: Text(
                              '${item.totalEpisodes} eps',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── Movie / Anime Title ──────────────────────────────────────────
            Text(
              item.title,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.obsidian,
                fontSize: 12.0,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // ── Year, Total Episodes & Genre Subtitle ─────────────────────────
            Text(
              [
                if (item.year != null) '${item.year}',
                if (item.totalEpisodes != null && item.totalEpisodes! > 0) '${item.totalEpisodes} eps',
                if (item.genres.isNotEmpty) item.genres.first,
              ].join(' • '),
              style: AppTypography.labelMdOutline().copyWith(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return MediaLetterPlaceholder(
      title: title,
      fontSize: 26,
    );
  }
}
