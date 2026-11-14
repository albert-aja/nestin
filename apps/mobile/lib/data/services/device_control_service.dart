import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/device_capability.dart';
import '../models/digital_wellbeing.dart';
import '../models/phone_mode.dart';

class DeviceSystemState {
  final int dndFilter; // Android NotificationManager.INTERRUPTION_FILTER_*; 1=ALL(off), 2=PRIORITY(on)
  final int brightnessRaw; // 0..255 on Android, 0..100 fallback
  final int screenTimeoutMs;
  final bool hasUsageStats;
  final bool hasDndAccess;
  final bool canWriteSettings;
  final bool hasOverlayPermission;
  final bool hasAccessibilityService;
  final bool hasExactAlarm;
  final bool hasNotifications;
  final bool isBatteryOptimizationExempt;
  final bool hasFamilyControlsEntitlement;

  const DeviceSystemState({
    this.dndFilter = 1,
    this.brightnessRaw = 128,
    this.screenTimeoutMs = 30000,
    this.hasUsageStats = false,
    this.hasDndAccess = false,
    this.canWriteSettings = false,
    this.hasOverlayPermission = false,
    this.hasAccessibilityService = false,
    this.hasExactAlarm = false,
    this.hasNotifications = true,
    this.isBatteryOptimizationExempt = false,
    this.hasFamilyControlsEntitlement = false,
  });

  bool get isDndEnabled => dndFilter != 1;
}

abstract class DeviceControlServiceInterface {
  Future<DeviceCapabilityRegistry> inspectCapabilities();
  Future<DeviceSystemState> readSystemState();
  Future<WellbeingDailySnapshot> fetchAppUsageToday({
    required List<TrackedAppRule> rules,
  });
  Future<PhoneModeActionOutcome> setDndEnabled(bool enable);
  Future<PhoneModeActionOutcome> restoreRawDndFilter(int filter);
  Future<PhoneModeActionOutcome> setScreenBrightness(int percent);
  Future<PhoneModeActionOutcome> restoreRawBrightness(int rawBrightness);
  Future<PhoneModeActionOutcome> setScreenTimeoutSeconds(int seconds);
  Future<PhoneModeActionOutcome> restoreRawScreenTimeoutMs(int timeoutMs);
  Future<bool> openPermissionSettings(NestinPermissionKind kind);
  Future<bool> openSystemModesOrWellbeing();
}

