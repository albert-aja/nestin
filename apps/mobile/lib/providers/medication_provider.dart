import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import '../data/models/medication_item.dart';
import '../data/models/medication_log.dart';
import '../data/models/medication_snooze.dart';
import '../data/services/storage_service.dart';
import '../data/services/notification_service.dart';

class TodayDoseSlot {
  final MedicationItem medication;
  final String timeString; // "08:00"
  final DateTime scheduledDateTime;
  final MedicationLog? log;
  final MedicationSnooze? snooze;

  const TodayDoseSlot({
    required this.medication,
    required this.timeString,
    required this.scheduledDateTime,
    this.log,
    this.snooze,
  });

  bool get isTaken => log?.action == MedicationAction.taken;
  bool get isSkipped => log?.action == MedicationAction.skipped;
  bool get isPending => log == null;
  bool get isSnoozed => isPending && snooze != null;
  bool get isWaitingSnooze => isSnoozed && snooze!.isActiveAt(DateTime.now());
}

class MedicationProvider extends ChangeNotifier {
  final StorageService _storageService;
  final NotificationService _notificationService;

  List<MedicationItem> _medications = [];
  List<MedicationLog> _logs = [];
  List<MedicationSnooze> _snoozes = [];
  StreamSubscription<NotificationResponse>? _notifActionSub;

  MedicationProvider(this._storageService, this._notificationService) {
    _loadFromStorage();
    _notifActionSub =
        _notificationService.actionResponseStream.listen(_onNotificationAction);
  }

  @override
  void dispose() {
    _notifActionSub?.cancel();
    super.dispose();
  }

  List<MedicationItem> get medications => List.unmodifiable(_medications);
  List<MedicationLog> get logs => List.unmodifiable(_logs);
  List<MedicationSnooze> get snoozes => List.unmodifiable(_snoozes);

  List<MedicationSnooze> get activeSnoozes {
    final now = DateTime.now();
    final todayKey = MedicationSnooze.formatDateKey(now);
    return List.unmodifiable(
      _snoozes.where((s) => s.dateKey == todayKey || s.isActiveAt(now)),
    );
  }

  MedicationSnooze? snoozeForSlot(
    String medicationId,
    String timeString, [
    DateTime? date,
  ]) {
    final dateKey = MedicationSnooze.formatDateKey(date ?? DateTime.now());
    for (final s in _snoozes) {
      if (s.medicationId == medicationId &&
          s.timeString == timeString &&
          s.dateKey == dateKey) {
        return s;
      }
    }
    return null;
  }

  List<MedicationItem> get activeMedications =>
      _medications.where((m) => m.isActive).toList();

  List<MedicationItem> get lowStockMedications =>
      _medications.where((m) => m.isActive && m.isLowStock).toList();

  bool get hasLowStockWarnings => lowStockMedications.isNotEmpty;

  void _loadFromStorage() {
    final now = DateTime.now();
    final todayKey = MedicationSnooze.formatDateKey(now);
    _medications = _storageService.loadMedications();
    _logs = _storageService.loadMedicationLogs();
    _snoozes = _storageService
        .loadMedicationSnoozes()
        .where((s) => s.dateKey == todayKey || s.isActiveAt(now))
        .toList();
    _scheduleUpcomingNotifications();
  }

  /// Syncs cached prefs written by background notification action isolates.
  Future<void> reloadFromStorage() async {
    await _storageService.reloadPrefs();
    _loadFromStorage();
    notifyListeners();
  }

  void _onNotificationAction(NotificationResponse response) {
    handleNotificationResponse(response);
  }

  /// Handles quick actions emitted from medication alerts (e.g. Snooze 15m).
  Future<bool> handleNotificationResponse(
    NotificationResponse response, {
    DateTime? nowOverride,
  }) async {
    if (response.actionId != NotificationService.actionMedicationSnooze15m) {
      return false;
    }
    final parsed = MedicationSnooze.parseDosePayload(response.payload);
    if (parsed == null) return false;

    final result = await snoozeDose(
      medicationId: parsed.medicationId,
      timeString: parsed.timeString,
      dismissNotificationId: response.id,
      nowOverride: nowOverride,
    );
    return result != null;
  }

