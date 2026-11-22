import 'package:material_ui/material_ui.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_localizations.dart';
import '../../ui/screens/nest/treehouse_painters.dart';
import '../../ui/screens/splash/seasonal_loading_theme.dart';
import 'challenge_profile.dart';

/// Auto-lock timeout options after leaving the Diary / backgrounding the app.
enum DiaryAutoLockDelay {
  immediately,
  oneMinute,
  fiveMinutes,
}

extension DiaryAutoLockDelayExt on DiaryAutoLockDelay {
  Duration get duration => switch (this) {
        DiaryAutoLockDelay.immediately => Duration.zero,
        DiaryAutoLockDelay.oneMinute => const Duration(minutes: 1),
        DiaryAutoLockDelay.fiveMinutes => const Duration(minutes: 5),
      };

  String get label => switch (this) {
        DiaryAutoLockDelay.immediately => 'Immediately',
        DiaryAutoLockDelay.oneMinute => '1 minute',
        DiaryAutoLockDelay.fiveMinutes => '5 minutes',
      };

  String get shortLabel => switch (this) {
        DiaryAutoLockDelay.immediately => 'Instant',
        DiaryAutoLockDelay.oneMinute => '1 min',
        DiaryAutoLockDelay.fiveMinutes => '5 min',
      };

  String get description => switch (this) {
        DiaryAutoLockDelay.immediately =>
          'Re-lock as soon as you leave Diary',
        DiaryAutoLockDelay.oneMinute =>
          'Re-lock 1 minute after leaving Diary',
        DiaryAutoLockDelay.fiveMinutes =>
          'Re-lock 5 minutes after leaving Diary',
      };

  String localizedLabel(AppLocalizations l10n) => switch (this) {
        DiaryAutoLockDelay.immediately => l10n.tr('autolock_immediately'),
        DiaryAutoLockDelay.oneMinute => l10n.tr('autolock_one_minute'),
        DiaryAutoLockDelay.fiveMinutes => l10n.tr('autolock_five_minutes'),
      };

  String localizedShortLabel(AppLocalizations l10n) => switch (this) {
        DiaryAutoLockDelay.immediately => l10n.tr('autolock_short_immediately'),
        DiaryAutoLockDelay.oneMinute => l10n.tr('autolock_short_one_minute'),
        DiaryAutoLockDelay.fiveMinutes => l10n.tr('autolock_short_five_minutes'),
      };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
        DiaryAutoLockDelay.immediately => l10n.tr('autolock_desc_immediately'),
        DiaryAutoLockDelay.oneMinute => l10n.tr('autolock_desc_one_minute'),
        DiaryAutoLockDelay.fiveMinutes => l10n.tr('autolock_desc_five_minutes'),
      };
}

/// Configurable dwell duration & animation speed on cold launch (`SplashScreen`).
enum SplashSpeed {
  quick,
  normal,
  relaxed,
  instant,
}

extension SplashSpeedExt on SplashSpeed {
  Duration get duration => switch (this) {
        SplashSpeed.quick => const Duration(milliseconds: 800),
        SplashSpeed.normal => const Duration(milliseconds: 1400),
        SplashSpeed.relaxed => const Duration(milliseconds: 2200),
        SplashSpeed.instant => Duration.zero,
      };

  Duration get animationDuration => switch (this) {
        SplashSpeed.quick => const Duration(milliseconds: 650),
        SplashSpeed.normal => const Duration(milliseconds: 1100),
        SplashSpeed.relaxed => const Duration(milliseconds: 1500),
        SplashSpeed.instant => Duration.zero,
      };

  bool get isInstant => this == SplashSpeed.instant;

  String localizedLabel(AppLocalizations l10n) => switch (this) {
        SplashSpeed.quick => l10n.tr('splash_speed_quick'),
        SplashSpeed.normal => l10n.tr('splash_speed_normal'),
        SplashSpeed.relaxed => l10n.tr('splash_speed_relaxed'),
        SplashSpeed.instant => l10n.tr('splash_speed_instant'),
      };

  String localizedShortLabel(AppLocalizations l10n) => switch (this) {
        SplashSpeed.quick => l10n.tr('splash_speed_short_quick'),
        SplashSpeed.normal => l10n.tr('splash_speed_short_normal'),
        SplashSpeed.relaxed => l10n.tr('splash_speed_short_relaxed'),
        SplashSpeed.instant => l10n.tr('splash_speed_short_instant'),
      };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
        SplashSpeed.quick => l10n.tr('splash_speed_desc_quick'),
        SplashSpeed.normal => l10n.tr('splash_speed_desc_normal'),
        SplashSpeed.relaxed => l10n.tr('splash_speed_desc_relaxed'),
        SplashSpeed.instant => l10n.tr('splash_speed_desc_instant'),
      };

  static SplashSpeed fromName(String? name) {
    return SplashSpeed.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SplashSpeed.normal,
    );
  }
}

