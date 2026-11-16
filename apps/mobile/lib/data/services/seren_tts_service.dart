import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_localizations.dart';

/// Hardware audio route / Bluetooth codec disconnect payload received from
/// Android (`ACTION_AUDIO_BECOMING_NOISY` / `AudioDeviceCallback`) or iOS
/// (`AVAudioSession.routeChangeNotification` / `interruptionNotification`).
class AudioRouteDisconnectEvent {
  final String reason;
  final String routeType;
  final String? deviceName;
  final DateTime timestamp;

  AudioRouteDisconnectEvent({
    required this.reason,
    required this.routeType,
    this.deviceName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isBluetooth => routeType == 'bluetooth';
  bool get isWired => routeType == 'wired';

  String get noticeTranslationKey {
    if (isBluetooth) return 'seren_disconnect_notice_bluetooth';
    if (isWired) return 'seren_disconnect_notice_wired';
    return 'seren_disconnect_notice_generic';
  }
}

/// Transport actions dispatched from Android `MediaSession` / `Notification.MediaStyle`
/// or iOS `MPRemoteCommandCenter` / lock-screen controls.
enum SerenMediaTransportAction {
  play,
  pause,
  togglePlayPause,
  stop,
  next,
  previous,
}

/// Snapshot of active Seren playback state synced to native OS lock-screen controls.
class SerenMediaTransportState {
  final bool isActive;
  final bool isPlaying;
  final String title;
  final String subtitle;
  final String album;
  final int timerRemainingSeconds;
  final int timerTotalSeconds;
  final String timerBadge;
  final String playActionLabel;
  final String pauseActionLabel;
  final String stopActionLabel;

  const SerenMediaTransportState({
    required this.isActive,
    required this.isPlaying,
    required this.title,
    required this.subtitle,
    required this.album,
    this.timerRemainingSeconds = 0,
    this.timerTotalSeconds = 0,
    this.timerBadge = '',
    this.playActionLabel = 'Play',
    this.pauseActionLabel = 'Pause',
    this.stopActionLabel = 'Stop',
  });

  Map<String, dynamic> toMap() => {
        'isActive': isActive,
        'isPlaying': isPlaying,
        'title': title,
        'subtitle': subtitle,
        'album': album,
        'timerRemainingSeconds': timerRemainingSeconds,
        'timerTotalSeconds': timerTotalSeconds,
        'timerBadge': timerBadge,
        'playActionLabel': playActionLabel,
        'pauseActionLabel': pauseActionLabel,
        'stopActionLabel': stopActionLabel,
      };
}

/// Native platform Text-to-Speech (TTS) & Hardware Audio Route Listener service
/// for Seren Bedtime Stories, Relaxation Reading, and Soundscape Mixer.
///
/// Uses platform MethodChannel (`com.nestin.app/tts`) backed by Android
/// `android.speech.tts.TextToSpeech` + `AudioManager` and iOS
/// `AVSpeechSynthesizer` + `AVAudioSession`, with a resilient timer progression
/// fallback for headless/test environments.
class SerenTtsService {
  static const MethodChannel _channel = MethodChannel('com.nestin.app/tts');
  static SerenTtsService? _activeRouteOwner;

  bool _isPlaying = false;
  bool _isPaused = false;
  double _speechRate = 0.85;
  double _volume = 0.90;
  String _languageCode = 'auto';
  List<String> _paragraphs = const [];
  int _currentParagraphIndex = 0;
  bool _isVoiceAvailable = true;
  String? _unavailableLanguageNoticeKey;
  Timer? _paragraphTimer;
  VoidCallback? onStateChanged;
  VoidCallback? onAllParagraphsCompleted;
  FutureOr<void> Function(AudioRouteDisconnectEvent event)?
      onAudioRouteDisconnected;
  FutureOr<void> Function(SerenMediaTransportAction action)?
      onMediaTransportAction;

  SerenMediaTransportState? _lastSyncedMediaSession;
  int _mediaSessionSyncCount = 0;

  SerenMediaTransportState? get lastSyncedMediaSession =>
      _lastSyncedMediaSession;
  int get mediaSessionSyncCount => _mediaSessionSyncCount;

  SerenTtsService() {
    _registerAudioRouteMethodHandler();
  }

  void _registerAudioRouteMethodHandler() {
    _activeRouteOwner = this;
    try {
      _channel.setMethodCallHandler(handleNativeMethodCall);
    } catch (_) {
      // Safe when constructed before ServicesBinding is initialized in pure Dart unit tests
    }
  }

  static SerenMediaTransportAction? _parseTransportAction(String? raw) {
    switch (raw) {
      case 'play':
        return SerenMediaTransportAction.play;
      case 'pause':
        return SerenMediaTransportAction.pause;
      case 'togglePlayPause':
        return SerenMediaTransportAction.togglePlayPause;
      case 'stop':
        return SerenMediaTransportAction.stop;
      case 'next':
        return SerenMediaTransportAction.next;
      case 'previous':
        return SerenMediaTransportAction.previous;
      default:
        return null;
    }
  }

  /// Processes push callbacks from native Android/iOS over `com.nestin.app/tts`.
  @visibleForTesting
  Future<dynamic> handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onAudioRouteDisconnected') {
      final raw = call.arguments;
      final args = raw is Map ? raw : const <dynamic, dynamic>{};
      final event = AudioRouteDisconnectEvent(
        reason: args['reason']?.toString() ?? 'unknown',
        routeType: args['routeType']?.toString() ?? 'unknown',
        deviceName: args['deviceName']?.toString(),
      );
      await onAudioRouteDisconnected?.call(event);
      return true;
    }
    if (call.method == 'onMediaTransportAction') {
      final raw = call.arguments;
      final actionName =
          raw is Map ? raw['action']?.toString() : raw?.toString();
      final action = _parseTransportAction(actionName);
      if (action != null) {
        await onMediaTransportAction?.call(action);
        return true;
      }
      return false;
    }
    return null;
  }

