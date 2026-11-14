import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Service responsible for synthesizing and managing Roo's signature dawn crow
/// and built-in procedural alarm audio tones with zero external internet dependencies.
class RooAlarmToneService {
  static const String rooMorningCrowId = 'rooster_dawn';
  static const String rooDawnCrowAliasId = 'rooster_crow';

  static final Map<String, String> _cachedFilePaths = {};

  static const List<Map<String, String>> builtInTones = [
    {
      'id': 'rooster_dawn',
      'name': 'Roo Morning Crow (Default)',
      'description': 'Crisp dawn rooster crow with rich acoustic syrinx harmonics',
      'mascot': 'Roo',
    },
    {
      'id': 'rooster_crow',
      'name': 'Roo Crisp Dawn Crow',
      'description': 'High-energy dawn rooster wake-up cry with natural vibrato',
      'mascot': 'Roo',
    },
    {
      'id': 'gentle_breeze',
      'name': 'Seren Gentle Breeze',
      'description': 'Soothing morning breeze blended with soft acoustic chimes',
      'mascot': 'Seren',
    },
    {
      'id': 'digital_pulse',
      'name': 'Digital Pulse',
      'description': 'Crisp, modern digital wake-up cadence and rhythmic beeps',
      'mascot': 'Scout',
    },
    {
      'id': 'bell_chime',
      'name': 'Temple Bell Chime',
      'description': 'Deep acoustic singing bowl chime with peaceful resonant decay',
      'mascot': 'Echo',
    },
    {
      'id': 'energetic_beat',
      'name': 'Energetic Rooster Beat',
      'description': 'Upbeat rhythmic sunrise tempo with motivating synth melody',
      'mascot': 'Roo',
    },
  ];

  /// Resolves human-readable display title for any built-in tone
  static String getToneDisplayName(String toneId) {
    final match = builtInTones.firstWhere(
      (t) => t['id'] == toneId,
      orElse: () => {'name': 'Roo Morning Crow (Default)'},
    );
    return match['name'] ?? 'Roo Morning Crow (Default)';
  }