/// View presentation mode for the Nest tab (`NestTreehouseScreen`).
enum NestViewMode {
  roomsGrid,
  treehouseScene,
}

extension NestViewModeExt on NestViewMode {
  bool get isScene => this == NestViewMode.treehouseScene;

  String localizedLabel(AppLocalizations l10n) => switch (this) {
        NestViewMode.roomsGrid => l10n.tr('nest_view_rooms_grid'),
        NestViewMode.treehouseScene => l10n.tr('nest_view_treehouse_scene'),
      };

  static NestViewMode fromName(String? name) {
    return NestViewMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => NestViewMode.roomsGrid,
    );
  }
}

class UserPreferences {
  final ThemeMode themeMode;
  final AppLanguage language;
  final bool use24Hour;
  final bool weekStartMonday;
  final int defaultSnoozeMinutes;
  final double defaultVolume;
  final bool defaultGradualVolume;
  final int defaultGradualSeconds;
  final bool defaultVibration;
  final String defaultSound;
  final WakeUpChallengeProfile globalChallengeProfile;
  final bool isBiometricEnabled;
  final bool isDiaryLockEnabled;
  final bool isAppLockEnabled;
  final String? securityPin;
  final String? securityPinHint;
  final DiaryAutoLockDelay diaryAutoLockDelay;
  final bool showJournalPrompts;
  final bool showThrowbacks;
  final bool hasCompletedOnboarding;
  final bool showWidgetMascots;
  final SplashSpeed splashSpeed;
  final SeasonalSplashTheme? seasonalSplashOverride;
  final NestViewMode nestViewMode;
  final TreehouseDayPhase? treehousePhaseOverride;

  const UserPreferences({
    this.themeMode = ThemeMode.dark,
    this.language = AppLanguage.en,
    this.use24Hour = false,
    this.weekStartMonday = true,
    this.defaultSnoozeMinutes = 9,
    this.defaultVolume = 0.85,
    this.defaultGradualVolume = true,
    this.defaultGradualSeconds = 60,
    this.defaultVibration = true,
    this.defaultSound = 'rooster_dawn',
    required this.globalChallengeProfile,
    this.isBiometricEnabled = false,
    this.isDiaryLockEnabled = false,
    this.isAppLockEnabled = false,
    this.securityPin,
    this.securityPinHint,
    this.diaryAutoLockDelay = DiaryAutoLockDelay.oneMinute,
    this.showJournalPrompts = true,
    this.showThrowbacks = true,
    this.hasCompletedOnboarding = false,
    this.showWidgetMascots = true,
    this.splashSpeed = SplashSpeed.normal,
    this.seasonalSplashOverride,
    this.nestViewMode = NestViewMode.roomsGrid,
    this.treehousePhaseOverride,
  });

  factory UserPreferences.defaults() {
    return UserPreferences(
      globalChallengeProfile: WakeUpChallengeProfile.defaultProfile(),
    );
  }

