import 'dart:async';
import 'package:flutter/material.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/app_localizations.dart';
import '../data/models/user_preferences.dart';
import '../data/models/challenge_profile.dart';
import '../data/models/journal_entry.dart';
import '../data/services/storage_service.dart';
import '../domain/security/diary_lock_helper.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final DateTime Function() _clock;
  late UserPreferences _preferences;

  SettingsProvider(this._storageService, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _preferences = _storageService.loadPreferences();
    AppLocalizations.currentLanguage = _preferences.language;
    unawaited(AppLocalizations.ensureDateFormatting());
  }

  UserPreferences get preferences => _preferences;
  ThemeMode get themeMode => _preferences.themeMode;
  AppLanguage get language => _preferences.language;
  Locale get locale => _preferences.language.locale;
  bool get use24Hour => _preferences.use24Hour;
  bool get weekStartMonday => _preferences.weekStartMonday;
  WakeUpChallengeProfile get globalChallengeProfile =>
      _preferences.globalChallengeProfile;

  Future<void> updatePreferences(UserPreferences newPrefs) async {
    _preferences = newPrefs;
    AppLocalizations.currentLanguage = _preferences.language;
    await _storageService.savePreferences(_preferences);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    await AppLocalizations.ensureDateFormatting();
    await updatePreferences(_preferences.copyWith(language: language));
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
  String? get securityPinHint => _preferences.securityPinHint;
  bool get hasPinHint =>
      _preferences.securityPinHint != null &&
      _preferences.securityPinHint!.trim().isNotEmpty;
  DiaryAutoLockDelay get diaryAutoLockDelay => _preferences.diaryAutoLockDelay;
  bool get hasPin =>
      _preferences.securityPin != null && _preferences.securityPin!.isNotEmpty;
  bool get showJournalPrompts => _preferences.showJournalPrompts;
  bool get showThrowbacks => _preferences.showThrowbacks;

  // Ephemeral in-session unlock state
  bool _isDiaryUnlocked = false;
  final Set<String> _unlockedEntryIds = {};
  DateTime? _leftDiaryAt;
  bool _isDiaryActive = false;
  Timer? _autoLockTimer;

  bool get isDiaryUnlocked => !isDiaryLockEnabled || _isDiaryUnlocked;

  bool get hasActiveDiaryUnlocks =>
      (isDiaryLockEnabled && _isDiaryUnlocked) || _unlockedEntryIds.isNotEmpty;

  bool isCustomEntryUnlocked(String entryId) =>
      _unlockedEntryIds.contains(entryId);

  /// Returns `true` when [entry] requires authentication before reading.
  ///
  /// Custom-locked entries are isolated from the global unlock flag and
  /// remain locked until unlocked specifically by their own PIN or password.
  bool isEntryLocked(JournalEntry entry) {
    if (!entry.isPrivate) return false;
    if (entry.hasCustomLock) {
      return !_unlockedEntryIds.contains(entry.id);
    }
    return !isDiaryUnlocked;
  }

  void unlockDiary() {
    _isDiaryUnlocked = true;
    _leftDiaryAt = null;
    _cancelAutoLockTimer();
    notifyListeners();
  }

  void unlockEntry(String entryId) {
    _unlockedEntryIds.add(entryId);
    _leftDiaryAt = null;
    _cancelAutoLockTimer();
    notifyListeners();
  }

  void lockEntry(String entryId) {
    if (_unlockedEntryIds.remove(entryId)) {
      notifyListeners();
    }
  }

  void lockDiary() {
    final hadChange = _isDiaryUnlocked || _unlockedEntryIds.isNotEmpty;
    _isDiaryUnlocked = false;
    _unlockedEntryIds.clear();
    _leftDiaryAt = null;
    _cancelAutoLockTimer();
    if (hadChange) {
      notifyListeners();
    }
  }

  /// Marks the Diary surface as active and enforces any overdue auto-lock timeout.
  void notifyDiaryEntered({DateTime? now}) {
    _isDiaryActive = true;
    _cancelAutoLockTimer();
    if (_leftDiaryAt != null) {
      evaluateAutoLock(now: now);
      _leftDiaryAt = null;
    }
  }

  /// Records that the user navigated away from Diary / backgrounded the app
  /// and arms the configured [diaryAutoLockDelay].
  void notifyDiaryLeft({DateTime? now}) {
    _isDiaryActive = false;
    if (!hasActiveDiaryUnlocks) {
      _leftDiaryAt = null;
      _cancelAutoLockTimer();
      return;
    }

    final current = now ?? _clock();
    _leftDiaryAt ??= current;
    final delay = _preferences.diaryAutoLockDelay;

    if (delay == DiaryAutoLockDelay.immediately) {
      lockDiary();
      return;
    }

    if (evaluateAutoLock(now: current)) return;

    final elapsed = current.difference(_leftDiaryAt!);
    final remaining = delay.duration - elapsed;
    _cancelAutoLockTimer();
    _autoLockTimer = Timer(remaining, () {
      if (!_isDiaryActive) {
        evaluateAutoLock();
      }
    });
  }

  /// Locks both global diary and custom-locked entries if inactivity elapsed.
  bool evaluateAutoLock({DateTime? now}) {
    if (_leftDiaryAt == null || !hasActiveDiaryUnlocks) return false;
    final elapsed = (now ?? _clock()).difference(_leftDiaryAt!);
    if (elapsed >= _preferences.diaryAutoLockDelay.duration) {
      lockDiary();
      return true;
    }
    return false;
  }

  void _cancelAutoLockTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
  }

  bool verifyPin(String enteredPin) {
    if (_preferences.securityPin == null || _preferences.securityPin!.isEmpty) {
      return true;
    }
    return _preferences.securityPin == enteredPin;
  }

  Future<void> setSecurityPin(
    String pin, {
    String? hint,
    bool clearHint = false,
  }) async {
    final normalizedHint = DiaryLockHelper.normalizeHint(hint);
    final shouldUpdateHint = clearHint || hint != null;
    await updatePreferences(
      _preferences.copyWith(
        securityPin: pin,
        securityPinHint: shouldUpdateHint ? normalizedHint : null,
        clearPinHint: clearHint || (hint != null && normalizedHint == null),
      ),
    );
  }

  Future<void> updateSecurityPinHint(String? hint) async {
    final normalized = DiaryLockHelper.normalizeHint(hint);
    await updatePreferences(
      _preferences.copyWith(
        securityPinHint: normalized,
        clearPinHint: normalized == null,
      ),
    );
  }

  Future<void> updateDiaryAutoLockDelay(DiaryAutoLockDelay delay) async {
    await updatePreferences(_preferences.copyWith(diaryAutoLockDelay: delay));
    if (!_isDiaryActive && _leftDiaryAt != null && hasActiveDiaryUnlocks) {
      if (delay == DiaryAutoLockDelay.immediately) {
        lockDiary();
      } else if (!evaluateAutoLock()) {
        final elapsed = _clock().difference(_leftDiaryAt!);
        final remaining = delay.duration - elapsed;
        _cancelAutoLockTimer();
        if (remaining <= Duration.zero) {
          lockDiary();
        } else {
          _autoLockTimer = Timer(remaining, () {
            if (!_isDiaryActive) {
              evaluateAutoLock();
            }
          });
        }
      }
    }
  }

  Future<void> removeSecurityPin() async {
    await updatePreferences(
      _preferences.copyWith(
        clearPin: true,
        clearPinHint: true,
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

  @override
  void dispose() {
    _cancelAutoLockTimer();
    super.dispose();
  }
}

