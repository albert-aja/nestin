import 'package:flutter/material.dart';

class AppColors {
  // Brand Rooster & Sunrise Palette
  static const Color primary = Color(0xFFE04A3A); // Nestin Crimson
  static const Color primaryLight = Color(0xFFFF6B5B);
  static const Color primaryDark = Color(0xFFB83224);

  static const Color accent = Color(0xFFFF9E1B); // Sunrise Amber
  static const Color accentLight = Color(0xFFFFB854);
  static const Color accentGlow = Color(0x33FF9E1B);

  // Dark Theme Surfaces (Modern Charcoal / Obsidian)
  static const Color darkBg = Color(0xFF111215);
  static const Color darkRecessed = Color(0xFF141519);
  static const Color darkSheet = Color(0xFF16171D);
  static const Color darkCard = Color(0xFF1A1B20);
  static const Color darkPanel = Color(0xFF1E2028);
  static const Color darkCardElevated = Color(0xFF23252C);
  static const Color darkTrack = Color(0xFF252834);
  static const Color darkBorder = Color(0xFF2D303A);
  static const Color darkTextPrimary = Color(0xFFF1F3F5);
  static const Color darkTextSecondary = Color(0xFF8E929E);
  static const Color darkTextMuted = Color(0xFF6B7280);

  // Light Theme Surfaces
  static const Color lightBg = Color(0xFFF4F6F9);
  static const Color lightRecessed = Color(0xFFEAEEF4);
  static const Color lightSheet = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightPanel = Color(0xFFF1F4F8);
  static const Color lightCardElevated = Color(0xFFE9EDF4);
  static const Color lightTrack = Color(0xFFDDE3EC);
  static const Color lightBorder = Color(0xFFDCE1EA);
  static const Color lightTextPrimary = Color(0xFF181A20);
  static const Color lightTextSecondary = Color(0xFF5A6170);
  static const Color lightTextMuted = Color(0xFF6E7585);

  // Functional Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Category Colors
  static const Color catWakeUp = Color(0xFFFF9E1B);
  static const Color catWork = Color(0xFF3A86FF);
  static const Color catPersonal = Color(0xFF8338EC);
  static const Color catHealth = Color(0xFF10B981);
  static const Color catActivities = Color(0xFF06D6A0);
  static const Color catOther = Color(0xFF6C757D);

  // Context-aware Adaptive Tokens (preserve dark surface depth + crisp light contrast)
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? darkBg : lightBg;

  static Color recessedSurface(BuildContext context) =>
      isDark(context) ? darkRecessed : lightRecessed;

  static Color sheetSurface(BuildContext context) =>
      isDark(context) ? darkSheet : lightSheet;

  static Color cardSurface(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;

  static Color elevatedSurface(BuildContext context) =>
      isDark(context) ? darkPanel : lightPanel;

  static Color trackSurface(BuildContext context) =>
      isDark(context) ? darkTrack : lightTrack;

  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  static Color subtleFill(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.04);

  static Color scrimHandle(BuildContext context) =>
      isDark(context) ? Colors.white24 : Colors.black26;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? darkTextMuted : lightTextMuted;

  /// Picks [darkColor] in dark mode and [lightColor] in light mode for tinted
  /// labels or decorative highlights that need extra contrast on light cards.
  static Color adaptive(
    BuildContext context, {
    required Color dark,
    required Color light,
  }) =>
      isDark(context) ? dark : light;
}

