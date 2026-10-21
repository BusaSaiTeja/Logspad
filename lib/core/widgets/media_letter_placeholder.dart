import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A modern, tactile placeholder showing the first letter of a movie, anime, or book
/// when no poster image is found or available.
class MediaLetterPlaceholder extends StatelessWidget {
  const MediaLetterPlaceholder({
    super.key,
    required this.title,
    this.fontSize = 28,
    this.width,
    this.height,
    this.borderRadius,
  });

  final String title;
  final double fontSize;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  // Harmonious, curated gradient palettes
  static const List<List<Color>> _palettes = [
    [Color(0xFF4F46E5), Color(0xFF3730A3)], // Deep Indigo
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)], // Electric Violet
    [Color(0xFF0EA5E9), Color(0xFF0284C7)], // Cyan
    [Color(0xFF10B981), Color(0xFF047857)], // Emerald
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Warm Amber
    [Color(0xFFF43F5E), Color(0xFFBE123C)], // Vivid Crimson
    [Color(0xFF6366F1), Color(0xFF4338CA)], // Royal Indigo
    [Color(0xFF14B8A6), Color(0xFF0F766E)], // Teal
  ];

  String _extractFirstLetter(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return 'M';
    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
        return char.toUpperCase();
      }
    }
    return clean[0].toUpperCase();
  }

  List<Color> _getGradient(String letter) {
    final code = letter.codeUnitAt(0);
    return _palettes[code % _palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final letter = _extractFirstLetter(title);
    final gradient = _getGradient(letter);

    Widget container = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: borderRadius,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle circular glow behind letter
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              width: fontSize * 2.2,
              height: fontSize * 2.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),

          // High-character bold initial letter
          Center(
            child: Text(
              letter,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );

    if (borderRadius != null) {
      container = ClipRRect(
        borderRadius: borderRadius!,
        child: container,
      );
    }

    return container;
  }
}
