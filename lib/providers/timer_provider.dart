import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/countdown_timer.dart';
import '../data/services/storage_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/audio_service.dart';

class TimerProvider extends ChangeNotifier {
  final StorageService _storageService;
  final NotificationService _notificationService;
  final AudioService _audioService;

  List<CountdownTimer> _timers = [];
  Timer? _ticker;

  TimerProvider(
    this._storageService,
    this._notificationService,
    this._audioService,
  ) {
    _loadTimers();
    _startTicker();
  }

  List<CountdownTimer> get timers => List.unmodifiable(_timers);
  List<CountdownTimer> get activeRunningTimers =>
      _timers.where((t) => t.isRunning).toList();

  void _loadTimers() {
    _timers = _storageService.loadTimers();
    if (_timers.isEmpty) {
      _timers = [
        CountdownTimer(
          id: const Uuid().v4(),
          label: 'Pomodoro Sprint',
          totalSeconds: 25 * 60,
          remainingSeconds: 25 * 60,
        ),
        CountdownTimer(
          id: const Uuid().v4(),
          label: 'French Press Coffee',
          totalSeconds: 4 * 60,
          remainingSeconds: 4 * 60,
        ),
        CountdownTimer(
          id: const Uuid().v4(),
          label: 'Power Nap',
          totalSeconds: 20 * 60,
          remainingSeconds: 20 * 60,
        ),
      ];
      _save();
    }
  }

  Future<void> _save() async {
    await _storageService.saveTimers(_timers);
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      bool stateChanged = false;

      for (int i = 0; i < _timers.length; i++) {
        final t = _timers[i];
        if (t.isRunning && !t.isPaused) {
          final nextRem = t.remainingSeconds - 1;

          if (nextRem <= 0) {
            _timers[i] = t.copyWith(
              remainingSeconds: 0,
              isRunning: false,
              isPaused: false,
            );
            stateChanged = true;
            _onTimerFinished(_timers[i]);
          } else {
            _timers[i] = t.copyWith(remainingSeconds: nextRem);
            stateChanged = true;
          }
        }
      }

      if (stateChanged) {
        notifyListeners();
      }
    });
  }

  void _onTimerFinished(CountdownTimer timer) {
    _audioService.previewTone('bell_chime', 1.0);
    _notificationService.showTimerCompleteNotification(
      id: timer.id.hashCode,
      title: 'Timer Done: ${timer.label}',
      body: 'Your countdown of ${timer.formattedTotal()} is complete!',
    );
  }

  Future<void> addTimer(String label, int totalSeconds) async {
    final timer = CountdownTimer(
      id: const Uuid().v4(),
      label: label.isEmpty ? 'Timer' : label,
      totalSeconds: totalSeconds,
      remainingSeconds: totalSeconds,
    );
    _timers.add(timer);
    await _save();
  }

  Future<void> startTimer(String id) async {
    final index = _timers.indexWhere((t) => t.id == id);
    if (index != -1) {
      _timers[index] = _timers[index].copyWith(
        isRunning: true,
        isPaused: false,
        startedAt: DateTime.now(),
      );
      await _save();
    }
  }

  Future<void> pauseTimer(String id) async {
    final index = _timers.indexWhere((t) => t.id == id);
    if (index != -1) {
      _timers[index] = _timers[index].copyWith(
        isRunning: true,
        isPaused: true,
      );
      await _save();
    }
  }

  Future<void> resumeTimer(String id) async {
    final index = _timers.indexWhere((t) => t.id == id);
    if (index != -1) {
      _timers[index] = _timers[index].copyWith(
        isRunning: true,
        isPaused: false,
      );
      await _save();
    }
  }

  Future<void> resetTimer(String id) async {
    final index = _timers.indexWhere((t) => t.id == id);
    if (index != -1) {
      final t = _timers[index];
      _timers[index] = t.copyWith(
        remainingSeconds: t.totalSeconds,
        isRunning: false,
        isPaused: false,
      );
      await _save();
    }
  }

  Future<void> deleteTimer(String id) async {
    _timers.removeWhere((t) => t.id == id);
    await _save();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

