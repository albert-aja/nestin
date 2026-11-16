import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/l10n/app_localizations.dart';
import '../data/models/journal_entry.dart';
import '../data/models/seren_relaxation_models.dart';
import '../data/services/ambient_sound_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/seren_tts_service.dart';
import '../data/services/storage_service.dart';
import 'journal_provider.dart';

class SerenRelaxationProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  final StorageService _storageService;
  final NotificationService? _notificationService;
  final AmbientSoundService _ambientSoundService;
  final SerenTtsService _ttsService;

  late SerenRelaxationPreferences _prefs;
  RelaxationTimeOfDayMode _timeOfDayMode = RelaxationTimeOfDayMode.anytime;
  late RelaxationPlaybackMode _playbackMode;

  // Multi-track mixer state
  List<SoundMixerTrackConfig> _activeTracks = [
    const SoundMixerTrackConfig(
      soundId: 'rain',
      volume: 0.70,
      distance: SoundDistance.balanced,
      stereoPosition: StereoPosition.center,
    ),
  ];
  bool _isMixerPlaying = false;
  String? _activeSoundscapeId;

  // Playback / Sleep Timer state
  Timer? _playbackTimer;
  int _timerTotalSeconds = 0;
  int _timerRemainingSeconds = 0;
  DateTime? _timerEndTime;
  double _fadeMultiplier = 1.0;

  // Guided Relaxation & Breathing state
  GuidedRelaxationSession? _activeGuidedSession;
  bool _isGuidedSessionRunning = false;
  bool _isGuidedSessionPaused = false;
  int _guidedDurationMinutes = 3;
  int _guidedElapsedSeconds = 0;
  int _guidedPhaseIndex = 0;
  int _guidedPhaseSecondsRemaining = 4;
  int _guidedCompletedCycles = 0;
  bool _guidedNarrationEnabled = false;
  Timer? _guidedTimer;

  // Visual Scene state
  String _activeVisualId = 'rainyWindow';

  // Reading & TTS state
  RelaxationReadingItem? _activeReading;
  int _selectedParagraphIndex = 0;
  final Set<String> _skippedMindfulPromptIds = {};

  // Hardware audio route disconnect guard & native OS media session state
  AudioRouteDisconnectEvent? _lastRouteDisconnectEvent;
  bool _pausedByHardwareDisconnect = false;
  DateTime? _lastRouteDisconnectHandledAt;
  bool _isMediaSessionPinned = false;
  bool _isDisposed = false;

  static const int morningReminderNotificationId = 7250;
  static const int eveningReminderNotificationId = 7251;

  SerenRelaxationProvider(
    this._storageService, {
    NotificationService? notificationService,
    AmbientSoundService? ambientSoundService,
    SerenTtsService? ttsService,
  })  : _notificationService = notificationService,
        _ambientSoundService = ambientSoundService ?? AmbientSoundService(),
        _ttsService = ttsService ?? SerenTtsService() {
    _load();
    _ttsService.onStateChanged = _onTtsStateChanged;
    _ttsService.onAllParagraphsCompleted = _onTtsAllCompleted;
    _ttsService.onAudioRouteDisconnected = _handleNativeAudioRouteDisconnected;
    _ttsService.onMediaTransportAction = handleMediaTransportAction;
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  void _load() {
    _prefs = _storageService.loadSerenRelaxationPreferences();
    _playbackMode = _prefs.defaultPlaybackMode;
    _activeVisualId = _prefs.preferredVisualId;

    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      _timeOfDayMode = RelaxationTimeOfDayMode.morning;
    } else if (hour >= 19 || hour < 5) {
      _timeOfDayMode = RelaxationTimeOfDayMode.evening;
    } else {
      _timeOfDayMode = RelaxationTimeOfDayMode.anytime;
    }
  }

  // --- Getters ---
  SerenRelaxationPreferences get prefs => _prefs;
  RelaxationTimeOfDayMode get timeOfDayMode => _timeOfDayMode;
  RelaxationPlaybackMode get playbackMode => _playbackMode;
  List<SoundMixerTrackConfig> get activeTracks =>
      List.unmodifiable(_activeTracks);
  bool get isMixerPlaying => _isMixerPlaying;
  String? get activeSoundscapeId => _activeSoundscapeId;
  double get masterVolume => _prefs.masterVolume;
  double get narrationVolume => _prefs.narrationVolume;
  bool get duckAmbientDuringNarration => _prefs.duckAmbientDuringNarration;
  double get ttsSpeechRate => _prefs.ttsSpeechRate;
  String get ttsLanguageCode => _prefs.ttsLanguageCode;
  bool get lowMotionVisuals => _prefs.lowMotionVisuals;
  bool get autoFadeOut => _prefs.autoFadeOut;
  bool get pauseOnHeadphoneDisconnect => _prefs.pauseOnHeadphoneDisconnect;
  bool get lockScreenControlsEnabled => _prefs.lockScreenControlsEnabled;
  bool get pausedByHardwareDisconnect => _pausedByHardwareDisconnect;
  AudioRouteDisconnectEvent? get lastRouteDisconnectEvent =>
      _lastRouteDisconnectEvent;
  bool get isMediaSessionActive =>
      _prefs.lockScreenControlsEnabled &&
      _isMediaSessionPinned &&
      (_isMixerPlaying || _ttsService.isActive || _activeTracks.isNotEmpty);

  // Timer Getters
  bool get isTimerActive => _timerRemainingSeconds > 0;
  int get timerTotalSeconds => _timerTotalSeconds;
  int get timerRemainingSeconds => _timerRemainingSeconds;
  double get fadeMultiplier => _fadeMultiplier;

  String get formattedTimerRemaining {
    final mins = _timerRemainingSeconds ~/ 60;
    final secs = _timerRemainingSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Guided Session Getters
  GuidedRelaxationSession? get activeGuidedSession => _activeGuidedSession;
  bool get isGuidedSessionRunning => _isGuidedSessionRunning;
  bool get isGuidedSessionPaused => _isGuidedSessionPaused;
  int get guidedDurationMinutes => _guidedDurationMinutes;
  int get guidedElapsedSeconds => _guidedElapsedSeconds;
  int get guidedPhaseIndex => _guidedPhaseIndex;
  int get guidedPhaseSecondsRemaining => _guidedPhaseSecondsRemaining;
  int get guidedCompletedCycles => _guidedCompletedCycles;
  bool get guidedNarrationEnabled => _guidedNarrationEnabled;

  BreathingPhaseStep? get currentBreathingStep {
    final session = _activeGuidedSession;
    if (session == null || session.breathingSteps.isEmpty) return null;
    return session
        .breathingSteps[_guidedPhaseIndex % session.breathingSteps.length];
  }

  int get guidedRemainingSeconds {
    final total = _guidedDurationMinutes * 60;
    return (total - _guidedElapsedSeconds).clamp(0, total);
  }

  // Visual Getters
  String get activeVisualId => _activeVisualId;
  VisualEnvironmentScene get activeVisualScene =>
      SerenRelaxationCatalog.visualById(_activeVisualId);

  // Reading & TTS Getters
  RelaxationReadingItem? get activeReading => _activeReading;
  SerenTtsService get ttsService => _ttsService;
  bool get isTtsPlaying => _ttsService.isPlaying;
  bool get isTtsPaused => _ttsService.isPaused;
  int get currentReadingParagraphIndex => _ttsService.currentParagraphIndex;
  int get activeReadingParagraphIndex =>
      (_ttsService.isPlaying || _ttsService.isPaused)
          ? _ttsService.currentParagraphIndex
          : _selectedParagraphIndex;
  int get activeReadingChapterIndex {
    final item = _activeReading ?? SerenRelaxationCatalog.readings.first;
    return item.chapterIndexForParagraph(activeReadingParagraphIndex);
  }
  Set<String> get skippedMindfulPromptIds =>
      Set.unmodifiable(_skippedMindfulPromptIds);

  /// Effective ambient ducking factor when TTS narration is actively speaking.
  double get effectiveDuckFactor {
    if (_ttsService.isPlaying && _prefs.duckAmbientDuringNarration) {
      return 0.35;
    }
    return 1.0;
  }

  /// Computes the final effective volume for a mixer track including distance
  /// acoustic attenuation, master volume, TTS ducking, and sleep timer fade-out.
  double computeTrackEffectiveVolume(SoundMixerTrackConfig track) {
    return AmbientSoundService.computeEffectiveTrackVolume(
      track,
      masterVolume: _prefs.masterVolume,
      duckFactor: effectiveDuckFactor,
      fadeMultiplier: _fadeMultiplier,
    );
  }

  /// Filtered sounds based on optional category or time-of-day recommendation.
  List<AmbientSoundItem> soundsForCategory(AmbientSoundCategory? category) {
    if (category == null) return SerenRelaxationCatalog.sounds;
    return SerenRelaxationCatalog.sounds
        .where((s) => s.category == category)
        .toList();
  }

  List<AmbientSoundItem> get recommendedSoundsForCurrentMode {
    if (_timeOfDayMode == RelaxationTimeOfDayMode.anytime) {
      return SerenRelaxationCatalog.sounds;
    }
    return SerenRelaxationCatalog.sounds
        .where((s) =>
            s.recommendedFor == _timeOfDayMode ||
            s.recommendedFor == RelaxationTimeOfDayMode.anytime)
        .toList();
  }

  List<AmbientSoundItem> get favoriteSounds {
    return _prefs.favoriteSoundIds
        .map(SerenRelaxationCatalog.soundById)
        .toList();
  }

  List<AmbientSoundItem> get recentSounds {
    return _prefs.recentSoundIds
        .map(SerenRelaxationCatalog.soundById)
        .toList();
  }

  List<SavedSoundscape> get curatedPresets =>
      SerenRelaxationCatalog.curatedPresets;
  List<SavedSoundscape> get customSoundscapes => _prefs.customSoundscapes;

  // ===========================================================================
  // MODE & PERSONALIZATION CONTROLS
  // ===========================================================================

  void setTimeOfDayMode(RelaxationTimeOfDayMode mode) {
    _timeOfDayMode = mode;
    notifyListeners();
  }

  Future<void> setPlaybackMode(RelaxationPlaybackMode mode) async {
    _playbackMode = mode;
    _prefs = _prefs.copyWith(defaultPlaybackMode: mode);
    await _storageService.saveSerenRelaxationPreferences(_prefs);

    if (mode == RelaxationPlaybackMode.visualOnly && _isMixerPlaying) {
      await _ambientSoundService.pauseMixer();
      _isMixerPlaying = false;
    } else if (mode != RelaxationPlaybackMode.visualOnly &&
        _activeTracks.isNotEmpty &&
        _isMixerPlaying) {
      await _syncAudioEngine();
    }
    notifyListeners();
  }

  Future<void> setLowMotionVisuals(bool enabled) async {
    _prefs = _prefs.copyWith(lowMotionVisuals: enabled);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
  }

  Future<void> setAutoFadeOut(bool enabled) async {
    _prefs = _prefs.copyWith(autoFadeOut: enabled);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
  }

  // ===========================================================================
  // AMBIENT SOUND LIBRARY & MULTI-TRACK MIXER (FEATURES A & B)
  // ===========================================================================

  bool isSoundInMix(String soundId) {
    return _activeTracks.any((t) => t.soundId == soundId);
  }

  bool isSoundFavorite(String soundId) {
    return _prefs.favoriteSoundIds.contains(soundId);
  }

  Future<void> toggleFavoriteSound(String soundId) async {
    final current = List<String>.from(_prefs.favoriteSoundIds);
    if (current.contains(soundId)) {
      current.remove(soundId);
    } else {
      current.add(soundId);
    }
    _prefs = _prefs.copyWith(favoriteSoundIds: current);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
  }

  Future<void> _recordRecentSound(String soundId) async {
    final recent = List<String>.from(_prefs.recentSoundIds);
    recent.remove(soundId);
    recent.insert(0, soundId);
    if (recent.length > 8) {
      recent.removeRange(8, recent.length);
    }
    _prefs = _prefs.copyWith(recentSoundIds: recent);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
  }

  /// Starts playing a single sound immediately (1-tap quick play).
  Future<void> playSingleSound(String soundId) async {
    final item = SerenRelaxationCatalog.soundById(soundId);
    _activeTracks = [
      SoundMixerTrackConfig(
        soundId: soundId,
        volume: 0.75,
        distance: item.defaultDistance,
        stereoPosition: StereoPosition.center,
      ),
    ];
    _activeSoundscapeId = null;
    if (item.pairedVisualId != null) {
      _activeVisualId = item.pairedVisualId!;
    }
    if (_playbackMode == RelaxationPlaybackMode.visualOnly) {
      _playbackMode = RelaxationPlaybackMode.audioAndVisual;
    }
    _isMixerPlaying = true;
    _pausedByHardwareDisconnect = false;
    await _recordRecentSound(soundId);
    await _syncAudioEngine();
    notifyListeners();
  }

  /// Adds or removes a sound track from the active multi-track soundscape.
  Future<void> toggleTrackInMix(String soundId) async {
    final existingIdx = _activeTracks.indexWhere((t) => t.soundId == soundId);
    if (existingIdx >= 0) {
      if (_activeTracks.length > 1) {
        _activeTracks = List<SoundMixerTrackConfig>.from(_activeTracks)
          ..removeAt(existingIdx);
      } else {
        // Last track removed -> stop playback cleanly
        _activeTracks = [];
        _isMixerPlaying = false;
      }
    } else {
      final item = SerenRelaxationCatalog.soundById(soundId);
      final updated = List<SoundMixerTrackConfig>.from(_activeTracks);
      if (updated.length >= 6) {
        updated.removeAt(0);
      }
      updated.add(
        SoundMixerTrackConfig(
          soundId: soundId,
          volume: 0.65,
          distance: item.defaultDistance,
          stereoPosition: StereoPosition.center,
        ),
      );
      _activeTracks = updated;
      await _recordRecentSound(soundId);
    }
    _activeSoundscapeId = null;
    await _syncAudioEngine();
    notifyListeners();
  }

  Future<void> setTrackVolume(String soundId, double volume) async {
    final idx = _activeTracks.indexWhere((t) => t.soundId == soundId);
    if (idx < 0) return;
    final updated = List<SoundMixerTrackConfig>.from(_activeTracks);
    updated[idx] = updated[idx].copyWith(
      volume: volume.clamp(0.0, 1.0),
      isMuted: false,
    );
    _activeTracks = updated;
    await _ambientSoundService.applyMixerVolumes(
      _activeTracks,
      masterVolume: _prefs.masterVolume,
      duckFactor: effectiveDuckFactor,
      fadeMultiplier: _fadeMultiplier,
    );
    notifyListeners();
  }

  Future<void> toggleTrackMute(String soundId) async {
    final idx = _activeTracks.indexWhere((t) => t.soundId == soundId);
    if (idx < 0) return;
    final updated = List<SoundMixerTrackConfig>.from(_activeTracks);
    updated[idx] = updated[idx].copyWith(isMuted: !updated[idx].isMuted);
    _activeTracks = updated;
    await _ambientSoundService.applyMixerVolumes(
      _activeTracks,
      masterVolume: _prefs.masterVolume,
      duckFactor: effectiveDuckFactor,
      fadeMultiplier: _fadeMultiplier,
    );
    notifyListeners();
  }

  Future<void> setTrackDistance(String soundId, SoundDistance distance) async {
    final idx = _activeTracks.indexWhere((t) => t.soundId == soundId);
    if (idx < 0) return;
    final updated = List<SoundMixerTrackConfig>.from(_activeTracks);
    updated[idx] = updated[idx].copyWith(distance: distance);
    _activeTracks = updated;
    await _ambientSoundService.refreshTrackVariant(
      updated[idx],
      masterVolume: _prefs.masterVolume,
      isPlaying: _isMixerPlaying &&
          _playbackMode != RelaxationPlaybackMode.visualOnly,
      duckFactor: effectiveDuckFactor,
      fadeMultiplier: _fadeMultiplier,
    );
    notifyListeners();
  }

  Future<void> setTrackStereoPosition(
    String soundId,
    StereoPosition position,
  ) async {
    final idx = _activeTracks.indexWhere((t) => t.soundId == soundId);
    if (idx < 0) return;
    final updated = List<SoundMixerTrackConfig>.from(_activeTracks);
    updated[idx] = updated[idx].copyWith(stereoPosition: position);
    _activeTracks = updated;
    await _ambientSoundService.refreshTrackVariant(
      updated[idx],
      masterVolume: _prefs.masterVolume,
      isPlaying: _isMixerPlaying &&
          _playbackMode != RelaxationPlaybackMode.visualOnly,
      duckFactor: effectiveDuckFactor,
      fadeMultiplier: _fadeMultiplier,
    );
    notifyListeners();
  }

  /// Updates the per-track Warmth / Brightness equalizer curve (`-1.0 .. +1.0`).
  /// Set [commitAudio] to false while dragging a slider and true on release to
  /// avoid regenerating intermediate WAV buffers mid-drag.
  Future<void> setTrackToneWarmth(
    String soundId,
    double toneWarmth, {
    bool commitAudio = true,
  }) async {
    final idx = _activeTracks.indexWhere((t) => t.soundId == soundId);
    if (idx < 0) return;
    final updated = List<SoundMixerTrackConfig>.from(_activeTracks);
    updated[idx] = updated[idx].copyWith(toneWarmth: toneWarmth);
    _activeTracks = updated;
    notifyListeners();
    if (commitAudio) {
      await _ambientSoundService.refreshTrackVariant(
        updated[idx],
        masterVolume: _prefs.masterVolume,
        isPlaying: _isMixerPlaying &&
            _playbackMode != RelaxationPlaybackMode.visualOnly,
        duckFactor: effectiveDuckFactor,
        fadeMultiplier: _fadeMultiplier,
      );
    }
  }

  Future<void> setMasterVolume(double volume) async {
    _prefs = _prefs.copyWith(masterVolume: volume.clamp(0.0, 1.0));
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    await _ambientSoundService.applyMixerVolumes(
      _activeTracks,
      masterVolume: _prefs.masterVolume,
      duckFactor: effectiveDuckFactor,
      fadeMultiplier: _fadeMultiplier,
    );
    notifyListeners();
  }

  Future<void> toggleMixerPlayback() async {
    if (_isMixerPlaying) {
      await pauseMixerPlayback();
    } else {
      await startMixerPlayback();
    }
  }

  Future<void> startMixerPlayback() async {
    if (_activeTracks.isEmpty) {
      _activeTracks = [
        const SoundMixerTrackConfig(
          soundId: 'rain',
          volume: 0.70,
          distance: SoundDistance.balanced,
          stereoPosition: StereoPosition.center,
        ),
      ];
    }
    if (_playbackMode == RelaxationPlaybackMode.visualOnly) {
      _playbackMode = RelaxationPlaybackMode.audioAndVisual;
    }
    _isMixerPlaying = true;
    _pausedByHardwareDisconnect = false;
    _fadeMultiplier = 1.0;
    await _syncAudioEngine();
    notifyListeners();
  }

  Future<void> pauseMixerPlayback() async {
    _isMixerPlaying = false;
    await _ambientSoundService.pauseMixer();
    await _syncNativeMediaSession();
    notifyListeners();
  }

  Future<void> stopAllPlayback() async {
    _isMixerPlaying = false;
    _isMediaSessionPinned = false;
    cancelPlaybackTimer(notify: false);
    await _ambientSoundService.stopMixer();
    await _ttsService.stop();
    stopGuidedSession(notify: false);
    await _ttsService.clearMediaSession();
    notifyListeners();
  }

  Future<void> _syncAudioEngine() async {
    final shouldPlayAudio = _isMixerPlaying &&
        _playbackMode != RelaxationPlaybackMode.visualOnly &&
        _activeTracks.isNotEmpty;
    if (shouldPlayAudio) {
      _isMediaSessionPinned = true;
    } else if (_activeTracks.isEmpty && !_ttsService.isActive) {
      _isMediaSessionPinned = false;
    }
    await _ambientSoundService.syncMixerTracks(
      _activeTracks,
      masterVolume: _prefs.masterVolume,
      shouldPlay: shouldPlayAudio,
      duckFactor: effectiveDuckFactor,
      fadeMultiplier: _fadeMultiplier,
    );
    await _syncNativeMediaSession();
  }

  // ===========================================================================
  // CUSTOM SOUNDSCAPE MANAGEMENT (FEATURE B 5.4)
  // ===========================================================================

  Future<void> loadSoundscape(
    SavedSoundscape soundscape, {
    bool autoPlay = true,
  }) async {
    _activeTracks = List<SoundMixerTrackConfig>.from(soundscape.tracks);
    _activeSoundscapeId = soundscape.id;
    _prefs = _prefs.copyWith(masterVolume: soundscape.masterVolume);
    if (soundscape.pairedVisualId != null) {
      _activeVisualId = soundscape.pairedVisualId!;
    }
    for (final t in soundscape.tracks) {
      await _recordRecentSound(t.soundId);
    }
    if (autoPlay) {
      if (_playbackMode == RelaxationPlaybackMode.visualOnly) {
        _playbackMode = RelaxationPlaybackMode.audioAndVisual;
      }
      _isMixerPlaying = true;
      _pausedByHardwareDisconnect = false;
      _fadeMultiplier = 1.0;
    }
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    await _syncAudioEngine();
    notifyListeners();
  }

  Future<SavedSoundscape> saveCurrentMixAsSoundscape(
    String name, {
    RelaxationTimeOfDayMode? recommendedFor,
  }) async {
    final now = DateTime.now();
    final trimmed = name.trim().isEmpty
        ? AppLocalizations.current.tr('seren_default_custom_mix_name')
        : name.trim();
    final created = SavedSoundscape(
      id: 'custom_${const Uuid().v4()}',
      name: trimmed,
      tracks: List<SoundMixerTrackConfig>.from(_activeTracks),
      masterVolume: _prefs.masterVolume,
      pairedVisualId: _activeVisualId,
      recommendedFor: recommendedFor ?? _timeOfDayMode,
      isPreset: false,
      createdAt: now,
      updatedAt: now,
    );
    final updated = List<SavedSoundscape>.from(_prefs.customSoundscapes)
      ..insert(0, created);
    _prefs = _prefs.copyWith(customSoundscapes: updated);
    _activeSoundscapeId = created.id;
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
    return created;
  }

  Future<void> renameCustomSoundscape(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final list = List<SavedSoundscape>.from(_prefs.customSoundscapes);
    final idx = list.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(
      name: trimmed,
      clearNameKey: true,
      updatedAt: DateTime.now(),
    );
    _prefs = _prefs.copyWith(customSoundscapes: list);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
  }

  Future<void> updateCustomSoundscapeFromCurrentMix(String id) async {
    final list = List<SavedSoundscape>.from(_prefs.customSoundscapes);
    final idx = list.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(
      tracks: List<SoundMixerTrackConfig>.from(_activeTracks),
      masterVolume: _prefs.masterVolume,
      pairedVisualId: _activeVisualId,
      updatedAt: DateTime.now(),
    );
    _prefs = _prefs.copyWith(customSoundscapes: list);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
  }

  Future<SavedSoundscape> duplicateSoundscape(SavedSoundscape source) async {
    final now = DateTime.now();
    final copySuffix = AppLocalizations.current.tr('seren_copy_suffix');
    final copy = SavedSoundscape(
      id: 'custom_${const Uuid().v4()}',
      name: '${source.displayName} ($copySuffix)',
      tracks: List<SoundMixerTrackConfig>.from(source.tracks),
      masterVolume: source.masterVolume,
      pairedVisualId: source.pairedVisualId,
      recommendedFor: source.recommendedFor,
      isPreset: false,
      createdAt: now,
      updatedAt: now,
    );
    final list = List<SavedSoundscape>.from(_prefs.customSoundscapes)
      ..insert(0, copy);
    _prefs = _prefs.copyWith(customSoundscapes: list);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
    return copy;
  }

  Future<void> deleteCustomSoundscape(String id) async {
    final list = List<SavedSoundscape>.from(_prefs.customSoundscapes)
      ..removeWhere((s) => s.id == id);
    if (_activeSoundscapeId == id) {
      _activeSoundscapeId = null;
    }
    _prefs = _prefs.copyWith(customSoundscapes: list);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
  }

  // ===========================================================================
  // SLEEP & PLAYBACK TIMER WITH GRACEFUL FADE-OUT (FEATURE D)
  // ===========================================================================

  Future<void> startPlaybackTimer(int minutes) async {
    _playbackTimer?.cancel();
    final clampedMinutes = minutes.clamp(1, 360);
    _timerTotalSeconds = clampedMinutes * 60;
    _timerRemainingSeconds = _timerTotalSeconds;
    _timerEndTime = DateTime.now().add(Duration(seconds: _timerTotalSeconds));
    _fadeMultiplier = 1.0;

    _prefs = _prefs.copyWith(defaultTimerMinutes: clampedMinutes);
    await _storageService.saveSerenRelaxationPreferences(_prefs);

    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tickTimerSecond();
    });
    await _syncNativeMediaSession();
    notifyListeners();
  }

  /// Advances the timer by 1 second, applying smooth fade-out over the last 30s.
  Future<void> tickTimerSecond() async {
    if (_timerRemainingSeconds <= 0) return;
    _timerRemainingSeconds--;

    if (_timerRemainingSeconds <= 0) {
      _timerRemainingSeconds = 0;
      _fadeMultiplier = 0.0;
      _playbackTimer?.cancel();
      _playbackTimer = null;
      _timerEndTime = null;
      await stopAllPlayback();
      return;
    }

    if (_prefs.autoFadeOut && _timerRemainingSeconds <= 30) {
      _fadeMultiplier = (_timerRemainingSeconds / 30.0).clamp(0.05, 1.0);
      await _ambientSoundService.applyMixerVolumes(
        _activeTracks,
        masterVolume: _prefs.masterVolume,
        duckFactor: effectiveDuckFactor,
        fadeMultiplier: _fadeMultiplier,
      );
    } else {
      _fadeMultiplier = 1.0;
    }
    await _syncNativeMediaSession();
    notifyListeners();
  }

  void cancelPlaybackTimer({bool notify = true}) {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _timerTotalSeconds = 0;
    _timerRemainingSeconds = 0;
    _timerEndTime = null;
    _fadeMultiplier = 1.0;
    if (_isMixerPlaying) {
      _ambientSoundService.applyMixerVolumes(
        _activeTracks,
        masterVolume: _prefs.masterVolume,
        duckFactor: effectiveDuckFactor,
        fadeMultiplier: 1.0,
      );
    }
    if (notify) {
      _syncNativeMediaSession();
      notifyListeners();
    }
  }

  // ===========================================================================
  // GUIDED RELAXATION & BREATHING SESSIONS (FEATURE C)
  // ===========================================================================

  Future<void> startGuidedSession(
    GuidedRelaxationSession session, {
    int? durationMinutes,
    bool? withVoiceNarration,
    bool playRecommendedSound = false,
  }) async {
    _guidedTimer?.cancel();
    _activeGuidedSession = session;
    _guidedDurationMinutes = durationMinutes ?? session.defaultDurationMinutes;
    _guidedElapsedSeconds = 0;
    _guidedPhaseIndex = 0;
    _guidedCompletedCycles = 0;
    _guidedPhaseSecondsRemaining =
        session.breathingSteps.isNotEmpty ? session.breathingSteps.first.seconds : 4;
    _isGuidedSessionRunning = true;
    _isGuidedSessionPaused = false;
    if (withVoiceNarration != null) {
      _guidedNarrationEnabled = withVoiceNarration;
    }

    if (playRecommendedSound && session.recommendedSoundId != null) {
      await playSingleSound(session.recommendedSoundId!);
    }

    if (_guidedNarrationEnabled && session.localizedPrompts.isNotEmpty) {
      await _ttsService.speakParagraphs(
        session.localizedPrompts,
        rate: _prefs.ttsSpeechRate,
        volume: _prefs.narrationVolume,
        languageCode: _prefs.ttsLanguageCode,
      );
    }

    _guidedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tickGuidedSessionSecond();
    });
    notifyListeners();
  }

  void tickGuidedSessionSecond() {
    final session = _activeGuidedSession;
    if (session == null || !_isGuidedSessionRunning || _isGuidedSessionPaused) {
      return;
    }

    _guidedElapsedSeconds++;
    if (_guidedElapsedSeconds >= _guidedDurationMinutes * 60) {
      stopGuidedSession();
      return;
    }

    if (_guidedPhaseSecondsRemaining > 1) {
      _guidedPhaseSecondsRemaining--;
    } else if (session.breathingSteps.isNotEmpty) {
      _guidedPhaseIndex =
          (_guidedPhaseIndex + 1) % session.breathingSteps.length;
      if (_guidedPhaseIndex == 0) {
        _guidedCompletedCycles++;
      }
      _guidedPhaseSecondsRemaining =
          session.breathingSteps[_guidedPhaseIndex].seconds;
    }
    notifyListeners();
  }

  void pauseGuidedSession() {
    if (!_isGuidedSessionRunning) return;
    _isGuidedSessionPaused = true;
    if (_guidedNarrationEnabled) {
      _ttsService.pause();
    }
    notifyListeners();
  }

  void resumeGuidedSession() {
    if (!_isGuidedSessionRunning || !_isGuidedSessionPaused) return;
    _isGuidedSessionPaused = false;
    if (_guidedNarrationEnabled) {
      _ttsService.resume();
    }
    notifyListeners();
  }

  void stopGuidedSession({bool notify = true}) {
    _guidedTimer?.cancel();
    _guidedTimer = null;
    _isGuidedSessionRunning = false;
    _isGuidedSessionPaused = false;
    _guidedElapsedSeconds = 0;
    _guidedPhaseIndex = 0;
    if (_guidedNarrationEnabled) {
      _ttsService.stop();
    }
    if (notify) notifyListeners();
  }

  void setGuidedNarrationEnabled(bool enabled) {
    _guidedNarrationEnabled = enabled;
    notifyListeners();
  }

  // ===========================================================================
  // CALMING VISUALS & AUDIO+VISUAL PAIRING (FEATURES E & F)
  // ===========================================================================

  Future<void> selectVisualScene(
    String sceneId, {
    bool pairSuggestedAudio = false,
  }) async {
    final scene = SerenRelaxationCatalog.visualById(sceneId);
    _activeVisualId = scene.id;
    _prefs = _prefs.copyWith(preferredVisualId: scene.id);
    await _storageService.saveSerenRelaxationPreferences(_prefs);

    if (pairSuggestedAudio) {
      await playSingleSound(scene.pairedSoundId);
    } else {
      notifyListeners();
    }
  }

  // ===========================================================================
  // BEDTIME STORIES, RELAXATION READING & TTS (FEATURE G)
  // ===========================================================================

  bool isReadingBookmarked(String readingId) =>
      _prefs.bookmarkedReadingIds.contains(readingId);

  bool isReadingFavorite(String readingId) =>
      _prefs.favoriteReadingIds.contains(readingId);

  Future<void> toggleBookmarkReading(String readingId) async {
    final list = List<String>.from(_prefs.bookmarkedReadingIds);
    if (list.contains(readingId)) {
      list.remove(readingId);
    } else {
      list.add(readingId);
    }
    _prefs = _prefs.copyWith(bookmarkedReadingIds: list);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
  }

  Future<void> toggleFavoriteReading(String readingId) async {
    final list = List<String>.from(_prefs.favoriteReadingIds);
    if (list.contains(readingId)) {
      list.remove(readingId);
    } else {
      list.add(readingId);
    }
    _prefs = _prefs.copyWith(favoriteReadingIds: list);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
  }

  Future<void> openReadingItem(
    String readingId, {
    bool startTts = false,
    bool playPairedAmbient = false,
  }) async {
    final item = SerenRelaxationCatalog.readingById(readingId);
    _activeReading = item;

    final history = List<String>.from(_prefs.readingHistoryIds);
    history.remove(readingId);
    history.insert(0, readingId);
    if (history.length > 12) {
      history.removeRange(12, history.length);
    }
    _prefs = _prefs.copyWith(readingHistoryIds: history);
    await _storageService.saveSerenRelaxationPreferences(_prefs);

    if (playPairedAmbient) {
      await playSingleSound(item.pairedSoundId);
    }

    final savedParagraph = (_prefs.readingLastParagraphIndex[readingId] ?? 0)
        .clamp(0, (item.effectiveParagraphKeys.length - 1).clamp(0, 9999));
    _selectedParagraphIndex = savedParagraph;

    if (startTts) {
      await startReadingTts(item: item, startParagraph: savedParagraph);
    } else {
      notifyListeners();
    }
  }

  Future<void> startReadingTts({
    RelaxationReadingItem? item,
    int startParagraph = 0,
  }) async {
    final target = item ?? _activeReading ?? SerenRelaxationCatalog.readings.first;
    _activeReading = target;
    _selectedParagraphIndex = startParagraph;
    _pausedByHardwareDisconnect = false;
    _isMediaSessionPinned = true;
    await _ttsService.speakParagraphs(
      target.paragraphs,
      startIndex: startParagraph,
      rate: _prefs.ttsSpeechRate,
      volume: _prefs.narrationVolume,
      languageCode: _prefs.ttsLanguageCode,
    );
    await _applyNarrationDucking();
    await _syncNativeMediaSession();
    notifyListeners();
  }

  /// Jumps directly to [chapterIndex] of the active reading item, persisting
  /// progress and moving TTS narration if active or requested.
  Future<void> jumpToReadingChapter(
    int chapterIndex, {
    bool startTts = false,
  }) async {
    final target = _activeReading ?? SerenRelaxationCatalog.readings.first;
    _activeReading = target;
    final clampedChapter = chapterIndex.clamp(0, target.chapterCount - 1);
    final startParagraph = target.startParagraphIndexForChapter(clampedChapter);
    _selectedParagraphIndex = startParagraph;

    final map = Map<String, int>.from(_prefs.readingLastParagraphIndex);
    map[target.id] = startParagraph;
    _prefs = _prefs.copyWith(readingLastParagraphIndex: map);
    await _storageService.saveSerenRelaxationPreferences(_prefs);

    if (startTts || _ttsService.isPlaying || _ttsService.isPaused) {
      await startReadingTts(item: target, startParagraph: startParagraph);
    } else {
      notifyListeners();
    }
  }

  Future<void> nextReadingChapter() async {
    final target = _activeReading ?? SerenRelaxationCatalog.readings.first;
    final nextIdx = activeReadingChapterIndex + 1;
    if (nextIdx < target.chapterCount) {
      await jumpToReadingChapter(nextIdx);
    }
  }

  Future<void> previousReadingChapter() async {
    final prevIdx = activeReadingChapterIndex - 1;
    if (prevIdx >= 0) {
      await jumpToReadingChapter(prevIdx);
    }
  }

  Future<void> pauseReadingTts() async {
    await _ttsService.pause();
    await _applyNarrationDucking();
    await _syncNativeMediaSession();
    notifyListeners();
  }

  Future<void> resumeReadingTts() async {
    _pausedByHardwareDisconnect = false;
    _isMediaSessionPinned = true;
    await _ttsService.resume();
    await _applyNarrationDucking();
    await _syncNativeMediaSession();
    notifyListeners();
  }

  Future<void> stopReadingTts() async {
    await _ttsService.stop();
    if (!_isMixerPlaying) {
      _isMediaSessionPinned = false;
    }
    await _applyNarrationDucking();
    await _syncNativeMediaSession();
    notifyListeners();
  }

  Future<void> nextReadingParagraph() async {
    await _ttsService.nextParagraph();
    _selectedParagraphIndex = _ttsService.currentParagraphIndex;
    _saveReadingParagraphProgress();
    notifyListeners();
  }

  Future<void> previousReadingParagraph() async {
    await _ttsService.previousParagraph();
    _selectedParagraphIndex = _ttsService.currentParagraphIndex;
    _saveReadingParagraphProgress();
    notifyListeners();
  }

  Future<void> setTtsSpeechRate(double rate) async {
    final clamped = rate.clamp(0.5, 1.5);
    _prefs = _prefs.copyWith(ttsSpeechRate: clamped);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    await _ttsService.setSpeechRate(clamped);
    notifyListeners();
  }

  Future<void> setNarrationVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _prefs = _prefs.copyWith(narrationVolume: clamped);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    await _ttsService.setVolume(clamped);
    notifyListeners();
  }

  Future<void> setDuckAmbientDuringNarration(bool enabled) async {
    _prefs = _prefs.copyWith(duckAmbientDuringNarration: enabled);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    await _applyNarrationDucking();
    notifyListeners();
  }

  Future<void> setTtsLanguageCode(String code) async {
    _prefs = _prefs.copyWith(ttsLanguageCode: code);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    await _ttsService.setLanguageCode(code);
    notifyListeners();
  }

  void _onTtsStateChanged() {
    if (_isDisposed) return;
    _selectedParagraphIndex = _ttsService.currentParagraphIndex;
    _saveReadingParagraphProgress();
    _applyNarrationDucking();
    _syncNativeMediaSession();
    notifyListeners();
  }

  void _onTtsAllCompleted() {
    if (_isDisposed) return;
    if (!_isMixerPlaying) {
      _isMediaSessionPinned = false;
    }
    _applyNarrationDucking();
    _syncNativeMediaSession();
    notifyListeners();
  }

  Future<void> _applyNarrationDucking() async {
    if (!_isMixerPlaying) return;
    await _ambientSoundService.applyMixerVolumes(
      _activeTracks,
      masterVolume: _prefs.masterVolume,
      duckFactor: effectiveDuckFactor,
      fadeMultiplier: _fadeMultiplier,
    );
  }

  void _saveReadingParagraphProgress() {
    final reading = _activeReading;
    if (reading == null) return;
    final map = Map<String, int>.from(_prefs.readingLastParagraphIndex);
    map[reading.id] = _ttsService.currentParagraphIndex;
    _prefs = _prefs.copyWith(readingLastParagraphIndex: map);
    _storageService.saveSerenRelaxationPreferences(_prefs);
  }

  // ===========================================================================
  // MINDFUL ACTIVITIES & ECHO JOURNAL INTEGRATION (FEATURE H)
  // ===========================================================================

  void skipMindfulPrompt(String promptId) {
    _skippedMindfulPromptIds.add(promptId);
    notifyListeners();
  }

  void resetSkippedMindfulPrompts() {
    _skippedMindfulPromptIds.clear();
    notifyListeners();
  }

  Future<JournalEntry> saveMindfulReflectionToJournal({
    required MindfulActivityPrompt prompt,
    required String responseText,
    required JournalProvider journalProvider,
  }) async {
    final now = DateTime.now();
    final trimmed = responseText.trim();
    final entry = JournalEntry(
      id: const Uuid().v4(),
      title: prompt.title,
      content: trimmed,
      date: now,
      mood: JournalMood.good,
      tags: ['Seren', 'Mindful', prompt.journalTag],
      gratitudeNote: prompt.storesGratitudePebble ? trimmed : null,
      isPrivate: false,
      createdAt: now,
      updatedAt: now,
    );
    await journalProvider.addJournalEntry(entry);
    notifyListeners();
    return entry;
  }

  // ===========================================================================
  // OPTIONAL MORNING & EVENING GENTLE REMINDERS (FEATURE I)
  // ===========================================================================

  Future<void> setMorningGentleReminder(bool enabled) async {
    _prefs = _prefs.copyWith(morningGentleReminderEnabled: enabled);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    if (_notificationService != null) {
      if (enabled) {
        final now = DateTime.now();
        var target = DateTime(now.year, now.month, now.day, 7, 30);
        if (!target.isAfter(now)) {
          target = target.add(const Duration(days: 1));
        }
        final l10n = AppLocalizations.current;
        await _notificationService.scheduleWellnessNotification(
          id: morningReminderNotificationId,
          title: l10n.tr('seren_morning_peace_notif_title'),
          body: l10n.tr('seren_morning_peace_notif_body'),
          scheduledDate: target,
          payload: 'seren_morning_peace',
        );
      } else {
        await _notificationService.cancel(morningReminderNotificationId);
      }
    }
    notifyListeners();
  }

  Future<void> setEveningUnwindReminder(bool enabled) async {
    _prefs = _prefs.copyWith(eveningUnwindReminderEnabled: enabled);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    if (_notificationService != null) {
      if (enabled) {
        final now = DateTime.now();
        var target = DateTime(now.year, now.month, now.day, 21, 30);
        if (!target.isAfter(now)) {
          target = target.add(const Duration(days: 1));
        }
        final l10n = AppLocalizations.current;
        await _notificationService.scheduleWellnessNotification(
          id: eveningReminderNotificationId,
          title: l10n.tr('seren_evening_unwind_notif_title'),
          body: l10n.tr('seren_evening_unwind_notif_body'),
          scheduledDate: target,
          payload: 'seren_evening_unwind',
        );
      } else {
        await _notificationService.cancel(eveningReminderNotificationId);
      }
    }
    notifyListeners();
  }

  // ===========================================================================
  // NATIVE OS MEDIASTYLE NOTIFICATION & LOCK-SCREEN TRANSPORT CONTROLS
  // ===========================================================================

  Future<void> setLockScreenControlsEnabled(bool enabled) async {
    _prefs = _prefs.copyWith(lockScreenControlsEnabled: enabled);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    if (!enabled) {
      await _ttsService.clearMediaSession();
    } else {
      await _syncNativeMediaSession();
    }
    notifyListeners();
  }

  /// Builds the current lock-screen & MediaSession metadata snapshot.
  SerenMediaTransportState get currentMediaTransportState {
    final l10n = AppLocalizations.current;
    final active = isMediaSessionActive;
    final playing = _isMixerPlaying || _ttsService.isPlaying;

    String title;
    String subtitle;

    if (_ttsService.isActive && _activeReading != null) {
      final reading = _activeReading!;
      title = reading.title;
      final mixNames = _activeTracks
          .map((t) => SerenRelaxationCatalog.soundById(t.soundId).title)
          .join(' + ');
      if (reading.isMultiChapter) {
        final chLabel = l10n
            .tr('seren_chapter_indicator')
            .replaceAll('{current}', '${activeReadingChapterIndex + 1}')
            .replaceAll('{total}', '${reading.chapterCount}');
        subtitle = mixNames.isNotEmpty ? '$chLabel • $mixNames' : chLabel;
      } else {
        subtitle = mixNames.isNotEmpty ? mixNames : reading.category.label;
      }
    } else {
      if (_activeSoundscapeId != null) {
        final allMixes = [...curatedPresets, ...customSoundscapes];
        final match =
            allMixes.where((s) => s.id == _activeSoundscapeId).toList();
        title = match.isNotEmpty
            ? match.first.displayName
            : l10n.tr('seren_screen_title');
      } else if (_activeTracks.length == 1) {
        title =
            SerenRelaxationCatalog.soundById(_activeTracks.first.soundId).title;
      } else {
        title = l10n.tr('seren_screen_title');
      }
      subtitle = _activeTracks.isNotEmpty
          ? _activeTracks
              .map((t) => SerenRelaxationCatalog.soundById(t.soundId).title)
              .join(' + ')
          : l10n.tr('seren_mixer_title');
    }

    final timerBadge = isTimerActive
        ? l10n
            .tr('seren_media_timer_remaining')
            .replaceAll('{time}', formattedTimerRemaining)
        : '';

    return SerenMediaTransportState(
      isActive: active,
      isPlaying: playing,
      title: title,
      subtitle: subtitle,
      album: l10n.tr('seren_media_session_album'),
      timerRemainingSeconds: _timerRemainingSeconds,
      timerTotalSeconds: _timerTotalSeconds,
      timerBadge: timerBadge,
      playActionLabel: l10n.tr('seren_media_action_play'),
      pauseActionLabel: l10n.tr('seren_media_action_pause'),
      stopActionLabel: l10n.tr('seren_media_action_stop'),
    );
  }

  Future<void> _syncNativeMediaSession() async {
    if (_isDisposed) return;
    if (!_prefs.lockScreenControlsEnabled) {
      await _ttsService.clearMediaSession();
      return;
    }
    final state = currentMediaTransportState;
    if (!state.isActive) {
      await _ttsService.clearMediaSession();
    } else {
      await _ttsService.syncMediaSession(state);
    }
  }

  /// Handles transport commands originating from Android `MediaSession` /
  /// `Notification.MediaStyle` or iOS `MPRemoteCommandCenter` lock-screen buttons.
  Future<void> handleMediaTransportAction(
    SerenMediaTransportAction action,
  ) async {
    if (_isDisposed) return;
    switch (action) {
      case SerenMediaTransportAction.play:
        if (_ttsService.isPaused) {
          await resumeReadingTts();
        }
        if (!_isMixerPlaying && _activeTracks.isNotEmpty) {
          await startMixerPlayback();
        }
        break;
      case SerenMediaTransportAction.pause:
        if (_isMixerPlaying) {
          await pauseMixerPlayback();
        }
        if (_ttsService.isPlaying) {
          await pauseReadingTts();
        }
        break;
      case SerenMediaTransportAction.togglePlayPause:
        final currentlyPlaying = _isMixerPlaying || _ttsService.isPlaying;
        if (currentlyPlaying) {
          await handleMediaTransportAction(SerenMediaTransportAction.pause);
        } else {
          await handleMediaTransportAction(SerenMediaTransportAction.play);
        }
        break;
      case SerenMediaTransportAction.stop:
        await stopAllPlayback();
        break;
      case SerenMediaTransportAction.next:
        if (_ttsService.isActive && _activeReading != null) {
          await nextReadingParagraph();
        } else if (curatedPresets.isNotEmpty) {
          final currentIdx = curatedPresets
              .indexWhere((p) => p.id == _activeSoundscapeId);
          final nextIdx = (currentIdx + 1) % curatedPresets.length;
          await loadSoundscape(curatedPresets[nextIdx]);
        }
        break;
      case SerenMediaTransportAction.previous:
        if (_ttsService.isActive && _activeReading != null) {
          await previousReadingParagraph();
        } else if (curatedPresets.isNotEmpty) {
          final currentIdx = curatedPresets
              .indexWhere((p) => p.id == _activeSoundscapeId);
          final prevIdx = currentIdx <= 0
              ? curatedPresets.length - 1
              : currentIdx - 1;
          await loadSoundscape(curatedPresets[prevIdx]);
        }
        break;
    }
  }

  // ===========================================================================
  // LIFECYCLE, INTERRUPTIONS & HEADPHONE DISCONNECT HANDLING (FEATURES 15 & 16)
  // ===========================================================================

  Future<void> setPauseOnHeadphoneDisconnect(bool enabled) async {
    _prefs = _prefs.copyWith(pauseOnHeadphoneDisconnect: enabled);
    await _storageService.saveSerenRelaxationPreferences(_prefs);
    notifyListeners();
  }

  void dismissHardwareDisconnectNotice() {
    if (!_pausedByHardwareDisconnect) return;
    _pausedByHardwareDisconnect = false;
    notifyListeners();
  }

  Future<void> _handleNativeAudioRouteDisconnected(
    AudioRouteDisconnectEvent event,
  ) async {
    if (_isDisposed || !_prefs.pauseOnHeadphoneDisconnect) return;

    final now = DateTime.now();
    if (_lastRouteDisconnectHandledAt != null &&
        now.difference(_lastRouteDisconnectHandledAt!).inMilliseconds < 400) {
      return;
    }
    _lastRouteDisconnectHandledAt = now;

    final wasActive = _isMixerPlaying ||
        _ttsService.isPlaying ||
        (_isGuidedSessionRunning && !_isGuidedSessionPaused);
    if (!wasActive) return;

    await handleAudioInterruption(disconnectEvent: event);
  }

  /// Handles incoming phone calls, audio focus loss, or headphone/Bluetooth unplugging
  /// by gracefully pausing active mixer and narration playback.
  Future<void> handleAudioInterruption({
    AudioRouteDisconnectEvent? disconnectEvent,
  }) async {
    if (_isDisposed) return;
    var didPauseAnything = false;
    if (_isMixerPlaying) {
      await pauseMixerPlayback();
      if (_isDisposed) return;
      didPauseAnything = true;
    }
    if (_ttsService.isPlaying) {
      await pauseReadingTts();
      if (_isDisposed) return;
      didPauseAnything = true;
    }
    if (_isGuidedSessionRunning && !_isGuidedSessionPaused) {
      pauseGuidedSession();
      didPauseAnything = true;
    }
    if (disconnectEvent != null && didPauseAnything && !_isDisposed) {
      _lastRouteDisconnectEvent = disconnectEvent;
      _pausedByHardwareDisconnect = true;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _timerEndTime != null) {
      final remaining = _timerEndTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _timerRemainingSeconds = 1;
        tickTimerSecond();
      } else {
        _timerRemainingSeconds = remaining;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _playbackTimer?.cancel();
    _guidedTimer?.cancel();
    _ambientSoundService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
