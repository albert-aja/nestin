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

  // Security & Privacy Lock
  bool get isBiometricEnabled => _preferences.isBiometricEnabled;
  bool get isDiaryLockEnabled => _preferences.isDiaryLockEnabled;
  bool get isAppLockEnabled => _preferences.isAppLockEnabled;
  String? get securityPin => _preferences.securityPin;
  bool get hasPin =>
      _preferences.securityPin != null && _preferences.securityPin!.isNotEmpty;
  bool get showJournalPrompts => _preferences.showJournalPrompts;
  bool get showThrowbacks => _preferences.showThrowbacks;

  // Ephemeral in-session unlock state
  bool _isDiaryUnlocked = false;
  bool get isDiaryUnlocked => !isDiaryLockEnabled || _isDiaryUnlocked;

  void unlockDiary() {
    _isDiaryUnlocked = true;
    notifyListeners();
  }

  void lockDiary() {
    _isDiaryUnlocked = false;
    notifyListeners();
  }

  bool verifyPin(String enteredPin) {
    if (_preferences.securityPin == null || _preferences.securityPin!.isEmpty) {
      return true;
    }
    return _preferences.securityPin == enteredPin;
  }

  Future<void> setSecurityPin(String pin) async {
    await updatePreferences(_preferences.copyWith(securityPin: pin));
  }

  Future<void> removeSecurityPin() async {
    await updatePreferences(
      _preferences.copyWith(
        clearPin: true,
        isDiaryLockEnabled: false,
        isBiometricEnabled: false,
        isAppLockEnabled: false,
      ),
    );
    _isDiaryUnlocked = false;
  }

  Future<void> toggleBiometric(bool enabled) async {
    await updatePreferences(_preferences.copyWith(isBiometricEnabled: enabled));
  }

  Future<void> toggleDiaryLock(bool enabled) async {
    await updatePreferences(_preferences.copyWith(isDiaryLockEnabled: enabled));
    if (!enabled) {
      _isDiaryUnlocked = true;
    } else {
      _isDiaryUnlocked = false;
    }
  }

  Future<void> toggleAppLock(bool enabled) async {
    await updatePreferences(_preferences.copyWith(isAppLockEnabled: enabled));
  }

  Future<void> toggleJournalPrompts(bool enabled) async {
    await updatePreferences(_preferences.copyWith(showJournalPrompts: enabled));
  }

  Future<void> toggleThrowbacks(bool enabled) async {
    await updatePreferences(_preferences.copyWith(showThrowbacks: enabled));
  }
}

