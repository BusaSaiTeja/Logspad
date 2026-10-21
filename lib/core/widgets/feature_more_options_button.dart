import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_logs/core/theme/app_colors.dart';

/// Reusable popup menu button for feature app bars.
/// Eliminates duplicate popup menus across feature screens (DRY / Rule of Three).
class FeatureMoreOptionsButton extends StatelessWidget {
  final String featureName;
  final VoidCallback? onSettingsTap;

  const FeatureMoreOptionsButton({
    super.key,
    required this.featureName,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.onSurfaceVariant),
      tooltip: 'More options',
      onSelected: (value) {
        if (value == 'settings') {
          if (onSettingsTap != null) {
            onSettingsTap!();
          } else {
            context.push('/settings');
          }
        } else if (value == 'marketplace') {
          context.push('/marketplace');
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'marketplace',
          child: Row(
            children: [
              Icon(Icons.storefront_outlined, size: 18, color: AppColors.onSurfaceVariant),
              SizedBox(width: 10),
              Text('Feature Marketplace'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18, color: AppColors.onSurfaceVariant),
              SizedBox(width: 10),
              Text('Settings'),
            ],
          ),
        ),
      ],
    );
  }
}