/// Platform MethodChannel bridge (`com.nestin.app/device_control`).
/// Reports OS denials and missing entitlements honestly instead of faking success.
class NativeDeviceControlService implements DeviceControlServiceInterface {
  static const MethodChannel _channel =
      MethodChannel('com.nestin.app/device_control');

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return 'desktop';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  @override
  Future<DeviceCapabilityRegistry> inspectCapabilities() async {
    final platform = _platformName();
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'inspectCapabilities',
      );
      if (raw != null) {
        return _registryFromMap(raw, platformFallback: platform);
      }
    } catch (_) {
      // MissingPluginException on desktop/tests or unsupported host falls back honestly below
    }
    return _fallbackRegistry(platform);
  }

  @override
  Future<DeviceSystemState> readSystemState() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'readSystemState',
      );
      if (raw != null) {
        return DeviceSystemState(
          dndFilter: (raw['dndFilter'] as num?)?.toInt() ?? 1,
          brightnessRaw: (raw['brightnessRaw'] as num?)?.toInt() ?? 128,
          screenTimeoutMs: (raw['screenTimeoutMs'] as num?)?.toInt() ?? 30000,
          hasUsageStats: raw['hasUsageStats'] as bool? ?? false,
          hasDndAccess: raw['hasDndAccess'] as bool? ?? false,
          canWriteSettings: raw['canWriteSettings'] as bool? ?? false,
          hasOverlayPermission: raw['hasOverlayPermission'] as bool? ?? false,
          hasAccessibilityService:
              raw['hasAccessibilityService'] as bool? ?? false,
          hasExactAlarm: raw['hasExactAlarm'] as bool? ?? false,
          hasNotifications: raw['hasNotifications'] as bool? ?? false,
          isBatteryOptimizationExempt:
              raw['isBatteryOptimizationExempt'] as bool? ?? false,
          hasFamilyControlsEntitlement:
              raw['hasFamilyControlsEntitlement'] as bool? ?? false,
        );
      }
    } catch (_) {}
    return const DeviceSystemState(hasNotifications: false);
  }

  @override
  Future<WellbeingDailySnapshot> fetchAppUsageToday({
    required List<TrackedAppRule> rules,
  }) async {
    final now = DateTime.now();
    final dateKey = _dateKey(now);
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getAppUsageToday',
        {
          'packages': rules.map((r) => r.packageName).toList(),
        },
      );
      if (raw != null) {
        final granted = raw['permissionGranted'] as bool? ?? false;
        final boundary = raw['boundaryMessage'] as String? ?? '';
        final rawList = (raw['records'] as List<dynamic>?) ?? const [];
        final records = rawList
            .whereType<Map>()
            .map((m) => AppUsageRecord(
                  packageName: m['packageName'] as String? ?? '',
                  appName: m['appName'] as String? ??
                      _displayNameForPackage(
                          rules, m['packageName'] as String? ?? ''),
                  usedMinutesToday: (m['usedMinutesToday'] as num?)?.toInt() ?? 0,
                  launchCountToday: (m['launchCountToday'] as num?)?.toInt() ?? 0,
                  lastUsedAt: (m['lastTimeUsedMs'] as num?) != null &&
                          (m['lastTimeUsedMs'] as num) > 0
                      ? DateTime.fromMillisecondsSinceEpoch(
                          (m['lastTimeUsedMs'] as num).toInt())
                      : null,
                  dateKey: dateKey,
                  dataSource: granted ? 'usage_stats' : 'unavailable',
                ))
            .toList();
        return WellbeingDailySnapshot(
          dateKey: dateKey,
          records: records,
          permissionGranted: granted,
          honestBoundaryMessage: boundary,
        );
      }
    } catch (_) {}

    return WellbeingDailySnapshot(
      dateKey: dateKey,
      records: const [],
      permissionGranted: false,
      honestBoundaryMessage: defaultTargetPlatform == TargetPlatform.iOS
          ? 'iOS requires Apple FamilyControls / DeviceActivity entitlement for cross-app Screen Time telemetry.'
          : 'Usage telemetry channel is unavailable on this platform.',
    );
  }

  @override
  Future<PhoneModeActionOutcome> setDndEnabled(bool enable) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'setDndEnabled',
        {'enable': enable},
      );
      if (raw != null) {
        return _outcomeFromMap(
          PhoneModeActionType.setDnd,
          enable ? 'DND On' : 'DND Off',
          raw,
        );
      }
    } catch (_) {}
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setDnd,
      targetValue: enable ? 'DND On' : 'DND Off',
      support: defaultTargetPlatform == TargetPlatform.iOS
          ? ActionExecutionSupport.delegatedToSystemSettings
          : ActionExecutionSupport.unsupported,
      succeeded: false,
      message: defaultTargetPlatform == TargetPlatform.iOS
          ? 'iOS apps cannot toggle Focus/DND directly; use System Settings.'
          : 'Device Do Not Disturb control unavailable on this host.',
    );
  }

  @override
  Future<PhoneModeActionOutcome> restoreRawDndFilter(int filter) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'restoreDndFilter',
        {'filter': filter},
      );
      if (raw != null) {
        return _outcomeFromMap(
          PhoneModeActionType.setDnd,
          'Filter $filter',
          raw,
        );
      }
    } catch (_) {}
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setDnd,
      targetValue: 'Filter $filter',
      support: ActionExecutionSupport.unsupported,
      succeeded: false,
      message: 'Could not restore Do Not Disturb on this platform.',
    );
  }

  @override
  Future<PhoneModeActionOutcome> setScreenBrightness(int percent) async {
    final clamped = percent.clamp(1, 100);
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'setScreenBrightness',
        {'percent': clamped},
      );
      if (raw != null) {
        return _outcomeFromMap(
          PhoneModeActionType.setScreenBrightness,
          '$clamped%',
          raw,
        );
      }
    } catch (_) {}
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setScreenBrightness,
      targetValue: '$clamped%',
      support: ActionExecutionSupport.unsupported,
      succeeded: false,
      message: 'System brightness control is unavailable on this platform.',
    );
  }

  @override
  Future<PhoneModeActionOutcome> restoreRawBrightness(int rawBrightness) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'restoreBrightness',
        {'brightnessRaw': rawBrightness},
      );
      if (raw != null) {
        return _outcomeFromMap(
          PhoneModeActionType.setScreenBrightness,
          'Raw $rawBrightness',
          raw,
        );
      }
    } catch (_) {}
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setScreenBrightness,
      targetValue: 'Raw $rawBrightness',
      support: ActionExecutionSupport.unsupported,
      succeeded: false,
      message: 'System brightness restoration is unavailable.',
    );
  }

  @override
  Future<PhoneModeActionOutcome> setScreenTimeoutSeconds(int seconds) async {
    final safeSeconds = seconds.clamp(15, 1800);
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'setScreenTimeoutSeconds',
        {'seconds': safeSeconds},
      );
      if (raw != null) {
        return _outcomeFromMap(
          PhoneModeActionType.setScreenTimeoutSeconds,
          '${safeSeconds}s',
          raw,
        );
      }
    } catch (_) {}
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setScreenTimeoutSeconds,
      targetValue: '${safeSeconds}s',
      support: ActionExecutionSupport.unsupported,
      succeeded: false,
      message: 'Screen timeout control requires Android WRITE_SETTINGS.',
    );
  }

  @override
  Future<PhoneModeActionOutcome> restoreRawScreenTimeoutMs(int timeoutMs) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'restoreScreenTimeoutMs',
        {'timeoutMs': timeoutMs},
      );
      if (raw != null) {
        return _outcomeFromMap(
          PhoneModeActionType.setScreenTimeoutSeconds,
          '${timeoutMs}ms',
          raw,
        );
      }
    } catch (_) {}
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setScreenTimeoutSeconds,
      targetValue: '${timeoutMs}ms',
      support: ActionExecutionSupport.unsupported,
      succeeded: false,
      message: 'Screen timeout restoration unavailable.',
    );
  }

  @override
  Future<bool> openPermissionSettings(NestinPermissionKind kind) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'openPermissionSettings',
        {'permission': kind.name},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openSystemModesOrWellbeing() async {
    try {
      final ok =
          await _channel.invokeMethod<bool>('openSystemModesOrWellbeing');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  PhoneModeActionOutcome _outcomeFromMap(
    PhoneModeActionType actionType,
    String targetValue,
    Map<String, dynamic> map,
  ) {
    return PhoneModeActionOutcome(
      actionType: actionType,
      targetValue: targetValue,
      support: ActionExecutionSupport.values.firstWhere(
        (e) => e.name == map['support'],
        orElse: () => ActionExecutionSupport.unsupported,
      ),
      succeeded: map['succeeded'] as bool? ?? false,
      message: map['message'] as String? ?? '',
      previousRawValue: (map['previousRawValue'] as num?)?.toInt(),
      appliedRawValue: (map['appliedRawValue'] as num?)?.toInt(),
    );
  }

  DeviceCapabilityRegistry _registryFromMap(
    Map<String, dynamic> map, {
    required String platformFallback,
  }) {
    final platform = map['platform'] as String? ?? platformFallback;
    final manufacturer = map['manufacturer'] as String? ?? 'unknown';
    final brand = map['brand'] as String? ?? 'unknown';
    final model = map['model'] as String? ?? 'unknown';
    final osVersion = map['osVersion'] as String? ?? 'unknown';
    final sdkInt = (map['sdkInt'] as num?)?.toInt() ?? 0;
    final isSamsung = manufacturer.toLowerCase().contains('samsung') ||
        brand.toLowerCase().contains('samsung');
    final hasFamilyControls =
        map['hasFamilyControlsEntitlement'] as bool? ?? false;

    final hasUsageStats = map['hasUsageStats'] as bool? ?? false;
    final hasDndAccess = map['hasDndAccess'] as bool? ?? false;
    final canWriteSettings = map['canWriteSettings'] as bool? ?? false;
    final hasOverlay = map['hasOverlayPermission'] as bool? ?? false;
    final hasAccessibility = map['hasAccessibilityService'] as bool? ?? false;
    final hasExactAlarm = map['hasExactAlarm'] as bool? ?? false;
    final hasNotifications = map['hasNotifications'] as bool? ?? false;
    final hasLocation = map['hasLocation'] as bool? ?? false;
    final hasBackgroundLocation =
        map['hasBackgroundLocation'] as bool? ?? false;
    final isBatteryExempt =
        map['isBatteryOptimizationExempt'] as bool? ?? false;

    final isAndroid = platform == 'android';
    final isIos = platform == 'ios';

    final capabilities = <String, DeviceCapabilityRecord>{
      DeviceCapabilityRegistry.actionUsageStats: DeviceCapabilityRecord(
        actionKey: DeviceCapabilityRegistry.actionUsageStats,
        label: 'App Usage Tracking',
        support: isAndroid
            ? (hasUsageStats
                ? ActionExecutionSupport.directlySupported
                : ActionExecutionSupport.permissionRequired)
            : (isIos && hasFamilyControls
                ? ActionExecutionSupport.permissionRequired
                : ActionExecutionSupport.unsupported),
        requiredPermission: isAndroid
            ? NestinPermissionKind.usageStats
            : NestinPermissionKind.familyControls,
        oemNote: isAndroid
            ? 'Uses Android UsageStatsManager after user grants Usage Access.'
            : 'iOS cross-app Screen Time requires Apple FamilyControls entitlement.',
      ),
      DeviceCapabilityRegistry.actionDndToggle: DeviceCapabilityRecord(
        actionKey: DeviceCapabilityRegistry.actionDndToggle,
        label: 'Do Not Disturb Control',
        support: isAndroid
            ? (hasDndAccess
                ? ActionExecutionSupport.directlySupported
                : ActionExecutionSupport.permissionRequired)
            : (isIos
                ? ActionExecutionSupport.delegatedToSystemSettings
                : ActionExecutionSupport.unsupported),
        requiredPermission: NestinPermissionKind.notificationPolicy,
        oemNote: isAndroid
            ? (isSamsung
                ? 'Supported via Notification Policy Access. Samsung Modes & Routines can complement this.'
                : 'Supported directly once Notification Policy Access is granted.')
            : 'iOS Focus modes are managed in iOS Settings / Control Center.',
      ),
      DeviceCapabilityRegistry.actionBrightnessControl: DeviceCapabilityRecord(
        actionKey: DeviceCapabilityRegistry.actionBrightnessControl,
        label: 'System Screen Brightness',
        support: isAndroid
            ? (canWriteSettings
                ? ActionExecutionSupport.directlySupported
                : ActionExecutionSupport.permissionRequired)
            : ActionExecutionSupport.unsupported,
        requiredPermission: NestinPermissionKind.writeSettings,
        oemNote: isAndroid
            ? 'Adjusts system brightness with snapshot restoration when Modify System Settings is granted.'
            : 'iOS only allows temporary in-app UIScreen brightness, not persistent system brightness.',
      ),
      DeviceCapabilityRegistry.actionScreenTimeoutControl:
          DeviceCapabilityRecord(
        actionKey: DeviceCapabilityRegistry.actionScreenTimeoutControl,
        label: 'Screen Auto-Lock Timeout',
        support: isAndroid
            ? (canWriteSettings
                ? ActionExecutionSupport.directlySupported
                : ActionExecutionSupport.permissionRequired)
            : ActionExecutionSupport.unsupported,
        requiredPermission: NestinPermissionKind.writeSettings,
        oemNote: isAndroid
            ? 'Requires Modify System Settings (WRITE_SETTINGS).'
            : 'iOS does not expose system Auto-Lock duration to third-party apps.',
      ),
      DeviceCapabilityRegistry.actionAppOverlayBanner: DeviceCapabilityRecord(
        actionKey: DeviceCapabilityRegistry.actionAppOverlayBanner,
        label: 'Mindful Pause / Warning Overlay',
        support: isAndroid
            ? (hasOverlay
                ? ActionExecutionSupport.directlySupported
                : ActionExecutionSupport.permissionRequired)
            : ActionExecutionSupport.unsupported,
        requiredPermission: NestinPermissionKind.systemAlertWindow,
        oemNote: isAndroid
            ? 'Shows full-screen alarms or mindful pause banners when allowed.'
            : 'Not supported on iOS; uses local notifications instead.',
      ),
      DeviceCapabilityRegistry.actionAppBlockingShield: DeviceCapabilityRecord(
        actionKey: DeviceCapabilityRegistry.actionAppBlockingShield,
        label: 'Hard Third-Party App Blocking Shield',
        support: isAndroid
            ? (hasAccessibility
                ? ActionExecutionSupport.directlySupported
                : ActionExecutionSupport.delegatedToSystemSettings)
            : (isIos && hasFamilyControls
                ? ActionExecutionSupport.permissionRequired
                : ActionExecutionSupport.unsupported),
        requiredPermission: isAndroid
            ? NestinPermissionKind.accessibilityService
            : NestinPermissionKind.familyControls,
        oemNote: isAndroid
            ? 'Without Accessibility shield/Work Profile, Nestin falls back to notifications and Digital Wellbeing delegation.'
            : 'Requires Apple FamilyControls & ManagedSettings entitlement.',
      ),
      DeviceCapabilityRegistry.actionSystemModesDelegation:
          DeviceCapabilityRecord(
        actionKey: DeviceCapabilityRegistry.actionSystemModesDelegation,
        label: isSamsung ? 'Samsung Modes & Routines' : 'OS Digital Wellbeing',
        support: isAndroid || isIos
            ? ActionExecutionSupport.delegatedToSystemSettings
            : ActionExecutionSupport.unsupported,
        oemNote: isSamsung
            ? 'Opens Samsung Modes & Routines / Digital Wellbeing for hardware/system rules outside third-party APIs.'
            : 'Opens OS Wellbeing / Focus settings for system-only toggles.',
      ),
      DeviceCapabilityRegistry.actionExactAlarms: DeviceCapabilityRecord(
        actionKey: DeviceCapabilityRegistry.actionExactAlarms,
        label: 'Exact Wake-Up Alarms',
        support: isAndroid
            ? (hasExactAlarm
                ? ActionExecutionSupport.directlySupported
                : ActionExecutionSupport.permissionRequired)
            : ActionExecutionSupport.directlySupported,
        requiredPermission: NestinPermissionKind.exactAlarm,
        oemNote: isAndroid
            ? 'Required for reliable Roo wake-up alarms at exact times.'
            : 'Scheduled via local notification triggers on iOS.',
      ),
    };

    final now = DateTime.now();
    final permissions = <PermissionEntry>[
      PermissionEntry(
        kind: NestinPermissionKind.notifications,
        title: 'Notifications',
        tier: PermissionRequirementTier.required,
        status: hasNotifications
            ? PermissionStatus.granted
            : PermissionStatus.denied,
        rationale:
            'Needed for wake-up alarms, Dose medication reminders, hydration nudges, and automation alerts.',
        enableInstructions:
            'Open App Settings -> Notifications -> Allow Notifications.',
        affectsFeatures: const [
          'Roo Alarms & Timers',
          'Seren Dose & Hydration',
          'Scout Pre-Limit Alerts',
          'Automation Notifications',
        ],
        lastCheckedAt: now,
      ),
      if (isAndroid) ...[
        PermissionEntry(
          kind: NestinPermissionKind.exactAlarm,
          title: 'Alarms & Reminders (Exact Alarms)',
          tier: PermissionRequirementTier.required,
          status: hasExactAlarm
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale:
              'Ensures Roo wake-up alarms, Dose medication schedules, and timed Focus ends fire on time.',
          enableInstructions:
              'Open Alarms & Reminders settings -> Allow setting alarms and reminders.',
          affectsFeatures: const ['Roo Alarms', 'Dose Medication', 'Phone Mode Schedules'],
          lastCheckedAt: now,
        ),
        PermissionEntry(
          kind: NestinPermissionKind.usageStats,
          title: 'Usage Access (Digital Wellbeing)',
          tier: PermissionRequirementTier.recommended,
          status: hasUsageStats
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale:
              'Lets Scout measure daily app time and trigger pre-limit warnings accurately offline.',
          enableInstructions:
              'Open Usage Data Access -> select Nestin -> Permit usage access.',
          affectsFeatures: const ['Scout App Usage Stats', 'Daily App Limits'],
          lastCheckedAt: now,
        ),
        PermissionEntry(
          kind: NestinPermissionKind.notificationPolicy,
          title: 'Do Not Disturb Access',
          tier: PermissionRequirementTier.optional,
          status: hasDndAccess
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale:
              'Allows Sleep, Work, and Study Phone Modes to toggle Do Not Disturb and restore your prior filter when done.',
          enableInstructions:
              'Open Do Not Disturb Access -> allow Nestin.',
          affectsFeatures: const ['Phone Modes (Sleep/Work/Study)', 'Automation DND'],
          lastCheckedAt: now,
        ),
        PermissionEntry(
          kind: NestinPermissionKind.writeSettings,
          title: 'Modify System Settings (Brightness & Timeout)',
          tier: PermissionRequirementTier.optional,
          status: canWriteSettings
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale:
              'Lets Phone Modes adjust system brightness and screen timeout and restore prior values if you did not change them manually.',
          enableInstructions:
              'Open Modify System Settings -> enable Allow modify system settings for Nestin.',
          affectsFeatures: const ['Phone Mode Dimming', 'Auto-Lock Timeout'],
          lastCheckedAt: now,
        ),
        PermissionEntry(
          kind: NestinPermissionKind.systemAlertWindow,
          title: 'Display Over Other Apps',
          tier: PermissionRequirementTier.optional,
          status: hasOverlay
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale:
              'Supports alarm dismissals on lock screens and optional mindful pause banners.',
          enableInstructions:
              'Open Appear on Top settings -> enable Nestin.',
          affectsFeatures: const ['Full-Screen Alarms', 'Soft Pause Prompts'],
          lastCheckedAt: now,
        ),
        PermissionEntry(
          kind: NestinPermissionKind.batteryOptimizationExempt,
          title: 'Unrestricted Battery Optimization',
          tier: PermissionRequirementTier.recommended,
          status: isBatteryExempt
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale:
              'Prevents OEM killers (Xiaomi/Samsung/OPPO/vivo) from dropping alarms and background automations.',
          enableInstructions:
              'Battery Settings -> Unrestricted / Don\'t optimize for Nestin.',
          affectsFeatures: const ['Background Alarms', 'Scheduled Phone Modes'],
          lastCheckedAt: now,
        ),
      ],
      PermissionEntry(
        kind: NestinPermissionKind.locationWhenInUse,
        title: 'Location (When In Use & Geofences)',
        tier: PermissionRequirementTier.optional,
        status: hasLocation
            ? PermissionStatus.granted
            : (hasBackgroundLocation
                ? PermissionStatus.granted
                : PermissionStatus.denied),
        rationale:
            'Powers Scout location-based reminders and arrive/leave Home or Work automations.',
        enableInstructions:
            'App Settings -> Permissions -> Location -> Allow while using or Always.',
        affectsFeatures: const ['Scout Location Reminders', 'Geofence Automations'],
        lastCheckedAt: now,
      ),
      if (isIos)
        PermissionEntry(
          kind: NestinPermissionKind.familyControls,
          title: 'Apple FamilyControls (Screen Time)',
          tier: PermissionRequirementTier.optional,
          status: hasFamilyControls
              ? PermissionStatus.granted
              : PermissionStatus.unavailable,
          rationale:
              'Required by iOS for reading cross-app usage telemetry and shielding other apps.',
          enableInstructions:
              'Requires Apple Developer FamilyControls entitlement enabled in the signed iOS build.',
          affectsFeatures: const ['iOS Cross-App Usage', 'iOS App Shielding'],
          canOpenSettings: false,
          lastCheckedAt: now,
        ),
    ];

    return DeviceCapabilityRegistry(
      platform: platform,
      manufacturer: manufacturer,
      brand: brand,
      model: model,
      osVersion: osVersion,
      sdkInt: sdkInt,
      isSamsungOneUi: isSamsung,
      hasFamilyControlsEntitlement: hasFamilyControls,
      capabilities: capabilities,
      permissions: permissions,
      inspectedAt: now,
    );
  }

  DeviceCapabilityRegistry _fallbackRegistry(String platform) {
    return _registryFromMap(
      {
        'platform': platform,
        'manufacturer': platform == 'ios' ? 'Apple' : 'Unknown',
        'brand': platform,
        'model': platform,
        'osVersion': platform,
        'sdkInt': 0,
      },
      platformFallback: platform,
    );
  }

  String _displayNameForPackage(List<TrackedAppRule> rules, String packageName) {
    for (final rule in rules) {
      if (rule.packageName == packageName) return rule.displayName;
    }
    return packageName;
  }

  String _dateKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}

/// Deterministic in-memory mock implementation for testing capability boundaries,
/// permission revocations, usage thresholds, and manual mid-session OS overrides.
class MockDeviceControlService implements DeviceControlServiceInterface {
  DeviceSystemState systemState;
  String platform;
  String manufacturer;
  bool isSamsungOneUi;
  Map<String, int> mockUsageMinutesByPackage;
  Map<String, int> mockLaunchCountsByPackage;
  final List<String> actionLog = [];

  MockDeviceControlService({
    this.systemState = const DeviceSystemState(
      dndFilter: 1,
      brightnessRaw: 180,
      screenTimeoutMs: 60000,
      hasUsageStats: true,
      hasDndAccess: true,
      canWriteSettings: true,
      hasOverlayPermission: true,
      hasAccessibilityService: false,
      hasExactAlarm: true,
      hasNotifications: true,
      isBatteryOptimizationExempt: true,
      hasFamilyControlsEntitlement: false,
    ),
    this.platform = 'android',
    this.manufacturer = 'Google',
    this.isSamsungOneUi = false,
    Map<String, int>? mockUsageMinutesByPackage,
    Map<String, int>? mockLaunchCountsByPackage,
  })  : mockUsageMinutesByPackage = mockUsageMinutesByPackage ?? {},
        mockLaunchCountsByPackage = mockLaunchCountsByPackage ?? {};

  @override
  Future<DeviceCapabilityRegistry> inspectCapabilities() async {
    final now = DateTime.now();
    final isAndroid = platform == 'android';
    final isIos = platform == 'ios';

    return DeviceCapabilityRegistry(
      platform: platform,
      manufacturer: manufacturer,
      brand: manufacturer,
      model: isIos ? 'iPhone' : 'TestDevice',
      osVersion: isIos ? '18.0' : '15',
      sdkInt: isAndroid ? 35 : 0,
      isSamsungOneUi: isSamsungOneUi,
      hasFamilyControlsEntitlement: systemState.hasFamilyControlsEntitlement,
      capabilities: {
        DeviceCapabilityRegistry.actionUsageStats: DeviceCapabilityRecord(
          actionKey: DeviceCapabilityRegistry.actionUsageStats,
          label: 'App Usage Tracking',
          support: isAndroid
              ? (systemState.hasUsageStats
                  ? ActionExecutionSupport.directlySupported
                  : ActionExecutionSupport.permissionRequired)
              : (isIos && systemState.hasFamilyControlsEntitlement
                  ? ActionExecutionSupport.permissionRequired
                  : ActionExecutionSupport.unsupported),
          requiredPermission: NestinPermissionKind.usageStats,
        ),
        DeviceCapabilityRegistry.actionDndToggle: DeviceCapabilityRecord(
          actionKey: DeviceCapabilityRegistry.actionDndToggle,
          label: 'Do Not Disturb Control',
          support: isAndroid
              ? (systemState.hasDndAccess
                  ? ActionExecutionSupport.directlySupported
                  : ActionExecutionSupport.permissionRequired)
              : ActionExecutionSupport.delegatedToSystemSettings,
          requiredPermission: NestinPermissionKind.notificationPolicy,
        ),
        DeviceCapabilityRegistry.actionBrightnessControl: DeviceCapabilityRecord(
          actionKey: DeviceCapabilityRegistry.actionBrightnessControl,
          label: 'System Screen Brightness',
          support: isAndroid
              ? (systemState.canWriteSettings
                  ? ActionExecutionSupport.directlySupported
                  : ActionExecutionSupport.permissionRequired)
              : ActionExecutionSupport.unsupported,
          requiredPermission: NestinPermissionKind.writeSettings,
        ),
        DeviceCapabilityRegistry.actionScreenTimeoutControl:
            DeviceCapabilityRecord(
          actionKey: DeviceCapabilityRegistry.actionScreenTimeoutControl,
          label: 'Screen Auto-Lock Timeout',
          support: isAndroid
              ? (systemState.canWriteSettings
                  ? ActionExecutionSupport.directlySupported
                  : ActionExecutionSupport.permissionRequired)
              : ActionExecutionSupport.unsupported,
          requiredPermission: NestinPermissionKind.writeSettings,
        ),
        DeviceCapabilityRegistry.actionAppOverlayBanner: DeviceCapabilityRecord(
          actionKey: DeviceCapabilityRegistry.actionAppOverlayBanner,
          label: 'Mindful Pause / Warning Overlay',
          support: isAndroid
              ? (systemState.hasOverlayPermission
                  ? ActionExecutionSupport.directlySupported
                  : ActionExecutionSupport.permissionRequired)
              : ActionExecutionSupport.unsupported,
          requiredPermission: NestinPermissionKind.systemAlertWindow,
        ),
        DeviceCapabilityRegistry.actionAppBlockingShield: DeviceCapabilityRecord(
          actionKey: DeviceCapabilityRegistry.actionAppBlockingShield,
          label: 'Hard App Blocking Shield',
          support: isAndroid
              ? (systemState.hasAccessibilityService
                  ? ActionExecutionSupport.directlySupported
                  : ActionExecutionSupport.delegatedToSystemSettings)
              : ActionExecutionSupport.unsupported,
          requiredPermission: NestinPermissionKind.accessibilityService,
        ),
        DeviceCapabilityRegistry.actionSystemModesDelegation:
            const DeviceCapabilityRecord(
          actionKey: DeviceCapabilityRegistry.actionSystemModesDelegation,
          label: 'OS Modes & Wellbeing',
          support: ActionExecutionSupport.delegatedToSystemSettings,
        ),
      },
      permissions: [
        PermissionEntry(
          kind: NestinPermissionKind.notifications,
          title: 'Notifications',
          tier: PermissionRequirementTier.required,
          status: systemState.hasNotifications
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale: 'Required for alarms and alerts.',
          enableInstructions: 'Enable Notifications in OS Settings.',
          lastCheckedAt: now,
        ),
        PermissionEntry(
          kind: NestinPermissionKind.exactAlarm,
          title: 'Exact Alarms',
          tier: PermissionRequirementTier.required,
          status: systemState.hasExactAlarm
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale: 'Required for wake-up alarms.',
          enableInstructions: 'Allow exact alarms in OS Settings.',
          lastCheckedAt: now,
        ),
        PermissionEntry(
          kind: NestinPermissionKind.usageStats,
          title: 'Usage Access',
          tier: PermissionRequirementTier.recommended,
          status: systemState.hasUsageStats
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale: 'Measures app screen time.',
          enableInstructions: 'Enable Usage Access.',
          lastCheckedAt: now,
        ),
        PermissionEntry(
          kind: NestinPermissionKind.notificationPolicy,
          title: 'Do Not Disturb Access',
          tier: PermissionRequirementTier.optional,
          status: systemState.hasDndAccess
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale: 'Allows Focus/Sleep Modes to set DND.',
          enableInstructions: 'Enable DND Policy Access.',
          lastCheckedAt: now,
        ),
        PermissionEntry(
          kind: NestinPermissionKind.writeSettings,
          title: 'Modify System Settings',
          tier: PermissionRequirementTier.optional,
          status: systemState.canWriteSettings
              ? PermissionStatus.granted
              : PermissionStatus.denied,
          rationale: 'Allows brightness and timeout adjustment.',
          enableInstructions: 'Allow Modify System Settings.',
          lastCheckedAt: now,
        ),
      ],
      inspectedAt: now,
    );
  }

  @override
  Future<DeviceSystemState> readSystemState() async => systemState;

  @override
  Future<WellbeingDailySnapshot> fetchAppUsageToday({
    required List<TrackedAppRule> rules,
  }) async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (!systemState.hasUsageStats || platform == 'ios') {
      return WellbeingDailySnapshot(
        dateKey: dateKey,
        records: const [],
        permissionGranted: false,
        honestBoundaryMessage: platform == 'ios'
            ? 'Requires Apple FamilyControls entitlement on iOS.'
            : 'Usage Access permission not granted.',
      );
    }

    final records = rules
        .map((r) => AppUsageRecord(
              packageName: r.packageName,
              appName: r.displayName,
              usedMinutesToday: mockUsageMinutesByPackage[r.packageName] ?? 0,
              launchCountToday: mockLaunchCountsByPackage[r.packageName] ?? 0,
              dateKey: dateKey,
              dataSource: 'usage_stats',
            ))
        .toList();

    return WellbeingDailySnapshot(
      dateKey: dateKey,
      records: records,
      permissionGranted: true,
    );
  }

  @override
  Future<PhoneModeActionOutcome> setDndEnabled(bool enable) async {
    if (platform != 'android') {
      return PhoneModeActionOutcome(
        actionType: PhoneModeActionType.setDnd,
        targetValue: enable ? 'DND On' : 'DND Off',
        support: ActionExecutionSupport.delegatedToSystemSettings,
        succeeded: false,
        message: 'Delegated to system settings on $platform.',
      );
    }
    if (!systemState.hasDndAccess) {
      return PhoneModeActionOutcome(
        actionType: PhoneModeActionType.setDnd,
        targetValue: enable ? 'DND On' : 'DND Off',
        support: ActionExecutionSupport.permissionRequired,
        succeeded: false,
        message: 'Notification Policy Access permission missing.',
      );
    }
    final prev = systemState.dndFilter;
    final next = enable ? 2 : 1;
    systemState = DeviceSystemState(
      dndFilter: next,
      brightnessRaw: systemState.brightnessRaw,
      screenTimeoutMs: systemState.screenTimeoutMs,
      hasUsageStats: systemState.hasUsageStats,
      hasDndAccess: systemState.hasDndAccess,
      canWriteSettings: systemState.canWriteSettings,
      hasOverlayPermission: systemState.hasOverlayPermission,
      hasAccessibilityService: systemState.hasAccessibilityService,
      hasExactAlarm: systemState.hasExactAlarm,
      hasNotifications: systemState.hasNotifications,
      isBatteryOptimizationExempt: systemState.isBatteryOptimizationExempt,
      hasFamilyControlsEntitlement: systemState.hasFamilyControlsEntitlement,
    );
    actionLog.add('setDnd:$next');
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setDnd,
      targetValue: enable ? 'DND On' : 'DND Off',
      support: ActionExecutionSupport.directlySupported,
      succeeded: true,
      message: enable ? 'Do Not Disturb enabled.' : 'Do Not Disturb disabled.',
      previousRawValue: prev,
      appliedRawValue: next,
    );
  }

  @override
  Future<PhoneModeActionOutcome> restoreRawDndFilter(int filter) async {
    if (!systemState.hasDndAccess) {
      return PhoneModeActionOutcome(
        actionType: PhoneModeActionType.setDnd,
        targetValue: 'Filter $filter',
        support: ActionExecutionSupport.permissionRequired,
        succeeded: false,
        message: 'Notification Policy Access revoked; cannot restore DND.',
      );
    }
    final prev = systemState.dndFilter;
    systemState = DeviceSystemState(
      dndFilter: filter,
      brightnessRaw: systemState.brightnessRaw,
      screenTimeoutMs: systemState.screenTimeoutMs,
      hasUsageStats: systemState.hasUsageStats,
      hasDndAccess: systemState.hasDndAccess,
      canWriteSettings: systemState.canWriteSettings,
      hasOverlayPermission: systemState.hasOverlayPermission,
      hasAccessibilityService: systemState.hasAccessibilityService,
      hasExactAlarm: systemState.hasExactAlarm,
      hasNotifications: systemState.hasNotifications,
      isBatteryOptimizationExempt: systemState.isBatteryOptimizationExempt,
      hasFamilyControlsEntitlement: systemState.hasFamilyControlsEntitlement,
    );
    actionLog.add('restoreDnd:$filter');
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setDnd,
      targetValue: 'Filter $filter',
      support: ActionExecutionSupport.directlySupported,
      succeeded: true,
      message: 'Restored prior DND state.',
      previousRawValue: prev,
      appliedRawValue: filter,
    );
  }

  @override
  Future<PhoneModeActionOutcome> setScreenBrightness(int percent) async {
    if (platform != 'android') {
      return PhoneModeActionOutcome(
        actionType: PhoneModeActionType.setScreenBrightness,
        targetValue: '$percent%',
        support: ActionExecutionSupport.unsupported,
        succeeded: false,
        message: 'System brightness control unsupported on $platform.',
      );
    }
    if (!systemState.canWriteSettings) {
      return PhoneModeActionOutcome(
        actionType: PhoneModeActionType.setScreenBrightness,
        targetValue: '$percent%',
        support: ActionExecutionSupport.permissionRequired,
        succeeded: false,
        message: 'WRITE_SETTINGS permission missing.',
      );
    }
    final prev = systemState.brightnessRaw;
    final raw = ((percent.clamp(1, 100) / 100) * 255).round().clamp(1, 255);
    systemState = DeviceSystemState(
      dndFilter: systemState.dndFilter,
      brightnessRaw: raw,
      screenTimeoutMs: systemState.screenTimeoutMs,
      hasUsageStats: systemState.hasUsageStats,
      hasDndAccess: systemState.hasDndAccess,
      canWriteSettings: systemState.canWriteSettings,
      hasOverlayPermission: systemState.hasOverlayPermission,
      hasAccessibilityService: systemState.hasAccessibilityService,
      hasExactAlarm: systemState.hasExactAlarm,
      hasNotifications: systemState.hasNotifications,
      isBatteryOptimizationExempt: systemState.isBatteryOptimizationExempt,
      hasFamilyControlsEntitlement: systemState.hasFamilyControlsEntitlement,
    );
    actionLog.add('setBrightness:$raw');
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setScreenBrightness,
      targetValue: '$percent%',
      support: ActionExecutionSupport.directlySupported,
      succeeded: true,
      message: 'Brightness adjusted to $percent%.',
      previousRawValue: prev,
      appliedRawValue: raw,
    );
  }

  @override
  Future<PhoneModeActionOutcome> restoreRawBrightness(int rawBrightness) async {
    if (!systemState.canWriteSettings) {
      return PhoneModeActionOutcome(
        actionType: PhoneModeActionType.setScreenBrightness,
        targetValue: 'Raw $rawBrightness',
        support: ActionExecutionSupport.permissionRequired,
        succeeded: false,
        message: 'WRITE_SETTINGS revoked; cannot restore brightness.',
      );
    }
    final prev = systemState.brightnessRaw;
    systemState = DeviceSystemState(
      dndFilter: systemState.dndFilter,
      brightnessRaw: rawBrightness,
      screenTimeoutMs: systemState.screenTimeoutMs,
      hasUsageStats: systemState.hasUsageStats,
      hasDndAccess: systemState.hasDndAccess,
      canWriteSettings: systemState.canWriteSettings,
      hasOverlayPermission: systemState.hasOverlayPermission,
      hasAccessibilityService: systemState.hasAccessibilityService,
      hasExactAlarm: systemState.hasExactAlarm,
      hasNotifications: systemState.hasNotifications,
      isBatteryOptimizationExempt: systemState.isBatteryOptimizationExempt,
      hasFamilyControlsEntitlement: systemState.hasFamilyControlsEntitlement,
    );
    actionLog.add('restoreBrightness:$rawBrightness');
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setScreenBrightness,
      targetValue: 'Raw $rawBrightness',
      support: ActionExecutionSupport.directlySupported,
      succeeded: true,
      message: 'Restored prior brightness.',
      previousRawValue: prev,
      appliedRawValue: rawBrightness,
    );
  }

  @override
  Future<PhoneModeActionOutcome> setScreenTimeoutSeconds(int seconds) async {
    if (platform != 'android') {
      return PhoneModeActionOutcome(
        actionType: PhoneModeActionType.setScreenTimeoutSeconds,
        targetValue: '${seconds}s',
        support: ActionExecutionSupport.unsupported,
        succeeded: false,
        message: 'Screen timeout unsupported on $platform.',
      );
    }
    if (!systemState.canWriteSettings) {
      return PhoneModeActionOutcome(
        actionType: PhoneModeActionType.setScreenTimeoutSeconds,
        targetValue: '${seconds}s',
        support: ActionExecutionSupport.permissionRequired,
        succeeded: false,
        message: 'WRITE_SETTINGS permission missing.',
      );
    }
    final prev = systemState.screenTimeoutMs;
    final next = seconds * 1000;
    systemState = DeviceSystemState(
      dndFilter: systemState.dndFilter,
      brightnessRaw: systemState.brightnessRaw,
      screenTimeoutMs: next,
      hasUsageStats: systemState.hasUsageStats,
      hasDndAccess: systemState.hasDndAccess,
      canWriteSettings: systemState.canWriteSettings,
      hasOverlayPermission: systemState.hasOverlayPermission,
      hasAccessibilityService: systemState.hasAccessibilityService,
      hasExactAlarm: systemState.hasExactAlarm,
      hasNotifications: systemState.hasNotifications,
      isBatteryOptimizationExempt: systemState.isBatteryOptimizationExempt,
      hasFamilyControlsEntitlement: systemState.hasFamilyControlsEntitlement,
    );
    actionLog.add('setTimeout:$next');
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setScreenTimeoutSeconds,
      targetValue: '${seconds}s',
      support: ActionExecutionSupport.directlySupported,
      succeeded: true,
      message: 'Screen timeout set to ${seconds}s.',
      previousRawValue: prev,
      appliedRawValue: next,
    );
  }

  @override
  Future<PhoneModeActionOutcome> restoreRawScreenTimeoutMs(int timeoutMs) async {
    if (!systemState.canWriteSettings) {
      return PhoneModeActionOutcome(
        actionType: PhoneModeActionType.setScreenTimeoutSeconds,
        targetValue: '${timeoutMs}ms',
        support: ActionExecutionSupport.permissionRequired,
        succeeded: false,
        message: 'WRITE_SETTINGS revoked; cannot restore screen timeout.',
      );
    }
    final prev = systemState.screenTimeoutMs;
    systemState = DeviceSystemState(
      dndFilter: systemState.dndFilter,
      brightnessRaw: systemState.brightnessRaw,
      screenTimeoutMs: timeoutMs,
      hasUsageStats: systemState.hasUsageStats,
      hasDndAccess: systemState.hasDndAccess,
      canWriteSettings: systemState.canWriteSettings,
      hasOverlayPermission: systemState.hasOverlayPermission,
      hasAccessibilityService: systemState.hasAccessibilityService,
      hasExactAlarm: systemState.hasExactAlarm,
      hasNotifications: systemState.hasNotifications,
      isBatteryOptimizationExempt: systemState.isBatteryOptimizationExempt,
      hasFamilyControlsEntitlement: systemState.hasFamilyControlsEntitlement,
    );
    actionLog.add('restoreTimeout:$timeoutMs');
    return PhoneModeActionOutcome(
      actionType: PhoneModeActionType.setScreenTimeoutSeconds,
      targetValue: '${timeoutMs}ms',
      support: ActionExecutionSupport.directlySupported,
      succeeded: true,
      message: 'Restored prior screen timeout.',
      previousRawValue: prev,
      appliedRawValue: timeoutMs,
    );
  }

  @override
  Future<bool> openPermissionSettings(NestinPermissionKind kind) async {
    actionLog.add('openPermissionSettings:${kind.name}');
    return true;
  }

  @override
  Future<bool> openSystemModesOrWellbeing() async {
    actionLog.add('openSystemModesOrWellbeing');
    return true;
  }
}
