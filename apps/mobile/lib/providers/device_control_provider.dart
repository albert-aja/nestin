import 'package:flutter/foundation.dart';
import '../data/models/device_capability.dart';
import '../data/models/digital_wellbeing.dart';
import '../data/models/phone_mode.dart';
import '../data/services/device_control_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/storage_service.dart';

class DeviceControlProvider extends ChangeNotifier {
  final StorageService _storage;
  final DeviceControlServiceInterface _service;
  final NotificationService? notifications;

  bool _disposed = false;
  bool _isRefreshing = false;

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
      await refreshAppUsage(now: now);
    } finally {
      _isRefreshing = false;
      _safeNotify();
    }
  }

  /// Inspects live OS capabilities & compares against previously granted
  /// permissions to catch silent OS/user revocations cleanly.
  Future<DeviceCapabilityRegistry> refreshCapabilities() async {
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
    _safeNotify();
    return _registry;
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
    _usageSnapshot = await _service.fetchAppUsageToday(rules: _appRules);
    final newLogs = <AppInterventionLog>[];
    final todayKey = _dateKey(checkNow);

    for (final rule in _appRules) {
      if (!rule.isEnabled) continue;

      final record = _usageSnapshot.recordForPackage(rule.packageName);
      final usedMinutes = record?.usedMinutesToday ?? 0;
      final inBlockedSchedule = rule.isWithinBlockedWindow(checkNow);

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
          rule.dailyLimitMinutes > 0 &&
          usedMinutes >= rule.dailyLimitMinutes) {
        reason = 'limit_reached';
      } else if (_usageSnapshot.permissionGranted &&
          rule.dailyLimitMinutes > 0 &&
          usedMinutes >= rule.warningMinutes &&
          rule.interventionLevel != WellbeingInterventionLevel.trackOnly) {
        reason = 'pre_limit_warning';
      }

      if (reason == null) continue;

      final alreadyLoggedToday = _interventionLogs.any(
        (log) =>
            log.ruleId == rule.id &&
            log.reason == reason &&
            _dateKey(log.timestamp) == todayKey,
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
        final msg = reason == 'pre_limit_warning'
            ? '${rule.displayName} reached $usedMinutes/${rule.dailyLimitMinutes} min (${rule.warningThresholdPercent}% warning).'
            : reason == 'limit_reached'
                ? '${rule.displayName} reached your daily limit ($usedMinutes min).'
                : '${rule.displayName} is inside your scheduled focus/bedtime window.';
        await notifications!.showWellbeingNotification(
          id: rule.id.hashCode.abs() % 100000 + 800000,
          title: 'Scout Wellbeing · ${rule.displayName}',
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
    _safeNotify();
  }

  Future<void> deleteAppRule(String ruleId) async {
    _appRules = _appRules.where((r) => r.id != ruleId).toList();
    await _storage.saveTrackedAppRules(_appRules);
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

  String _dateKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}
