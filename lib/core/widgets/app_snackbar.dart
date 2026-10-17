import 'package:flutter/material.dart';

/// Centralized, premium floating SnackBar helper following LogsPad design guidelines.
///
/// Features:
/// - Floating behavior with rounded corners (12px)
/// - High-contrast obsidian surface for success & info, crimson for error
/// - Distinct semantic icons with micro-spacing
/// - Automatic dismissal of previous SnackBars to prevent queue lag
abstract final class AppSnackBar {
  /// Displays a floating success SnackBar with a green checkmark icon.
  static void showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: _cleanMessage(message),
      backgroundColor: const Color(0xFF0F172A),
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF10B981),
      action: action,
      duration: duration,
    );
  }

  /// Displays a floating error SnackBar with an alert icon.
  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message: _cleanMessage(message),
      backgroundColor: const Color(0xFF991B1B),
      icon: Icons.error_outline_rounded,
      iconColor: Colors.white,
      action: action,
      duration: duration,
    );
  }

  /// Displays a floating info/neutral SnackBar with an info icon.
  static void showInfo(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: _cleanMessage(message),
      backgroundColor: const Color(0xFF0F172A),
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF818CF8),
      action: action,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required Color iconColor,
    SnackBarAction? action,
    required Duration duration,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        action: action,
      ),
    );
  }

  static String _cleanMessage(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring('Exception: '.length).trim();
    }
    return cleaned;
  }
}
