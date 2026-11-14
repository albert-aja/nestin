import 'package:flutter/material.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_localizations.dart';
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
    );
  }
}

