import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/alarm_category.dart';
import '../data/models/automation_rule.dart';
import '../data/models/device_capability.dart';
import '../data/models/reminder.dart';
import '../data/models/task_item.dart';
import '../data/services/notification_service.dart';
import '../data/services/storage_service.dart';
import 'device_control_provider.dart';
import 'hydration_provider.dart';
import 'reminder_provider.dart';
import 'task_provider.dart';

class PendingAutomationConfirmation {
  final String id;
  final AutomationRule rule;
  final String triggerReason;
  final DateTime requestedAt;

  PendingAutomationConfirmation({
    String? id,
    required this.rule,
    required this.triggerReason,
    DateTime? requestedAt,
  })  : id = id ?? const Uuid().v4(),
        requestedAt = requestedAt ?? DateTime.now();
}

class AutomationProvider extends ChangeNotifier {
  final StorageService _storage;
  final DeviceControlProvider _deviceControl;
  final TaskProvider? tasks;
  final ReminderProvider? reminders;
  final HydrationProvider? hydration;
  final NotificationService? notifications;

  bool _disposed = false;
  List<AutomationRule> _rules = [];
  List<AutomationExecutionLog> _logs = [];
  final Map<String, SharedSettingOwnership> _ownership = {};
  final List<PendingAutomationConfirmation> _pendingConfirmations = [];

  AutomationProvider(
    this._storage,
    this._deviceControl, {
    this.tasks,
    this.reminders,
    this.hydration,
    this.notifications,
  }) {
    _loadPersisted();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  List<AutomationRule> get rules => List.unmodifiable(_rules);
  List<AutomationExecutionLog> get logs => List.unmodifiable(_logs);
  Map<String, SharedSettingOwnership> get activeOwnership {
    final now = DateTime.now();
    return Map.unmodifiable(
      Map.fromEntries(
        _ownership.entries.where((e) => e.value.isActiveAt(now)),
      ),
    );
  }

  List<PendingAutomationConfirmation> get pendingConfirmations =>
      List.unmodifiable(_pendingConfirmations);

  void _loadPersisted() {
    if (_storage.hasSavedAutomationRules()) {
      _rules = _storage.loadAutomationRules();
    } else {
      _rules = AutomationRule.defaultTemplates();
      _storage.saveAutomationRules(_rules);
    }
    _logs = _storage.loadAutomationLogs();
  }

  Future<void> addOrUpdateRule(AutomationRule rule) async {
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      _rules = [..._rules]..[idx] = rule;
    } else {
      _rules = [..._rules, rule];
    }
    await _storage.saveAutomationRules(_rules);
    _safeNotify();
  }

  Future<void> toggleRule(String ruleId, bool enabled) async {
    final idx = _rules.indexWhere((r) => r.id == ruleId);
    if (idx < 0) return;
    _rules = [..._rules]..[idx] = _rules[idx].copyWith(isEnabled: enabled);
    await _storage.saveAutomationRules(_rules);
    _safeNotify();
  }

  Future<void> deleteRule(String ruleId) async {
    _rules = _rules.where((r) => r.id != ruleId).toList();
    _ownership.removeWhere((_, o) => o.ownerId == ruleId);
    _pendingConfirmations.removeWhere((p) => p.rule.id == ruleId);
    await _storage.saveAutomationRules(_rules);
    _safeNotify();
  }

