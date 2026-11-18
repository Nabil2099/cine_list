import 'package:flutter/material.dart';

/// Exact CineList color palette and derived surface/contrast tokens.
abstract final class AppColors {
  // Core 5-color foundation
  static const Color pacificBlue = Color(0xFF0FA3B1);
  static const Color black = Color(0xFF000505);
  static const Color khakiBeige = Color(0xFFCEB992);
  static const Color dustyLavender = Color(0xFF78586F);
  static const Color softPeriwinkle = Color(0xFF998FC7);

  // Derived surface shades for dark cinematic hierarchy
  static const Color surfaceBase = Color(0xFF0B0A0E);
  static const Color surfaceElevated = Color(0xFF16121A);
  static const Color surfaceCard = Color(0xFF1E1724);
  static const Color surfaceInput = Color(0xFF191520);
  static const Color surfaceBorder = Color(0xFF31263B);

  // Text colors
  static const Color textPrimary = Color(0xFFF4F1ED);
  static const Color textSecondary = Color(0xFFB5AEB9);
  static const Color textMuted = Color(0xFF847C8A);

  // Semantic colors
  static const Color starAmber = Color(0xFFF5B942);
  static const Color success = Color(0xFF2EC4B6);
  static const Color error = Color(0xFFE05A6D);
  static const Color warning = Color(0xFFE5A93B);
  static const Color creatorEmerald = Color(0xFF3E8E6E);
}
