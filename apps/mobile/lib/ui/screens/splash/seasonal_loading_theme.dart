import 'package:flutter/material.dart';

/// Seasonal themes used for the Phase-2 wallpaper loading screen after the
/// initial Nestin logo banner.
enum SeasonalSplashTheme {
  newYear,
  lunarLantern,
  springBloom,
  summerSun,
  autumnHarvest,
  cozyLantern,
  christmas,
}

extension SeasonalSplashThemeExt on SeasonalSplashTheme {
  String get labelKey => switch (this) {
        SeasonalSplashTheme.newYear => 'splash_season_opt_new_year',
        SeasonalSplashTheme.lunarLantern => 'splash_season_opt_lunar',
        SeasonalSplashTheme.springBloom => 'splash_season_opt_spring',
        SeasonalSplashTheme.summerSun => 'splash_season_opt_summer',
        SeasonalSplashTheme.autumnHarvest => 'splash_season_opt_autumn',
        SeasonalSplashTheme.cozyLantern => 'splash_season_opt_cozy',
        SeasonalSplashTheme.christmas => 'splash_season_opt_christmas',
      };

  static SeasonalSplashTheme? fromNameOrNull(String? name) {
    if (name == null || name.isEmpty || name == 'auto') return null;
    for (final value in SeasonalSplashTheme.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// Visual and localized specification for a seasonal loading wallpaper.
class SeasonalLoadingSpec {
  final SeasonalSplashTheme theme;
  final String badgeKey;
  final String titleKey;
  final String subtitleKey;
  final String mascotAsset;
  final List<Color> darkGradient;
  final List<Color> lightGradient;
  final Color accentColor;
  final Color secondaryAccentColor;

  const SeasonalLoadingSpec({
    required this.theme,
    required this.badgeKey,
    required this.titleKey,
    required this.subtitleKey,
    required this.mascotAsset,
    required this.darkGradient,
    required this.lightGradient,
    required this.accentColor,
    required this.secondaryAccentColor,
  });
}

/// Resolves the active seasonal loading wallpaper from the current date or an
/// optional user override.
class SeasonalSplashResolver {
  const SeasonalSplashResolver._();

  static SeasonalSplashTheme resolveTheme({
    DateTime? now,
    SeasonalSplashTheme? override,
  }) {
    if (override != null) return override;
    final month = (now ?? DateTime.now()).month;
    return switch (month) {
      12 => SeasonalSplashTheme.christmas,
      1 => SeasonalSplashTheme.newYear,
      2 => SeasonalSplashTheme.lunarLantern,
      3 || 4 || 5 => SeasonalSplashTheme.springBloom,
      6 || 7 || 8 => SeasonalSplashTheme.summerSun,
      9 || 10 => SeasonalSplashTheme.autumnHarvest,
      11 => SeasonalSplashTheme.cozyLantern,
      _ => SeasonalSplashTheme.cozyLantern,
    };
  }

  static SeasonalLoadingSpec resolve({
    DateTime? now,
    SeasonalSplashTheme? override,
  }) {
    final theme = resolveTheme(now: now, override: override);
    return specFor(theme);
  }

  static SeasonalLoadingSpec specFor(SeasonalSplashTheme theme) {
    return switch (theme) {
      SeasonalSplashTheme.christmas => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.christmas,
          badgeKey: 'splash_season_christmas_badge',
          titleKey: 'splash_season_christmas_title',
          subtitleKey: 'splash_season_christmas_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_wishlist_occasion_planners.png',
          darkGradient: [
            Color(0xFF0C1B1E),
            Color(0xFF142F2B),
            Color(0xFF24161A),
          ],
          lightGradient: [
            Color(0xFFEAF5F1),
            Color(0xFFF6EFE8),
            Color(0xFFFCEAE8),
          ],
          accentColor: Color(0xFFD94B43),
          secondaryAccentColor: Color(0xFFF3B749),
        ),
      SeasonalSplashTheme.newYear => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.newYear,
          badgeKey: 'splash_season_new_year_badge',
          titleKey: 'splash_season_new_year_title',
          subtitleKey: 'splash_season_new_year_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_morning_awakening_squad.png',
          darkGradient: [
            Color(0xFF0E1328),
            Color(0xFF1B2347),
            Color(0xFF2A1D3D),
          ],
          lightGradient: [
            Color(0xFFEEF2FF),
            Color(0xFFFDF5E6),
            Color(0xFFF6EEFA),
          ],
          accentColor: Color(0xFFF59E0B),
          secondaryAccentColor: Color(0xFF60A5FA),
        ),
      SeasonalSplashTheme.lunarLantern => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.lunarLantern,
          badgeKey: 'splash_season_lunar_badge',
          titleKey: 'splash_season_lunar_title',
          subtitleKey: 'splash_season_lunar_subtitle',
          mascotAsset: 'assets/mascots/sprites/echo/candlelight.png',
          darkGradient: [
            Color(0xFF230E14),
            Color(0xFF3A151D),
            Color(0xFF1E1418),
          ],
          lightGradient: [
            Color(0xFFFFF1EE),
            Color(0xFFFFF6E5),
            Color(0xFFFBE9E7),
          ],
          accentColor: Color(0xFFE04A3A),
          secondaryAccentColor: Color(0xFFFFB74D),
        ),
      SeasonalSplashTheme.springBloom => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.springBloom,
          badgeKey: 'splash_season_spring_badge',
          titleKey: 'splash_season_spring_title',
          subtitleKey: 'splash_season_spring_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_inspiration_quote_atelier.png',
          darkGradient: [
            Color(0xFF14211D),
            Color(0xFF1D2E28),
            Color(0xFF2B1E28),
          ],
          lightGradient: [
            Color(0xFFECFDF5),
            Color(0xFFFDF2F8),
            Color(0xFFF0FDF4),
          ],
          accentColor: Color(0xFF10B981),
          secondaryAccentColor: Color(0xFFF472B6),
        ),
      SeasonalSplashTheme.summerSun => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.summerSun,
          badgeKey: 'splash_season_summer_badge',
          titleKey: 'splash_season_summer_title',
          subtitleKey: 'splash_season_summer_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_travel_adventure_packers.png',
          darkGradient: [
            Color(0xFF0D1E2E),
            Color(0xFF15324A),
            Color(0xFF2B2418),
          ],
          lightGradient: [
            Color(0xFFE0F2FE),
            Color(0xFFFEF9C3),
            Color(0xFFFFEDD5),
          ],
          accentColor: Color(0xFF3B82F6),
          secondaryAccentColor: Color(0xFFF59E0B),
        ),
      SeasonalSplashTheme.autumnHarvest => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.autumnHarvest,
          badgeKey: 'splash_season_autumn_badge',
          titleKey: 'splash_season_autumn_title',
          subtitleKey: 'splash_season_autumn_subtitle',
          mascotAsset: 'assets/mascots/sprites/seren/tea_time.png',
          darkGradient: [
            Color(0xFF241410),
            Color(0xFF382016),
            Color(0xFF1C181B),
          ],
          lightGradient: [
            Color(0xFFFFF7ED),
            Color(0xFFFEF3C7),
            Color(0xFFFCE7D6),
          ],
          accentColor: Color(0xFFD97706),
          secondaryAccentColor: Color(0xFFE04A3A),
        ),
      SeasonalSplashTheme.cozyLantern => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.cozyLantern,
          badgeKey: 'splash_season_cozy_badge',
          titleKey: 'splash_season_cozy_title',
          subtitleKey: 'splash_season_cozy_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_evening_wind_down_crew.png',
          darkGradient: [
            Color(0xFF121524),
            Color(0xFF1E2236),
            Color(0xFF261E24),
          ],
          lightGradient: [
            Color(0xFFF1F5F9),
            Color(0xFFEDE9FE),
            Color(0xFFFEF3C7),
          ],
          accentColor: Color(0xFF8B5CF6),
          secondaryAccentColor: Color(0xFFFF9E1B),
        ),
    };
  }
}
