import 'package:uuid/uuid.dart';

enum AutomationTriggerType {
  timeSchedule,
  alarmDismissed,
  geofenceEnter,
  geofenceExit,
  calendarEventUpcoming,
  appUsageThreshold,
  manual,
}

extension AutomationTriggerTypeExt on AutomationTriggerType {
  String get label {
    switch (this) {
      case AutomationTriggerType.timeSchedule:
        return 'Time Schedule';
      case AutomationTriggerType.alarmDismissed:
        return 'After Wake-Up Alarm';
      case AutomationTriggerType.geofenceEnter:
        return 'Arrive at Place';
      case AutomationTriggerType.geofenceExit:
        return 'Leave Place';
      case AutomationTriggerType.calendarEventUpcoming:
        return 'Before Calendar Event';
      case AutomationTriggerType.appUsageThreshold:
        return 'App Usage Limit Reached';
      case AutomationTriggerType.manual:
        return 'Manual One-Tap';
    }
  }
}

enum AutomationConditionType {
  always,
  weekdayOnly,
  weekendOnly,
  timeWindow,
  activePhoneModeEquals,
  permissionGranted,
}

class AutomationCondition {
  final AutomationConditionType type;
  final String? paramA;
  final String? paramB;

  const AutomationCondition({
    this.type = AutomationConditionType.always,
    this.paramA,
    this.paramB,
  });

  String get summary {
    switch (type) {
      case AutomationConditionType.always:
        return 'Always';
      case AutomationConditionType.weekdayOnly:
        return 'Weekdays only (Mon-Fri)';
      case AutomationConditionType.weekendOnly:
        return 'Weekends only (Sat-Sun)';
      case AutomationConditionType.timeWindow:
        return 'Between ${paramA ?? '00:00'} and ${paramB ?? '23:59'}';
      case AutomationConditionType.activePhoneModeEquals:
        return 'Active Mode is ${paramA ?? 'any'}';
      case AutomationConditionType.permissionGranted:
        return 'Requires permission ${paramA ?? ''}';
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'paramA': paramA,
        'paramB': paramB,
      };

  factory AutomationCondition.fromJson(Map<String, dynamic> json) {
    return AutomationCondition(
      type: AutomationConditionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AutomationConditionType.always,
      ),
      paramA: json['paramA'] as String?,
      paramB: json['paramB'] as String?,
    );
  }
}

enum AutomationActionType {
  activatePhoneMode,
  endActivePhoneMode,
  sendNotification,
  createTask,
  createReminder,
  logHydration,
  setDndEnabled,
  setBrightness,
  delegateToSystemSettings,
}

extension AutomationActionTypeExt on AutomationActionType {
  String get label {
    switch (this) {
      case AutomationActionType.activatePhoneMode:
        return 'Activate Phone Mode';
      case AutomationActionType.endActivePhoneMode:
        return 'End Active Phone Mode & Restore';
      case AutomationActionType.sendNotification:
        return 'Send Local Notification';
      case AutomationActionType.createTask:
        return 'Create Task';
      case AutomationActionType.createReminder:
        return 'Create Reminder';
      case AutomationActionType.logHydration:
        return 'Log Quick Water Intake';
      case AutomationActionType.setDndEnabled:
        return 'Toggle Do Not Disturb';
      case AutomationActionType.setBrightness:
        return 'Adjust Screen Brightness';
      case AutomationActionType.delegateToSystemSettings:
        return 'Open OS Modes / Settings';
    }
  }

  bool get isDeviceModifying =>
      this == AutomationActionType.activatePhoneMode ||
      this == AutomationActionType.setDndEnabled ||
      this == AutomationActionType.setBrightness;
}

class AutomationAction {
  final AutomationActionType type;
  final Map<String, dynamic> params;

  const AutomationAction({
    required this.type,
    this.params = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'params': params,
      };

  factory AutomationAction.fromJson(Map<String, dynamic> json) {
    return AutomationAction(
      type: AutomationActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AutomationActionType.sendNotification,
      ),
      params: Map<String, dynamic>.from(
        (json['params'] as Map<dynamic, dynamic>?) ?? const {},
      ),
    );
  }
}

class AutomationRetryPolicy {
  final int maxRetries;
  final int backoffSeconds;

  const AutomationRetryPolicy({
    this.maxRetries = 2,
    this.backoffSeconds = 5,
  });

  Map<String, dynamic> toJson() => {
        'maxRetries': maxRetries,
        'backoffSeconds': backoffSeconds,
      };

  factory AutomationRetryPolicy.fromJson(Map<String, dynamic> json) {
    return AutomationRetryPolicy(
      maxRetries: json['maxRetries'] as int? ?? 2,
      backoffSeconds: json['backoffSeconds'] as int? ?? 5,
    );
  }
}

