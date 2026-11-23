import 'package:material_ui/material_ui.dart';

/// Seasonal themes used for the Phase-2 wallpaper loading screen after the
/// initial Nestin logo banner.
enum SeasonalSplashTheme {
  everydaySunnyPicnic,
  everydayTreehouse,
  everydayFireplace,
  everydayStarlight,
  newYear,
  lunarLantern,
  friendshipLetters,
  eidLantern,
  springBloom,
  earthDay,
  summerSun,
  midsummerKite,
  midAutumn,
  autumnHarvest,
  halloween,
  cozyLantern,
  gratitudeHarvest,
  christmas,
}

extension SeasonalSplashThemeExt on SeasonalSplashTheme {
  String get labelKey => switch (this) {
        SeasonalSplashTheme.everydaySunnyPicnic =>
          'splash_season_opt_everyday_picnic',
        SeasonalSplashTheme.everydayTreehouse =>
          'splash_season_opt_everyday_treehouse',
        SeasonalSplashTheme.everydayFireplace =>
          'splash_season_opt_everyday_fireplace',
        SeasonalSplashTheme.everydayStarlight =>
          'splash_season_opt_everyday_starlight',
        SeasonalSplashTheme.newYear => 'splash_season_opt_new_year',
        SeasonalSplashTheme.lunarLantern => 'splash_season_opt_lunar',
        SeasonalSplashTheme.friendshipLetters => 'splash_season_opt_friendship',
        SeasonalSplashTheme.eidLantern => 'splash_season_opt_eid',
        SeasonalSplashTheme.springBloom => 'splash_season_opt_spring',
        SeasonalSplashTheme.earthDay => 'splash_season_opt_earth_day',
        SeasonalSplashTheme.summerSun => 'splash_season_opt_summer',
        SeasonalSplashTheme.midsummerKite => 'splash_season_opt_midsummer',
        SeasonalSplashTheme.midAutumn => 'splash_season_opt_mid_autumn',
        SeasonalSplashTheme.autumnHarvest => 'splash_season_opt_autumn',
        SeasonalSplashTheme.halloween => 'splash_season_opt_halloween',
        SeasonalSplashTheme.cozyLantern => 'splash_season_opt_cozy',
        SeasonalSplashTheme.gratitudeHarvest => 'splash_season_opt_gratitude',
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
  final String? wallpaperAsset;
  final String? customWallpaperFilePath;
  final String? remotePackSlug;
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
    this.wallpaperAsset,
    this.customWallpaperFilePath,
    this.remotePackSlug,
    required this.darkGradient,
    required this.lightGradient,
    required this.accentColor,
    required this.secondaryAccentColor,
  });

  bool get hasCustomPhoto =>
      !hasRemotePack &&
      customWallpaperFilePath != null &&
      customWallpaperFilePath!.trim().isNotEmpty;

  bool get hasRemotePack =>
      remotePackSlug != null && remotePackSlug!.trim().isNotEmpty;

  SeasonalLoadingSpec copyWith({
    SeasonalSplashTheme? theme,
    String? badgeKey,
    String? titleKey,
    String? subtitleKey,
    String? mascotAsset,
    String? wallpaperAsset,
    String? customWallpaperFilePath,
    String? remotePackSlug,
    List<Color>? darkGradient,
    List<Color>? lightGradient,
    Color? accentColor,
    Color? secondaryAccentColor,
  }) {
    return SeasonalLoadingSpec(
      theme: theme ?? this.theme,
      badgeKey: badgeKey ?? this.badgeKey,
      titleKey: titleKey ?? this.titleKey,
      subtitleKey: subtitleKey ?? this.subtitleKey,
      mascotAsset: mascotAsset ?? this.mascotAsset,
      wallpaperAsset: wallpaperAsset ?? this.wallpaperAsset,
      customWallpaperFilePath:
          customWallpaperFilePath ?? this.customWallpaperFilePath,
      remotePackSlug: remotePackSlug ?? this.remotePackSlug,
      darkGradient: darkGradient ?? this.darkGradient,
      lightGradient: lightGradient ?? this.lightGradient,
      accentColor: accentColor ?? this.accentColor,
      secondaryAccentColor: secondaryAccentColor ?? this.secondaryAccentColor,
    );
  }
}