  /// Synthesizes or retrieves a cached local WAV file on disk for fallback playback
  static Future<String?> getOrCreateToneFile(String toneId) async {
    if (_cachedFilePaths.containsKey(toneId)) {
      final cached = _cachedFilePaths[toneId]!;
      if (File(cached).existsSync() && File(cached).lengthSync() > 1000) {
        return cached;
      }
    }

    try {
      Directory dir;
      try {
        dir = await getApplicationDocumentsDirectory()
            .timeout(const Duration(milliseconds: 150));
      } catch (_) {
        dir = Directory.systemTemp;
      }

      final tonesDir = Directory('${dir.path}/alarm_tones');
      if (!tonesDir.existsSync()) {
        tonesDir.createSync(recursive: true);
      }

      final targetFile = File('${tonesDir.path}/$toneId.wav');
      if (targetFile.existsSync() && targetFile.lengthSync() > 1000) {
        _cachedFilePaths[toneId] = targetFile.path;
        return targetFile.path;
      }

      final wavBytes = synthesizeToneWavBytes(toneId);
      await targetFile.writeAsBytes(wavBytes);
      _cachedFilePaths[toneId] = targetFile.path;
      return targetFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Synthesizes 16-bit 44.1 kHz PCM WAV byte buffer for any built-in tone
  static Uint8List synthesizeToneWavBytes(String toneId, {int sampleRate = 44100}) {
    switch (toneId) {
      case 'rooster_dawn':
      case 'rooster_crow':
        return synthesizeRoosterCrowWavBytes(sampleRate: sampleRate);
      case 'gentle_breeze':
        return synthesizeGentleBreezeWavBytes(sampleRate: sampleRate);
      case 'digital_pulse':
        return synthesizeDigitalPulseWavBytes(sampleRate: sampleRate);
      case 'bell_chime':
        return synthesizeBellChimeWavBytes(sampleRate: sampleRate);
      case 'energetic_beat':
        return synthesizeEnergeticBeatWavBytes(sampleRate: sampleRate);
      default:
        return synthesizeRoosterCrowWavBytes(sampleRate: sampleRate);
    }
  }

  /// Synthesizes Roo's signature dawn crow: "Cock-a-doodle-doo!"
  /// Features 4 expressive vocal syllables, avian syrinx harmonics,
  /// natural vibrato/tremolo, and crisp morning clarity.
  static Uint8List synthesizeRoosterCrowWavBytes({int sampleRate = 44100}) {
    const durationSeconds = 3.6;
    final totalSamples = (sampleRate * durationSeconds).toInt();
    final pcmData = Int16List(totalSamples);
    final rnd = Random(1337);

    double phase = 0.0;
    double breathFilter = 0.0;

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate.toDouble();

      double noteAmp = 0.0;
      double targetFreq = 0.0;

      if (t >= 0.15 && t < 0.50) {
        // 1. "Cock"
        final p = (t - 0.15) / 0.35;
        targetFreq = 380.0 + (470.0 - 380.0) * pow(p, 0.7);
        noteAmp = p < 0.12 ? (p / 0.12) : (p > 0.80 ? (1.0 - p) / 0.20 : 0.92);
      } else if (t >= 0.58 && t < 0.82) {
        // 2. "a"
        final p = (t - 0.58) / 0.24;
        targetFreq = 360.0 - 30.0 * p;
        noteAmp = (p < 0.15 ? (p / 0.15) : (p > 0.75 ? (1.0 - p) / 0.25 : 1.0)) * 0.72;
      } else if (t >= 0.90 && t < 1.38) {
        // 3. "doodle"
        final p = (t - 0.90) / 0.48;
        targetFreq = 620.0 + (860.0 - 620.0) * pow(p, 0.85);
        noteAmp = (p < 0.10 ? (p / 0.10) : (p > 0.82 ? (1.0 - p) / 0.18 : 1.0)) * 0.95;
      } else if (t >= 1.42 && t < 3.20) {
        // 4. "dooooo" (sustained climax with rich natural vibrato & decay)
        final p = (t - 1.42) / 1.78;
        final vibratoEnv = p < 0.12 ? p / 0.12 : 1.0;
        final vibrato = 22.0 * vibratoEnv * sin(2 * pi * 5.8 * (t - 1.42));
        final baseFreq = 930.0 - 150.0 * pow(p, 1.3);
        targetFreq = baseFreq + vibrato;

        if (p < 0.04) {
          noteAmp = p / 0.04;
        } else if (p < 0.65) {
          final tremolo = 1.0 - 0.07 * (0.5 + 0.5 * sin(2 * pi * 5.8 * (t - 1.42)));
          noteAmp = 1.0 * tremolo;
        } else {
          final decayP = (p - 0.65) / 0.35;
          noteAmp = pow(1.0 - decayP, 1.8).toDouble();
        }
      }

      if (noteAmp <= 0.001 || targetFreq <= 10.0) {
        pcmData[i] = 0;
        continue;
      }

      phase += (2.0 * pi * targetFreq) / sampleRate;
      if (phase > 2.0 * pi * 1000) phase -= 2.0 * pi * 1000;

      // Rich avian syrinx harmonics
      double raw = 1.00 * sin(phase) +
          0.75 * sin(2.0 * phase + 0.25) +
          0.55 * sin(3.0 * phase + 0.50) +
          0.38 * sin(4.0 * phase + 0.80) +
          0.25 * sin(5.0 * phase + 1.10) +
          0.16 * sin(6.0 * phase + 1.40) +
          0.10 * sin(7.0 * phase + 1.70);
      raw /= 3.19;

      // Syrinx rasp / gentle non-linear saturation
      final rasp = raw * 1.4 - 0.22 * pow(raw, 3);

      // Subtle breath noise
      final white = rnd.nextDouble() * 2.0 - 1.0;
      breathFilter = 0.85 * breathFilter + 0.15 * white;
      final breath = breathFilter * 0.035;

      final sample = (rasp + breath) * noteAmp;
      pcmData[i] = (sample * 28500).clamp(-32000, 32000).toInt();
    }

    return _buildWavHeaderAndData(pcmData: pcmData, sampleRate: sampleRate);
  }

  /// Synthesizes Seren's Gentle Breeze with soft chimes
  static Uint8List synthesizeGentleBreezeWavBytes({int sampleRate = 44100}) {
    const durationSeconds = 4.0;
    final totalSamples = (sampleRate * durationSeconds).toInt();
    final pcmData = Int16List(totalSamples);
    final rnd = Random(42);

    final chimes = [261.63, 329.63, 392.00, 493.88, 587.33];
    final chimeStartTimes = [0.1, 0.6, 1.1, 1.6, 2.1];

    double noiseFilter = 0.0;

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate.toDouble();
      final white = rnd.nextDouble() * 2.0 - 1.0;
      noiseFilter = 0.98 * noiseFilter + 0.02 * white;
      final windMod = sin(2 * pi * 0.3 * t);
      final wind = noiseFilter * (0.08 + 0.05 * windMod);

      double chimeSum = 0.0;
      for (int c = 0; c < chimes.length; c++) {
        final start = chimeStartTimes[c];
        if (t >= start) {
          final age = t - start;
          final freq = chimes[c];
          final env = exp(-age * 1.8);
          final strike = sin(2 * pi * freq * age) +
              0.3 * sin(2 * pi * freq * 2.76 * age) * exp(-age * 4.0);
          chimeSum += strike * env * 0.22;
        }
      }

      final sample = (wind + chimeSum).clamp(-1.0, 1.0);
      pcmData[i] = (sample * 26000).clamp(-32000, 32000).toInt();
    }

    return _buildWavHeaderAndData(pcmData: pcmData, sampleRate: sampleRate);
  }

