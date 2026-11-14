import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'roo_alarm_tone_service.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _rampTimer;
  bool _isPlaying = false;
  double _currentVolume = 0.0;

  bool get isPlaying => _isPlaying;
  double get currentVolume => _currentVolume;

  static const List<Map<String, String>> availableTones = [
    {'id': 'rooster_dawn', 'name': 'Roo Morning Crow (Default)'},
    {'id': 'rooster_crow', 'name': 'Roo Crisp Dawn Crow'},
    {'id': 'gentle_breeze', 'name': 'Gentle Breeze'},
    {'id': 'digital_pulse', 'name': 'Digital Pulse'},
    {'id': 'bell_chime', 'name': 'Temple Bell Chime'},
    {'id': 'energetic_beat', 'name': 'Energetic Rooster Beat'},
  ];

  AudioService() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  /// Starts playback with optional gradual volume increase
  Future<void> startAlarm({
    required String soundId,
    String? customFilePath,
    required double targetVolume,
    required bool gradualVolume,
    required int gradualDurationSeconds,
  }) async {
    await stop();

    _isPlaying = true;
    _player.setReleaseMode(ReleaseMode.loop);

    if (gradualVolume && gradualDurationSeconds > 0) {
      _currentVolume = 0.05;
      await _player.setVolume(_currentVolume);

      _playSelectedTone(soundId, customFilePath: customFilePath);

      final totalSteps = gradualDurationSeconds.clamp(5, 300);
      final stepIncrement = (targetVolume - 0.05) / totalSteps;
      int currentStep = 0;

      _rampTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!_isPlaying) {
          timer.cancel();
          return;
        }
        currentStep++;
        _currentVolume = (0.05 + stepIncrement * currentStep).clamp(0.0, targetVolume);
        await _player.setVolume(_currentVolume);

        if (currentStep >= totalSteps) {
          timer.cancel();
        }
      });
    } else {
      _currentVolume = targetVolume.clamp(0.0, 1.0);
      await _player.setVolume(_currentVolume);
      _playSelectedTone(soundId, customFilePath: customFilePath);
    }
  }

  void _playSelectedTone(String soundId, {String? customFilePath}) {
    try {
      if (customFilePath != null && File(customFilePath).existsSync()) {
        _player.play(DeviceFileSource(customFilePath)).catchError((_) {});
      } else {
        _player.play(AssetSource('sounds/$soundId.wav')).catchError((_) {
          RooAlarmToneService.getOrCreateToneFile(soundId).then((cachedPath) {
            if (cachedPath != null && File(cachedPath).existsSync()) {
              _player.play(DeviceFileSource(cachedPath)).catchError((_) {});
            }
          }).catchError((_) {});
        });
      }
    } catch (_) {}
  }

  /// Preview a tone for 4 seconds
  Future<void> previewTone(
    String soundId,
    double volume, {
    String? customFilePath,
  }) async {
    await stop();
    _isPlaying = true;
    try {
      await _player.setVolume(volume);
    } catch (_) {}
    _playSelectedTone(soundId, customFilePath: customFilePath);
    Timer(const Duration(seconds: 4), () {
      if (_isPlaying) stop();
    });
  }

  Future<void> stop() async {
    _rampTimer?.cancel();
    _rampTimer = null;
    _isPlaying = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    _rampTimer?.cancel();
    _player.dispose();
  }
}
