/// Honest classification of whether an action or device capability can run
/// automatically on the current OS/device, needs permission, delegates to
/// system settings, or is unsupported.
enum ActionExecutionSupport {
  directlySupported,
  permissionRequired,
  delegatedToSystemSettings,
  unsupported,
}

/// Permissions across Android, iOS, and shared Nestin modules inspected by the
/// centralized Permission Center.
enum NestinPermissionKind {
  notifications,
  exactAlarm,
  usageStats,
  notificationPolicy,
  writeSettings,
  systemAlertWindow,
  accessibilityService,
  locationWhenInUse,
  locationAlways,
  batteryOptimizationExempt,
  familyControls,
}

enum PermissionRequirementTier {
  required,
  recommended,
  optional,
}

enum PermissionStatus {
  granted,
  denied,
  revoked,
  restricted,
  unavailable,
}

class PermissionEntry {
  final NestinPermissionKind kind;
  final String title;
  final PermissionRequirementTier tier;
  final PermissionStatus status;
  final String rationale;
  final String enableInstructions;
  final List<String> affectsFeatures;
  final bool canOpenSettings;
  final bool wasPreviouslyGranted;
  final DateTime? lastCheckedAt;

  const PermissionEntry({
    required this.kind,
    required this.title,
    required this.tier,
    required this.status,
    required this.rationale,
    required this.enableInstructions,
    this.affectsFeatures = const [],
    this.canOpenSettings = true,
    this.wasPreviouslyGranted = false,
    this.lastCheckedAt,
  });

  bool get isGranted => status == PermissionStatus.granted;
  bool get isRevoked => status == PermissionStatus.revoked;
  bool get needsAttention =>
      status == PermissionStatus.denied ||
      status == PermissionStatus.revoked ||
      (tier == PermissionRequirementTier.required && !isGranted);

  PermissionEntry copyWith({
    PermissionStatus? status,
    bool? wasPreviouslyGranted,
    DateTime? lastCheckedAt,
    bool? canOpenSettings,
    String? enableInstructions,
  }) {
    return PermissionEntry(
      kind: kind,
      title: title,
      tier: tier,
      status: status ?? this.status,
      rationale: rationale,
      enableInstructions: enableInstructions ?? this.enableInstructions,
      affectsFeatures: affectsFeatures,
      canOpenSettings: canOpenSettings ?? this.canOpenSettings,
      wasPreviouslyGranted: wasPreviouslyGranted ?? this.wasPreviouslyGranted,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'title': title,
        'tier': tier.name,
        'status': status.name,
        'rationale': rationale,
        'enableInstructions': enableInstructions,
        'affectsFeatures': affectsFeatures,
        'canOpenSettings': canOpenSettings,
        'wasPreviouslyGranted': wasPreviouslyGranted,
        'lastCheckedAt': lastCheckedAt?.toIso8601String(),
      };

  factory PermissionEntry.fromJson(Map<String, dynamic> json) {
    return PermissionEntry(
      kind: NestinPermissionKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => NestinPermissionKind.notifications,
      ),
      title: json['title'] as String? ?? '',
      tier: PermissionRequirementTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => PermissionRequirementTier.optional,
      ),
      status: PermissionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PermissionStatus.denied,
      ),
      rationale: json['rationale'] as String? ?? '',
      enableInstructions: json['enableInstructions'] as String? ?? '',
      affectsFeatures:
          (json['affectsFeatures'] as List<dynamic>?)?.cast<String>() ?? const [],
      canOpenSettings: json['canOpenSettings'] as bool? ?? true,
      wasPreviouslyGranted: json['wasPreviouslyGranted'] as bool? ?? false,
      lastCheckedAt: json['lastCheckedAt'] != null
          ? DateTime.tryParse(json['lastCheckedAt'] as String)
          : null,
    );
  }
}