/// Metadata for a curated seasonal/holiday wallpaper pack in the `/api/v1/media`
/// backend catalog that users can download and activate for Phase 2 of [SplashScreen].
class RemoteHolidayWallpaperPack {
  final String id;
  final String slug;
  final String optionLabelKey;
  final String badgeKey;
  final String titleKey;
  final String subtitleKey;
  final String bundledPreviewAsset;
  final String mascotAsset;
  final String storageBucket;
  final String storagePath;
  final String? publicUrl;
  final int byteSize;
  final String mascotDomain;
  final SeasonalSplashTheme pairedParticlesTheme;
  final List<Color> darkGradient;
  final List<Color> lightGradient;
  final Color accentColor;
  final Color secondaryAccentColor;

  const RemoteHolidayWallpaperPack({
    required this.id,
    required this.slug,
    required this.optionLabelKey,
    required this.badgeKey,
    required this.titleKey,
    required this.subtitleKey,
    required this.bundledPreviewAsset,
    required this.mascotAsset,
    this.storageBucket = 'public-media',
    required this.storagePath,
    this.publicUrl,
    required this.byteSize,
    required this.mascotDomain,
    required this.pairedParticlesTheme,
    required this.darkGradient,
    required this.lightGradient,
    required this.accentColor,
    required this.secondaryAccentColor,
  });

  String get formattedSizeKb => '${(byteSize / 1024).round()} KB';

  RemoteHolidayWallpaperPack mergeRemoteMetadata(Map<String, dynamic> json) {
    return RemoteHolidayWallpaperPack(
      id: (json['id'] as String?) ?? id,
      slug: (json['slug'] as String?) ?? slug,
      optionLabelKey: optionLabelKey,
      badgeKey: badgeKey,
      titleKey: titleKey,
      subtitleKey: subtitleKey,
      bundledPreviewAsset: bundledPreviewAsset,
      mascotAsset: mascotAsset,
      storageBucket: (json['storageBucket'] as String?) ?? storageBucket,
      storagePath: (json['storagePath'] as String?) ?? storagePath,
      publicUrl: (json['publicUrl'] as String?) ?? publicUrl,
      byteSize: (json['byteSize'] is num)
          ? (json['byteSize'] as num).toInt()
          : byteSize,
      mascotDomain: (json['mascotDomain'] as String?) ?? mascotDomain,
      pairedParticlesTheme: pairedParticlesTheme,
      darkGradient: darkGradient,
      lightGradient: lightGradient,
      accentColor: accentColor,
      secondaryAccentColor: secondaryAccentColor,
    );
  }

  SeasonalLoadingSpec toLoadingSpec({String? localCachedFilePath}) {
    return SeasonalLoadingSpec(
      theme: pairedParticlesTheme,
      badgeKey: badgeKey,
      titleKey: titleKey,
      subtitleKey: subtitleKey,
      mascotAsset: mascotAsset,
      wallpaperAsset: bundledPreviewAsset,
      customWallpaperFilePath: localCachedFilePath,
      remotePackSlug: slug,
      darkGradient: darkGradient,
      lightGradient: lightGradient,
      accentColor: accentColor,
      secondaryAccentColor: secondaryAccentColor,
    );
  }
}

/// Curated catalog of remote seasonal/holiday wallpaper packs from the `media`
/// backend module (`/api/v1/media?assetType=wallpaper`).
class RemoteHolidayWallpaperCatalog {
  const RemoteHolidayWallpaperCatalog._();