  /// Evaluates all enabled rules matching [triggerType] ordered by priority descending.
  Future<List<AutomationExecutionLog>> triggerByEvent(
    AutomationTriggerType triggerType, {
    String triggerReason = '',
    Map<String, dynamic> eventContext = const {},
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    final candidates = _rules
        .where((r) => r.isEnabled && r.triggerType == triggerType)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final results = <AutomationExecutionLog>[];
    for (final rule in candidates) {
      if (!_matchesTriggerConfig(rule, eventContext, checkNow)) {
        continue;
      }
      final reason = triggerReason.isNotEmpty
          ? triggerReason
          : '${triggerType.label}${eventContext['placeName'] != null ? ' · ${eventContext['placeName']}' : ''}';
      final log = await _executeRule(
        rule,
        triggerReason: reason,
        bypassConfirmation: false,
        now: checkNow,
      );
      results.add(log);
    }
    return results;
  }

  Future<AutomationExecutionLog?> runRuleManually(
    String ruleId, {
    bool bypassConfirmation = true,
    DateTime? now,
  }) async {
    final rule = _rules.cast<AutomationRule?>().firstWhere(
          (r) => r?.id == ruleId,
          orElse: () => null,
        );
    if (rule == null) return null;
    return _executeRule(
      rule,
      triggerReason: 'Manual run',
      bypassConfirmation: bypassConfirmation,
      now: now ?? DateTime.now(),
    );
  }

  Future<AutomationExecutionLog?> confirmPendingExecution(
    String pendingId, {
    DateTime? now,
  }) async {
    final idx = _pendingConfirmations.indexWhere((p) => p.id == pendingId);
    if (idx < 0) return null;
    final pending = _pendingConfirmations.removeAt(idx);
    _safeNotify();
    return _executeRule(
      pending.rule,
      triggerReason: '${pending.triggerReason} (User confirmed)',
      bypassConfirmation: true,
      now: now ?? DateTime.now(),
    );
  }

  void dismissPendingExecution(String pendingId) {
    _pendingConfirmations.removeWhere((p) => p.id == pendingId);
    _safeNotify();
  }

  /// Releases ownership & rolls back active device Phone Mode started by [logId].
  Future<bool> rollbackExecution(String logId) async {
    final idx = _logs.indexWhere((l) => l.id == logId);
    if (idx < 0) return false;
    final log = _logs[idx];
    if (!log.canRollback || log.rolledBack) return false;

    final snap = _deviceControl.activeSnapshot;
    if (snap != null &&
        (log.rollbackSnapshotId == null ||
            snap.snapshotId == log.rollbackSnapshotId)) {
      await _deviceControl.endActivePhoneMode(reason: 'automation_rollback');
    }

    _ownership.removeWhere((_, o) => o.ownerId == log.ruleId);

    _logs = [..._logs]
      ..[idx] = log.copyWith(
        status: AutomationExecutionStatus.rolledBack,
        rolledBack: true,
        summary: '${log.summary} -> Rolled back.',
      );
    await _storage.saveAutomationLogs(_logs);
    _safeNotify();
    return true;
  }

  /// Releases a conflict lock manually (e.g. from UI) for [settingKey].
  void releaseOwnershipLock(String settingKey) {
    _ownership.remove(settingKey);
    _safeNotify();
  }

  bool _matchesTriggerConfig(
    AutomationRule rule,
    Map<String, dynamic> eventContext,
    DateTime now,
  ) {
    final cfg = rule.triggerConfig;
    if (cfg.isEmpty) return true;

    if (rule.triggerType == AutomationTriggerType.timeSchedule &&
        cfg['time'] is String) {
      final hhmm = cfg['time'] as String;
      final nowHm =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      if (eventContext['ignoreClockMatch'] != true && hhmm != nowHm) {
        return false;
      }
      final weekdays = (cfg['weekdays'] as List<dynamic>?)?.cast<int>();
      if (weekdays != null &&
          weekdays.isNotEmpty &&
          !weekdays.contains(now.weekday)) {
        return false;
      }
    }

    if ((rule.triggerType == AutomationTriggerType.geofenceEnter ||
            rule.triggerType == AutomationTriggerType.geofenceExit) &&
        cfg['placeName'] is String &&
        (cfg['placeName'] as String).trim().isNotEmpty) {
      final expected = (cfg['placeName'] as String).trim().toLowerCase();
      final actual =
          (eventContext['placeName'] as String? ?? '').trim().toLowerCase();
      if (actual.isNotEmpty && actual != expected) return false;
    }

    if (rule.triggerType == AutomationTriggerType.appUsageThreshold &&
        cfg['packageName'] is String &&
        (cfg['packageName'] as String).trim().isNotEmpty) {
      final expected = (cfg['packageName'] as String).trim();
      final actual = (eventContext['packageName'] as String? ?? '').trim();
      if (actual.isNotEmpty && actual != expected) return false;
    }

    return true;
  }

  bool _evaluateConditions(AutomationRule rule, DateTime now) {
    for (final c in rule.conditions) {
      switch (c.type) {
        case AutomationConditionType.always:
          break;
        case AutomationConditionType.weekdayOnly:
          if (now.weekday > 5) return false;
          break;
        case AutomationConditionType.weekendOnly:
          if (now.weekday < 6) return false;
          break;
        case AutomationConditionType.timeWindow:
          if (!_inTimeWindow(now, c.paramA ?? '00:00', c.paramB ?? '23:59')) {
            return false;
          }
          break;
        case AutomationConditionType.activePhoneModeEquals:
          if (_deviceControl.activePhoneModeId != c.paramA) return false;
          break;
        case AutomationConditionType.permissionGranted:
          final kind = NestinPermissionKind.values.firstWhere(
            (e) => e.name == c.paramA,
            orElse: () => NestinPermissionKind.notifications,
          );
          if (!_deviceControl.registry.isGranted(kind)) return false;
          break;
      }
    }
    return true;
  }

  bool _inTimeWindow(DateTime now, String start, String end) {
    int parseMin(String s) {
      final parts = s.split(':');
      if (parts.length != 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }

    final sMin = parseMin(start);
    final eMin = parseMin(end);
    final nMin = now.hour * 60 + now.minute;
    return sMin <= eMin
        ? (nMin >= sMin && nMin < eMin)
        : (nMin >= sMin || nMin < eMin);
  }

  Future<AutomationExecutionLog> _executeRule(
    AutomationRule rule, {
    required String triggerReason,
    required bool bypassConfirmation,
    required DateTime now,
  }) async {
    if (!_evaluateConditions(rule, now)) {
      return _recordLog(
        AutomationExecutionLog(
          ruleId: rule.id,
          ruleName: rule.name,
          triggerReason: triggerReason,
          status: AutomationExecutionStatus.skippedCondition,
          summary: 'Skipped because rule condition did not match.',
          timestamp: now,
        ),
      );
    }

    if (rule.requiresConfirmation && !bypassConfirmation) {
      _pendingConfirmations.add(
        PendingAutomationConfirmation(
          rule: rule,
          triggerReason: triggerReason,
          requestedAt: now,
        ),
      );
      if (notifications != null) {
        await notifications!.showAutomationNotification(
          id: rule.id.hashCode.abs() % 100000 + 850000,
          title: 'Confirm Automation · ${rule.name}',
          body: '$triggerReason triggered a device-control rule. Tap to review.',
          payload: 'nestin://automation',
        );
      }
      return _recordLog(
        AutomationExecutionLog(
          ruleId: rule.id,
          ruleName: rule.name,
          triggerReason: triggerReason,
          status: AutomationExecutionStatus.pendingConfirmation,
          summary: 'Waiting for user confirmation before running device actions.',
          timestamp: now,
        ),
      );
    }

    final actionResults = <String>[];
    var successes = 0;
    var permissionBlocked = false;
    var conflictBlocked = false;
    var unsupportedCount = 0;
    var hardFailed = false;
    var attemptsUsed = 1;
    var canRollback = false;
    String? rollbackSnapshotId;

    for (final action in rule.actions) {
      // Conflict / Ownership Lock Check for shared device settings
      final settingKeys = _settingKeysForAction(action.type);
      String? conflictingOwner;
      for (final key in settingKeys) {
        final existing = _ownership[key];
        if (existing != null &&
            existing.ownerId != rule.id &&
            existing.isActiveAt(now)) {
          if (rule.priority <= existing.priority) {
            conflictingOwner =
                '$key locked by ${existing.ownerName} (priority ${existing.priority})';
            break;
          }
        }
      }

      if (conflictingOwner != null) {
        conflictBlocked = true;
        actionResults.add('${action.type.label}: Blocked ($conflictingOwner)');
        continue;
      }

      // Retry transient failures according to RetryPolicy
      final maxAttempts = 1 + rule.retryPolicy.maxRetries;
      var completed = false;
      for (var attempt = 1; attempt <= maxAttempts && !completed; attempt++) {
        attemptsUsed = attempt > attemptsUsed ? attempt : attemptsUsed;
        try {
          switch (action.type) {
            case AutomationActionType.activatePhoneMode:
              final modeId =
                  action.params['modeId'] as String? ?? 'mode_work';
              final outcomes = await _deviceControl.activatePhoneMode(
                modeId,
                now: now,
              );
              final anySucceeded = outcomes.any((o) => o.succeeded);
              final anyPermMissing = outcomes.any(
                (o) => o.support == ActionExecutionSupport.permissionRequired,
              );
              final anyUnsupported = outcomes.any(
                (o) => o.support == ActionExecutionSupport.unsupported,
              );
              if (anySucceeded || outcomes.isNotEmpty) {
                for (final key in settingKeys) {
                  _ownership[key] = SharedSettingOwnership(
                    settingKey: key,
                    ownerId: rule.id,
                    ownerName: rule.name,
                    priority: rule.priority,
                    acquiredAt: now,
                    expiresAt: _deviceControl.activeSnapshot?.expiresAt,
                  );
                }
              }
              if (anySucceeded) {
                successes++;
                canRollback = true;
                rollbackSnapshotId = _deviceControl.activeSnapshot?.snapshotId;
                actionResults.add(
                    'Activated Phone Mode ($modeId): ${outcomes.map((o) => o.message).join(' ')}');
              } else if (anyPermMissing) {
                permissionBlocked = true;
                actionResults.add(
                    'Phone Mode ($modeId) needs permissions: ${outcomes.map((o) => o.message).join(' ')}');
              } else if (anyUnsupported) {
                unsupportedCount++;
                actionResults.add(
                    'Phone Mode ($modeId) unsupported/delegated: ${outcomes.map((o) => o.message).join(' ')}');
              } else {
                hardFailed = true;
                actionResults.add('Phone Mode ($modeId) made no changes.');
              }
              completed = true;
              break;

            case AutomationActionType.endActivePhoneMode:
              final notes = await _deviceControl.endActivePhoneMode(
                reason: 'automation_rule:${rule.name}',
              );
              _ownership.clear();
              successes++;
              actionResults.add(
                  'Ended Phone Mode: ${notes.isEmpty ? 'No active mode.' : notes.join(' ')}');
              completed = true;
              break;

            case AutomationActionType.setDndEnabled:
              final enable = action.params['enable'] as bool? ?? true;
              final dndSupport = _deviceControl.registry.supportFor(
                DeviceCapabilityRegistry.actionDndToggle,
              );
              if (dndSupport == ActionExecutionSupport.permissionRequired) {
                permissionBlocked = true;
                actionResults.add(
                    'Toggle DND blocked: Notification Policy Access permission required.');
              } else if (dndSupport == ActionExecutionSupport.unsupported ||
                  dndSupport == ActionExecutionSupport.delegatedToSystemSettings) {
                unsupportedCount++;
                actionResults.add(
                    'Toggle DND is ${dndSupport.name} on ${_deviceControl.registry.platform}.');
              } else {
                successes++;
                _ownership['dnd'] = SharedSettingOwnership(
                  settingKey: 'dnd',
                  ownerId: rule.id,
                  ownerName: rule.name,
                  priority: rule.priority,
                  acquiredAt: now,
                );
                actionResults.add('DND ${enable ? 'enabled' : 'disabled'} cleanly.');
              }
              completed = true;
              break;

            case AutomationActionType.setBrightness:
              final brightSupport = _deviceControl.registry.supportFor(
                DeviceCapabilityRegistry.actionBrightnessControl,
              );
              if (brightSupport == ActionExecutionSupport.permissionRequired) {
                permissionBlocked = true;
                actionResults.add(
                    'Brightness blocked: WRITE_SETTINGS permission required.');
              } else if (brightSupport == ActionExecutionSupport.unsupported) {
                unsupportedCount++;
                actionResults.add(
                    'Brightness adjustment unsupported on ${_deviceControl.registry.platform}.');
              } else {
                successes++;
                _ownership['brightness'] = SharedSettingOwnership(
                  settingKey: 'brightness',
                  ownerId: rule.id,
                  ownerName: rule.name,
                  priority: rule.priority,
                  acquiredAt: now,
                );
                actionResults.add(
                    'Brightness target ${action.params['percent'] ?? 50}% checked.');
              }
              completed = true;
              break;

            case AutomationActionType.sendNotification:
              final title = action.params['title'] as String? ?? rule.name;
              final body = action.params['body'] as String? ?? triggerReason;
              if (notifications != null) {
                await notifications!.showAutomationNotification(
                  id: rule.id.hashCode.abs() % 100000 + 860000,
                  title: title,
                  body: body,
                  payload: 'nestin://automation',
                );
              }
              successes++;
              actionResults.add('Dispatched notification: "$title".');
              completed = true;
              break;

            case AutomationActionType.createTask:
              final title = action.params['title'] as String? ?? rule.name;
              final catName =
                  (action.params['category'] as String? ?? '').toLowerCase();
              final taskCategory = AlarmCategory.predefined.firstWhere(
                (c) => c.name.toLowerCase() == catName,
                orElse: () => AlarmCategory.predefined.last,
              );
              if (tasks != null) {
                await tasks!.addTask(
                  TaskItem(
                    id: const Uuid().v4(),
                    title: title,
                    category: taskCategory,
                    priority: TaskPriority.medium,
                    createdAt: now,
                  ),
                );
                successes++;
                actionResults.add('Created task "$title".');
              } else {
                actionResults.add('Task creation queued ("$title").');
                successes++;
              }
              completed = true;
              break;

            case AutomationActionType.createReminder:
              final title = action.params['title'] as String? ?? rule.name;
              final mins = action.params['minutesFromNow'] as int? ?? 15;
              if (reminders != null) {
                await reminders!.addReminder(
                  Reminder(
                    id: const Uuid().v4(),
                    title: title,
                    dueDateTime: now.add(Duration(minutes: mins)),
                    category: AlarmCategory.predefined.last,
                    createdAt: now,
                  ),
                );
              }
              successes++;
              actionResults.add('Scheduled reminder "$title" (+${mins}m).');
              completed = true;
              break;

            case AutomationActionType.logHydration:
              final ml = action.params['ml'] as int? ?? 250;
              final glasses = (ml / 250).round().clamp(1, 8);
              if (hydration != null) {
                await hydration!.addGlass(glasses);
              }
              successes++;
              actionResults.add('Logged +$ml ml hydration intake.');
              completed = true;
              break;

            case AutomationActionType.delegateToSystemSettings:
              final opened = await _deviceControl.openSystemModesOrWellbeing();
              if (opened) {
                successes++;
                actionResults.add('Opened OS Modes & Digital Wellbeing settings.');
              } else {
                unsupportedCount++;
                actionResults.add('Could not open OS settings on this host.');
              }
              completed = true;
              break;
          }
        } catch (e) {
          if (attempt == maxAttempts) {
            hardFailed = true;
            actionResults.add('${action.type.label} failed after $attempt attempts: $e');
          }
        }
      }
    }

    final total = rule.actions.length;
    final AutomationExecutionStatus finalStatus;
    if (successes == total && total > 0) {
      finalStatus = AutomationExecutionStatus.succeeded;
    } else if (successes > 0) {
      finalStatus = AutomationExecutionStatus.partiallySucceeded;
    } else if (conflictBlocked) {
      finalStatus = AutomationExecutionStatus.blockedByConflict;
    } else if (permissionBlocked) {
      finalStatus = AutomationExecutionStatus.blockedByPermission;
    } else if (unsupportedCount > 0 && !hardFailed) {
      finalStatus = AutomationExecutionStatus.unsupported;
    } else {
      finalStatus = AutomationExecutionStatus.failed;
    }

    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      _rules = [..._rules]
        ..[idx] = _rules[idx].copyWith(
          lastTriggeredAt: now,
          executionCount: _rules[idx].executionCount + 1,
        );
      await _storage.saveAutomationRules(_rules);
    }

    return _recordLog(
      AutomationExecutionLog(
        ruleId: rule.id,
        ruleName: rule.name,
        triggerReason: triggerReason,
        status: finalStatus,
        summary: actionResults.isEmpty
            ? 'No actions configured.'
            : actionResults.join(' | '),
        actionResults: actionResults,
        attemptCount: attemptsUsed,
        canRollback: canRollback,
        rollbackSnapshotId: rollbackSnapshotId,
        timestamp: now,
      ),
    );
  }

  List<String> _settingKeysForAction(AutomationActionType type) {
    switch (type) {
      case AutomationActionType.activatePhoneMode:
        return const ['phone_mode', 'dnd', 'brightness', 'screen_timeout'];
      case AutomationActionType.setDndEnabled:
        return const ['dnd'];
      case AutomationActionType.setBrightness:
        return const ['brightness'];
      default:
        return const [];
    }
  }

  Future<AutomationExecutionLog> _recordLog(AutomationExecutionLog log) async {
    _logs = [log, ..._logs].take(200).toList();
    await _storage.saveAutomationLogs(_logs);
    _safeNotify();
    return log;
  }
}
