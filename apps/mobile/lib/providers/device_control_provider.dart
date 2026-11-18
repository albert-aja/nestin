import 'package:flutter/foundation.dart';
import '../core/l10n/app_localizations.dart';
import '../data/models/app_restriction.dart';
import '../data/models/device_capability.dart';
import '../data/models/digital_wellbeing.dart';
import '../data/models/phone_mode.dart';
import '../data/services/device_control_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/storage_service.dart';
import '../domain/wellbeing/focus_lock_bridge.dart';
import '../domain/wellbeing/restriction_engine.dart';

class DeviceControlProvider extends ChangeNotifier
    implements FocusLockCoordinator {
  final StorageService _storage;
  final DeviceControlServiceInterface _service;
  final NotificationService? notifications;

  bool _disposed = false;
  bool _isRefreshing = false;

  final RestrictionEngine _engine = const RestrictionEngine();
  late DeviceCapabilityRegistry _registry;
  List<TrackedAppRule> _appRules = [];
  WellbeingDailySnapshot _usageSnapshot = const WellbeingDailySnapshot(
    dateKey: '',
    records: [],
    permissionGranted: false,
  );
  List<AppInterventionLog> _interventionLogs = [];
  List<PhoneModeProfile> _phoneModes = [];
  String? _activePhoneModeId;
  StateRestorationSnapshot? _activeSnapshot;
  StateRestorationSnapshot? _lastRestorationSummary;

  // Roo Digital Discipline & App Control state backed by the Shared Restriction Engine
  List<AppFastCommitment> _appFastCommitments = [];
  FocusLockConfig _focusLockConfig = const FocusLockConfig();
  FocusLockSession? _activeFocusSession;
  List<RestrictionAuditLog> _restrictionAuditLogs = [];
  List<InstalledAppInfo> _discoveredApps = [];
  List<RestrictionRule> _extraRestrictionRules = [];
  final Map<String, DateTime> _reminderGraceUntil = {};
  bool _hasCompletedDiscovery = false;

  DeviceControlProvider(
    this._storage, {
    DeviceControlServiceInterface? service,
    this.notifications,
    bool autoRefresh = true,
  }) : _service = service ?? NativeDeviceControlService() {
    _registry = DeviceCapabilityRegistry(
      platform: _initialPlatformLabel(),
      inspectedAt: DateTime.now(),
    );
    _loadPersisted();
    if (autoRefresh) {
      refreshAll();
    }
  }

  String _initialPlatformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'desktop';
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Getters
  bool get isRefreshing => _isRefreshing;
  DeviceCapabilityRegistry get registry => _registry;
  List<TrackedAppRule> get appRules => List.unmodifiable(_appRules);
  WellbeingDailySnapshot get usageSnapshot => _usageSnapshot;
  List<AppInterventionLog> get interventionLogs =>
      List.unmodifiable(_interventionLogs);
  List<PhoneModeProfile> get phoneModes => List.unmodifiable(_phoneModes);
  String? get activePhoneModeId => _activePhoneModeId;
  StateRestorationSnapshot? get activeSnapshot => _activeSnapshot;
  StateRestorationSnapshot? get lastRestorationSummary =>
      _lastRestorationSummary;

  List<AppFastCommitment> get appFastCommitments =>
      List.unmodifiable(_appFastCommitments);
  FocusLockConfig get focusLockConfig => _focusLockConfig;
  FocusLockSession? get activeFocusSession => _activeFocusSession;
  List<RestrictionAuditLog> get restrictionAuditLogs =>
      List.unmodifiable(_restrictionAuditLogs);
  List<InstalledAppInfo> get discoveredApps =>
      List.unmodifiable(_discoveredApps);
  List<RestrictionRule> get extraRestrictionRules =>
      List.unmodifiable(_extraRestrictionRules);
  bool get hasCompletedAppDiscovery => _hasCompletedDiscovery;

  bool isPackageInstalled(String packageName) {
    if (!_hasCompletedDiscovery || _discoveredApps.isEmpty) return true;
    if (RestrictionEngine.isEssentialSystemPackage(packageName)) return true;
    return _discoveredApps.any((a) => a.packageName == packageName);
  }

  PlatformSupportLevel supportLevelForStrength(RestrictionStrength strength) =>
      _engine.resolvePlatformSupport(_registry, strength: strength);

  List<AppFastCommitment> appFastByStatus(
    AppFastStatus status, {
    DateTime? now,
  }) {
    final checkNow = now ?? DateTime.now();
    return _appFastCommitments
        .where((c) => c.resolvedStatusAt(checkNow) == status)
        .toList();
  }

  Map<String, String> get _knownAppNames {
    final map = <String, String>{};
    for (final a in _discoveredApps) {
      map[a.packageName] = a.appName;
    }
    for (final r in _appRules) {
      map.putIfAbsent(r.packageName, () => r.displayName);
    }
    for (final c in _appFastCommitments) {
      for (final e in c.targetAppNames.entries) {
        map.putIfAbsent(e.key, () => e.value);
      }
    }
    for (final e in _focusLockConfig.restrictedAppNames.entries) {
      map.putIfAbsent(e.key, () => e.value);
    }
    return map;
  }

  String displayNameForPackage(String packageName) =>
      _knownAppNames[packageName] ?? packageName;

  PhoneModeProfile? get activePhoneMode {
    if (_activePhoneModeId == null) return null;
    for (final mode in _phoneModes) {
      if (mode.id == _activePhoneModeId) return mode;
    }
    return null;
  }

  void _loadPersisted() {
    if (_storage.hasSavedTrackedAppRules()) {
      _appRules = _storage.loadTrackedAppRules();
    } else {
      _appRules = TrackedAppRule.defaultPresets();
      _storage.saveTrackedAppRules(_appRules);
    }

    _interventionLogs = _storage.loadAppInterventionLogs();

    if (_storage.hasSavedPhoneModeProfiles()) {
      _phoneModes = _storage.loadPhoneModeProfiles();
    } else {
      _phoneModes = PhoneModeProfile.defaultProfiles();
      _storage.savePhoneModeProfiles(_phoneModes);
    }

    _activePhoneModeId = _storage.loadActivePhoneModeId();
    _activeSnapshot = _storage.loadStateRestorationSnapshot();
    _appFastCommitments = _storage.loadAppFastCommitments();
    _focusLockConfig = _storage.loadFocusLockConfig();
    _activeFocusSession = _storage.loadActiveFocusLockSession();
    _restrictionAuditLogs = _storage.loadRestrictionAuditLogs();
    _discoveredApps = _storage.loadInstalledAppsCache();
    _extraRestrictionRules = _storage.loadExtraRestrictionRules();

    final savedHistory = _storage.loadPermissionHistory();
    if (savedHistory.isNotEmpty) {
      _registry = DeviceCapabilityRegistry(
        platform: _registry.platform,
        permissions: savedHistory,
        inspectedAt: DateTime.now(),
      );
    }
  }

  Future<void> refreshAll({DateTime? now}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _safeNotify();
    try {
      await refreshCapabilities();
      await recoverExpiredOrInterruptedModeIfNeeded(now: now);
      await reconcileRestrictions(now: now, notify: false);
      await refreshAppUsage(now: now);
      await syncNativeRestrictionPolicy(now: now);
    } finally {
      _isRefreshing = false;
      _safeNotify();
    }
  }

  /// Inspects live OS capabilities & compares against previously granted
  /// permissions to catch silent OS/user revocations cleanly.
  Future<DeviceCapabilityRegistry> refreshCapabilities() async {
    final startedHere = !_isRefreshing;
    if (startedHere) {
      _isRefreshing = true;
      _safeNotify();
    }
    try {
      final inspected = await _service.inspectCapabilities();
      final previousEntries = _storage.loadPermissionHistory();
      final previousByKind = {for (final p in previousEntries) p.kind: p};

      final mergedPermissions = inspected.permissions.map((live) {
        final prev = previousByKind[live.kind];
        final wasGrantedBefore =
            (prev?.isGranted ?? false) || (prev?.wasPreviouslyGranted ?? false);
        if (live.isGranted) {
          return live.copyWith(
            status: PermissionStatus.granted,
            wasPreviouslyGranted: true,
          );
        }
        if (wasGrantedBefore && live.status == PermissionStatus.denied) {
          return live.copyWith(
            status: PermissionStatus.revoked,
            wasPreviouslyGranted: true,
          );
        }
        return live.copyWith(wasPreviouslyGranted: wasGrantedBefore);
      }).toList();

      _registry = DeviceCapabilityRegistry(
        platform: inspected.platform,
        manufacturer: inspected.manufacturer,
        brand: inspected.brand,
        model: inspected.model,
        osVersion: inspected.osVersion,
        sdkInt: inspected.sdkInt,
        isSamsungOneUi: inspected.isSamsungOneUi,
        hasFamilyControlsEntitlement: inspected.hasFamilyControlsEntitlement,
        capabilities: inspected.capabilities,
        permissions: mergedPermissions,
        inspectedAt: inspected.inspectedAt,
      );

      await _storage.savePermissionHistory(mergedPermissions);
      return _registry;
    } finally {
      if (startedHere) {
        _isRefreshing = false;
      }
      _safeNotify();
    }
  }

  /// Recovers any interrupted Phone Mode whose scheduled duration elapsed
  /// while the app was closed, safely preserving manual mid-session user edits.
  Future<void> recoverExpiredOrInterruptedModeIfNeeded({DateTime? now}) async {
    final checkNow = now ?? DateTime.now();
    final snap = _activeSnapshot;
    if (snap == null || snap.wasRestored) {
      if (_activePhoneModeId != null && snap == null) {
        _activePhoneModeId = null;
        await _storage.saveActivePhoneModeId(null);
      }
      return;
    }
    if (snap.expiresAt != null && !checkNow.isBefore(snap.expiresAt!)) {
      await endActivePhoneMode(reason: 'expired_after_restart');
    }
  }

  /// Fetches daily usage stats and evaluates all 5 Digital Wellbeing
  /// intervention levels without overpromising OS-blocked locks.
  Future<List<AppInterventionLog>> refreshAppUsage({
    bool dispatchNotifications = true,
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    final primaryResetRule = _appRules.isNotEmpty ? _appRules.first : null;
    final activeFastPackages = _appFastCommitments
        .where((c) => c.isActiveAt(checkNow))
        .expand((c) => c.targetPackages)
        .toList();

    _usageSnapshot = await _service.fetchAppUsageToday(
      rules: _appRules,
      additionalPackages: activeFastPackages,
      resetHour: primaryResetRule?.dailyResetHour ?? 0,
      resetMinute: primaryResetRule?.dailyResetMinute ?? 0,
    );

    // Auto-mark App Fast as failed if lock was bypassed natively via App Shield grace
    for (final pkg in _usageSnapshot.bypassedPackages) {
      _failActiveAppFastsForPackageSync(
        pkg,
        reason: 'lock_bypassed_shield_grace',
        now: checkNow,
      );
    }

    // Auto-mark App Fast as failed if app usage is detected during the active fast window
    for (final c in _appFastCommitments) {
      if (c.resolvedStatusAt(checkNow) != AppFastStatus.active) continue;
      for (final pkg in c.targetPackages) {
        final record = _usageSnapshot.recordForPackage(pkg);
        if (record == null) continue;
        final usedAfterStart = record.lastUsedAt != null &&
            (record.lastUsedAt!.isAfter(c.startAt) ||
                record.lastUsedAt!.isAtSameMomentAs(c.startAt));
        final usedMinutesIncreased = c.initialUsedMinutes.containsKey(pkg) &&
            record.usedMinutesToday > (c.initialUsedMinutes[pkg] ?? 0);
        if (usedAfterStart || usedMinutesIncreased) {
          _failActiveAppFastsForPackageSync(
            pkg,
            reason: 'usage_detected_during_fast',
            now: checkNow,
          );
          break;
        }
      }
    }

    final newLogs = <AppInterventionLog>[];
    final todayKey = _dateKey(checkNow);

    for (final rule in _appRules) {
      if (!rule.isEnabled) continue;

      final record = _usageSnapshot.recordForPackage(rule.packageName);
      final usedMinutes = record?.usedMinutesToday ?? 0;
      final inBlockedSchedule = rule.isWithinBlockedWindow(checkNow);
      final effectiveLimit = rule.effectiveLimitMinutesFor(checkNow);
      final warningLimit = rule.warningMinutesFor(checkNow);
      final ruleWindowKey = rule.currentResetWindowKey(checkNow);

      String? reason;
      String? outcome;

      if (inBlockedSchedule &&
          (rule.interventionLevel ==
                  WellbeingInterventionLevel.blockingSchedule ||
              rule.interventionLevel ==
                  WellbeingInterventionLevel.strictModeGuard ||
              rule.interventionLevel ==
                  WellbeingInterventionLevel.timedSoftPause)) {
        reason = 'scheduled_block';
      } else if (_usageSnapshot.permissionGranted &&
          effectiveLimit > 0 &&
          usedMinutes >= effectiveLimit) {
        reason = 'limit_reached';
      } else if (_usageSnapshot.permissionGranted &&
          effectiveLimit > 0 &&
          usedMinutes >= warningLimit &&
          rule.interventionLevel != WellbeingInterventionLevel.trackOnly) {
        reason = 'pre_limit_warning';
      }

      if (reason == null) continue;

      final alreadyLoggedToday = _interventionLogs.any(
        (log) =>
            log.ruleId == rule.id &&
            log.reason == reason &&
            (_dateKey(log.timestamp) == todayKey ||
                ruleWindowKey.startsWith(_dateKey(log.timestamp)) &&
                    _dateKey(log.timestamp) == todayKey),
      );
      if (alreadyLoggedToday) continue;

      switch (rule.interventionLevel) {
        case WellbeingInterventionLevel.trackOnly:
          continue;
        case WellbeingInterventionLevel.preLimitWarning:
          outcome = 'notification_sent';
          break;
        case WellbeingInterventionLevel.timedSoftPause:
          outcome = 'paused_by_user';
          break;
        case WellbeingInterventionLevel.blockingSchedule:
          final shieldSupport = _registry.supportFor(
            DeviceCapabilityRegistry.actionAppBlockingShield,
          );
          outcome = shieldSupport == ActionExecutionSupport.directlySupported
              ? 'blocked_via_shield'
              : 'delegated_to_settings';
          break;
        case WellbeingInterventionLevel.strictModeGuard:
          final shieldSupport = _registry.supportFor(
            DeviceCapabilityRegistry.actionAppBlockingShield,
          );
          final overlaySupport = _registry.supportFor(
            DeviceCapabilityRegistry.actionAppOverlayBanner,
          );
          if (shieldSupport == ActionExecutionSupport.directlySupported) {
            outcome = 'blocked_via_shield';
          } else if (overlaySupport ==
              ActionExecutionSupport.directlySupported) {
            outcome = 'banner_shown';
          } else if (shieldSupport == ActionExecutionSupport.unsupported) {
            outcome = 'unsupported';
          } else {
            outcome = 'delegated_to_settings';
          }
          break;
      }

      final log = AppInterventionLog(
        ruleId: rule.id,
        appName: rule.displayName,
        packageName: rule.packageName,
        level: rule.interventionLevel,
        reason: reason,
        outcome: outcome,
        timestamp: checkNow,
      );
      newLogs.add(log);

      if (dispatchNotifications && notifications != null) {
        final l10n = AppLocalizations.current;
        final msg = reason == 'pre_limit_warning'
            ? l10n.tr('reached_min_warning', {'rule_displayName': rule.displayName, 'usedMinutes': usedMinutes, 'effectiveLimit': effectiveLimit, 'rule_warningThresholdPercent': rule.warningThresholdPercent})
            : reason == 'limit_reached'
                ? l10n.tr('reached_your_daily_limit_min', {'rule_displayName': rule.displayName, 'usedMinutes': usedMinutes, 'effectiveLimit': effectiveLimit})
                : l10n.tr('is_inside_your_scheduled_focus_bedtime', {'rule_displayName': rule.displayName});
        await notifications!.showWellbeingNotification(
          id: rule.id.hashCode.abs() % 100000 + 800000,
          title: l10n.tr('roo_discipline', {'rule_displayName': rule.displayName}),
          body: msg,
          payload: 'nestin://wellbeing',
        );
      }
    }

    if (newLogs.isNotEmpty) {
      _interventionLogs = [...newLogs, ..._interventionLogs].take(150).toList();
      await _storage.saveAppInterventionLogs(_interventionLogs);
    }

    _safeNotify();
    return newLogs;
  }

  Future<void> logManualInterventionOutcome({
    required TrackedAppRule rule,
    required String reason,
    required String outcome,
  }) async {
    final log = AppInterventionLog(
      ruleId: rule.id,
      appName: rule.displayName,
      packageName: rule.packageName,
      level: rule.interventionLevel,
      reason: reason,
      outcome: outcome,
    );
    _interventionLogs = [log, ..._interventionLogs].take(150).toList();
    await _storage.saveAppInterventionLogs(_interventionLogs);
    _safeNotify();
  }

  Future<void> addOrUpdateAppRule(TrackedAppRule rule) async {
    final idx = _appRules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      _appRules = [..._appRules]..[idx] = rule;
    } else {
      _appRules = [..._appRules, rule];
    }
    await _storage.saveTrackedAppRules(_appRules);
    await syncNativeRestrictionPolicy();
    _safeNotify();
  }

  Future<void> deleteAppRule(String ruleId) async {
    _appRules = _appRules.where((r) => r.id != ruleId).toList();
    await _storage.saveTrackedAppRules(_appRules);
    await syncNativeRestrictionPolicy();
    _safeNotify();
  }

  Future<void> addOrUpdatePhoneMode(PhoneModeProfile profile) async {
    final idx = _phoneModes.indexWhere((m) => m.id == profile.id);
    if (idx >= 0) {
      _phoneModes = [..._phoneModes]..[idx] = profile;
    } else {
      _phoneModes = [..._phoneModes, profile];
    }
    await _storage.savePhoneModeProfiles(_phoneModes);
    _safeNotify();
  }

  Future<void> deletePhoneMode(String modeId) async {
    if (_activePhoneModeId == modeId) {
      await endActivePhoneMode(reason: 'mode_deleted');
    }
    _phoneModes = _phoneModes.where((m) => m.id != modeId).toList();
    await _storage.savePhoneModeProfiles(_phoneModes);
    _safeNotify();
  }

  /// Activates a Phone Mode profile, captures a Safe State Restoration
  /// Snapshot BEFORE mutating any OS setting, and executes every action honestly.
  Future<List<PhoneModeActionOutcome>> activatePhoneMode(
    String modeId, {
    DateTime? now,
  }) async {
    final target = _phoneModes.cast<PhoneModeProfile?>().firstWhere(
          (m) => m?.id == modeId,
          orElse: () => null,
        );
    if (target == null) return const [];

    // Restore prior session first so original pre-Focus OS baseline isn't lost.
    if (_activePhoneModeId != null && _activeSnapshot != null && !_activeSnapshot!.wasRestored) {
      await endActivePhoneMode(reason: 'switched_mode');
    }

    final startTime = now ?? DateTime.now();
    final systemBefore = await _service.readSystemState();
    var snapshot = StateRestorationSnapshot(
      modeId: target.id,
      modeName: target.name,
      capturedAt: startTime,
      expiresAt: target.durationMinutes != null
          ? startTime.add(Duration(minutes: target.durationMinutes!))
          : null,
      previousDndFilter: systemBefore.dndFilter,
      previousBrightnessRaw: systemBefore.brightnessRaw,
      previousScreenTimeoutMs: systemBefore.screenTimeoutMs,
    );

    final outcomes = <PhoneModeActionOutcome>[];

    if (target.enableDnd) {
      final dndOutcome = await _service.setDndEnabled(true);
      outcomes.add(dndOutcome);
      if (dndOutcome.succeeded) {
        snapshot = snapshot.copyWith(
          dndModifiedByNestin: true,
          appliedDndFilter: dndOutcome.appliedRawValue,
        );
      }
    }

    if (target.targetBrightnessPercent != null) {
      final brightOutcome = await _service.setScreenBrightness(
        target.targetBrightnessPercent!,
      );
      outcomes.add(brightOutcome);
      if (brightOutcome.succeeded) {
        snapshot = snapshot.copyWith(
          brightnessModifiedByNestin: true,
          appliedBrightnessRaw: brightOutcome.appliedRawValue,
        );
      }
    }

    if (target.targetScreenTimeoutSeconds != null) {
      final timeoutOutcome = await _service.setScreenTimeoutSeconds(
        target.targetScreenTimeoutSeconds!,
      );
      outcomes.add(timeoutOutcome);
      if (timeoutOutcome.succeeded) {
        snapshot = snapshot.copyWith(
          timeoutModifiedByNestin: true,
          appliedScreenTimeoutMs: timeoutOutcome.appliedRawValue,
        );
      }
    }

    if (target.restrictedAppRuleIds.isNotEmpty) {
      final shieldSupport = _registry.supportFor(
        DeviceCapabilityRegistry.actionAppBlockingShield,
      );
      outcomes.add(
        PhoneModeActionOutcome(
          actionType: PhoneModeActionType.applyAppRestrictions,
          targetValue: '${target.restrictedAppRuleIds.length} apps',
          support: shieldSupport,
          succeeded: shieldSupport != ActionExecutionSupport.unsupported,
          message: shieldSupport == ActionExecutionSupport.directlySupported
              ? 'Applied restriction rules across ${target.restrictedAppRuleIds.length} tracked apps.'
              : 'Tracking & soft pause active; OS-level hard app lock requires ${_registry.platform == 'ios' ? 'Apple FamilyControls entitlement' : 'Accessibility / OS Digital Wellbeing'}.',
        ),
      );
    }

    _activePhoneModeId = target.id;
    _activeSnapshot = snapshot;
    await _storage.saveActivePhoneModeId(_activePhoneModeId);
    await _storage.saveStateRestorationSnapshot(_activeSnapshot);
    await refreshCapabilities();
    _safeNotify();
    return outcomes;
  }

  /// Ends the active Phone Mode and restores ONLY settings modified by Nestin
  /// whose current OS value still matches what Nestin applied (preserving manual user edits).
  Future<List<String>> endActivePhoneMode({String reason = 'manual_end'}) async {
    final snap = _activeSnapshot;
    final notes = <String>[];

    if (snap != null && !snap.wasRestored) {
      final currentOs = await _service.readSystemState();

      if (snap.dndModifiedByNestin && snap.previousDndFilter != null) {
        if (currentOs.dndFilter == snap.appliedDndFilter) {
          final outcome =
              await _service.restoreRawDndFilter(snap.previousDndFilter!);
          notes.add(outcome.succeeded
              ? 'Restored Do Not Disturb to prior setting.'
              : 'DND restore declined: ${outcome.message}');
        } else {
          notes.add(
              'Preserved user manual Do Not Disturb change made during ${snap.modeName}.');
        }
      }

      if (snap.brightnessModifiedByNestin &&
          snap.previousBrightnessRaw != null) {
        final applied = snap.appliedBrightnessRaw ?? currentOs.brightnessRaw;
        if ((currentOs.brightnessRaw - applied).abs() <= 2) {
          final outcome =
              await _service.restoreRawBrightness(snap.previousBrightnessRaw!);
          notes.add(outcome.succeeded
              ? 'Restored screen brightness to prior setting.'
              : 'Brightness restore declined: ${outcome.message}');
        } else {
          notes.add(
              'Preserved user manual brightness adjustment made during ${snap.modeName}.');
        }
      }

      if (snap.timeoutModifiedByNestin &&
          snap.previousScreenTimeoutMs != null) {
        if (currentOs.screenTimeoutMs == snap.appliedScreenTimeoutMs) {
          final outcome = await _service
              .restoreRawScreenTimeoutMs(snap.previousScreenTimeoutMs!);
          notes.add(outcome.succeeded
              ? 'Restored screen timeout to prior setting.'
              : 'Screen timeout restore declined: ${outcome.message}');
        } else {
          notes.add(
              'Preserved user manual screen timeout change made during ${snap.modeName}.');
        }
      }

      if (!snap.hasAnyModifiedSetting) {
        notes.add(
          'Ended ${snap.modeName} ($reason). No OS settings had been altered directly.',
        );
      }

      _lastRestorationSummary = snap.copyWith(
        wasRestored: true,
        restoredAt: DateTime.now(),
        restorationNotes: notes,
      );
    }

    _activePhoneModeId = null;
    _activeSnapshot = null;
    await _storage.saveActivePhoneModeId(null);
    await _storage.saveStateRestorationSnapshot(null);
    await refreshCapabilities();
    _safeNotify();
    return notes;
  }

  Future<bool> openPermissionSettings(NestinPermissionKind kind) =>
      _service.openPermissionSettings(kind);

  Future<bool> openSystemModesOrWellbeing() =>
      _service.openSystemModesOrWellbeing();

  Future<bool> requestFamilyControlsAuthorization() async {
    final granted = await _service.requestFamilyControlsAuthorization();
    await refreshCapabilities();
    return granted;
  }

  // --- Phase 1: Native App Discovery ---

  Future<List<InstalledAppInfo>> discoverInstalledApps({
    bool includeSystemApps = false,
  }) async {
    final found = await _service.discoverInstalledApps(
      includeSystemApps: includeSystemApps,
    );
    _hasCompletedDiscovery = true;
    if (found.isNotEmpty) {
      _discoveredApps = found;
      await _storage.saveInstalledAppsCache(_discoveredApps);
    }
    _safeNotify();
    return _discoveredApps;
  }

  // --- Phase 2: App Fast Commitments ---

  Future<void> createAppFastCommitment(
    AppFastCommitment commitment, {
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    final initialUsage = <String, int>{};
    for (final pkg in commitment.targetPackages) {
      final rec = _usageSnapshot.recordForPackage(pkg);
      initialUsage[pkg] = rec?.usedMinutesToday ?? 0;
    }
    final normalized = commitment.copyWith(
      initialUsedMinutes: commitment.initialUsedMinutes.isNotEmpty
          ? commitment.initialUsedMinutes
          : initialUsage,
      status: commitment.resolvedStatusAt(checkNow),
      updatedAt: checkNow,
    );
    _appFastCommitments = [normalized, ..._appFastCommitments];
    await _storage.saveAppFastCommitments(_appFastCommitments);
    await _appendAuditForTargets(
      normalized.targetPackages,
      now: checkNow,
      detailOverride: 'Created App Fast "${normalized.title}" (${normalized.mode.label}).',
    );
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
  }

  Future<void> updateAppFastCommitment(
    AppFastCommitment commitment, {
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    final idx = _appFastCommitments.indexWhere((c) => c.id == commitment.id);
    if (idx < 0) return;
    _appFastCommitments = [..._appFastCommitments]
      ..[idx] = commitment.copyWith(
        status: commitment.resolvedStatusAt(checkNow),
        updatedAt: checkNow,
      );
    await _storage.saveAppFastCommitments(_appFastCommitments);
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
  }

  Future<void> failAppFastCommitment(
    String id, {
    required String reason,
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    final idx = _appFastCommitments.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final current = _appFastCommitments[idx];
    if (current.status == AppFastStatus.failed ||
        current.status == AppFastStatus.cancelled ||
        current.status == AppFastStatus.completed) {
      return;
    }
    _appFastCommitments = [..._appFastCommitments]
      ..[idx] = current.copyWith(
        status: AppFastStatus.failed,
        failedAt: checkNow,
        failureReason: reason,
        updatedAt: checkNow,
      );
    await _storage.saveAppFastCommitments(_appFastCommitments);
    await _appendAuditForTargets(
      current.targetPackages,
      now: checkNow,
      detailOverride: 'App Fast "${current.title}" marked as FAILED ($reason).',
    );
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
  }

  void _failActiveAppFastsForPackageSync(
    String packageName, {
    required String reason,
    DateTime? now,
  }) {
    final checkNow = now ?? DateTime.now();
    var changed = false;
    final updated = <AppFastCommitment>[];
    final failedCommitmentTitles = <String>[];
    for (final c in _appFastCommitments) {
      if (c.isActiveAt(checkNow) && c.targetPackages.contains(packageName)) {
        changed = true;
        failedCommitmentTitles.add(c.title);
        updated.add(c.copyWith(
          status: AppFastStatus.failed,
          failedAt: checkNow,
          failureReason: reason,
          updatedAt: checkNow,
        ));
      } else {
        updated.add(c);
      }
    }
    if (changed) {
      _appFastCommitments = updated;
      _storage.saveAppFastCommitments(_appFastCommitments);
      for (final title in failedCommitmentTitles) {
        _appendAuditForTargets(
          [packageName],
          now: checkNow,
          detailOverride:
              'App Fast "$title" marked as FAILED ($reason) due to activity on $packageName.',
        );
      }
      syncNativeRestrictionPolicy(now: checkNow);
      _safeNotify();
    }
  }

  Future<void> cancelAppFastCommitment(String id, {DateTime? now}) async {
    final checkNow = now ?? DateTime.now();
    final idx = _appFastCommitments.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final current = _appFastCommitments[idx];
    _appFastCommitments = [..._appFastCommitments]
      ..[idx] = current.copyWith(
        status: AppFastStatus.cancelled,
        cancelledAt: checkNow,
        updatedAt: checkNow,
      );
    await _storage.saveAppFastCommitments(_appFastCommitments);
    await _appendAuditForTargets(
      current.targetPackages,
      now: checkNow,
      detailOverride: 'Cancelled App Fast "${current.title}".',
    );
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
  }

  Future<void> deleteAppFastCommitment(String id, {DateTime? now}) async {
    _appFastCommitments =
        _appFastCommitments.where((c) => c.id != id).toList();
    await _storage.saveAppFastCommitments(_appFastCommitments);
    await syncNativeRestrictionPolicy(now: now);
    _safeNotify();
  }

  // --- Phase 3: Focus Lock Integration (Roo Pomodoro & Digital Discipline) ---

  Future<void> updateFocusLockConfig(FocusLockConfig config) async {
    _focusLockConfig = config;
    await _storage.saveFocusLockConfig(_focusLockConfig);
    await syncNativeRestrictionPolicy();
    _safeNotify();
  }

  /// Single clean interface for Roo Pomodoro (or Roo Digital Discipline) to
  /// activate temporary Focus Lock restrictions via the Shared Restriction Engine.
  Future<FocusLockSession?> activateFocusLockSession({
    required String source,
    required String taskLabel,
    required Duration duration,
    String phase = 'work',
    List<String>? overrideRestrictedPackages,
    List<String>? overrideAllowedPackages,
    bool? overrideRestrictDuringBreaks,
    bool? overrideAllowManualEnd,
    RestrictionEnforcementMode? overrideMode,
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    if (!_focusLockConfig.enabled && source == 'roo_pomodoro') {
      return null;
    }

    final restricted = (overrideRestrictedPackages ??
            _focusLockConfig.restrictedPackages)
        .where((p) => !RestrictionEngine.isEssentialSystemPackage(p))
        .toList();
    if (restricted.isEmpty) {
      return null;
    }

    final safeDuration = duration.inSeconds > 0
        ? duration
        : const Duration(minutes: 25);

    final session = FocusLockSession(
      source: source,
      taskLabel: taskLabel,
      phase: phase,
      restrictedPackages: restricted,
      allowedPackages: overrideAllowedPackages ?? _focusLockConfig.allowedPackages,
      restrictDuringBreaks:
          overrideRestrictDuringBreaks ?? _focusLockConfig.restrictDuringBreaks,
      allowManualEnd: overrideAllowManualEnd ?? _focusLockConfig.allowManualEnd,
      enforcementMode: overrideMode ?? _focusLockConfig.enforcementMode,
      customMessage: _focusLockConfig.customMessage,
      startedAt: checkNow,
      expectedEndAt: checkNow.add(safeDuration),
    );

    _activeFocusSession = session;
    await _storage.saveActiveFocusLockSession(_activeFocusSession);
    await _appendAuditForTargets(
      session.restrictedPackages,
      now: checkNow,
      detailOverride:
          'Activated Focus Lock ($source · ${session.taskLabel}) for ${safeDuration.inMinutes}m.',
    );
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
    return session;
  }

  Future<void> updateFocusLockPhase({
    required String phase,
    required Duration duration,
    bool isPaused = false,
    DateTime? now,
  }) async {
    final current = _activeFocusSession;
    if (current == null) return;
    final checkNow = now ?? DateTime.now();
    final safeDuration = duration.inSeconds > 0
        ? duration
        : const Duration(minutes: 5);

    _activeFocusSession = current.copyWith(
      phase: phase,
      expectedEndAt: checkNow.add(safeDuration),
      isPaused: isPaused,
      pausedAt: isPaused ? checkNow : null,
      clearPausedAt: !isPaused,
    );
    await _storage.saveActiveFocusLockSession(_activeFocusSession);
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
  }

  Future<void> pauseFocusLock({DateTime? now}) async {
    final current = _activeFocusSession;
    if (current == null || current.isPaused) return;
    final checkNow = now ?? DateTime.now();
    _activeFocusSession = current.copyWith(
      isPaused: true,
      pausedAt: checkNow,
    );
    await _storage.saveActiveFocusLockSession(_activeFocusSession);
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
  }

  Future<void> resumeFocusLock({
    Duration? remainingDuration,
    DateTime? now,
  }) async {
    final current = _activeFocusSession;
    if (current == null || !current.isPaused) return;
    final checkNow = now ?? DateTime.now();
    final rem = remainingDuration ??
        (current.pausedAt != null
            ? current.expectedEndAt.difference(current.pausedAt!)
            : const Duration(minutes: 15));
    _activeFocusSession = current.copyWith(
      isPaused: false,
      clearPausedAt: true,
      expectedEndAt: checkNow.add(rem.isNegative ? Duration.zero : rem),
    );
    await _storage.saveActiveFocusLockSession(_activeFocusSession);
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
  }

  /// Releases only the temporary Focus Lock session; App Fast commitments and
  /// Daily Usage Limits remain untouched cleanly in [RestrictionEngine].
  Future<bool> endFocusLockSession({
    String reason = 'ended',
    bool force = false,
    DateTime? now,
  }) async {
    final current = _activeFocusSession;
    if (current == null) return true;
    if (!force && reason == 'manual_end' && !current.allowManualEnd) {
      return false;
    }

    final checkNow = now ?? DateTime.now();
    _activeFocusSession = null;
    await _storage.saveActiveFocusLockSession(null);
    await _appendAuditForTargets(
      current.restrictedPackages,
      now: checkNow,
      detailOverride: 'Released Focus Lock (${current.taskLabel} · $reason).',
    );
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
    return true;
  }

  // --- Phase 4 & 5: Shared Restriction Engine Evaluation, Reconciliation & Audit ---

  RestrictionDecision evaluateApp(
    String packageName, {
    String? appName,
    DateTime? now,
  }) {
    final checkNow = now ?? DateTime.now();
    return _engine.evaluateApp(
      packageName: packageName,
      appName: appName ?? displayNameForPackage(packageName),
      now: checkNow,
      registry: _registry,
      appFastCommitments: _appFastCommitments,
      activeFocusSession: _activeFocusSession,
      usageRules: _appRules,
      usageSnapshot: _usageSnapshot,
      extraRules: _extraRestrictionRules,
    );
  }

  Map<String, RestrictionDecision> evaluateAllTracked({DateTime? now}) {
    final checkNow = now ?? DateTime.now();
    final packages = <String>{
      for (final r in _appRules) r.packageName,
      for (final c in _appFastCommitments) ...c.targetPackages,
      if (_activeFocusSession != null) ..._activeFocusSession!.restrictedPackages,
      for (final e in _extraRestrictionRules) e.packageName,
    };
    return {
      for (final pkg in packages) pkg: evaluateApp(pkg, now: checkNow),
    };
  }

  bool isInReminderGrace(String packageName, {DateTime? now}) {
    final checkNow = now ?? DateTime.now();
    final until = _reminderGraceUntil[packageName];
    if (until == null) return false;
    if (!checkNow.isBefore(until)) {
      _reminderGraceUntil.remove(packageName);
      return false;
    }
    return true;
  }

  void recordReminderContinueAnyway(
    String packageName, {
    Duration grace = const Duration(minutes: 5),
    DateTime? now,
  }) {
    final checkNow = now ?? DateTime.now();
    _reminderGraceUntil[packageName] = checkNow.add(grace);
    _failActiveAppFastsForPackageSync(
      packageName,
      reason: 'lock_bypassed_continue_anyway',
      now: checkNow,
    );
    final decision = evaluateApp(packageName, now: checkNow);
    final log = RestrictionAuditLog(
      packageName: packageName,
      appName: decision.appName,
      effectiveStrength: decision.effectiveStrength,
      winningSource: decision.winningRule?.sourceType,
      coexistingSources: decision.activeRules.map((e) => e.sourceType).toList(),
      outcome: RestrictionExecutionOutcome.userContinuedInReminder,
      platformSupport: decision.platformSupport,
      detail: 'User acknowledged Reminder Mode intervention & continued for ${grace.inMinutes}m.',
      timestamp: checkNow,
    );
    _restrictionAuditLogs = [log, ..._restrictionAuditLogs].take(200).toList();
    _storage.saveRestrictionAuditLogs(_restrictionAuditLogs);
    _safeNotify();
  }

  Future<RestrictionDecision> evaluateAndRecordLaunchAttempt(
    String packageName, {
    String? appName,
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    await reconcileRestrictions(now: checkNow, notify: false);
    final decision = evaluateApp(packageName, appName: appName, now: checkNow);

    if (decision.isRestricted) {
      final log = RestrictionAuditLog(
        packageName: packageName,
        appName: decision.appName,
        effectiveStrength: decision.effectiveStrength,
        winningSource: decision.winningRule?.sourceType,
        coexistingSources:
            decision.activeRules.map((e) => e.sourceType).toList(),
        outcome: decision.outcome,
        platformSupport: decision.platformSupport,
        detail: decision.explanation,
        timestamp: checkNow,
      );
      _restrictionAuditLogs = [log, ..._restrictionAuditLogs].take(200).toList();
      await _storage.saveRestrictionAuditLogs(_restrictionAuditLogs);
      _safeNotify();
    }
    return decision;
  }

  /// Reconciles time-based lifecycle transitions (App Fast activation/expiry,
  /// expired/orphaned Focus Lock recovery across restarts/timezone changes,
  /// expired extra automation rules) without mutating unrelated active rules.
  Future<void> reconcileRestrictions({
    DateTime? now,
    bool notify = true,
  }) async {
    final checkNow = now ?? DateTime.now();
    var appFastChanged = false;
    final updatedCommitments = <AppFastCommitment>[];

    for (final c in _appFastCommitments) {
      final resolved = c.resolvedStatusAt(checkNow);
      if (resolved != c.status) {
        appFastChanged = true;
        updatedCommitments.add(
          c.copyWith(status: resolved, updatedAt: checkNow),
        );
      } else {
        updatedCommitments.add(c);
      }
    }

    if (appFastChanged) {
      _appFastCommitments = updatedCommitments;
      await _storage.saveAppFastCommitments(_appFastCommitments);
    }

    if (_activeFocusSession != null &&
        _activeFocusSession!.isExpiredAt(checkNow)) {
      final expired = _activeFocusSession!;
      _activeFocusSession = null;
      await _storage.saveActiveFocusLockSession(null);
      await _appendAuditForTargets(
        expired.restrictedPackages,
        now: checkNow,
        detailOverride:
            'Auto-released expired Focus Lock (${expired.taskLabel}) safely.',
      );
    }

    final activeExtras =
        _extraRestrictionRules.where((e) => e.isActiveAt(checkNow)).toList();
    if (activeExtras.length != _extraRestrictionRules.length) {
      _extraRestrictionRules = activeExtras;
      await _storage.saveExtraRestrictionRules(_extraRestrictionRules);
    }

    _reminderGraceUntil.removeWhere((_, until) => !checkNow.isBefore(until));

    if (notify) {
      _safeNotify();
    }
  }

  Future<void> syncNativeRestrictionPolicy({DateTime? now}) async {
    final checkNow = now ?? DateTime.now();
    final policies = _engine.buildNativePolicyEntries(
      now: checkNow,
      registry: _registry,
      appFastCommitments: _appFastCommitments,
      activeFocusSession: _activeFocusSession,
      usageRules: _appRules,
      usageSnapshot: _usageSnapshot,
      extraRules: _extraRestrictionRules,
    );
    await _service.syncRestrictionPolicy(
      policies,
      focusExpiresAt: _activeFocusSession?.expectedEndAt,
    );
  }

  Future<void> registerExtraRestrictionRule(
    RestrictionRule rule, {
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    final idx = _extraRestrictionRules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      _extraRestrictionRules = [..._extraRestrictionRules]..[idx] = rule;
    } else {
      _extraRestrictionRules = [..._extraRestrictionRules, rule];
    }
    await _storage.saveExtraRestrictionRules(_extraRestrictionRules);
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
  }

  Future<void> unregisterExtraRestrictionRule(
    String id, {
    DateTime? now,
  }) async {
    _extraRestrictionRules =
        _extraRestrictionRules.where((r) => r.id != id).toList();
    await _storage.saveExtraRestrictionRules(_extraRestrictionRules);
    await syncNativeRestrictionPolicy(now: now);
    _safeNotify();
  }

  Future<void> handleDayOrTimezoneChange({DateTime? now}) async {
    final checkNow = now ?? DateTime.now();
    await reconcileRestrictions(now: checkNow, notify: false);
    await refreshAppUsage(now: checkNow, dispatchNotifications: false);
    await syncNativeRestrictionPolicy(now: checkNow);
    _safeNotify();
  }

  Future<void> clearRestrictionAuditLogs() async {
    _restrictionAuditLogs = [];
    await _storage.saveRestrictionAuditLogs(_restrictionAuditLogs);
    _safeNotify();
  }

  Future<void> _appendAuditForTargets(
    List<String> packages, {
    required DateTime now,
    required String detailOverride,
  }) async {
    if (packages.isEmpty) return;
    final primaryPkg = packages.first;
    final decision = evaluateApp(primaryPkg, now: now);
    final log = RestrictionAuditLog(
      packageName: packages.join(','),
      appName: packages.length == 1
          ? displayNameForPackage(primaryPkg)
          : '${packages.length} apps (${displayNameForPackage(primaryPkg)}, ...)',
      effectiveStrength: decision.effectiveStrength,
      winningSource: decision.winningRule?.sourceType,
      coexistingSources: decision.activeRules.map((e) => e.sourceType).toList(),
      outcome: decision.outcome,
      platformSupport: decision.platformSupport,
      detail: detailOverride,
      timestamp: now,
    );
    _restrictionAuditLogs = [log, ..._restrictionAuditLogs].take(200).toList();
    await _storage.saveRestrictionAuditLogs(_restrictionAuditLogs);
  }

  @override
  Future<void> onPomodoroFocusStarted({
    required String taskLabel,
    required String phase,
    required Duration remaining,
  }) async {
    await activateFocusLockSession(
      source: 'roo_pomodoro',
      taskLabel: taskLabel,
      phase: phase,
      duration: remaining,
    );
  }

  @override
  Future<void> onPomodoroFocusPhaseChanged({
    required String phase,
    required Duration remaining,
    required bool isPaused,
  }) async {
    if (_activeFocusSession == null) return;
    await updateFocusLockPhase(
      phase: phase,
      duration: remaining,
      isPaused: isPaused,
    );
  }

  @override
  Future<void> onPomodoroFocusPaused() async {
    await pauseFocusLock();
  }

  @override
  Future<void> onPomodoroFocusResumed({
    required Duration remaining,
  }) async {
    await resumeFocusLock(remainingDuration: remaining);
  }

  @override
  Future<void> onPomodoroFocusEnded({required String reason}) async {
    await endFocusLockSession(reason: reason, force: true);
  }

  String _dateKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}
