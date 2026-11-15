/// Clean decoupled interface allowing Roo's Pomodoro timer to request
/// Focus Lock activation, phase changes, pauses, and releases from the
/// Shared Restriction Engine without touching native device APIs directly.
abstract class FocusLockCoordinator {
  Future<void> onPomodoroFocusStarted({
    required String taskLabel,
    required String phase,
    required Duration remaining,
  });

  Future<void> onPomodoroFocusPhaseChanged({
    required String phase,
    required Duration remaining,
    required bool isPaused,
  });

  Future<void> onPomodoroFocusPaused();

  Future<void> onPomodoroFocusResumed({
    required Duration remaining,
  });

  Future<void> onPomodoroFocusEnded({
    required String reason,
  });
}