  /// Synchronizes active Seren Soundscape Mixer & Story TTS state to native
  /// Android `MediaSession` (`Notification.MediaStyle`) and iOS `MPNowPlayingInfoCenter`.
  Future<void> syncMediaSession(SerenMediaTransportState state) async {
    _lastSyncedMediaSession = state;
    _mediaSessionSyncCount++;
    try {
      unawaited(
        _channel
            .invokeMethod<void>('syncMediaSession', state.toMap())
            .catchError((_) {}),
      );
    } catch (_) {}
  }

  /// Clears the native lock-screen notification and deactivates the media session.
  Future<void> clearMediaSession() async {
    _lastSyncedMediaSession = const SerenMediaTransportState(
      isActive: false,
      isPlaying: false,
      title: '',
      subtitle: '',
      album: '',
    );
    _mediaSessionSyncCount++;
    try {
      unawaited(
        _channel.invokeMethod<void>('clearMediaSession').catchError((_) {}),
      );
    } catch (_) {}
  }

  /// Queries native platform audio outputs for whether a wired or Bluetooth device is active.
  Future<bool?> isExternalAudioConnected() async {
    try {
      return await _channel.invokeMethod<bool>('isExternalAudioConnected');
    } catch (_) {
      return null;
    }
  }

  /// Optional fast progression duration for unit/widget tests.
  Duration? testParagraphDurationOverride;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isActive => _isPlaying || _isPaused;
  double get speechRate => _speechRate;
  double get volume => _volume;
  String get languageCode => _languageCode;
  int get currentParagraphIndex => _currentParagraphIndex;
  int get totalParagraphs => _paragraphs.length;
  bool get isVoiceAvailable => _isVoiceAvailable;
  String? get unavailableLanguageNoticeKey => _unavailableLanguageNoticeKey;

  double get progress {
    if (_paragraphs.isEmpty) return 0.0;
    return ((_currentParagraphIndex + 1) / _paragraphs.length).clamp(0.0, 1.0);
  }

  String resolveEffectiveLocaleCode() {
    if (_languageCode == 'en-US' || _languageCode == 'id-ID') {
      return _languageCode;
    }
    return AppLocalizations.currentLanguage == AppLanguage.id
        ? 'id-ID'
        : 'en-US';
  }

  /// Starts reading a list of paragraphs from [startIndex].
  Future<void> speakParagraphs(
    List<String> paragraphs, {
    int startIndex = 0,
    double? rate,
    double? volume,
    String? languageCode,
  }) async {
    _paragraphTimer?.cancel();
    if (paragraphs.isEmpty) return;

    if (rate != null) _speechRate = rate.clamp(0.5, 1.5);
    if (volume != null) _volume = volume.clamp(0.0, 1.0);
    if (languageCode != null) _languageCode = languageCode;

    _paragraphs = List<String>.unmodifiable(paragraphs);
    _currentParagraphIndex = startIndex.clamp(0, _paragraphs.length - 1);
    _isPlaying = true;
    _isPaused = false;
    _unavailableLanguageNoticeKey = null;
    onStateChanged?.call();

    await _speakCurrentParagraph();
  }