  static const List<RemoteHolidayWallpaperPack> packs = [
    RemoteHolidayWallpaperPack(
      id: '30000000-0000-0000-0000-000000000003',
      slug: 'cherry-blossom-picnic',
      optionLabelKey: 'splash_pack_cherry_blossom_opt',
      badgeKey: 'splash_pack_cherry_blossom_badge',
      titleKey: 'splash_pack_cherry_blossom_title',
      subtitleKey: 'splash_pack_cherry_blossom_subtitle',
      bundledPreviewAsset:
          'assets/mascots/wallpapers/seasonal/cherry_blossom_picnic.jpg',
      mascotAsset:
          'assets/mascots/sprites/ensembles/trio_inspiration_quote_atelier.png',
      storagePath: 'wallpapers/seasonal/cherry_blossom_picnic.jpg',
      byteSize: 262144,
      mascotDomain: 'pippin',
      pairedParticlesTheme: SeasonalSplashTheme.springBloom,
      darkGradient: [
        Color(0xFF1F1624),
        Color(0xFF332030),
        Color(0xFF1A2822),
      ],
      lightGradient: [
        Color(0xFFFDF2F8),
        Color(0xFFFCE7F3),
        Color(0xFFECFDF5),
      ],
      accentColor: Color(0xFFEC4899),
      secondaryAccentColor: Color(0xFFF9A8D4),
    ),
    RemoteHolidayWallpaperPack(
      id: '30000000-0000-0000-0000-000000000004',
      slug: 'winter-snow-cabin',
      optionLabelKey: 'splash_pack_winter_cabin_opt',
      badgeKey: 'splash_pack_winter_cabin_badge',
      titleKey: 'splash_pack_winter_cabin_title',
      subtitleKey: 'splash_pack_winter_cabin_subtitle',
      bundledPreviewAsset:
          'assets/mascots/wallpapers/seasonal/winter_snow_cabin.jpg',
      mascotAsset:
          'assets/mascots/sprites/ensembles/trio_evening_wind_down_crew.png',
      storagePath: 'wallpapers/seasonal/winter_snow_cabin.jpg',
      byteSize: 278528,
      mascotDomain: 'echo',
      pairedParticlesTheme: SeasonalSplashTheme.christmas,
      darkGradient: [
        Color(0xFF0E1B2A),
        Color(0xFF1A2D42),
        Color(0xFF281C18),
      ],
      lightGradient: [
        Color(0xFFEFF6FF),
        Color(0xFFE0F2FE),
        Color(0xFFFEF3C7),
      ],
      accentColor: Color(0xFF38BDF8),
      secondaryAccentColor: Color(0xFFFBBF24),
    ),
    RemoteHolidayWallpaperPack(
      id: '30000000-0000-0000-0000-000000000005',
      slug: 'sunset-seaside-lighthouse',
      optionLabelKey: 'splash_pack_seaside_lighthouse_opt',
      badgeKey: 'splash_pack_seaside_lighthouse_badge',
      titleKey: 'splash_pack_seaside_lighthouse_title',
      subtitleKey: 'splash_pack_seaside_lighthouse_subtitle',
      bundledPreviewAsset:
          'assets/mascots/wallpapers/seasonal/sunset_seaside_lighthouse.jpg',
      mascotAsset:
          'assets/mascots/sprites/ensembles/trio_travel_adventure_packers.png',
      storagePath: 'wallpapers/seasonal/sunset_seaside_lighthouse.jpg',
      byteSize: 253952,
      mascotDomain: 'scout',
      pairedParticlesTheme: SeasonalSplashTheme.summerSun,
      darkGradient: [
        Color(0xFF1D162B),
        Color(0xFF382032),
        Color(0xFF152938),
      ],
      lightGradient: [
        Color(0xFFFFF7ED),
        Color(0xFFFFEDD5),
        Color(0xFFE0F2FE),
      ],
      accentColor: Color(0xFFF97316),
      secondaryAccentColor: Color(0xFFFDE047),
    ),
    RemoteHolidayWallpaperPack(
      id: '30000000-0000-0000-0000-000000000006',
      slug: 'tropical-bamboo-mist',
      optionLabelKey: 'splash_pack_bamboo_mist_opt',
      badgeKey: 'splash_pack_bamboo_mist_badge',
      titleKey: 'splash_pack_bamboo_mist_title',
      subtitleKey: 'splash_pack_bamboo_mist_subtitle',
      bundledPreviewAsset:
          'assets/mascots/wallpapers/seasonal/tropical_bamboo_mist.jpg',
      mascotAsset: 'assets/mascots/sprites/seren/bamboo_rain_lantern.png',
      storagePath: 'wallpapers/seasonal/tropical_bamboo_mist.jpg',
      byteSize: 249856,
      mascotDomain: 'seren',
      pairedParticlesTheme: SeasonalSplashTheme.earthDay,
      darkGradient: [
        Color(0xFF0C221C),
        Color(0xFF15352C),
        Color(0xFF1A2823),
      ],
      lightGradient: [
        Color(0xFFECFDF5),
        Color(0xFFD1FAE5),
        Color(0xFFE0F2FE),
      ],
      accentColor: Color(0xFF10B981),
      secondaryAccentColor: Color(0xFF6EE7B7),
    ),
  ];

