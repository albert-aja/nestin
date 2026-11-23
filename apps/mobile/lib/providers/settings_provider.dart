import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/app_localizations.dart';
import '../data/models/user_preferences.dart';
import '../data/models/challenge_profile.dart';
import '../data/models/journal_entry.dart';
import '../data/services/backend_gateway_service.dart';
import '../data/services/splash_wallpaper_pack_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/widget_sync_service.dart';
import '../domain/security/diary_lock_helper.dart';
import '../ui/screens/nest/treehouse_painters.dart';
import '../ui/screens/splash/seasonal_loading_theme.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final DateTime Function() _clock;
  late UserPreferences _preferences;

  SettingsProvider(this._storageService, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _preferences = _storageService.loadPreferences();
    AppLocalizations.currentLanguage = _preferences.language;
    WidgetSyncService.instance
        .setShowMascotsEnabled(_preferences.showWidgetMascots);
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
    WidgetSyncService.instance
        .setShowMascotsEnabled(_preferences.showWidgetMascots);
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
  bool get hasCompletedOnboarding => _preferences.hasCompletedOnboarding;
  bool get showWidgetMascots => _preferences.showWidgetMascots;
  SplashSpeed get splashSpeed => _preferences.splashSpeed;
  SeasonalSplashTheme? get seasonalSplashOverride =>
      _preferences.seasonalSplashOverride;
  String? get customSplashPhotoPath => _preferences.customSplashPhotoPath;
  bool get hasCustomSplashPhoto =>
      _preferences.customSplashPhotoPath != null &&
      _preferences.customSplashPhotoPath!.trim().isNotEmpty;
  String? get activeRemoteSplashPackSlug =>
      _preferences.activeRemoteSplashPackSlug;
  List<String> get installedRemoteSplashPackSlugs =>
      List.unmodifiable(_preferences.installedRemoteSplashPackSlugs);
  Map<String, String> get installedRemoteSplashPackPaths =>
      Map.unmodifiable(_preferences.installedRemoteSplashPackPaths);
  NestViewMode get nestViewMode => _preferences.nestViewMode;
  TreehouseDayPhase? get treehousePhaseOverride =>
      _preferences.treehousePhaseOverride;

  final Map<String, double> _splashPackDownloadProgress = {};
  List<RemoteHolidayWallpaperPack> _remoteSplashPacks =
      RemoteHolidayWallpaperCatalog.packs;

  List<RemoteHolidayWallpaperPack> get remoteSplashPacks =>
      List.unmodifiable(_remoteSplashPacks);

  bool isRemoteSplashPackInstalled(String slug) =>
      _preferences.installedRemoteSplashPackSlugs.contains(slug);

  bool isRemoteSplashPackDownloading(String slug) =>
      _splashPackDownloadProgress.containsKey(slug);

  double remoteSplashPackDownloadProgress(String slug) =>
      _splashPackDownloadProgress[slug] ?? 0.0;

  Future<void> setSplashSpeed(SplashSpeed speed) async {
    await updatePreferences(_preferences.copyWith(splashSpeed: speed));
  }

  Future<void> setNestViewMode(NestViewMode mode) async {
    if (_preferences.nestViewMode == mode) return;
    await updatePreferences(_preferences.copyWith(nestViewMode: mode));
  }

  Future<void> toggleNestViewMode() async {
    final next = _preferences.nestViewMode == NestViewMode.roomsGrid
        ? NestViewMode.treehouseScene
        : NestViewMode.roomsGrid;
    await setNestViewMode(next);
  }

  Future<void> setTreehousePhaseOverride(TreehouseDayPhase? phase) async {
    if (_preferences.treehousePhaseOverride == phase) return;
    await updatePreferences(
      phase == null
          ? _preferences.copyWith(clearTreehousePhaseOverride: true)
          : _preferences.copyWith(treehousePhaseOverride: phase),
    );
  }

  Future<void> setSeasonalSplashOverride(SeasonalSplashTheme? theme) async {
    await updatePreferences(
      theme == null
          ? _preferences.copyWith(
              clearSeasonalSplashOverride: true,
              clearActiveRemoteSplashPackSlug: true,
            )
          : _preferences.copyWith(
              seasonalSplashOverride: theme,
              clearActiveRemoteSplashPackSlug: true,
            ),
    );
  }

  /// Sets or clears a personal local photo path for Phase 2 of [SplashScreen].
  Future<void> setCustomSplashPhotoPath(String? filePath) async {
    final trimmed = filePath?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await clearCustomSplashPhoto();
      return;
    }
    await updatePreferences(
      _preferences.copyWith(customSplashPhotoPath: trimmed),
    );
  }

  /// Launches the device file picker to import a personal local photo for
  /// Phase 2 of [SplashScreen].
  Future<String?> pickAndSetCustomSplashPhoto() async {
    final imported =
        await SplashWallpaperPackService.pickAndImportPersonalPhoto();
    if (imported == null) return null;
    final previous = _preferences.customSplashPhotoPath;
    await setCustomSplashPhotoPath(imported);
    if (previous != null && previous != imported) {
      await SplashWallpaperPackService.deletePersonalPhotoFile(previous);
    }
    return imported;
  }

  /// Imports a local file at [sourcePath] into the app sandbox and activates it
  /// as the Phase 2 personal splash photo.
  Future<String?> importAndSetCustomSplashPhotoFromFile(
    String sourcePath,
  ) async {
    final imported =
        await SplashWallpaperPackService.importPersonalPhotoFromFile(
      sourcePath,
    );
    if (imported == null) return null;
    final previous = _preferences.customSplashPhotoPath;
    await setCustomSplashPhotoPath(imported);
    if (previous != null && previous != imported) {
      await SplashWallpaperPackService.deletePersonalPhotoFile(previous);
    }
    return imported;
  }

  /// Clears the custom personal splash photo preference and removes any
  /// sandboxed copy from disk.
  Future<void> clearCustomSplashPhoto({bool deleteFile = true}) async {
    final previous = _preferences.customSplashPhotoPath;
    await updatePreferences(
      _preferences.copyWith(clearCustomSplashPhotoPath: true),
    );
    if (deleteFile && previous != null) {
      await SplashWallpaperPackService.deletePersonalPhotoFile(previous);
    }
  }

  /// Refreshes the remote holiday wallpaper catalog from `/api/v1/media` when
  /// [gateway] is configured, falling back to the built-in catalog offline.
  Future<List<RemoteHolidayWallpaperPack>> refreshRemoteSplashCatalog({
    BackendGatewayService? gateway,
  }) async {
    final packs = await SplashWallpaperPackService.fetchCatalogPacks(
      gateway: gateway,
      locale: _preferences.language.code,
    );
    _remoteSplashPacks = packs;
    notifyListeners();
    return packs;
  }

  /// Downloads and caches a curated seasonal wallpaper pack by [slug] from the
  /// media catalog so it is available in Phase 2 of [SplashScreen].
  Future<bool> installRemoteSplashPack(
    String slug, {
    bool activateOnInstall = false,
  }) async {
    final pack = _remoteSplashPacks
            .where((p) => p.slug == slug)
            .firstOrNull ??
        RemoteHolidayWallpaperCatalog.bySlug(slug);
    if (pack == null) return false;
    if (isRemoteSplashPackDownloading(slug)) return false;

    _splashPackDownloadProgress[slug] = 0.05;
    notifyListeners();

    final cachedPath = await SplashWallpaperPackService.downloadAndCachePack(
      pack,
      onProgress: (p) {
        _splashPackDownloadProgress[slug] = p.clamp(0.0, 1.0);
        notifyListeners();
      },
    );

    _splashPackDownloadProgress.remove(slug);
    if (cachedPath == null) {
      notifyListeners();
      return false;
    }

    final nextSlugs = <String>{
      ..._preferences.installedRemoteSplashPackSlugs,
      slug,
    }.toList(growable: false);
    final nextPaths = <String, String>{
      ..._preferences.installedRemoteSplashPackPaths,
      slug: cachedPath,
    };

    await updatePreferences(
      _preferences.copyWith(
        installedRemoteSplashPackSlugs: nextSlugs,
        installedRemoteSplashPackPaths: nextPaths,
        activeRemoteSplashPackSlug: activateOnInstall
            ? slug
            : _preferences.activeRemoteSplashPackSlug,
        clearSeasonalSplashOverride: activateOnInstall,
      ),
    );
    return true;
  }

  /// Removes a downloaded remote seasonal wallpaper pack from local cache and
  /// resets the active selection to Auto if it was active.
  Future<void> removeRemoteSplashPack(String slug) async {
    final cachedPath = _preferences.installedRemoteSplashPackPaths[slug];
    await SplashWallpaperPackService.removeCachedPack(
      slug,
      cachedFilePath: cachedPath,
    );

    final nextSlugs = _preferences.installedRemoteSplashPackSlugs
        .where((s) => s != slug)
        .toList(growable: false);
    final nextPaths = Map<String, String>.from(
      _preferences.installedRemoteSplashPackPaths,
    )..remove(slug);
    final wasActive = _preferences.activeRemoteSplashPackSlug == slug;

    await updatePreferences(
      _preferences.copyWith(
        installedRemoteSplashPackSlugs: nextSlugs,
        installedRemoteSplashPackPaths: nextPaths,
        clearActiveRemoteSplashPackSlug: wasActive,
      ),
    );
  }

  /// Activates or clears a downloaded remote holiday wallpaper pack for Phase 2
  /// of [SplashScreen].
  Future<void> setActiveRemoteSplashPackSlug(String? slug) async {
    if (slug == null || slug.trim().isEmpty) {
      await updatePreferences(
        _preferences.copyWith(clearActiveRemoteSplashPackSlug: true),
      );
      return;
    }
    await updatePreferences(
      _preferences.copyWith(
        activeRemoteSplashPackSlug: slug.trim(),
        clearSeasonalSplashOverride: true,
      ),
    );
  }

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

  Future<void> completeMascotOnboarding() async {
    if (_preferences.hasCompletedOnboarding) return;
    await updatePreferences(
      _preferences.copyWith(hasCompletedOnboarding: true),
    );
  }

  Future<void> resetMascotOnboarding() async {
    if (!_preferences.hasCompletedOnboarding) return;
    await updatePreferences(
      _preferences.copyWith(hasCompletedOnboarding: false),
    );
  }

  Future<void> toggleWidgetMascots(bool enabled) async {
    WidgetSyncService.instance.setShowMascotsEnabled(enabled);
    await updatePreferences(_preferences.copyWith(showWidgetMascots: enabled));
    await WidgetSyncService.instance.syncQuickCapture(showMascots: enabled);
  }

  @override
  void dispose() {
    _cancelAutoLockTimer();
    super.dispose();
  }
}