  Future<void> _speakCurrentParagraph() async {
    _paragraphTimer?.cancel();
    if (!_isPlaying || _isPaused || _paragraphs.isEmpty) return;
    if (_currentParagraphIndex < 0 ||
        _currentParagraphIndex >= _paragraphs.length) {
      await stop();
      onAllParagraphsCompleted?.call();
      return;
    }

    final text = _paragraphs[_currentParagraphIndex];
    final locale = resolveEffectiveLocaleCode();

    try {
      unawaited(
        _channel
            .invokeMethod<dynamic>('speak', {
              'text': text,
              'language': locale,
              'rate': _speechRate,
              'volume': _volume,
            })
            .then((result) {
              if (result is Map) {
                final supported = result['languageSupported'] as bool? ?? true;
                _isVoiceAvailable = supported;
                if (!supported) {
                  _unavailableLanguageNoticeKey =
                      'seren_tts_voice_fallback_notice';
                  onStateChanged?.call();
                }
              }
            })
            .catchError((_) {}),
      );
    } catch (_) {
      // Headless or test environment: keep _isVoiceAvailable true and rely on progression timer
    }

    // Estimate natural speaking duration for this paragraph based on word count & speech rate
    final Duration stepDuration;
    if (testParagraphDurationOverride != null) {
      stepDuration = testParagraphDurationOverride!;
    } else {
      final wordCount =
          text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final baseSeconds = ((wordCount / 2.4) / _speechRate).round().clamp(3, 45);
      stepDuration = Duration(seconds: baseSeconds);
    }

    _paragraphTimer = Timer(stepDuration, () {
      if (!_isPlaying || _isPaused) return;
      if (_currentParagraphIndex + 1 < _paragraphs.length) {
        _currentParagraphIndex++;
        onStateChanged?.call();
        _speakCurrentParagraph();
      } else {
        _isPlaying = false;
        _isPaused = false;
        onStateChanged?.call();
        onAllParagraphsCompleted?.call();
      }
    });
  }

  Future<void> pause() async {
    if (!_isPlaying) return;
    _paragraphTimer?.cancel();
    _isPlaying = false;
    _isPaused = true;
    try {
      unawaited(_channel.invokeMethod<void>('stop').catchError((_) {}));
    } catch (_) {}
    onStateChanged?.call();
  }

  Future<void> resume() async {
    if (!_isPaused || _paragraphs.isEmpty) return;
    _isPaused = false;
    _isPlaying = true;
    onStateChanged?.call();
    await _speakCurrentParagraph();
  }

  Future<void> stop() async {
    _paragraphTimer?.cancel();
    _paragraphTimer = null;
    _isPlaying = false;
    _isPaused = false;
    try {
      unawaited(_channel.invokeMethod<void>('stop').catchError((_) {}));
    } catch (_) {}
    onStateChanged?.call();
  }

  Future<void> nextParagraph() async {
    if (_paragraphs.isEmpty) return;
    if (_currentParagraphIndex + 1 < _paragraphs.length) {
      _currentParagraphIndex++;
      onStateChanged?.call();
      if (_isPlaying) {
        await _speakCurrentParagraph();
      }
    }
  }

  Future<void> previousParagraph() async {
    if (_paragraphs.isEmpty) return;
    if (_currentParagraphIndex > 0) {
      _currentParagraphIndex--;
      onStateChanged?.call();
      if (_isPlaying) {
        await _speakCurrentParagraph();
      }
    }
  }

  Future<void> jumpToParagraph(int index) async {
    if (_paragraphs.isEmpty) return;
    _currentParagraphIndex = index.clamp(0, _paragraphs.length - 1);
    onStateChanged?.call();
    if (_isPlaying) {
      await _speakCurrentParagraph();
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 1.5);
    onStateChanged?.call();
    if (_isPlaying) {
      await _speakCurrentParagraph();
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    onStateChanged?.call();
    if (_isPlaying) {
      await _speakCurrentParagraph();
    }
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    _unavailableLanguageNoticeKey = null;
    onStateChanged?.call();
    if (_isPlaying) {
      await _speakCurrentParagraph();
    }
  }

  void dispose() {
    _paragraphTimer?.cancel();
    if (_activeRouteOwner == this) {
      _activeRouteOwner = null;
      try {
        _channel.setMethodCallHandler(null);
      } catch (_) {}
    }
    if (_isPlaying || _isPaused) {
      try {
        _channel.invokeMethod<void>('stop').catchError((_) {});
      } catch (_) {}
    }
  }
}
