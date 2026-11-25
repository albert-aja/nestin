import 'package:flutter/foundation.dart';

/// Visual template styles available for the Daily Affirmation Lock-Screen Wallpaper.
enum DailyWallpaperTemplate {
  sanctuaryMinimal,
  seasonalAtmosphere,
  treehouseGlassCard;

  String toJsonKey() => name;

  static DailyWallpaperTemplate fromJsonKey(String? raw) {
    for (final value in DailyWallpaperTemplate.values) {
      if (value.name == raw) return value;
    }
    return DailyWallpaperTemplate.sanctuaryMinimal;
  }

  String get titleKey => switch (this) {
        DailyWallpaperTemplate.sanctuaryMinimal =>
          'daily_wp_tpl_sanctuary_minimal',
        DailyWallpaperTemplate.seasonalAtmosphere =>
          'daily_wp_tpl_seasonal_atmosphere',
        DailyWallpaperTemplate.treehouseGlassCard =>
          'daily_wp_tpl_treehouse_glass',
      };

  String get subtitleKey => switch (this) {
        DailyWallpaperTemplate.sanctuaryMinimal =>
          'daily_wp_tpl_sanctuary_minimal_desc',
        DailyWallpaperTemplate.seasonalAtmosphere =>
          'daily_wp_tpl_seasonal_atmosphere_desc',
        DailyWallpaperTemplate.treehouseGlassCard =>
          'daily_wp_tpl_treehouse_glass_desc',
      };
}

/// Android wallpaper target destination (Lock Screen Only vs Lock & Home Screen).
enum DailyWallpaperTarget {
  lockOnly,
  lockAndHome;

  String toJsonKey() => name;

  String toChannelValue() =>
      this == DailyWallpaperTarget.lockAndHome ? 'both' : 'lock';

  static DailyWallpaperTarget fromJsonKey(String? raw) {
    if (raw == DailyWallpaperTarget.lockAndHome.name || raw == 'both') {
      return DailyWallpaperTarget.lockAndHome;
    }
    return DailyWallpaperTarget.lockOnly;
  }

  String get labelKey => switch (this) {
        DailyWallpaperTarget.lockOnly => 'daily_wp_target_lock_only',
        DailyWallpaperTarget.lockAndHome => 'daily_wp_target_lock_and_home',
      };
}

/// Quote pool filter used when selecting daily lock-screen affirmations.
enum DailyWallpaperSource {
  dailyFeatured,
  favorites,
  calmGrounded;

  String toJsonKey() => name;

  static DailyWallpaperSource fromJsonKey(String? raw) {
    for (final value in DailyWallpaperSource.values) {
      if (value.name == raw) return value;
    }
    return DailyWallpaperSource.dailyFeatured;
  }

  String get labelKey => switch (this) {
        DailyWallpaperSource.dailyFeatured => 'daily_wp_source_featured',
        DailyWallpaperSource.favorites => 'daily_wp_source_favorites',
        DailyWallpaperSource.calmGrounded => 'daily_wp_source_calm_grounded',
      };
}

/// Persisted configuration for Nestin's opt-in Daily Affirmation Lock-Screen Wallpaper.
@immutable
class DailyWallpaperConfig {
  static const String personalPhotoWallpaperId = 'personal_photo';

  final bool enabled;
  final DailyWallpaperTemplate template;
  final DailyWallpaperTarget target;
  final DailyWallpaperSource quoteSource;
  final int refreshHour;
  final int refreshMinute;
  final bool showMascotSprite;
  final String? lastAppliedDate;

  /// Optional Nestin wallpaper backdrop ID applied behind the lock-screen
  /// affirmation:
  /// - `null`: Template default backdrop
  /// - `'theme:<SeasonalSplashTheme.name>'`: Built-in Everyday or Seasonal art
  /// - `'pack:<slug>'`: Downloadable Everyday or Seasonal wallpaper pack
  /// - `'personal_photo'`: User's imported Personal Photo wallpaper
  final String? customWallpaperId;