  Future<void> _save() async {
    await _storageService.saveMedications(_medications);
    await _storageService.saveMedicationLogs(_logs);
    await _storageService.saveMedicationSnoozes(_snoozes);
    _scheduleUpcomingNotifications();
    notifyListeners();
  }

  // --- CRUD Operations ---

  Future<void> addMedication(MedicationItem medication) async {
    _medications.add(medication);
    await _save();
  }

  Future<void> updateMedication(MedicationItem medication) async {
    final index = _medications.indexWhere((m) => m.id == medication.id);
    if (index != -1) {
      _medications[index] = medication;
      await _save();
    }
  }

  Future<void> deleteMedication(String id) async {
    _clearNotificationsAndSnoozesForMed(id);
    _medications.removeWhere((m) => m.id == id);
    _logs.removeWhere((l) => l.medicationId == id);
    await _save();
  }

  Future<void> toggleActive(String id) async {
    final index = _medications.indexWhere((m) => m.id == id);
    if (index != -1) {
      final med = _medications[index];
      final nextActive = !med.isActive;
      _medications[index] = med.copyWith(isActive: nextActive);
      if (!nextActive) {
        _clearNotificationsAndSnoozesForMed(id);
      }
      await _save();
    }
  }

  void _clearNotificationsAndSnoozesForMed(String medicationId) {
    for (final s in _snoozes.where((s) => s.medicationId == medicationId)) {
      _notificationService.cancel(
        MedicationSnooze.snoozedDoseNotificationId(
          s.medicationId,
          s.timeString,
          s.dateKey,
        ),
      );
    }
    _snoozes.removeWhere((s) => s.medicationId == medicationId);

    final medIndex = _medications.indexWhere((m) => m.id == medicationId);
    if (medIndex != -1) {
      for (final timeStr in _medications[medIndex].scheduleTimes) {
        for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
          _notificationService.cancel(
            MedicationSnooze.regularDoseNotificationId(
              medicationId,
              timeStr,
              dayOffset,
            ),
          );
        }
      }
    }
  }

  // --- 1-Tap Take / Skip Logging ---

  Future<MedicationLog?> recordDose({
    required String medicationId,
    required String timeString,
    required MedicationAction action,
    String? reason,
    DateTime? actionTime,
    DateTime? targetDate,
  }) async {
    final index = _medications.indexWhere((m) => m.id == medicationId);
    if (index == -1) return null;

    final med = _medications[index];
    final now = targetDate ?? DateTime.now();
    final effectiveActionTime = actionTime ?? DateTime.now();

    // Parse timeString e.g. "08:00"
    final parts = timeString.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // Remove existing log for this exact dose slot on this date if present
    _logs.removeWhere((l) =>
        l.medicationId == medicationId &&
        l.scheduledTimeString == timeString &&
        l.scheduledDateTime.year == scheduledDate.year &&
        l.scheduledDateTime.month == scheduledDate.month &&
        l.scheduledDateTime.day == scheduledDate.day);

    final log = MedicationLog(
      id: const Uuid().v4(),
      medicationId: med.id,
      medicationName: med.name,
      doseAmount: med.dosageAmount,
      doseUnit: med.dosageUnit,
      scheduledTimeString: timeString,
      scheduledDateTime: scheduledDate,
      actionTime: effectiveActionTime,
      action: action,
      reason: reason,
    );

    _logs.add(log);

    // Clear any active snooze once a dose is logged as taken or skipped.
    final dateKey = MedicationSnooze.formatDateKey(scheduledDate);
    _snoozes.removeWhere((s) =>
        s.medicationId == medicationId &&
        s.timeString == timeString &&
        s.dateKey == dateKey);
    await _notificationService.cancel(
      MedicationSnooze.snoozedDoseNotificationId(
        medicationId,
        timeString,
        dateKey,
      ),
    );

    // Decrement stock if taken
    if (action == MedicationAction.taken && med.currentStock != null) {
      final decrement = med.dosageAmount.toInt().clamp(1, 100);
      final newStock = (med.currentStock! - decrement).clamp(0, 999999);
      _medications[index] = med.copyWith(currentStock: newStock);
    }

    await _save();
    return log;
  }

  Future<void> undoDose(String logId) async {
    final logIndex = _logs.indexWhere((l) => l.id == logId);
    if (logIndex == -1) return;

    final log = _logs[logIndex];
    final medIndex = _medications.indexWhere((m) => m.id == log.medicationId);

    // If taken, restore stock
    if (medIndex != -1 && log.action == MedicationAction.taken) {
      final med = _medications[medIndex];
      if (med.currentStock != null) {
        final restoredStock = med.currentStock! + med.dosageAmount.toInt().clamp(1, 100);
        _medications[medIndex] = med.copyWith(currentStock: restoredStock);
      }
    }

    _logs.removeAt(logIndex);
    await _save();
  }

  // --- 1-Tap Dose Time Snooze (15m default) ---

  bool _isSlotLoggedOnDate(
    String medicationId,
    String timeString,
    DateTime date,
  ) {
    return _logs.any((l) =>
        l.medicationId == medicationId &&
        l.scheduledTimeString == timeString &&
        l.scheduledDateTime.year == date.year &&
        l.scheduledDateTime.month == date.month &&
        l.scheduledDateTime.day == date.day);
  }

  /// Postpones a scheduled dose alert by [duration] (default 15 minutes) and
  /// schedules a follow-up reminder with the Snooze 15m notification action.
  Future<MedicationSnooze?> snoozeDose({
    required String medicationId,
    required String timeString,
    Duration duration = NotificationService.medicationSnoozeDuration,
    int? dismissNotificationId,
    DateTime? nowOverride,
  }) async {
    final medIndex = _medications.indexWhere((m) => m.id == medicationId);
    if (medIndex == -1 || !_medications[medIndex].isActive) return null;

    final now = nowOverride ?? DateTime.now();
    if (_isSlotLoggedOnDate(medicationId, timeString, now)) return null;

    final entry = await _notificationService.scheduleMedicationSnooze(
      med: _medications[medIndex],
      timeString: timeString,
      existingSnoozes: _snoozes,
      duration: duration,
      dismissNotificationId: dismissNotificationId,
      nowOverride: now,
    );

    _snoozes = MedicationSnooze.mergeAndPrune(_snoozes, entry, now);
    await _storageService.saveMedicationSnoozes(_snoozes);
    notifyListeners();
    return entry;
  }

  /// Dismisses an active snooze for the slot without logging Taken/Skipped.
  Future<void> cancelSnooze({
    required String medicationId,
    required String timeString,
    DateTime? targetDate,
  }) async {
    final dateKey =
        MedicationSnooze.formatDateKey(targetDate ?? DateTime.now());
    final hadEntry = _snoozes.any((s) =>
        s.medicationId == medicationId &&
        s.timeString == timeString &&
        s.dateKey == dateKey);
    if (!hadEntry) return;

    _snoozes.removeWhere((s) =>
        s.medicationId == medicationId &&
        s.timeString == timeString &&
        s.dateKey == dateKey);
    await _notificationService.cancel(
      MedicationSnooze.snoozedDoseNotificationId(
        medicationId,
        timeString,
        dateKey,
      ),
    );
    await _storageService.saveMedicationSnoozes(_snoozes);
    notifyListeners();
  }

  // --- Pill Refill Operations ---

  Future<void> refillMedication(String id, int addedQuantity) async {
    final index = _medications.indexWhere((m) => m.id == id);
    if (index != -1 && addedQuantity > 0) {
      final med = _medications[index];
      final current = med.currentStock ?? 0;
      _medications[index] = med.copyWith(currentStock: current + addedQuantity);
      await _save();
    }
  }

  // --- Today's Dose Slots & Progress ---

  List<TodayDoseSlot> get todayDoses => getDosesForDate(DateTime.now());

  List<TodayDoseSlot> getDosesForDate(DateTime date) {
    final slots = <TodayDoseSlot>[];

    for (final med in activeMedications) {
      if (!med.isScheduledForDate(date)) continue;

      for (final timeStr in med.scheduleTimes) {
        final parts = timeStr.split(':');
        final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
        final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        final scheduledDate = DateTime(date.year, date.month, date.day, hour, minute);

        final matchingLog = _logs.cast<MedicationLog?>().firstWhere(
              (l) =>
                  l != null &&
                  l.medicationId == med.id &&
                  l.scheduledTimeString == timeStr &&
                  l.scheduledDateTime.year == date.year &&
                  l.scheduledDateTime.month == date.month &&
                  l.scheduledDateTime.day == date.day,
              orElse: () => null,
            );

        slots.add(TodayDoseSlot(
          medication: med,
          timeString: timeStr,
          scheduledDateTime: scheduledDate,
          log: matchingLog,
          snooze: matchingLog == null ? snoozeForSlot(med.id, timeStr, date) : null,
        ));
      }
    }

    slots.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    return slots;
  }

  int get todayDosesTakenCount => todayDoses.where((d) => d.isTaken).length;
  int get todayDosesTotalCount => todayDoses.length;

  double get todayAdherenceFraction {
    if (todayDosesTotalCount == 0) return 1.0;
    return (todayDosesTakenCount / todayDosesTotalCount).clamp(0.0, 1.0);
  }

  // --- Adherence Streak Analytics ---

  /// Computes consecutive days backwards where scheduled doses were taken
  int get adherenceStreakDays {
    final now = DateTime.now();
    int streak = 0;

    // Check today first: if all today's scheduled doses so far are taken
    final todaySlots = getDosesForDate(now);
    final todayTaken = todaySlots.where((s) => s.isTaken).length;
    final todayPending = todaySlots.where((s) => s.isPending).length;

    // If today had scheduled doses and user took at least one without missing any past ones
    if (todaySlots.isNotEmpty && todayTaken > 0 && todayPending == 0) {
      streak++;
    }

    // Look back up to 365 days
    DateTime checkDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    for (int i = 0; i < 365; i++) {
      final slots = getDosesForDate(checkDate);
      if (slots.isEmpty) {
        // No medications scheduled on this day, keep streak alive
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

      final taken = slots.where((s) => s.isTaken).length;
      final total = slots.length;

      if (taken == total && total > 0) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break; // Streak broken
      }
    }

    return streak;
  }

  /// Weekly adherence percentage over the last 7 calendar days
  double get weeklyAdherenceRate {
    final now = DateTime.now();
    int totalScheduled = 0;
    int totalTaken = 0;

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final slots = getDosesForDate(date);
      totalScheduled += slots.length;
      totalTaken += slots.where((s) => s.isTaken).length;
    }

    if (totalScheduled == 0) return 1.0;
    return (totalTaken / totalScheduled).clamp(0.0, 1.0);
  }

  // --- Notification Scheduling ---

  void _scheduleUpcomingNotifications() {
    final now = DateTime.now();

    // Schedule notifications for today and tomorrow for active medications
    for (final med in activeMedications) {
      for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
        final targetDate = now.add(Duration(days: dayOffset));
        if (!med.isScheduledForDate(targetDate)) continue;

        for (int i = 0; i < med.scheduleTimes.length; i++) {
          final timeStr = med.scheduleTimes[i];
          final parts = timeStr.split(':');
          final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
          final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          final doseTime = DateTime(
              targetDate.year, targetDate.month, targetDate.day, hour, minute);

          // Only schedule if time is in the future
          if (doseTime.isAfter(now)) {
            if (_isSlotLoggedOnDate(med.id, timeStr, targetDate)) {
              continue;
            }
            if (dayOffset == 0 && snoozeForSlot(med.id, timeStr, now) != null) {
              continue;
            }
            final notificationId = MedicationSnooze.regularDoseNotificationId(
              med.id,
              timeStr,
              dayOffset,
            );

            final mealAdvice = med.mealInstruction != MealInstruction.anytime
                ? ' • ${med.mealInstruction.label}'
                : '';

            _notificationService.scheduleMedicationNotification(
              id: notificationId,
              title: '💊 Seren: Time for ${med.name}',
              body: 'Take ${med.dosageString}$mealAdvice. Stay consistent!',
              scheduledDate: doseTime,
              payload: MedicationSnooze.buildDosePayload(med.id, timeStr),
            );
          }
        }
      }
    }
  }
}

