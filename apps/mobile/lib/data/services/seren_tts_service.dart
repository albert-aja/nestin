import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_localizations.dart';

/// Native platform Text-to-Speech (TTS) service for Seren Bedtime Stories,
/// Relaxation Reading, and Guided Relaxation narration (Feature G 10.1).
///
/// Uses platform MethodChannel (`com.nestin.app/tts`) backed by Android
/// `android.speech.tts.TextToSpeech` and iOS `AVSpeechSynthesizer` with a
/// resilient timer progression fallback for headless/test environments.
class SerenTtsService {
  static const MethodChannel _channel = MethodChannel('com.nestin.app/tts');

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
      final result = await _channel.invokeMethod<dynamic>('speak', {
        'text': text,
        'language': locale,
        'rate': _speechRate,
        'volume': _volume,
      });
      if (result is Map) {
        final supported = result['languageSupported'] as bool? ?? true;
        _isVoiceAvailable = supported;
        if (!supported) {
          _unavailableLanguageNoticeKey = 'seren_tts_voice_fallback_notice';
        }
      }
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
      await _channel.invokeMethod<void>('stop');
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
      await _channel.invokeMethod<void>('stop');
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
    if (_isPlaying || _isPaused) {
      try {
        _channel.invokeMethod<void>('stop').catchError((_) {});
      } catch (_) {}
    }
  }
}