  const DailyWallpaperConfig({
    this.enabled = false,
    this.template = DailyWallpaperTemplate.sanctuaryMinimal,
    this.target = DailyWallpaperTarget.lockOnly,
    this.quoteSource = DailyWallpaperSource.dailyFeatured,
    this.refreshHour = 5,
    this.refreshMinute = 0,
    this.showMascotSprite = true,
    this.lastAppliedDate,
    this.customWallpaperId,
  });

  bool get hasCustomWallpaper =>
      customWallpaperId != null && customWallpaperId!.trim().isNotEmpty;

  String get formattedRefreshTime {
    final h = refreshHour.clamp(0, 23).toString().padLeft(2, '0');
    final m = refreshMinute.clamp(0, 59).toString().padLeft(2, '0');
    return '$h:$m';
  }

  DailyWallpaperConfig copyWith({
    bool? enabled,
    DailyWallpaperTemplate? template,
    DailyWallpaperTarget? target,
    DailyWallpaperSource? quoteSource,
    int? refreshHour,
    int? refreshMinute,
    bool? showMascotSprite,
    String? lastAppliedDate,
    bool clearLastAppliedDate = false,
    String? customWallpaperId,
    bool clearCustomWallpaperId = false,
  }) {
    return DailyWallpaperConfig(
      enabled: enabled ?? this.enabled,
      template: template ?? this.template,
      target: target ?? this.target,
      quoteSource: quoteSource ?? this.quoteSource,
      refreshHour: (refreshHour ?? this.refreshHour).clamp(0, 23),
      refreshMinute: (refreshMinute ?? this.refreshMinute).clamp(0, 59),
      showMascotSprite: showMascotSprite ?? this.showMascotSprite,
      lastAppliedDate: clearLastAppliedDate
          ? null
          : (lastAppliedDate ?? this.lastAppliedDate),
      customWallpaperId: clearCustomWallpaperId
          ? null
          : (customWallpaperId ?? this.customWallpaperId),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'template': template.toJsonKey(),
        'target': target.toJsonKey(),
        'quoteSource': quoteSource.toJsonKey(),
        'refreshHour': refreshHour,
        'refreshMinute': refreshMinute,
        'showMascotSprite': showMascotSprite,
        'lastAppliedDate': lastAppliedDate,
        'customWallpaperId': customWallpaperId,
      };

  factory DailyWallpaperConfig.fromJson(Map<String, dynamic> json) {
    final rawCustomWp = (json['customWallpaperId'] as String?)?.trim();
    return DailyWallpaperConfig(
      enabled: json['enabled'] as bool? ?? false,
      template: DailyWallpaperTemplate.fromJsonKey(json['template'] as String?),
      target: DailyWallpaperTarget.fromJsonKey(json['target'] as String?),
      quoteSource:
          DailyWallpaperSource.fromJsonKey(json['quoteSource'] as String?),
      refreshHour: ((json['refreshHour'] as num?)?.toInt() ?? 5).clamp(0, 23),
      refreshMinute:
          ((json['refreshMinute'] as num?)?.toInt() ?? 0).clamp(0, 59),
      showMascotSprite: json['showMascotSprite'] as bool? ?? true,
      lastAppliedDate: json['lastAppliedDate'] as String?,
      customWallpaperId:
          (rawCustomWp == null || rawCustomWp.isEmpty) ? null : rawCustomWp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyWallpaperConfig &&
        other.enabled == enabled &&
        other.template == template &&
        other.target == target &&
        other.quoteSource == quoteSource &&
        other.refreshHour == refreshHour &&
        other.refreshMinute == refreshMinute &&
        other.showMascotSprite == showMascotSprite &&
        other.lastAppliedDate == lastAppliedDate &&
        other.customWallpaperId == customWallpaperId;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        template,
        target,
        quoteSource,
        refreshHour,
        refreshMinute,
        showMascotSprite,
        lastAppliedDate,
        customWallpaperId,
      );
}