  static RemoteHolidayWallpaperPack? bySlug(String? slug) {
    if (slug == null || slug.trim().isEmpty) return null;
    for (final pack in packs) {
      if (pack.slug == slug) return pack;
    }
    return null;
  }
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
    final date = now ?? DateTime.now();
    final month = date.month;
    final day = date.day;

    // Smart Hybrid schedule: dedicated seasonal & holiday date windows first,
    // then time-of-day Everyday (non-seasonal) portraits on regular days.
    if (_isEidWindow(date)) {
      return SeasonalSplashTheme.eidLantern;
    }
    if (month == 12) {
      return SeasonalSplashTheme.christmas;
    }
    if (month == 1 && day <= 10) {
      return SeasonalSplashTheme.newYear;
    }
    if (month == 2 && day <= 11) {
      return SeasonalSplashTheme.lunarLantern;
    }
    if (month == 2 && day >= 12 && day <= 16) {
      return SeasonalSplashTheme.friendshipLetters;
    }
    if ((month == 3 && day >= 20) || (month == 4 && day <= 10)) {
      return SeasonalSplashTheme.springBloom;
    }
    if (month == 4 && day >= 20 && day <= 24) {
      return SeasonalSplashTheme.earthDay;
    }
    if (month == 6 && day >= 15) {
      return SeasonalSplashTheme.summerSun;
    }
    if ((month == 7 && day >= 15) || (month == 8 && day <= 18)) {
      return SeasonalSplashTheme.midsummerKite;
    }
    if (month == 9 && day >= 15 && day <= 28) {
      return SeasonalSplashTheme.midAutumn;
    }
    if (month == 10 && day <= 14) {
      return SeasonalSplashTheme.autumnHarvest;
    }
    if (month == 10 && day >= 24) {
      return SeasonalSplashTheme.halloween;
    }
    if (month == 11 && day <= 10) {
      return SeasonalSplashTheme.cozyLantern;
    }
    if (month == 11 && day >= 22 && day <= 28) {
      return SeasonalSplashTheme.gratitudeHarvest;
    }