  /// Synthesizes Digital Pulse cadence
  static Uint8List synthesizeDigitalPulseWavBytes({int sampleRate = 44100}) {
    const durationSeconds = 3.0;
    final totalSamples = (sampleRate * durationSeconds).toInt();
    final pcmData = Int16List(totalSamples);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate.toDouble();
      final cycle = t % 1.5;
      double sample = 0.0;

      if (cycle < 0.8) {
        final pulseIndex = (cycle / 0.2).floor();
        final pulseT = cycle - pulseIndex * 0.2;
        if (pulseT < 0.10) {
          final freq = pulseIndex == 3 ? 1760.0 : 880.0;
          final p = pulseT / 0.10;
          final env = p < 0.1 ? (p / 0.1) : (p > 0.8 ? (1.0 - p) / 0.2 : 1.0);
          sample = sin(2 * pi * freq * pulseT) * env * 0.8;
        }
      }

      pcmData[i] = (sample * 26000).clamp(-32000, 32000).toInt();
    }

    return _buildWavHeaderAndData(pcmData: pcmData, sampleRate: sampleRate);
  }

  /// Synthesizes Temple Bell Chime
  static Uint8List synthesizeBellChimeWavBytes({int sampleRate = 44100}) {
    const durationSeconds = 4.0;
    final totalSamples = (sampleRate * durationSeconds).toInt();
    final pcmData = Int16List(totalSamples);

    const baseFreq = 528.0;
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate.toDouble();
      if (t < 0.05) {
        pcmData[i] = 0;
        continue;
      }
      final age = t - 0.05;
      final f1 = sin(2 * pi * baseFreq * age) * exp(-age * 0.9);
      final f2 = sin(2 * pi * baseFreq * 2.02 * age) * exp(-age * 1.4) * 0.45;
      final f3 = sin(2 * pi * baseFreq * 3.01 * age) * exp(-age * 2.2) * 0.25;
      final f4 = sin(2 * pi * baseFreq * 4.76 * age) * exp(-age * 3.5) * 0.15;

      final bell = (f1 + f2 + f3 + f4) * 0.65;
      pcmData[i] = (bell * 28000).clamp(-32000, 32000).toInt();
    }

    return _buildWavHeaderAndData(pcmData: pcmData, sampleRate: sampleRate);
  }

  /// Synthesizes Energetic Rooster Beat
  static Uint8List synthesizeEnergeticBeatWavBytes({int sampleRate = 44100}) {
    const durationSeconds = 3.2;
    final totalSamples = (sampleRate * durationSeconds).toInt();
    final pcmData = Int16List(totalSamples);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate.toDouble();
      final beatT = t % 0.5;

      double kick = 0.0;
      if (beatT < 0.20) {
        final kickP = beatT / 0.20;
        final freq = 120.0 * exp(-kickP * 4.0) + 45.0;
        kick = sin(2 * pi * freq * beatT) * exp(-kickP * 5.0) * 0.85;
      }

      final step = ((t % 2.0) / 0.25).floor();
      final stepT = t % 0.25;
      final arpFreqs = [523.25, 659.25, 783.99, 1046.50];
      final noteFreq = arpFreqs[step % arpFreqs.length];
      final noteEnv = exp(-stepT * 8.0);
      final synth = sin(2 * pi * noteFreq * stepT) * noteEnv * 0.35;

      final sample = (kick + synth).clamp(-1.0, 1.0);
      pcmData[i] = (sample * 27000).clamp(-32000, 32000).toInt();
    }

    return _buildWavHeaderAndData(pcmData: pcmData, sampleRate: sampleRate);
  }

  /// Builds valid 44-byte RIFF header followed by 16-bit PCM samples
  static Uint8List _buildWavHeaderAndData({
    required Int16List pcmData,
    required int sampleRate,
  }) {
    final totalSamples = pcmData.length;
    final dataByteLength = totalSamples * 2;
    final byteData = ByteData(44 + dataByteLength);

    // RIFF chunk descriptor
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, 36 + dataByteLength, Endian.little);
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // "fmt " sub-chunk
    byteData.setUint8(12, 0x66);
    byteData.setUint8(13, 0x6D);
    byteData.setUint8(14, 0x74);
    byteData.setUint8(15, 0x20);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);

    // "data" sub-chunk
    byteData.setUint8(36, 0x64);
    byteData.setUint8(37, 0x61);
    byteData.setUint8(38, 0x74);
    byteData.setUint8(39, 0x61);
    byteData.setUint32(40, dataByteLength, Endian.little);

    int offset = 44;
    for (int i = 0; i < totalSamples; i++) {
      byteData.setInt16(offset, pcmData[i], Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }
}

