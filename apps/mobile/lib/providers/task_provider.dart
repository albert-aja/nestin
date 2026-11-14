import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/task_item.dart';
import '../data/models/alarm_category.dart';
import '../data/services/storage_service.dart';

class TaskProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<TaskItem> _tasks = [];

  TaskProvider(this._storageService) {
    _loadTasks();
  }

  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  List<TaskItem> get pendingTasks =>
      _tasks.where((t) => !t.isCompleted).toList()
        ..sort((a, b) => (a.dueDate ?? DateTime(2099))
            .compareTo(b.dueDate ?? DateTime(2099)));

  List<TaskItem> get completedTasks =>
      _tasks.where((t) => t.isCompleted).toList()
        ..sort((a, b) => (b.completedAt ?? DateTime.now())
            .compareTo(a.completedAt ?? DateTime.now()));

  List<TaskItem> tasksDueToday(DateTime now) {
    return _tasks.where((t) => !t.isCompleted && t.isDueToday(now)).toList();
  }

  List<TaskItem> overdueTasks(DateTime now) {
    return _tasks.where((t) => t.isOverdue(now)).toList();
  }

  void _loadTasks() {
    _tasks = _storageService.loadTasks();
    if (_tasks.isEmpty) {
      final now = DateTime.now();
      _tasks = [
        TaskItem(
          id: const Uuid().v4(),
          title: 'Organize Everyday Space Dashboard',
          notes: 'Customize widget layout and verify quick actions',
          dueDate: DateTime(now.year, now.month, now.day),
          dueTime: const TimeOfDay(hour: 15, minute: 0),
          priority: TaskPriority.high,
          category: AlarmCategory.fromType(AlarmCategoryType.work),
          subtasks: const [
            TaskSubItem(id: 's1', title: 'Verify Today cards', isCompleted: true),
            TaskSubItem(id: 's2', title: 'Check navigation tabs', isCompleted: false),
          ],
          hasReminder: true,
          createdAt: now,
        ),
        TaskItem(
          id: const Uuid().v4(),
          title: 'Grocery essentials run',
          notes: 'Fresh fruit, oats, and green tea',
          dueDate: DateTime(now.year, now.month, now.day),
          priority: TaskPriority.medium,
          category: AlarmCategory.fromType(AlarmCategoryType.personal),
          createdAt: now,
        ),
      ];
      _save();
    }
  }

  Future<void> _save() async {
    await _storageService.saveTasks(_tasks);
    notifyListeners();
  }

  Future<void> addTask(TaskItem task) async {
    _tasks.add(task);
    await _save();
  }

  Future<void> updateTask(TaskItem task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      await _save();
    }
  }

  Future<void> toggleTaskCompletion(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final current = _tasks[index];
      final willComplete = !current.isCompleted;
      _tasks[index] = current.copyWith(
        isCompleted: willComplete,
        completedAt: willComplete ? DateTime.now() : null,
        clearCompletedAt: !willComplete,
      );
      await _save();
    }
  }

  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      final updatedSubs = task.subtasks.map((s) {
        if (s.id == subtaskId) {
          return s.copyWith(isCompleted: !s.isCompleted);
        }
        return s;
      }).toList();

      _tasks[index] = task.copyWith(subtasks: updatedSubs);
      await _save();
    }
  }

  int indexOfTask(String id) => _tasks.indexWhere((t) => t.id == id);

  /// Restores a deleted or previously modified [task] snapshot at [index].
  Future<void> restoreTask(TaskItem task, {int? index}) async {
    final existingIndex = _tasks.indexWhere((t) => t.id == task.id);
    if (existingIndex != -1) {
      _tasks[existingIndex] = task;
    } else {
      final insertAt = (index ?? _tasks.length).clamp(0, _tasks.length);
      _tasks.insert(insertAt, task);
    }
    await _save();
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _save();
  }
}

