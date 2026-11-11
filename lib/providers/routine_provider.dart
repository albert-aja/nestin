import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/routine_item.dart';
import '../data/services/storage_service.dart';

class RoutineProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<RoutineItem> _routines = [];

  RoutineProvider(this._storageService) {
    _loadRoutines();
  }

  List<RoutineItem> get routines => List.unmodifiable(_routines);

  void _loadRoutines() {
    _routines = _storageService.loadRoutines();
    final now = DateTime.now();

    if (_routines.isEmpty) {
      _routines = [
        RoutineItem(
          id: const Uuid().v4(),
          title: 'Morning Energizer',
          description: 'Start the day calm and focused',
          type: RoutineType.morning,
          steps: const [
            'Drink 500ml water',
            '5-minute light stretching',
            'Plan top 3 daily priorities',
            'Healthy balanced breakfast',
          ],
          completedStepIndices: const {0},
          streakCount: 3,
          lastCompletedDate: now.subtract(const Duration(days: 1)),
          createdAt: now,
        ),
        RoutineItem(
          id: const Uuid().v4(),
          title: 'Evening Wind-down',
          description: 'Prepare mind and body for restorative sleep',
          type: RoutineType.evening,
          steps: const [
            'Review completed tasks',
            'Set alarm and wake-up challenge',
            'Dim lights and screens 30m before bed',
            'Read 10 pages or gratitude note',
          ],
          completedStepIndices: const {},
          streakCount: 2,
          lastCompletedDate: now.subtract(const Duration(days: 1)),
          createdAt: now,
        ),
      ];
      _save();
    } else {
      // Check if day rolled over; if so, clear daily step indices
      bool needsSave = false;
      for (int i = 0; i < _routines.length; i++) {
        final r = _routines[i];
        if (r.lastCompletedDate != null) {
          final isSameDay = r.lastCompletedDate!.year == now.year &&
              r.lastCompletedDate!.month == now.month &&
              r.lastCompletedDate!.day == now.day;
          if (!isSameDay && r.completedStepIndices.isNotEmpty) {
            _routines[i] = r.copyWith(completedStepIndices: {});
            needsSave = true;
          }
        }
      }
      if (needsSave) _save();
    }
  }

  Future<void> _save() async {
    await _storageService.saveRoutines(_routines);
    notifyListeners();
  }

  Future<void> toggleStep(String routineId, int stepIndex) async {
    final index = _routines.indexWhere((r) => r.id == routineId);
    if (index != -1) {
      final r = _routines[index];
      final currentIndices = Set<int>.from(r.completedStepIndices);

      if (currentIndices.contains(stepIndex)) {
        currentIndices.remove(stepIndex);
      } else {
        currentIndices.add(stepIndex);
      }

      final now = DateTime.now();
      final allDone = currentIndices.length >= r.steps.length;
      final newStreak = allDone ? r.streakCount + 1 : r.streakCount;

      _routines[index] = r.copyWith(
        completedStepIndices: currentIndices,
        lastCompletedDate: allDone ? now : r.lastCompletedDate,
        streakCount: newStreak,
      );
      await _save();
    }
  }

  Future<void> addRoutine(RoutineItem routine) async {
    _routines.add(routine);
    await _save();
  }

  Future<void> deleteRoutine(String id) async {
    _routines.removeWhere((r) => r.id == id);
    await _save();
  }
}

