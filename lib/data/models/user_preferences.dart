import 'package:flutter/material.dart';
import 'challenge_profile.dart';

class UserPreferences {
  final ThemeMode themeMode;
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
  final bool showJournalPrompts;
  final bool showThrowbacks;

  const UserPreferences({
    this.themeMode = ThemeMode.dark,
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
    bool? showJournalPrompts,
    bool? showThrowbacks,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
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
      showJournalPrompts: showJournalPrompts ?? this.showJournalPrompts,
      showThrowbacks: showThrowbacks ?? this.showThrowbacks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
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
    final globalProfileJson = json['globalChallengeProfile'];
    final globalProfile = globalProfileJson != null
        ? WakeUpChallengeProfile.fromJson(
            globalProfileJson as Map<String, dynamic>,
          )
        : WakeUpChallengeProfile.defaultProfile();

    return UserPreferences(
      themeMode: theme,
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
      showJournalPrompts: json['showJournalPrompts'] as bool? ?? true,
      showThrowbacks: json['showThrowbacks'] as bool? ?? true,
    );
  }
}

