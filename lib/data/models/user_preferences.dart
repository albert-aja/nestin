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
    );
  }
}