enum AutomationExecutionStatus {
  succeeded,
  partiallySucceeded,
  pendingConfirmation,
  blockedByPermission,
  blockedByConflict,
  skippedCondition,
  unsupported,
  failed,
  rolledBack,
}

class SharedSettingOwnership {
  final String settingKey; // 'dnd', 'brightness', 'screen_timeout', 'phone_mode'
  final String ownerId;
  final String ownerName;
  final int priority;
  final DateTime acquiredAt;
  final DateTime? expiresAt;

  const SharedSettingOwnership({
    required this.settingKey,
    required this.ownerId,
    required this.ownerName,
    required this.priority,
    required this.acquiredAt,
    this.expiresAt,
  });

  bool isActiveAt(DateTime now) =>
      expiresAt == null || expiresAt!.isAfter(now);

  Map<String, dynamic> toJson() => {
        'settingKey': settingKey,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'priority': priority,
        'acquiredAt': acquiredAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory SharedSettingOwnership.fromJson(Map<String, dynamic> json) {
    return SharedSettingOwnership(
      settingKey: json['settingKey'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      priority: json['priority'] as int? ?? 50,
      acquiredAt: json['acquiredAt'] != null
          ? (DateTime.tryParse(json['acquiredAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }
}

class AutomationRule {
  final String id;
  final String name;
  final String description;
  final String familyOwner; // roo, echo, seren, pippin, twill, scout
  final bool isEnabled;
  final int priority; // 1..100
  final bool requiresConfirmation;
  final AutomationTriggerType triggerType;
  final Map<String, dynamic> triggerConfig;
  final List<AutomationCondition> conditions;
  final List<AutomationAction> actions;
  final AutomationRetryPolicy retryPolicy;
  final DateTime? lastTriggeredAt;
  final int executionCount;

  AutomationRule({
    String? id,
    required this.name,
    this.description = '',
    this.familyOwner = 'scout',
    this.isEnabled = true,
    this.priority = 50,
    this.requiresConfirmation = false,
    required this.triggerType,
    this.triggerConfig = const {},
    this.conditions = const [AutomationCondition()],
    this.actions = const [],
    this.retryPolicy = const AutomationRetryPolicy(),
    this.lastTriggeredAt,
    this.executionCount = 0,
  }) : id = id ?? const Uuid().v4();

  AutomationRule copyWith({
    String? name,
    String? description,
    String? familyOwner,
    bool? isEnabled,
    int? priority,
    bool? requiresConfirmation,
    AutomationTriggerType? triggerType,
    Map<String, dynamic>? triggerConfig,
    List<AutomationCondition>? conditions,
    List<AutomationAction>? actions,
    AutomationRetryPolicy? retryPolicy,
    DateTime? lastTriggeredAt,
    int? executionCount,
  }) {
    return AutomationRule(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      familyOwner: familyOwner ?? this.familyOwner,
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority ?? this.priority,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      triggerType: triggerType ?? this.triggerType,
      triggerConfig: triggerConfig ?? Map<String, dynamic>.from(this.triggerConfig),
      conditions: conditions ?? List<AutomationCondition>.from(this.conditions),
      actions: actions ?? List<AutomationAction>.from(this.actions),
      retryPolicy: retryPolicy ?? this.retryPolicy,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      executionCount: executionCount ?? this.executionCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'familyOwner': familyOwner,
        'isEnabled': isEnabled,
        'priority': priority,
        'requiresConfirmation': requiresConfirmation,
        'triggerType': triggerType.name,
        'triggerConfig': triggerConfig,
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'retryPolicy': retryPolicy.toJson(),
        'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
        'executionCount': executionCount,
      };

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    return AutomationRule(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Automation Rule',
      description: json['description'] as String? ?? '',
      familyOwner: json['familyOwner'] as String? ?? 'scout',
      isEnabled: json['isEnabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 50,
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
      triggerType: AutomationTriggerType.values.firstWhere(
        (e) => e.name == json['triggerType'],
        orElse: () => AutomationTriggerType.manual,
      ),
      triggerConfig: Map<String, dynamic>.from(
        (json['triggerConfig'] as Map<dynamic, dynamic>?) ?? const {},
      ),
      conditions: (json['conditions'] as List<dynamic>?)
              ?.map((e) =>
                  AutomationCondition.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [AutomationCondition()],
      actions: (json['actions'] as List<dynamic>?)
              ?.map((e) =>
                  AutomationAction.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      retryPolicy: json['retryPolicy'] != null
          ? AutomationRetryPolicy.fromJson(
              Map<String, dynamic>.from(json['retryPolicy'] as Map),
            )
          : const AutomationRetryPolicy(),
      lastTriggeredAt: json['lastTriggeredAt'] != null
          ? DateTime.tryParse(json['lastTriggeredAt'] as String)
          : null,
      executionCount: json['executionCount'] as int? ?? 0,
    );
  }

  static List<AutomationRule> defaultTemplates() => [
        AutomationRule(
          id: 'auto_bedtime_winddown',
          name: 'Bedtime Wind-Down',
          description:
              'At 22:30 every night, activates Sleep Mode (DND + 15% brightness with safe restore) and reminds you to wind down.',
          familyOwner: 'roo',
          priority: 80,
          requiresConfirmation: false,
          triggerType: AutomationTriggerType.timeSchedule,
          triggerConfig: const {'time': '22:30', 'weekdays': [1, 2, 3, 4, 5, 6, 7]},
          actions: const [
            AutomationAction(
              type: AutomationActionType.activatePhoneMode,
              params: {'modeId': 'mode_sleep'},
            ),
            AutomationAction(
              type: AutomationActionType.sendNotification,
              params: {
                'title': 'Sleep Mode Active',
                'body': 'Nestin dimmed screen & enabled DND. Original settings will restore when Sleep ends.',
              },
            ),
          ],
        ),
        AutomationRule(
          id: 'auto_morning_hydrate',
          name: 'Morning Hydration Nudge',
          description:
              'When your wake-up alarm is dismissed, logs/prompts a glass of water and schedules morning briefing.',
          familyOwner: 'seren',
          priority: 60,
          triggerType: AutomationTriggerType.alarmDismissed,
          actions: const [
            AutomationAction(
              type: AutomationActionType.sendNotification,
              params: {
                'title': 'Good morning — Start Hydrated',
                'body': 'Tap to log your first 250 ml glass of water and check Today.',
              },
            ),
          ],
        ),
        AutomationRule(
          id: 'auto_arrive_work_focus',
          name: 'Arrive at Work -> Focus Prompt',
          description:
              'Asks confirmation before enabling Work Focus Mode when entering your Work geofence.',
          familyOwner: 'scout',
          priority: 70,
          requiresConfirmation: true,
          triggerType: AutomationTriggerType.geofenceEnter,
          triggerConfig: const {'placeName': 'Work'},
          conditions: const [
            AutomationCondition(type: AutomationConditionType.weekdayOnly),
          ],
          actions: const [
            AutomationAction(
              type: AutomationActionType.activatePhoneMode,
              params: {'modeId': 'mode_work'},
            ),
          ],
        ),
      ];
}

class AutomationExecutionLog {
  final String id;
  final String ruleId;
  final String ruleName;
  final String triggerReason;
  final AutomationExecutionStatus status;
  final String summary;
  final List<String> actionResults;
  final int attemptCount;
  final bool canRollback;
  final bool rolledBack;
  final String? rollbackSnapshotId;
  final DateTime timestamp;

  AutomationExecutionLog({
    String? id,
    required this.ruleId,
    required this.ruleName,
    required this.triggerReason,
    required this.status,
    required this.summary,
    this.actionResults = const [],
    this.attemptCount = 1,
    this.canRollback = false,
    this.rolledBack = false,
    this.rollbackSnapshotId,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  AutomationExecutionLog copyWith({
    AutomationExecutionStatus? status,
    String? summary,
    bool? rolledBack,
  }) {
    return AutomationExecutionLog(
      id: id,
      ruleId: ruleId,
      ruleName: ruleName,
      triggerReason: triggerReason,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      actionResults: actionResults,
      attemptCount: attemptCount,
      canRollback: canRollback,
      rolledBack: rolledBack ?? this.rolledBack,
      rollbackSnapshotId: rollbackSnapshotId,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleId': ruleId,
        'ruleName': ruleName,
        'triggerReason': triggerReason,
        'status': status.name,
        'summary': summary,
        'actionResults': actionResults,
        'attemptCount': attemptCount,
        'canRollback': canRollback,
        'rolledBack': rolledBack,
        'rollbackSnapshotId': rollbackSnapshotId,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AutomationExecutionLog.fromJson(Map<String, dynamic> json) {
    return AutomationExecutionLog(
      id: json['id'] as String?,
      ruleId: json['ruleId'] as String? ?? '',
      ruleName: json['ruleName'] as String? ?? '',
      triggerReason: json['triggerReason'] as String? ?? '',
      status: AutomationExecutionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AutomationExecutionStatus.failed,
      ),
      summary: json['summary'] as String? ?? '',
      actionResults:
          (json['actionResults'] as List<dynamic>?)?.cast<String>() ?? const [],
      attemptCount: json['attemptCount'] as int? ?? 1,
      canRollback: json['canRollback'] as bool? ?? false,
      rolledBack: json['rolledBack'] as bool? ?? false,
      rollbackSnapshotId: json['rollbackSnapshotId'] as String?,
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
