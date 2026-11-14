import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/countdown_timer.dart';
import '../data/models/focus_session_log.dart';
import '../data/services/storage_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/audio_service.dart';
import '../data/services/ambient_sound_service.dart';

class TimerProvider extends ChangeNotifier {
  final StorageService _storageService;
  final NotificationService _notificationService;
  final AudioService _audioService;
  final AmbientSoundService _ambientSoundService;

  // Regular Countdown Timers
  List<CountdownTimer> _timers = [];
  Timer? _ticker;

  // Pomodoro Focus Engine State
  FocusPhase _pomodoroPhase = FocusPhase.work;
  int _pomodoroCycle = 1; // 1 to 4
  int _pomodoroWorkDurationSeconds = 25 * 60;
  int _pomodoroShortBreakSeconds = 5 * 60;
  int _pomodoroLongBreakSeconds = 15 * 60;
  late int _pomodoroRemainingSeconds;
  bool _isPomodoroRunning = false;
  bool _isPomodoroPaused = false;
  String _pomodoroTaskLabel = 'Focus Sprint';
  AmbientSoundType _selectedAmbientSound = AmbientSoundType.none;
  double _ambientVolume = 0.5;

  // Focus History Logs
  List<FocusSessionLog> _focusLogs = [];

  TimerProvider(
    this._storageService,
    this._notificationService,
    this._audioService, [
    AmbientSoundService? ambientSoundService,
  ]) : _ambientSoundService = ambientSoundService ?? AmbientSoundService() {
    _pomodoroRemainingSeconds = _pomodoroWorkDurationSeconds;
    _loadTimers();
    _loadFocusLogs();
    _startTicker();
  }

  // --- Getters ---

  List<CountdownTimer> get timers => List.unmodifiable(_timers);
  List<CountdownTimer> get activeRunningTimers =>
      _timers.where((t) => t.isRunning).toList();

  // Pomodoro Getters
  FocusPhase get pomodoroPhase => _pomodoroPhase;
  int get pomodoroCycle => _pomodoroCycle;
  int get pomodoroRemainingSeconds => _pomodoroRemainingSeconds;
  bool get isPomodoroRunning => _isPomodoroRunning;
  bool get isPomodoroPaused => _isPomodoroPaused;
  String get pomodoroTaskLabel => _pomodoroTaskLabel;
  AmbientSoundType get selectedAmbientSound => _selectedAmbientSound;
  double get ambientVolume => _ambientVolume;
  AmbientSoundService get ambientSoundService => _ambientSoundService;

  int get pomodoroTotalSeconds {
    switch (_pomodoroPhase) {
      case FocusPhase.work:
        return _pomodoroWorkDurationSeconds;
      case FocusPhase.shortBreak:
        return _pomodoroShortBreakSeconds;
      case FocusPhase.longBreak:
        return _pomodoroLongBreakSeconds;
    }
  }

  double get pomodoroProgress {
    if (pomodoroTotalSeconds <= 0) return 0.0;
    return (_pomodoroRemainingSeconds / pomodoroTotalSeconds).clamp(0.0, 1.0);
  }