    return resolveEverydayThemeForHour(date.hour);
  }

  static SeasonalSplashTheme resolveEverydayThemeForHour(int hour) {
    if (hour >= 5 && hour < 12) {
      return SeasonalSplashTheme.everydaySunnyPicnic;
    }
    if (hour >= 12 && hour < 17) {
      return SeasonalSplashTheme.everydayTreehouse;
    }
    if (hour >= 17 && hour < 21) {
      return SeasonalSplashTheme.everydayFireplace;
    }
    return SeasonalSplashTheme.everydayStarlight;
  }

  static bool _isEidWindow(DateTime date) {
    final m = date.month;
    final d = date.day;
    return switch (date.year) {
      2025 => (m == 3 && d >= 30) || (m == 4 && d <= 2),
      2026 => m == 3 && d >= 19 && d <= 22,
      2027 => m == 3 && d >= 9 && d <= 12,
      2028 => m == 2 && d >= 26 && d <= 29,
      2029 => m == 2 && d >= 14 && d <= 17,
      2030 => m == 2 && d >= 4 && d <= 7,
      _ => false,
    };
  }

  static SeasonalLoadingSpec resolve({
    DateTime? now,
    SeasonalSplashTheme? override,
    String? customPhotoPath,
    String? remotePackSlug,
    Map<String, String>? installedRemotePackPaths,
  }) {
    final trimmedPhoto = customPhotoPath?.trim();
    if (trimmedPhoto != null && trimmedPhoto.isNotEmpty) {
      final baseTheme = resolveTheme(now: now, override: override);
      final baseSpec = specFor(baseTheme);
      return baseSpec.copyWith(
        badgeKey: 'splash_custom_photo_badge',
        titleKey: 'splash_custom_photo_title',
        subtitleKey: 'splash_custom_photo_subtitle',
        customWallpaperFilePath: trimmedPhoto,
      );
    }

    final pack = RemoteHolidayWallpaperCatalog.bySlug(remotePackSlug);
    if (pack != null) {
      final cachedPath = installedRemotePackPaths?[pack.slug];
      return pack.toLoadingSpec(localCachedFilePath: cachedPath);
    }

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
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/christmas_wallpaper.jpg',
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
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/happy_new_year.jpg',
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
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/lunar_new_year_potrait.jpg',
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
      SeasonalSplashTheme.friendshipLetters => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.friendshipLetters,
          badgeKey: 'splash_season_friendship_badge',
          titleKey: 'splash_season_friendship_title',
          subtitleKey: 'splash_season_friendship_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_inspiration_quote_atelier.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/friendship_cozy_letters.jpg',
          darkGradient: [
            Color(0xFF2B141C),
            Color(0xFF3D1C28),
            Color(0xFF24161A),
          ],
          lightGradient: [
            Color(0xFFFFF1F2),
            Color(0xFFFFE4E6),
            Color(0xFFFEF3C7),
          ],
          accentColor: Color(0xFFF43F5E),
          secondaryAccentColor: Color(0xFFFBBF24),
        ),
      SeasonalSplashTheme.eidLantern => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.eidLantern,
          badgeKey: 'splash_season_eid_badge',
          titleKey: 'splash_season_eid_title',
          subtitleKey: 'splash_season_eid_subtitle',
          mascotAsset: 'assets/mascots/sprites/echo/candlelight.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/eid_lantern_courtyard.jpg',
          darkGradient: [
            Color(0xFF0A2220),
            Color(0xFF133631),
            Color(0xFF1F2418),
          ],
          lightGradient: [
            Color(0xFFECFDF5),
            Color(0xFFFEF3C7),
            Color(0xFFE6F4F1),
          ],
          accentColor: Color(0xFF10B981),
          secondaryAccentColor: Color(0xFFFBBF24),
        ),
      SeasonalSplashTheme.springBloom => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.springBloom,
          badgeKey: 'splash_season_spring_badge',
          titleKey: 'splash_season_spring_title',
          subtitleKey: 'splash_season_spring_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_inspiration_quote_atelier.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/spring_gardening_festival.jpg',
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
      SeasonalSplashTheme.earthDay => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.earthDay,
          badgeKey: 'splash_season_earth_day_badge',
          titleKey: 'splash_season_earth_day_title',
          subtitleKey: 'splash_season_earth_day_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_inspiration_quote_atelier.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/earth_day_rainy_planting.jpg',
          darkGradient: [
            Color(0xFF0E241E),
            Color(0xFF18382F),
            Color(0xFF1B2430),
          ],
          lightGradient: [
            Color(0xFFECFDF5),
            Color(0xFFE0F2FE),
            Color(0xFFF0FDF4),
          ],
          accentColor: Color(0xFF22C55E),
          secondaryAccentColor: Color(0xFF38BDF8),
        ),
      SeasonalSplashTheme.summerSun => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.summerSun,
          badgeKey: 'splash_season_summer_badge',
          titleKey: 'splash_season_summer_title',
          subtitleKey: 'splash_season_summer_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_travel_adventure_packers.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/summer_splash_river.jpg',
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
      SeasonalSplashTheme.midsummerKite => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.midsummerKite,
          badgeKey: 'splash_season_midsummer_badge',
          titleKey: 'splash_season_midsummer_title',
          subtitleKey: 'splash_season_midsummer_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_travel_adventure_packers.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/midsummer_kite_camp.jpg',
          darkGradient: [
            Color(0xFF102424),
            Color(0xFF1C3830),
            Color(0xFF2F2816),
          ],
          lightGradient: [
            Color(0xFFECFCCB),
            Color(0xFFFEF3C7),
            Color(0xFFE0F2FE),
          ],
          accentColor: Color(0xFF10B981),
          secondaryAccentColor: Color(0xFFFBBF24),
        ),
      SeasonalSplashTheme.midAutumn => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.midAutumn,
          badgeKey: 'splash_season_mid_autumn_badge',
          titleKey: 'splash_season_mid_autumn_title',
          subtitleKey: 'splash_season_mid_autumn_subtitle',
          mascotAsset: 'assets/mascots/sprites/echo/candlelight.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/mid_autumn_moon_festival.jpg',
          darkGradient: [
            Color(0xFF0E162B),
            Color(0xFF1A2847),
            Color(0xFF2A2018),
          ],
          lightGradient: [
            Color(0xFFEEF2FF),
            Color(0xFFFEF3C7),
            Color(0xFFFFEDD5),
          ],
          accentColor: Color(0xFFF59E0B),
          secondaryAccentColor: Color(0xFFFDE68A),
        ),
      SeasonalSplashTheme.autumnHarvest => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.autumnHarvest,
          badgeKey: 'splash_season_autumn_badge',
          titleKey: 'splash_season_autumn_title',
          subtitleKey: 'splash_season_autumn_subtitle',
          mascotAsset: 'assets/mascots/sprites/seren/tea_time.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/autumn_harvest_festival.jpg',
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
      SeasonalSplashTheme.halloween => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.halloween,
          badgeKey: 'splash_season_halloween_badge',
          titleKey: 'splash_season_halloween_title',
          subtitleKey: 'splash_season_halloween_subtitle',
          mascotAsset: 'assets/mascots/sprites/echo/candlelight.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/halloween_pumpkin_night.jpg',
          darkGradient: [
            Color(0xFF1C102B),
            Color(0xFF2E1B42),
            Color(0xFF2A1812),
          ],
          lightGradient: [
            Color(0xFFF3E8FF),
            Color(0xFFFFEDD5),
            Color(0xFFFEF3C7),
          ],
          accentColor: Color(0xFFF97316),
          secondaryAccentColor: Color(0xFFFACC15),
        ),
      SeasonalSplashTheme.cozyLantern => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.cozyLantern,
          badgeKey: 'splash_season_cozy_badge',
          titleKey: 'splash_season_cozy_title',
          subtitleKey: 'splash_season_cozy_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_evening_wind_down_crew.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/november_cozy_hearth.jpg',
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
      SeasonalSplashTheme.gratitudeHarvest => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.gratitudeHarvest,
          badgeKey: 'splash_season_gratitude_badge',
          titleKey: 'splash_season_gratitude_title',
          subtitleKey: 'splash_season_gratitude_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_evening_wind_down_crew.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/seasonal/gratitude_harvest_table.jpg',
          darkGradient: [
            Color(0xFF231510),
            Color(0xFF3A2116),
            Color(0xFF1D1719),
          ],
          lightGradient: [
            Color(0xFFFFF7ED),
            Color(0xFFFEF3C7),
            Color(0xFFFCE7D6),
          ],
          accentColor: Color(0xFFD97706),
          secondaryAccentColor: Color(0xFFFBBF24),
        ),
      SeasonalSplashTheme.everydaySunnyPicnic => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.everydaySunnyPicnic,
          badgeKey: 'splash_season_everyday_picnic_badge',
          titleKey: 'splash_season_everyday_picnic_title',
          subtitleKey: 'splash_season_everyday_picnic_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_morning_awakening_squad.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/everyday/everyday_sunny_picnic.jpg',
          darkGradient: [
            Color(0xFF10241D),
            Color(0xFF1C3A2C),
            Color(0xFF2B2A18),
          ],
          lightGradient: [
            Color(0xFFECFDF5),
            Color(0xFFFEF9C3),
            Color(0xFFE0F2FE),
          ],
          accentColor: Color(0xFF10B981),
          secondaryAccentColor: Color(0xFFFBBF24),
        ),
      SeasonalSplashTheme.everydayTreehouse => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.everydayTreehouse,
          badgeKey: 'splash_season_everyday_treehouse_badge',
          titleKey: 'splash_season_everyday_treehouse_title',
          subtitleKey: 'splash_season_everyday_treehouse_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_inspiration_quote_atelier.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/everyday/everyday_treehouse_welcome.jpg',
          darkGradient: [
            Color(0xFF1B1912),
            Color(0xFF2B2418),
            Color(0xFF17221B),
          ],
          lightGradient: [
            Color(0xFFFEF3C7),
            Color(0xFFECFCCB),
            Color(0xFFFFEDD5),
          ],
          accentColor: Color(0xFFF59E0B),
          secondaryAccentColor: Color(0xFFFDE68A),
        ),
      SeasonalSplashTheme.everydayFireplace => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.everydayFireplace,
          badgeKey: 'splash_season_everyday_fireplace_badge',
          titleKey: 'splash_season_everyday_fireplace_title',
          subtitleKey: 'splash_season_everyday_fireplace_subtitle',
          mascotAsset:
              'assets/mascots/sprites/ensembles/trio_evening_wind_down_crew.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/everyday/everyday_rainy_fireplace.jpg',
          darkGradient: [
            Color(0xFF1F1412),
            Color(0xFF33201B),
            Color(0xFF161D2B),
          ],
          lightGradient: [
            Color(0xFFFFEDD5),
            Color(0xFFFEF3C7),
            Color(0xFFE2E8F0),
          ],
          accentColor: Color(0xFFE04A3A),
          secondaryAccentColor: Color(0xFFFFB74D),
        ),
      SeasonalSplashTheme.everydayStarlight => const SeasonalLoadingSpec(
          theme: SeasonalSplashTheme.everydayStarlight,
          badgeKey: 'splash_season_everyday_starlight_badge',
          titleKey: 'splash_season_everyday_starlight_title',
          subtitleKey: 'splash_season_everyday_starlight_subtitle',
          mascotAsset: 'assets/mascots/sprites/seren/starlight_blanket.png',
          wallpaperAsset:
              'assets/mascots/wallpapers/everyday/everyday_starlight_slumber.jpg',
          darkGradient: [
            Color(0xFF0B1226),
            Color(0xFF152242),
            Color(0xFF0E1D21),
          ],
          lightGradient: [
            Color(0xFFEEF2FF),
            Color(0xFFE0E7FF),
            Color(0xFFECFDF5),
          ],
          accentColor: Color(0xFF8B5CF6),
          secondaryAccentColor: Color(0xFFFDE68A),
        ),
    };
  }
}
