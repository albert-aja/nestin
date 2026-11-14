import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

enum AmbientSoundType {
  none,
  rain,
  coffeeShop,
  forest,
}

extension AmbientSoundTypeExtension on AmbientSoundType {
  String get label {
    switch (this) {
      case AmbientSoundType.none:
        return 'Silent (Off)';
      case AmbientSoundType.rain:
        return 'Rainfall';
      case AmbientSoundType.coffeeShop:
        return 'Coffee Shop';
      case AmbientSoundType.forest:
        return 'Forest Breeze';
    }
  }

  String get description {
    switch (this) {
      case AmbientSoundType.none:
        return 'Pure silence without ambient noise';
      case AmbientSoundType.rain:
        return 'Soothing drizzle and gentle drops';
      case AmbientSoundType.coffeeShop:
        return 'Warm cafe murmur and soft clinks';
      case AmbientSoundType.forest:
        return 'Gentle wind and peaceful birdsong';
    }
  }

  IconData get icon {
    switch (this) {
      case AmbientSoundType.none:
        return Icons.volume_off_rounded;
      case AmbientSoundType.rain:
        return Icons.water_drop_rounded;
      case AmbientSoundType.coffeeShop:
        return Icons.local_cafe_rounded;
      case AmbientSoundType.forest:
        return Icons.park_rounded;
    }
  }
}

class AmbientSoundService {
  final AudioPlayer _player = AudioPlayer();
  AmbientSoundType _currentType = AmbientSoundType.none;
  double _volume = 0.5;
  bool _isPlaying = false;
  final Map<AmbientSoundType, String> _generatedFiles = {};

  AmbientSoundType get currentType => _currentType;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;

  AmbientSoundService() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> play(AmbientSoundType type, {double? volume}) async {
    if (volume != null) _volume = volume;
    _currentType = type;

    if (type == AmbientSoundType.none) {
      await stop();
      return;
    }

    try {
      await _player.setVolume(_volume);
      final filePath = await _getOrCreateAudioFile(type);
      if (filePath != null && File(filePath).existsSync()) {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(DeviceFileSource(filePath));
        _isPlaying = true;
      }
    } catch (_) {
      // Ignored if headless / platform audio unsupported
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
  }

  Future<void> stop() async {
    _isPlaying = false;
    _currentType = AmbientSoundType.none;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> pause() async {
    _isPlaying = false;
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_currentType != AmbientSoundType.none) {
      try {
        await _player.resume();
        _isPlaying = true;
      } catch (_) {}
    }
  }

  Future<String?> _getOrCreateAudioFile(AmbientSoundType type) async {
    if (_generatedFiles.containsKey(type)) {
      final existing = _generatedFiles[type]!;
      if (File(existing).existsSync()) return existing;
    }

    try {
      Directory dir;
      try {
        dir = await getApplicationDocumentsDirectory()
            .timeout(const Duration(milliseconds: 100));
      } catch (_) {
        dir = Directory.systemTemp;
      }

      final ambientDir = Directory('${dir.path}/ambient_sounds');
      if (!ambientDir.existsSync()) {
        ambientDir.createSync(recursive: true);
      }

      final fileName = 'ambient_${type.name}.wav';
      final file = File('${ambientDir.path}/$fileName');
      if (file.existsSync() && file.lengthSync() > 1000) {
        _generatedFiles[type] = file.path;
        return file.path;
      }

      final bytes = synthesizeWavBytes(type);
      await file.writeAsBytes(bytes);
      _generatedFiles[type] = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Uint8List synthesizeWavBytes(AmbientSoundType type) {
    const sampleRate = 22050;
    const durationSeconds = 4;
    final totalSamples = sampleRate * durationSeconds;
    final rnd = Random(42);

    final pcmData = Int16List(totalSamples);

    switch (type) {
      case AmbientSoundType.rain:
        // Filtered pink noise with soft droplet burst spikes
        double b0 = 0, b1 = 0, b2 = 0;
        for (int i = 0; i < totalSamples; i++) {
          double white = rnd.nextDouble() * 2 - 1;
          b0 = 0.99765 * b0 + white * 0.0990460;
          b1 = 0.96300 * b1 + white * 0.2965164;
          b2 = 0.57000 * b2 + white * 1.0526913;
          double pink = b0 + b1 + b2 + white * 0.1848;

          if (rnd.nextDouble() < 0.003) {
            pink += (rnd.nextDouble() * 0.5);
          }
          pcmData[i] = (pink * 3200).clamp(-30000, 30000).toInt();
        }
        break;

      case AmbientSoundType.coffeeShop:
        // Low rumble murmurs + gentle occasional cup clink resonance
        double s0 = 0;
        for (int i = 0; i < totalSamples; i++) {
          double white = rnd.nextDouble() * 2 - 1;
          s0 = 0.985 * s0 + white * 0.015;
          double t = i / sampleRate.toDouble();
          double hum = sin(2 * pi * 130 * t) * 0.12 + sin(2 * pi * 240 * t) * 0.08;
          int cycle = i % 33000;
          double clink = 0.0;
          if (cycle < 600) {
            clink = sin(2 * pi * 2100 * (cycle / sampleRate)) * exp(-cycle / 90.0) * 0.25;
          }
          double combined = (s0 * 3.2 + hum + clink);
          pcmData[i] = (combined * 6500).clamp(-30000, 30000).toInt();
        }
        break;

      case AmbientSoundType.forest:
        // Soft wind modulating slowly + harmonious bird frequency chirps
        for (int i = 0; i < totalSamples; i++) {
          double t = i / sampleRate.toDouble();
          double wind = sin(2 * pi * 0.25 * t) * (rnd.nextDouble() * 0.18 + 0.08);

          double bird = 0.0;
          int cycle = i % (sampleRate * 2);
          if (cycle > 8000 && cycle < 11000) {
            double bt = (cycle - 8000) / sampleRate.toDouble();
            double freq = 2900 + 700 * sin(2 * pi * 14 * bt);
            bird = sin(2 * pi * freq * bt) * 0.3 * (1.0 - (cycle - 8000) / 3000.0);
          }

          double combined = wind + bird;
          pcmData[i] = (combined * 7500).clamp(-30000, 30000).toInt();
        }
        break;

      case AmbientSoundType.none:
        break;
    }

    final byteData = ByteData(44 + totalSamples * 2);
    // "RIFF"
    byteData.setUint8(0, 0x52);
    byteData.setUint8(1, 0x49);
    byteData.setUint8(2, 0x46);
    byteData.setUint8(3, 0x46);
    byteData.setUint32(4, 36 + totalSamples * 2, Endian.little);
    // "WAVE"
    byteData.setUint8(8, 0x57);
    byteData.setUint8(9, 0x41);
    byteData.setUint8(10, 0x56);
    byteData.setUint8(11, 0x45);
    // "fmt "
    byteData.setUint8(12, 0x66);
    byteData.setUint8(13, 0x6D);
    byteData.setUint8(14, 0x74);
    byteData.setUint8(15, 0x20);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    byteData.setUint16(32, 2, Endian.little); // BlockAlign
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample
    // "data"
    byteData.setUint8(36, 0x64);
    byteData.setUint8(37, 0x61);
    byteData.setUint8(38, 0x74);
    byteData.setUint8(39, 0x61);
    byteData.setUint32(40, totalSamples * 2, Endian.little);

    int offset = 44;
    for (int i = 0; i < totalSamples; i++) {
      byteData.setInt16(offset, pcmData[i], Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  void dispose() {
    _player.dispose();
  }
}