  String formattedPomodoroRemaining() {
    final m = _pomodoroRemainingSeconds ~/ 60;
    final s = _pomodoroRemainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // History & Metrics Getters
  List<FocusSessionLog> get focusLogs => List.unmodifiable(_focusLogs);

  int get todayFocusMinutes {
    final now = DateTime.now();
    return _focusLogs
        .where((l) =>
            l.phase == FocusPhase.work &&
            l.completedAt.year == now.year &&
            l.completedAt.month == now.month &&
            l.completedAt.day == now.day)
        .fold(0, (sum, item) => sum + item.durationMinutes);
  }

  int get todayCompletedPomodoros {
    final now = DateTime.now();
    return _focusLogs
        .where((l) =>
            l.phase == FocusPhase.work &&
            l.completedAt.year == now.year &&
            l.completedAt.month == now.month &&
            l.completedAt.day == now.day)
        .length;
  }

  int get totalCompletedPomodoros {
    return _focusLogs.where((l) => l.phase == FocusPhase.work).length;
  }

  int get totalFocusMinutes {
    return _focusLogs
        .where((l) => l.phase == FocusPhase.work)
        .fold(0, (sum, item) => sum + item.durationMinutes);
  }

  // --- Initial Loading ---

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

  void _loadFocusLogs() {
    _focusLogs = _storageService.loadFocusLogs();
  }

  Future<void> _save() async {
    await _storageService.saveTimers(_timers);
    notifyListeners();
  }

  // --- Unified 1-Second Ticker ---

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      bool stateChanged = false;

      // 1. Tick Countdown Timers
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

      // 2. Tick Pomodoro Focus Timer
      if (_isPomodoroRunning && !_isPomodoroPaused) {
        if (_pomodoroRemainingSeconds > 0) {
          _pomodoroRemainingSeconds--;
          stateChanged = true;
          if (_pomodoroRemainingSeconds <= 0) {
            _onPomodoroPhaseFinished();
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

  Future<void> _onPomodoroPhaseFinished() async {
    // Play bell chime
    _audioService.previewTone('bell_chime', 1.0);
    await _ambientSoundService.stop();

    if (_pomodoroPhase == FocusPhase.work) {
      // Record completed work session to log
      final durationMins = _pomodoroWorkDurationSeconds ~/ 60;
      final log = FocusSessionLog(
        id: const Uuid().v4(),
        taskLabel: _pomodoroTaskLabel,
        durationMinutes: durationMins,
        phase: FocusPhase.work,
        completedAt: DateTime.now(),
        ambientSoundUsed: _selectedAmbientSound != AmbientSoundType.none
            ? _selectedAmbientSound.name
            : null,
      );
      _focusLogs.insert(0, log);
      await _storageService.saveFocusLogs(_focusLogs);

      _notificationService.showTimerCompleteNotification(
        id: 7771,
        title: 'Work Sprint Complete! 🎉',
        body:
            'Finished $durationMins min of $_pomodoroTaskLabel. Take a well-earned break!',
      );

      // Advance to Break
      if (_pomodoroCycle >= 4) {
        _pomodoroPhase = FocusPhase.longBreak;
        _pomodoroRemainingSeconds = _pomodoroLongBreakSeconds;
        _pomodoroCycle = 1;
      } else {
        _pomodoroPhase = FocusPhase.shortBreak;
        _pomodoroRemainingSeconds = _pomodoroShortBreakSeconds;
      }
    } else {
      // Break completed
      _notificationService.showTimerCompleteNotification(
        id: 7772,
        title: 'Break Finished ⚡',
        body: 'Ready for cycle $_pomodoroCycle focus session?',
      );

      if (_pomodoroPhase == FocusPhase.shortBreak) {
        _pomodoroCycle++;
      }
      _pomodoroPhase = FocusPhase.work;
      _pomodoroRemainingSeconds = _pomodoroWorkDurationSeconds;
    }

    _isPomodoroRunning = false;
    _isPomodoroPaused = false;
    notifyListeners();
  }

  // --- Pomodoro User Actions ---

  Future<void> startPomodoro() async {
    _isPomodoroRunning = true;
    _isPomodoroPaused = false;
    if (_selectedAmbientSound != AmbientSoundType.none) {
      await _ambientSoundService.play(_selectedAmbientSound,
          volume: _ambientVolume);
    }
    notifyListeners();
  }

  Future<void> pausePomodoro() async {
    _isPomodoroPaused = true;
    await _ambientSoundService.pause();
    notifyListeners();
  }

  Future<void> resumePomodoro() async {
    _isPomodoroPaused = false;
    if (_selectedAmbientSound != AmbientSoundType.none) {
      await _ambientSoundService.resume();
    }
    notifyListeners();
  }

  Future<void> resetPomodoro() async {
    _isPomodoroRunning = false;
    _isPomodoroPaused = false;
    _pomodoroRemainingSeconds = pomodoroTotalSeconds;
    await _ambientSoundService.stop();
    notifyListeners();
  }

  Future<void> skipPomodoroPhase() async {
    await _ambientSoundService.stop();
    if (_pomodoroPhase == FocusPhase.work) {
      if (_pomodoroCycle >= 4) {
        _pomodoroPhase = FocusPhase.longBreak;
        _pomodoroRemainingSeconds = _pomodoroLongBreakSeconds;
        _pomodoroCycle = 1;
      } else {
        _pomodoroPhase = FocusPhase.shortBreak;
        _pomodoroRemainingSeconds = _pomodoroShortBreakSeconds;
      }
    } else {
      if (_pomodoroPhase == FocusPhase.shortBreak) {
        _pomodoroCycle++;
      }
      _pomodoroPhase = FocusPhase.work;
      _pomodoroRemainingSeconds = _pomodoroWorkDurationSeconds;
    }
    _isPomodoroRunning = false;
    _isPomodoroPaused = false;
    notifyListeners();
  }

  void setPomodoroTaskLabel(String label) {
    _pomodoroTaskLabel = label.trim().isEmpty ? 'Focus Sprint' : label.trim();
    notifyListeners();
  }

  Future<void> setAmbientSound(AmbientSoundType type) async {
    _selectedAmbientSound = type;
    if (_isPomodoroRunning && !_isPomodoroPaused) {
      await _ambientSoundService.play(type, volume: _ambientVolume);
    }
    notifyListeners();
  }

  Future<void> setAmbientVolume(double volume) async {
    _ambientVolume = volume.clamp(0.0, 1.0);
    await _ambientSoundService.setVolume(_ambientVolume);
    notifyListeners();
  }

  Future<void> setCustomPomodoroDurations({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
  }) async {
    if (workMinutes != null && workMinutes > 0) {
      _pomodoroWorkDurationSeconds = workMinutes * 60;
    }
    if (shortBreakMinutes != null && shortBreakMinutes > 0) {
      _pomodoroShortBreakSeconds = shortBreakMinutes * 60;
    }
    if (longBreakMinutes != null && longBreakMinutes > 0) {
      _pomodoroLongBreakSeconds = longBreakMinutes * 60;
    }

    if (!_isPomodoroRunning) {
      _pomodoroRemainingSeconds = pomodoroTotalSeconds;
    }
    notifyListeners();
  }

  Future<void> deleteFocusLog(String id) async {
    _focusLogs.removeWhere((l) => l.id == id);
    await _storageService.saveFocusLogs(_focusLogs);
    notifyListeners();
  }

  Future<void> clearFocusLogs() async {
    _focusLogs.clear();
    await _storageService.saveFocusLogs(_focusLogs);
    notifyListeners();
  }

  // --- Countdown Timers CRUD (Preserved) ---

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
    _ambientSoundService.dispose();
    super.dispose();
  }
}
