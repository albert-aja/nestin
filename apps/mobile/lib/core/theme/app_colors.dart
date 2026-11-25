import 'package:material_ui/material_ui.dart';

/// Global single source of truth for Nestin's color system.
///
/// Organize & edit all brand, mascot domain, semantic status, surface, and
/// extended palette tokens here so rebranding or palette updates propagate
/// across the entire app from one file.
class AppColors {
  // ---------------------------------------------------------------------------
  // Brand Nestin Leaf Green Palette (sampled from assets/banner.jpg)
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFF649330); // Nestin Leaf Green (Light Mode)
  static const Color primaryLight = Color(0xFF7CB342); // Nestin Leaf Green (Dark Mode)
  static const Color primaryDark = Color(0xFF4B7022); // Deep Nestin Leaf Green

  // Top Navbar Wordmark Inks (assets/banner.jpg)
  static const Color wordmarkCharcoal = Color(0xFF2D3036); // "nest" in Light Mode
  static const Color wordmarkOffWhite = Color(0xFFF3F5F7); // "nest" in Dark Mode

  // Global Sunrise Amber Secondary Accent
  static const Color accent = Color(0xFFFF9E1B); // Sunrise Amber
  static const Color accentLight = Color(0xFFFFB854);
  static const Color accentGlow = Color(0x33FF9E1B);

  // ---------------------------------------------------------------------------
  // Mascot Flock Domain Palettes (6 Companions)
  // ---------------------------------------------------------------------------
  // Roo (Rooster — Time, Alarms, Tasks, Habits & Digital Discipline)
  static const Color roo = Color(0xFFE04A3A);
  static const Color rooLight = Color(0xFFFF6B5B);
  static const Color rooDark = Color(0xFFB83224);
  // Legacy Roo aliases preserved for backward compatibility
  static const Color rooCrimson = roo;
  static const Color rooCrimsonLight = rooLight;
  static const Color rooCrimsonDark = rooDark;

  // Scout (Carrier Pigeon — Today, Weather, BeforeYouGo & Utilities)
  static const Color scout = Color(0xFF3B82F6);
  static const Color scoutLight = Color(0xFF60A5FA);
  static const Color scoutDark = Color(0xFF1D4ED8);
  static const Color scoutSoft = Color(0xFFEFF6FF);

  // Seren (Dove — Personal Wellness, Sleep, Relaxation & Mental Aid)
  static const Color seren = Color(0xFF8B5CF6);
  static const Color serenLight = Color(0xFFA78BFA);
  static const Color serenSoft = Color(0xFFC4B5FD);
  static const Color serenDeep = Color(0xFF7C3AED);
  static const Color serenDark = Color(0xFF6D28D9);

  // Pippin (Explorer Dodo — Reading, Hobbies, Bucket List & Inspiration)
  static const Color pippin = Color(0xFF10B981);
  static const Color pippinLight = Color(0xFF34D399);
  static const Color pippinDeep = Color(0xFF059669);
  static const Color pippinDark = Color(0xFF047857);
  static const Color pippinSoft = Color(0xFFECFDF5);

  // Twill (Weaver Bird — Notes, Lists, Wishlist & Personal Money)
  static const Color twill = Color(0xFFF59E0B);
  static const Color twillLight = Color(0xFFFBBF24);
  static const Color twillDeep = Color(0xFFC26A00);
  static const Color twillDark = Color(0xFFB45309);
  static const Color twillSoft = Color(0xFFFFFBEB);
  static const Color twillBorder = Color(0xFFFDE68A);

  // Echo (Wise Owl — Journal, Diary, Memories & Reflection)
  static const Color echo = Color(0xFFD97706);
  static const Color echoLight = Color(0xFFFBBF24);
  static const Color echoDark = Color(0xFF92400E);

  // ---------------------------------------------------------------------------
  // Dark Theme Surfaces (Modern Charcoal / Obsidian)
  // ---------------------------------------------------------------------------
  static const Color darkBg = Color(0xFF111215);
  static const Color darkRecessed = Color(0xFF141519);
  static const Color darkSheet = Color(0xFF16171D);
  static const Color darkCard = Color(0xFF1A1B20);
  static const Color darkPanel = Color(0xFF1E2028);
  static const Color darkCardElevated = Color(0xFF23252C);
  static const Color darkSurfaceSubtle = Color(0xFF23252E);
  static const Color darkTrack = Color(0xFF252834);
  static const Color darkBorder = Color(0xFF2D303A);
  static const Color darkBorderStrong = Color(0xFF2C2F3A);
  static const Color darkTextPrimary = Color(0xFFF1F3F5);
  static const Color darkTextSecondary = Color(0xFF8E929E);
  static const Color darkTextMuted = Color(0xFF6B7280);
  static const Color darkSwitchThumb = Color(0xFFA0A5B1);
  static const Color darkSwitchTrack = Color(0xFF333640);
  static const Color darkSurfaceDeep = Color(0xFF090A0F);
  static const Color bedsideBg = Color(0xFF0F1014); // Active alarm bedside dark surface

  // ---------------------------------------------------------------------------
  // Light Theme Surfaces
  // ---------------------------------------------------------------------------
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
  static const Color lightSwitchThumb = Color(0xFFBDC2CC);
  static const Color lightSwitchTrack = Color(0xFFE2E5EA);

  // ---------------------------------------------------------------------------
  // Neutral Slate & Gray Scale
  // ---------------------------------------------------------------------------
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF374151);
  static const Color slate600 = Color(0xFF4B5563);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray200 = Color(0xFFE5E7EB);

  // ---------------------------------------------------------------------------
  // Functional Status Tokens
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF047857);
  static const Color successSoft = Color(0xFFECFDF5);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3C7);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color errorDeep = Color(0xFFB91C1C);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFEFF6FF);

  // ---------------------------------------------------------------------------
  // Extended Feature & Semantic Accents
  // ---------------------------------------------------------------------------
  // Hydration / Sky Blue
  static const Color sky = Color(0xFF38BDF8);
  static const Color skyMid = Color(0xFF0EA5E9);
  static const Color skyDark = Color(0xFF0284C7);
  static const Color skyDeep = Color(0xFF0369A1);
  static const Color skySoft = Color(0xFFE0F2FE);
  static const Color skyLight = Color(0xFF93C5FD);

  // Focus / Sleep / Indigo
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoLight = Color(0xFF818CF8);
  static const Color indigoDark = Color(0xFF4F46E5);
  static const Color indigoDeep = Color(0xFF1E1B4B);
  static const Color indigoSoft = Color(0xFFEEF2FF);

  // Mood / Heart / Rose & Pink
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkLight = Color(0xFFF472B6);
  static const Color rose = Color(0xFFE11D48);
  static const Color roseLight = Color(0xFFFB7185);
  static const Color roseSoft = Color(0xFFFFE4E6);

  // Teal / Cyan / Mint / Fresh Green
  static const Color cyan = Color(0xFF06B6D4);
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealLight = Color(0xFF2DD4BF);
  static const Color tealDark = Color(0xFF0D9488);
  static const Color mint = Color(0xFF6EE7B7);
  static const Color emeraldDeep = Color(0xFF064E3B);
  static const Color green = Color(0xFF22C55E);

  // Warm Orange / Coral / Peach
  static const Color orange = Color(0xFFF97316);
  static const Color orangeLight = Color(0xFFFB923C);
  static const Color orangeDark = Color(0xFFEA580C);
  static const Color orangeDeep = Color(0xFFC2410C);
  static const Color orangeBrown = Color(0xFF9A3412);
  static const Color orangeSoft = Color(0xFFFFEDD5);
  static const Color peachSoft = Color(0xFFFFEFE6);
  static const Color coral = Color(0xFFFF8A65);

  // Purple / Violet / Electric
  static const Color purple = Color(0xFFA855F7);
  static const Color purpleLight = Color(0xFFC084FC);
  static const Color violetDeep = Color(0xFF5B21B6);
  static const Color violetMidnight = Color(0xFF4C1D95);
  static const Color electricBlue = Color(0xFF3A86FF);
  static const Color electricPurple = Color(0xFF8338EC);

  // ---------------------------------------------------------------------------
  // Alarm Category Colors
  // ---------------------------------------------------------------------------
  static const Color catWakeUp = accent;
  static const Color catWork = electricBlue;
  static const Color catPersonal = electricPurple;
  static const Color catHealth = success;
  static const Color catActivities = Color(0xFF06D6A0);
  static const Color catOther = Color(0xFF6C757D);

  // ---------------------------------------------------------------------------
  // Context-Aware Adaptive Helpers
  // ---------------------------------------------------------------------------
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Context-aware Nestin Leaf Green brand accent (`#649330` Light / `#7CB342` Dark).
  static Color primaryAdaptive(BuildContext context) =>
      isDark(context) ? primaryLight : primary;

  static Color rooAdaptive(BuildContext context) =>
      isDark(context) ? roo : rooDark;

  static Color scoutAdaptive(BuildContext context) =>
      isDark(context) ? scout : scoutDark;

  static Color serenAdaptive(BuildContext context) =>
      isDark(context) ? serenLight : serenDark;

  static Color pippinAdaptive(BuildContext context) =>
      isDark(context) ? pippin : pippinDark;

  static Color twillAdaptive(BuildContext context) =>
      isDark(context) ? twill : twillDark;

  static Color echoAdaptive(BuildContext context) =>
      isDark(context) ? echo : echoDark;

  static Color skyAdaptive(BuildContext context) =>
      isDark(context) ? sky : skyDark;

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

  /// Picks [dark] in dark mode and [light] in light mode for tinted
  /// labels or decorative highlights that need extra contrast on light cards.
  static Color adaptive(
    BuildContext context, {
    required Color dark,
    required Color light,
  }) =>
      isDark(context) ? dark : light;
}
