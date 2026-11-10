import 'package:flutter/material.dart';
import '../data/models/user_preferences.dart';
import '../data/models/challenge_profile.dart';
import '../data/services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  late UserPreferences _preferences;

  SettingsProvider(this._storageService) {
    _preferences = _storageService.loadPreferences();
  }

  UserPreferences get preferences => _preferences;
  ThemeMode get themeMode => _preferences.themeMode;
  bool get use24Hour => _preferences.use24Hour;
  bool get weekStartMonday => _preferences.weekStartMonday;
  WakeUpChallengeProfile get globalChallengeProfile =>
      _preferences.globalChallengeProfile;

  Future<void> updatePreferences(UserPreferences newPrefs) async {
    _preferences = newPrefs;
    await _storageService.savePreferences(_preferences);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await updatePreferences(_preferences.copyWith(themeMode: mode));
  }

  Future<void> toggle24Hour(bool enabled) async {
    await updatePreferences(_preferences.copyWith(use24Hour: enabled));
  }

  Future<void> updateGlobalChallengeProfile(WakeUpChallengeProfile profile) async {
    await updatePreferences(
      _preferences.copyWith(globalChallengeProfile: profile),
    );
  }

  Future<void> updateDefaultSnooze(int minutes) async {
    await updatePreferences(_preferences.copyWith(defaultSnoozeMinutes: minutes));
  }

  Future<void> updateDefaultVolume(double volume) async {
    await updatePreferences(_preferences.copyWith(defaultVolume: volume));
  }

  Future<void> updateGradualVolume({
    required bool enabled,
    required int durationSeconds,
  }) async {
    await updatePreferences(
      _preferences.copyWith(
        defaultGradualVolume: enabled,
        defaultGradualSeconds: durationSeconds,
      ),
    );
  }
}