class DeviceCapabilityRecord {
  final String actionKey;
  final String label;
  final ActionExecutionSupport support;
  final NestinPermissionKind? requiredPermission;
  final String oemNote;
  final bool canOpenSettings;

  const DeviceCapabilityRecord({
    required this.actionKey,
    required this.label,
    required this.support,
    this.requiredPermission,
    this.oemNote = '',
    this.canOpenSettings = true,
  });

  Map<String, dynamic> toJson() => {
        'actionKey': actionKey,
        'label': label,
        'support': support.name,
        'requiredPermission': requiredPermission?.name,
        'oemNote': oemNote,
        'canOpenSettings': canOpenSettings,
      };

  factory DeviceCapabilityRecord.fromJson(Map<String, dynamic> json) {
    return DeviceCapabilityRecord(
      actionKey: json['actionKey'] as String? ?? '',
      label: json['label'] as String? ?? '',
      support: ActionExecutionSupport.values.firstWhere(
        (e) => e.name == json['support'],
        orElse: () => ActionExecutionSupport.unsupported,
      ),
      requiredPermission: json['requiredPermission'] != null
          ? NestinPermissionKind.values.firstWhere(
              (e) => e.name == json['requiredPermission'],
              orElse: () => NestinPermissionKind.notifications,
            )
          : null,
      oemNote: json['oemNote'] as String? ?? '',
      canOpenSettings: json['canOpenSettings'] as bool? ?? true,
    );
  }
}

/// Snapshot of device/OS capabilities, OEM quirks, and permission states.
class DeviceCapabilityRegistry {
  final String platform;
  final String manufacturer;
  final String brand;
  final String model;
  final String osVersion;
  final int sdkInt;
  final bool isSamsungOneUi;
  final bool hasFamilyControlsEntitlement;
  final Map<String, DeviceCapabilityRecord> capabilities;
  final List<PermissionEntry> permissions;
  final DateTime inspectedAt;

  const DeviceCapabilityRegistry({
    required this.platform,
    this.manufacturer = 'unknown',
    this.brand = 'unknown',
    this.model = 'unknown',
    this.osVersion = 'unknown',
    this.sdkInt = 0,
    this.isSamsungOneUi = false,
    this.hasFamilyControlsEntitlement = false,
    this.capabilities = const {},
    this.permissions = const [],
    required this.inspectedAt,
  });

  DeviceCapabilityRecord? recordFor(String actionKey) => capabilities[actionKey];

  ActionExecutionSupport supportFor(String actionKey) =>
      capabilities[actionKey]?.support ?? ActionExecutionSupport.unsupported;

  PermissionEntry? permissionFor(NestinPermissionKind kind) {
    for (final entry in permissions) {
      if (entry.kind == kind) return entry;
    }
    return null;
  }

  bool isGranted(NestinPermissionKind kind) =>
      permissionFor(kind)?.isGranted ?? false;

  List<PermissionEntry> get revokedPermissions =>
      permissions.where((p) => p.isRevoked).toList();

  List<PermissionEntry> get requiredMissingPermissions => permissions
      .where((p) =>
          p.tier == PermissionRequirementTier.required && !p.isGranted)
      .toList();

  List<PermissionEntry> get recommendedOrOptionalMissingPermissions => permissions
      .where((p) =>
          p.tier != PermissionRequirementTier.required &&
          (p.status == PermissionStatus.denied ||
              p.status == PermissionStatus.revoked))
      .toList();

  static const String actionUsageStats = 'usage_stats';
  static const String actionDndToggle = 'dnd_toggle';
  static const String actionBrightnessControl = 'brightness_control';
  static const String actionScreenTimeoutControl = 'screen_timeout_control';
  static const String actionAppOverlayBanner = 'app_overlay_banner';
  static const String actionAppBlockingShield = 'app_blocking_shield';
  static const String actionSystemModesDelegation = 'system_modes_delegation';
  static const String actionExactAlarms = 'exact_alarms';
  static const String actionGeofencing = 'geofencing';
}