  UserPreferences copyWith({
    ThemeMode? themeMode,
    AppLanguage? language,
    bool? use24Hour,
    bool? weekStartMonday,
    int? defaultSnoozeMinutes,
    double? defaultVolume,
    bool? defaultGradualVolume,
    int? defaultGradualSeconds,
    bool? defaultVibration,
    String? defaultSound,
    WakeUpChallengeProfile? globalChallengeProfile,
    bool? isBiometricEnabled,
    bool? isDiaryLockEnabled,
    bool? isAppLockEnabled,
    String? securityPin,
    bool? clearPin,
    String? securityPinHint,
    bool? clearPinHint,
    DiaryAutoLockDelay? diaryAutoLockDelay,
    bool? showJournalPrompts,
    bool? showThrowbacks,
    bool? hasCompletedOnboarding,
    bool? showWidgetMascots,
    SplashSpeed? splashSpeed,
    SeasonalSplashTheme? seasonalSplashOverride,
    bool clearSeasonalSplashOverride = false,
    NestViewMode? nestViewMode,
    TreehouseDayPhase? treehousePhaseOverride,
    bool clearTreehousePhaseOverride = false,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      use24Hour: use24Hour ?? this.use24Hour,
      weekStartMonday: weekStartMonday ?? this.weekStartMonday,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      defaultVolume: defaultVolume ?? this.defaultVolume,
      defaultGradualVolume: defaultGradualVolume ?? this.defaultGradualVolume,
      defaultGradualSeconds:
          defaultGradualSeconds ?? this.defaultGradualSeconds,
      defaultVibration: defaultVibration ?? this.defaultVibration,
      defaultSound: defaultSound ?? this.defaultSound,
      globalChallengeProfile:
          globalChallengeProfile ?? this.globalChallengeProfile,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isDiaryLockEnabled: isDiaryLockEnabled ?? this.isDiaryLockEnabled,
      isAppLockEnabled: isAppLockEnabled ?? this.isAppLockEnabled,
      securityPin: clearPin == true ? null : (securityPin ?? this.securityPin),
      securityPinHint: clearPinHint == true
          ? null
          : (securityPinHint ?? this.securityPinHint),
      diaryAutoLockDelay: diaryAutoLockDelay ?? this.diaryAutoLockDelay,
      showJournalPrompts: showJournalPrompts ?? this.showJournalPrompts,
      showThrowbacks: showThrowbacks ?? this.showThrowbacks,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      showWidgetMascots: showWidgetMascots ?? this.showWidgetMascots,
      splashSpeed: splashSpeed ?? this.splashSpeed,
      seasonalSplashOverride: clearSeasonalSplashOverride
          ? null
          : (seasonalSplashOverride ?? this.seasonalSplashOverride),
      nestViewMode: nestViewMode ?? this.nestViewMode,
      treehousePhaseOverride: clearTreehousePhaseOverride
          ? null
          : (treehousePhaseOverride ?? this.treehousePhaseOverride),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
      'language': language.code,
      'use24Hour': use24Hour,
      'weekStartMonday': weekStartMonday,
      'defaultSnoozeMinutes': defaultSnoozeMinutes,
      'defaultVolume': defaultVolume,
      'defaultGradualVolume': defaultGradualVolume,
      'defaultGradualSeconds': defaultGradualSeconds,
      'defaultVibration': defaultVibration,
      'defaultSound': defaultSound,
      'globalChallengeProfile': globalChallengeProfile.toJson(),
      'isBiometricEnabled': isBiometricEnabled,
      'isDiaryLockEnabled': isDiaryLockEnabled,
      'isAppLockEnabled': isAppLockEnabled,
      'securityPin': securityPin,
      'securityPinHint': securityPinHint,
      'diaryAutoLockDelay': diaryAutoLockDelay.name,
      'showJournalPrompts': showJournalPrompts,
      'showThrowbacks': showThrowbacks,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'showWidgetMascots': showWidgetMascots,
      'splashSpeed': splashSpeed.name,
      'seasonalSplashOverride': seasonalSplashOverride?.name,
      'nestViewMode': nestViewMode.name,
      'treehousePhaseOverride': treehousePhaseOverride?.name,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final themeName = json['themeMode'] as String? ?? 'dark';
    final theme = ThemeMode.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => ThemeMode.dark,
    );
    final delayName = json['diaryAutoLockDelay'] as String? ?? 'oneMinute';
    final autoLockDelay = DiaryAutoLockDelay.values.firstWhere(
      (e) => e.name == delayName,
      orElse: () => DiaryAutoLockDelay.oneMinute,
    );
    final globalProfileJson = json['globalChallengeProfile'];
    final globalProfile = globalProfileJson != null
        ? WakeUpChallengeProfile.fromJson(
            globalProfileJson as Map<String, dynamic>,
          )
        : WakeUpChallengeProfile.defaultProfile();

    return UserPreferences(
      themeMode: theme,
      language: AppLanguageExt.fromCode(json['language'] as String?),
      use24Hour: json['use24Hour'] as bool? ?? false,
      weekStartMonday: json['weekStartMonday'] as bool? ?? true,
      defaultSnoozeMinutes: json['defaultSnoozeMinutes'] as int? ?? 9,
      defaultVolume: (json['defaultVolume'] as num?)?.toDouble() ?? 0.85,
      defaultGradualVolume: json['defaultGradualVolume'] as bool? ?? true,
      defaultGradualSeconds: json['defaultGradualSeconds'] as int? ?? 60,
      defaultVibration: json['defaultVibration'] as bool? ?? true,
      defaultSound: json['defaultSound'] as String? ?? 'rooster_dawn',
      globalChallengeProfile: globalProfile,
      isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? false,
      isDiaryLockEnabled: json['isDiaryLockEnabled'] as bool? ?? false,
      isAppLockEnabled: json['isAppLockEnabled'] as bool? ?? false,
      securityPin: json['securityPin'] as String?,
      securityPinHint: json['securityPinHint'] as String?,
      diaryAutoLockDelay: autoLockDelay,
      showJournalPrompts: json['showJournalPrompts'] as bool? ?? true,
      showThrowbacks: json['showThrowbacks'] as bool? ?? true,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
      showWidgetMascots: json['showWidgetMascots'] as bool? ?? true,
      splashSpeed: SplashSpeedExt.fromName(json['splashSpeed'] as String?),
      seasonalSplashOverride: SeasonalSplashThemeExt.fromNameOrNull(
        json['seasonalSplashOverride'] as String?,
      ),
      nestViewMode: NestViewModeExt.fromName(json['nestViewMode'] as String?),
      treehousePhaseOverride: TreehouseDayPhaseX.fromNameOrNull(
        json['treehousePhaseOverride'] as String?,
      ),
    );
  }
}

