# Nestin Shared Automation Engine

Implemented in `lib/data/models/automation_rule.dart`, `lib/providers/automation_provider.dart`, and `lib/ui/screens/automation/automation_hub_screen.dart`.

---

## 1. Unified Pipeline (`Trigger -> Condition -> Confirmation -> Conflict Lock -> Retry -> Log / Rollback`)

### Triggers (`AutomationTriggerType`)
- `timeSchedule` — Clock schedule (`HH:mm` + weekday filter)
- `alarmDismissed` — Post-wake-up routine handoff from Roo
- `geofenceEnter` / `geofenceExit` — Place transitions from Scout (`SavedPlace`)
- `calendarEventUpcoming` — Pre-event preparation from Roo Calendar
- `appUsageThreshold` — Digital Wellbeing threshold crossings from Scout
- `manual` — Direct one-tap execution

### Conditions (`AutomationConditionType`)
- `always`, `weekdayOnly`, `weekendOnly`, `timeWindow` (supports overnight ranges e.g. `22:00`–`07:00`), `activePhoneModeEquals`, `permissionGranted`.

### Actions (`AutomationActionType`)
- `activatePhoneMode`, `endActivePhoneMode`
- `setDndEnabled`, `setBrightness` (guarded via `DeviceCapabilityRegistry`)
- `sendNotification` (`nestin_automation_channel`)
- `createTask` (`TaskProvider`), `createReminder` (`ReminderProvider`), `logHydration` (`HydrationProvider`)
- `delegateToSystemSettings`

---

## 2. Safety & Conflict Guarantees

1. **User Confirmation Gate (`requiresConfirmation`):**
   - Rules modifying device state (e.g., entering Focus on arriving at Work) can require confirmation first.
   - Instead of mutating OS state immediately, `AutomationProvider` creates a `PendingAutomationConfirmation`, dispatches a local notification alert, and surfaces `Confirm & Run` / `Skip` actions in `HomeDashboardScreen` and `AutomationHubScreen`.

2. **Shared Setting Ownership & Conflict Locks (`SharedSettingOwnership`):**
   - Before modifying `'phone_mode'`, `'dnd'`, `'brightness'`, or `'screen_timeout'`, `AutomationProvider` inspects `_ownership`.
   - Lower- or equal-priority rules cannot clobber an active higher-priority owner and return `AutomationExecutionStatus.blockedByConflict` with the conflicting owner's name & priority.
   - Higher-priority rules can override safely and take ownership. Users can also manually release locks in `AutomationHubScreen`.

3. **Retry Policy & Honest Failure Reporting:**
   - Configurable `AutomationRetryPolicy` (`maxRetries`, `backoffSeconds`) retries transient execution errors, while deterministic permission denials (`blockedByPermission`) or unsupported platform capabilities (`unsupported`) fail immediately and transparently without hanging.

4. **Rollback (`rollbackExecution`):**
   - Phone Mode activations initiated by an automation store `rollbackSnapshotId`.
   - Invoking `rollbackExecution(logId)` triggers `DeviceControlProvider.endActivePhoneMode(reason: 'automation_rollback')` (respecting user manual mid-session OS edits), releases ownership locks owned by the rule, and marks the audit log `rolledBack`.
