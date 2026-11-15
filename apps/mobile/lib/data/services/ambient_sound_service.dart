import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../models/seren_relaxation_models.dart';

enum AmbientSoundType {
  none,
  rain,
  coffeeShop,
  forest,
}

extension AmbientSoundTypeExtension on AmbientSoundType {
  String get label {
    final l10n = AppLocalizations.current;
    switch (this) {
      case AmbientSoundType.none:
        return l10n.tr('seren_sound_none_label');
      case AmbientSoundType.rain:
        return l10n.tr('seren_sound_rain_title');
      case AmbientSoundType.coffeeShop:
        return l10n.tr('seren_sound_cafe_title');
      case AmbientSoundType.forest:
        return l10n.tr('seren_sound_forest_title');
    }
  }

  String get description {
    final l10n = AppLocalizations.current;
    switch (this) {
      case AmbientSoundType.none:
        return l10n.tr('seren_sound_none_desc');
      case AmbientSoundType.rain:
        return l10n.tr('seren_sound_rain_desc');
      case AmbientSoundType.coffeeShop:
        return l10n.tr('seren_sound_cafe_desc');
      case AmbientSoundType.forest:
        return l10n.tr('seren_sound_forest_desc');
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
  AudioPlayer? _player;
  AudioPlayer get _lazyPlayer => _player ??= AudioPlayer();
  final Map<String, AudioPlayer> _mixerPlayers = {};
  AmbientSoundType _currentType = AmbientSoundType.none;
  double _volume = 0.5;
  bool _isPlaying = false;
  bool _isMixerPlaying = false;
  final Map<AmbientSoundType, String> _generatedFiles = {};
  final Map<String, String> _generatedTrackFiles = {};

  AmbientSoundType get currentType => _currentType;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;
  bool get isMixerPlaying => _isMixerPlaying;
  Set<String> get activeMixerSoundIds => _mixerPlayers.keys.toSet();

  AmbientSoundService();

  Future<void> play(AmbientSoundType type, {double? volume}) async {
    if (volume != null) _volume = volume;
    _currentType = type;

    if (type == AmbientSoundType.none) {
      await stop();
      return;
    }

    try {
      final player = _lazyPlayer;
      await player.setVolume(_volume);
      final filePath = await _getOrCreateAudioFile(type);
      if (filePath != null && File(filePath).existsSync()) {
        await player.setReleaseMode(ReleaseMode.loop);
        await player.play(DeviceFileSource(filePath));
        _isPlaying = true;
      }
    } catch (_) {
      // Ignored if headless / platform audio unsupported
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    if (_player == null) return;
    try {
      await _player!.setVolume(_volume);
    } catch (_) {}
  }

  Future<void> stop() async {
    _isPlaying = false;
    _currentType = AmbientSoundType.none;
    if (_player == null) return;
    try {
      await _player!.stop();
    } catch (_) {}
  }

  Future<void> pause() async {
    _isPlaying = false;
    if (_player == null) return;
    try {
      await _player!.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_currentType != AmbientSoundType.none) {
      try {
        await _lazyPlayer.resume();
        _isPlaying = true;
      } catch (_) {}
    }
  }

  // ===========================================================================
  // MULTI-TRACK SOUNDSCAPE MIXER ENGINE (CORE FEATURE A & B)
  // ===========================================================================

  /// Calculates effective player volume combining track volume, master volume,
  /// distance attenuation, narration ducking factor, and timer fade-out factor.
  static double computeEffectiveTrackVolume(
    SoundMixerTrackConfig track, {
    required double masterVolume,
    double duckFactor = 1.0,
    double fadeMultiplier = 1.0,
  }) {
    if (track.isMuted) return 0.0;
    final raw = track.volume *
        masterVolume *
        track.distance.acousticAttenuation *
        duckFactor *
        fadeMultiplier;
    return raw.clamp(0.0, 1.0);
  }

  /// Synchronizes all active mixer tracks smoothly without stopping unchanged tracks.
  Future<void> syncMixerTracks(
    List<SoundMixerTrackConfig> tracks, {
    required double masterVolume,
    required bool shouldPlay,
    double duckFactor = 1.0,
    double fadeMultiplier = 1.0,
  }) async {
    final desiredIds = tracks.map((t) => t.soundId).toSet();

    // Stop and dispose removed tracks
    final existingIds = _mixerPlayers.keys.toList();
    for (final id in existingIds) {
      if (!desiredIds.contains(id)) {
        final removed = _mixerPlayers.remove(id);
        try {
          await removed?.stop();
          await removed?.dispose();
        } catch (_) {}
      }
    }

    if (!shouldPlay || tracks.isEmpty) {
      _isMixerPlaying = false;
      for (final player in _mixerPlayers.values) {
        try {
          await player.pause();
        } catch (_) {}
      }
      return;
    }

    _isMixerPlaying = true;

    for (final track in tracks) {
      final effectiveVol = computeEffectiveTrackVolume(
        track,
        masterVolume: masterVolume,
        duckFactor: duckFactor,
        fadeMultiplier: fadeMultiplier,
      );

      var player = _mixerPlayers[track.soundId];
      final isNewPlayer = player == null;
      if (player == null) {
        player = AudioPlayer();
        _mixerPlayers[track.soundId] = player;
      }

      try {
        await player.setVolume(effectiveVol);
        await player.setBalance(track.stereoPosition.balanceValue);
        final filePath = await getOrCreateTrackAudioFile(
          track.soundId,
          distance: track.distance,
          stereoPosition: track.stereoPosition,
          toneWarmth: track.toneWarmth,
        );
        if (filePath != null && File(filePath).existsSync()) {
          if (isNewPlayer || player.state != PlayerState.playing) {
            await player.setReleaseMode(ReleaseMode.loop);
            await player.play(DeviceFileSource(filePath));
          }
        }
      } catch (_) {
        // Safe fallback in headless test environments
      }
    }
  }

  /// Re-renders or updates a single track when distance, stereo position, or EQ warmth changes.
  Future<void> refreshTrackVariant(
    SoundMixerTrackConfig track, {
    required double masterVolume,
    required bool isPlaying,
    double duckFactor = 1.0,
    double fadeMultiplier = 1.0,
  }) async {
    final player = _mixerPlayers[track.soundId];
    if (player == null) return;

    final effectiveVol = computeEffectiveTrackVolume(
      track,
      masterVolume: masterVolume,
      duckFactor: duckFactor,
      fadeMultiplier: fadeMultiplier,
    );

    try {
      await player.setVolume(effectiveVol);
      await player.setBalance(track.stereoPosition.balanceValue);
      if (isPlaying) {
        final filePath = await getOrCreateTrackAudioFile(
          track.soundId,
          distance: track.distance,
          stereoPosition: track.stereoPosition,
          toneWarmth: track.toneWarmth,
        );
        if (filePath != null && File(filePath).existsSync()) {
          await player.setReleaseMode(ReleaseMode.loop);
          await player.play(DeviceFileSource(filePath));
        }
      }
    } catch (_) {}
  }

  /// Fast volume update across active mixer tracks (used for sliders, ducking, and timer fade-out).
  Future<void> applyMixerVolumes(
    List<SoundMixerTrackConfig> tracks, {
    required double masterVolume,
    double duckFactor = 1.0,
    double fadeMultiplier = 1.0,
  }) async {
    for (final track in tracks) {
      final player = _mixerPlayers[track.soundId];
      if (player == null) continue;
      final effectiveVol = computeEffectiveTrackVolume(
        track,
        masterVolume: masterVolume,
        duckFactor: duckFactor,
        fadeMultiplier: fadeMultiplier,
      );
      try {
        await player.setVolume(effectiveVol);
      } catch (_) {}
    }
  }

  Future<void> pauseMixer() async {
    _isMixerPlaying = false;
    for (final player in _mixerPlayers.values) {
      try {
        await player.pause();
      } catch (_) {}
    }
  }

  Future<void> stopMixer() async {
    _isMixerPlaying = false;
    final players = _mixerPlayers.values.toList();
    _mixerPlayers.clear();
    for (final player in players) {
      try {
        await player.stop();
        await player.dispose();
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

  static const int synthSampleRate = 22050;
  static const int loopDurationSeconds = 4;
  static const double crossfadeOverlapSeconds = 1.5;

  /// Resolves or generates a cached stereo WAV file for any sound ID, distance,
  /// stereo pan, and quantized equalizer warmth level (`-1.0 .. +1.0`).
  Future<String?> getOrCreateTrackAudioFile(
    String soundId, {
    SoundDistance distance = SoundDistance.balanced,
    StereoPosition stereoPosition = StereoPosition.center,
    double toneWarmth = 0.0,
  }) async {
    final eqBucket = (toneWarmth.clamp(-1.0, 1.0) * 10).round();
    final cacheKey =
        'v2_${soundId}_${distance.name}_${stereoPosition.name}_eq$eqBucket';
    if (_generatedTrackFiles.containsKey(cacheKey)) {
      final existing = _generatedTrackFiles[cacheKey]!;
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

      final fileName = 'seren_$cacheKey.wav';
      final file = File('${ambientDir.path}/$fileName');
      if (file.existsSync() && file.lengthSync() > 1000) {
        _generatedTrackFiles[cacheKey] = file.path;
        return file.path;
      }

      final bytes = synthesizeTrackWavBytes(
        soundId,
        distance: distance,
        stereoPosition: stereoPosition,
        toneWarmth: eqBucket / 10.0,
      );
      await file.writeAsBytes(bytes);
      _generatedTrackFiles[cacheKey] = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Legacy mono WAV synthesis preserved for backwards compatibility.
  static Uint8List synthesizeWavBytes(AmbientSoundType type) {
    switch (type) {
      case AmbientSoundType.rain:
        return synthesizeTrackWavBytes('rain');
      case AmbientSoundType.coffeeShop:
        return synthesizeTrackWavBytes('coffeeShop');
      case AmbientSoundType.forest:
        return synthesizeTrackWavBytes('forest');
      case AmbientSoundType.none:
        return synthesizeTrackWavBytes('none');
    }
  }

  /// Applies a 1.5-second equal-power sine/cosine overlap crossfade across the
  /// head of [primaryBuffer] using [overlapTailBuffer] so looping back from
  /// `primaryBuffer[N - 1]` to `primaryBuffer[0]` is completely click-free.
  static void applyDualBufferLoopCrossfade(
    Float64List primaryBuffer,
    Float64List overlapTailBuffer,
  ) {
    final fadeFrames = overlapTailBuffer.length.clamp(0, primaryBuffer.length);
    if (fadeFrames <= 1) return;
    final denom = (fadeFrames - 1).toDouble();
    for (int i = 0; i < fadeFrames; i++) {
      final u = i / denom;
      final headWeight = sin(u * (pi / 2.0));
      final tailWeight = cos(u * (pi / 2.0));
      primaryBuffer[i] =
          overlapTailBuffer[i] * tailWeight + primaryBuffer[i] * headWeight;
    }
  }

  /// Shapes [samples] in-place with a Warmth / Brightness equalizer curve.
  /// - `toneWarmth < 0`: Gentle low-pass hiss tame + subtle 240Hz warm shelf.
  /// - `toneWarmth > 0`: Airy high-shelf presence lift.
  static void applyWarmthEqualizer(Float64List samples, double toneWarmth) {
    final clamped = toneWarmth.clamp(-1.0, 1.0);
    if (clamped.abs() < 0.01 || samples.isEmpty) return;

    if (clamped < 0) {
      final warmAmt = -clamped;
      // Progressive treble rolloff down to alpha = 0.075 at full warmth (-1.0)
      final trebleCutAlpha = (0.62 - 0.545 * warmAmt).clamp(0.075, 0.95);
      const bodyAlpha = 0.068;
      double lpTreble = samples[0];
      double lpBody = samples[0];
      for (int i = 0; i < samples.length; i++) {
        final x = samples[i];
        lpTreble += trebleCutAlpha * (x - lpTreble);
        lpBody += bodyAlpha * (lpTreble - lpBody);
        final softened = x * (1.0 - warmAmt) + lpTreble * warmAmt;
        samples[i] = softened + lpBody * (0.18 * warmAmt);
      }
    } else {
      final brightAmt = clamped;
      // Split above ~1.1kHz and gently lift crisp upper harmonics without harshness
      const splitAlpha = 0.28;
      double lowMid = samples[0];
      for (int i = 0; i < samples.length; i++) {
        final x = samples[i];
        lowMid += splitAlpha * (x - lowMid);
        final highAir = x - lowMid;
        samples[i] = x + highAir * (0.65 * brightAmt);
      }
    }
  }

  /// Procedural 16-bit Stereo WAV synthesizer with:
  /// 1. Dual-buffer extended synthesis (`4.0s + 1.5s` overlap tail)
  /// 2. Distance low-pass filtering & Per-Track Warmth/Brightness Equalizer
  /// 3. Multi-tap spatial reverb & constant-power stereo positioning
  /// 4. Dual-buffer 1.5-second equal-power overlap crossfade seam polisher
  static Uint8List synthesizeTrackWavBytes(
    String soundId, {
    SoundDistance distance = SoundDistance.balanced,
    StereoPosition stereoPosition = StereoPosition.center,
    double toneWarmth = 0.0,
  }) {
    const sampleRate = synthSampleRate;
    const totalFrames = sampleRate * loopDurationSeconds;
    final overlapFrames = (sampleRate * crossfadeOverlapSeconds).round();
    final extendedFrames = totalFrames + overlapFrames;
    const numChannels = 2;
    final rnd = Random(soundId.hashCode ^ 0x5E2E);

    final rawMono = Float64List(extendedFrames);

    if (soundId != 'none') {
      _fillProceduralSignal(soundId, rawMono, sampleRate, rnd);
    }

    // Apply Distance Acoustic Processing + Warmth/Brightness EQ on full 5.5s buffer
    // so both the primary loop body and the 1.5s overlap tail share warm filter/reverb tails.
    final eqBrightnessBoost = toneWarmth > 0 ? toneWarmth.clamp(0.0, 1.0) : 0.0;
    final alpha = (distance.lowPassAlpha +
            (1.0 - distance.lowPassAlpha) * 0.40 * eqBrightnessBoost)
        .clamp(0.05, 0.99);
    final wetMix = distance.spatialReverbMix;
    final dryMix = 1.0 - wetMix * 0.45;
    final atten = distance.acousticAttenuation;
    const delay1Samples = 815; // ~37ms at 22050Hz
    const delay2Samples = 1610; // ~73ms at 22050Hz

    final filtered = Float64List(extendedFrames);
    double lpState = 0.0;
    for (int i = 0; i < extendedFrames; i++) {
      lpState = lpState + alpha * (rawMono[i] - lpState);
      filtered[i] = lpState;
    }

    applyWarmthEqualizer(filtered, toneWarmth);

    final leftPan = stereoPosition.leftGain;
    final rightPan = stereoPosition.rightGain;

    final primaryL = Float64List(totalFrames);
    final primaryR = Float64List(totalFrames);
    final tailL = Float64List(overlapFrames);
    final tailR = Float64List(overlapFrames);

    for (int i = 0; i < extendedFrames; i++) {
      final dry = filtered[i];
      final echo1 = i >= delay1Samples ? filtered[i - delay1Samples] * 0.55 : 0.0;
      final echo2 = i >= delay2Samples ? filtered[i - delay2Samples] * 0.35 : 0.0;

      final sampleL = (dry * dryMix + (echo1 + echo2 * 0.8) * wetMix) * atten * leftPan;
      final sampleR = (dry * dryMix + (echo1 * 0.8 + echo2) * wetMix) * atten * rightPan;

      if (i < totalFrames) {
        primaryL[i] = sampleL;
        primaryR[i] = sampleR;
      } else {
        final tailIdx = i - totalFrames;
        tailL[tailIdx] = sampleL;
        tailR[tailIdx] = sampleR;
      }
    }

    // Polish loop boundary using dual-buffer 1.5s equal-power overlap crossfade
    applyDualBufferLoopCrossfade(primaryL, tailL);
    applyDualBufferLoopCrossfade(primaryR, tailR);

    final processedL = Int16List(totalFrames);
    final processedR = Int16List(totalFrames);
    for (int i = 0; i < totalFrames; i++) {
      processedL[i] = (primaryL[i] * 26000).clamp(-30000.0, 30000.0).toInt();
      processedR[i] = (primaryR[i] * 26000).clamp(-30000.0, 30000.0).toInt();
    }

    final dataSize = totalFrames * numChannels * 2;
    final byteData = ByteData(44 + dataSize);
    // "RIFF"
    byteData.setUint8(0, 0x52);
    byteData.setUint8(1, 0x49);
    byteData.setUint8(2, 0x46);
    byteData.setUint8(3, 0x46);
    byteData.setUint32(4, 36 + dataSize, Endian.little);
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
    byteData.setUint16(22, numChannels, Endian.little); // Stereo (2 channels)
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * numChannels * 2, Endian.little);
    byteData.setUint16(32, numChannels * 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    // "data"
    byteData.setUint8(36, 0x64);
    byteData.setUint8(37, 0x61);
    byteData.setUint8(38, 0x74);
    byteData.setUint8(39, 0x61);
    byteData.setUint32(40, dataSize, Endian.little);

    int offset = 44;
    for (int i = 0; i < totalFrames; i++) {
      byteData.setInt16(offset, processedL[i], Endian.little);
      offset += 2;
      byteData.setInt16(offset, processedR[i], Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  static void _fillProceduralSignal(
    String soundId,
    Float64List out,
    int sampleRate,
    Random rnd,
  ) {
    final n = out.length;
    switch (soundId) {
      case 'rain':
      case 'rainWindow':
        double b0 = 0, b1 = 0, b2 = 0;
        final dropRate = soundId == 'rainWindow' ? 0.0055 : 0.0028;
        for (int i = 0; i < n; i++) {
          final white = rnd.nextDouble() * 2 - 1;
          b0 = 0.99765 * b0 + white * 0.0990460;
          b1 = 0.96300 * b1 + white * 0.2965164;
          b2 = 0.57000 * b2 + white * 1.0526913;
          double pink = (b0 + b1 + b2 + white * 0.1848) * 0.12;
          if (rnd.nextDouble() < dropRate) {
            pink += (rnd.nextDouble() * 0.22);
          }
          out[i] = pink;
        }
        break;

      case 'thunderstorm':
        double brown = 0;
        for (int i = 0; i < n; i++) {
          final t = i / sampleRate;
          final white = rnd.nextDouble() * 2 - 1;
          brown = (brown + 0.02 * white) / 1.02;
          final rumbleEnvelope = 0.35 + 0.65 * pow(sin(pi * t / 4.0), 2);
          final subBoom = sin(2 * pi * 48.0 * t) * 0.22 * rumbleEnvelope;
          out[i] = (brown * 1.8 * rumbleEnvelope) + subBoom;
        }
        break;

      case 'oceanWaves':
        double pinkState = 0;
        for (int i = 0; i < n; i++) {
          final t = i / sampleRate;
          final white = rnd.nextDouble() * 2 - 1;
          pinkState = 0.96 * pinkState + 0.04 * white;
          final swell = 0.25 + 0.70 * (0.5 + 0.5 * sin(2 * pi * 0.25 * t));
          out[i] = pinkState * swell * 1.6;
        }
        break;

      case 'riverStream':
        double lp = 0;
        for (int i = 0; i < n; i++) {
          final t = i / sampleRate;
          final white = rnd.nextDouble() * 2 - 1;
          lp = 0.88 * lp + 0.12 * white;
          final ripple = sin(2 * pi * (420 + 140 * sin(2 * pi * 1.5 * t)) * t) * 0.05;
          out[i] = lp * 0.85 + ripple;
        }
        break;

      case 'forest':
      case 'birdsSinging':
        for (int i = 0; i < n; i++) {
          final t = i / sampleRate;
          final wind = sin(2 * pi * 0.25 * t) * (rnd.nextDouble() * 0.16 + 0.06);
          double bird = 0.0;
          final cycle = i % (sampleRate * 2);
          if (cycle > 5000 && cycle < 9500) {
            final bt = (cycle - 5000) / sampleRate;
            final freq = 2600 + 650 * sin(2 * pi * 12 * bt);
            bird = sin(2 * pi * freq * bt) * 0.25 * (1.0 - (cycle - 5000) / 4500.0);
          }
          out[i] = soundId == 'birdsSinging' ? (wind * 0.4 + bird * 1.3) : (wind + bird);
        }
        break;

      case 'gentleWind':
        double state = 0;
        for (int i = 0; i < n; i++) {
          final t = i / sampleRate;
          final white = rnd.nextDouble() * 2 - 1;
          state = 0.992 * state + 0.008 * white;
          final gust = 0.45 + 0.55 * sin(2 * pi * 0.25 * t);
          out[i] = state * 3.0 * gust;
        }
        break;

      case 'nightInsects':
        for (int i = 0; i < n; i++) {
          final t = i / sampleRate;
          final pulse = (sin(2 * pi * 3.5 * t) > 0.1) ? 1.0 : 0.15;
          final carrier = sin(2 * pi * 3850 * t) * 0.14 + sin(2 * pi * 4120 * t) * 0.08;
          final softAir = (rnd.nextDouble() * 2 - 1) * 0.03;
          out[i] = carrier * pulse + softAir;
        }
        break;

      case 'fireplace':
        double warm = 0;
        double popEnv = 0;
        for (int i = 0; i < n; i++) {
          final white = rnd.nextDouble() * 2 - 1;
          warm = 0.99 * warm + 0.01 * white;
          if (rnd.nextDouble() < 0.0018) {
            popEnv = 0.55;
          }
          popEnv *= 0.975;
          final crackle = white * popEnv;
          out[i] = warm * 2.2 + crackle;
        }
        break;

      case 'coffeeShop':
      case 'roomAmbience':
      case 'quietLibrary':
        double s0 = 0;
        for (int i = 0; i < n; i++) {
          final white = rnd.nextDouble() * 2 - 1;
          s0 = 0.988 * s0 + white * 0.012;
          final t = i / sampleRate;
          final hum = sin(2 * pi * 120 * t) * 0.06;
          out[i] = s0 * (soundId == 'coffeeShop' ? 2.4 : 1.3) + hum;
        }
        break;

      case 'whiteNoise':
        for (int i = 0; i < n; i++) {
          out[i] = (rnd.nextDouble() * 2 - 1) * 0.25;
        }
        break;

      case 'pinkNoise':
        double b0 = 0, b1 = 0, b2 = 0;
        for (int i = 0; i < n; i++) {
          final white = rnd.nextDouble() * 2 - 1;
          b0 = 0.99765 * b0 + white * 0.0990460;
          b1 = 0.96300 * b1 + white * 0.2965164;
          b2 = 0.57000 * b2 + white * 1.0526913;
          out[i] = (b0 + b1 + b2 + white * 0.1848) * 0.11;
        }
        break;

      case 'brownNoise':
      case 'nightAmbience':
        double last = 0;
        for (int i = 0; i < n; i++) {
          final white = rnd.nextDouble() * 2 - 1;
          last = (last + 0.02 * white) / 1.02;
          out[i] = last * 1.6;
        }
        break;

      case 'calmInstrumental':
      case 'gentlePiano':
      case 'ambientPad':
      case 'morningMelody':
        final baseFreq = soundId == 'morningMelody'
            ? 261.63 // C4
            : (soundId == 'gentlePiano' ? 220.0 : 174.61); // A3 / F3
        for (int i = 0; i < n; i++) {
          final t = i / sampleRate;
          final env = 0.55 + 0.45 * sin(2 * pi * 0.25 * t);
          final root = sin(2 * pi * baseFreq * t) * 0.18;
          final third = sin(2 * pi * (baseFreq * 1.25) * t) * 0.12;
          final fifth = sin(2 * pi * (baseFreq * 1.5) * t) * 0.12;
          final octave = sin(2 * pi * (baseFreq * 2.0) * t) * 0.06;
          out[i] = (root + third + fifth + octave) * env;
        }
        break;

      case 'singingBowls':
        // Resonant Tibetan/crystal singing bowl with inharmonic bell partials
        // (1.0x, 2.756x, 5.404x) and gentle 1.5Hz binaural shimmer beating.
        // Uses a raised-cosine bloom envelope so loop edges (t=0, t=4s) are click-free.
        const f0 = 216.0; // Warm A3-adjacent healing bowl fundamental
        const f1 = f0 * 2.756;
        const f2 = f0 * 5.404;
        for (int i = 0; i < n; i++) {
          final t = i / sampleRate;
          final bloomEnv = 0.35 + 0.65 * (0.5 - 0.5 * cos(2 * pi * t / 4.0));
          final shimmerEnv = 0.5 - 0.5 * cos(2 * pi * t / 2.0);
          final fundamental =
              (sin(2 * pi * f0 * t) + 0.75 * sin(2 * pi * (f0 + 1.5) * t)) * 0.18;
          final overtone1 =
              (sin(2 * pi * f1 * t) + 0.5 * sin(2 * pi * (f1 - 1.0) * t)) *
                  0.07 *
                  shimmerEnv;
          final overtone2 = sin(2 * pi * f2 * t) * 0.025 * pow(shimmerEnv, 2);
          out[i] = (fundamental + overtone1 + overtone2) * bloomEnv;
        }
        break;

      case 'softKalimba':
        // 8-note pentatonic thumb-piano arpeggio (0.5s per tine pluck across 4s loop).
        // Combines warm fundamental tine resonance with a fast-decaying metallic
        // 2.98x overtone transient and soft cross-note sustain tail.
        const notes = <double>[
          261.63, // C4
          329.63, // E4
          392.00, // G4
          440.00, // A4
          523.25, // C5
          659.25, // E5
          587.33, // D5
          392.00, // G4
        ];
        final stepSamples = sampleRate ~/ 2; // 0.5s per note
        for (int i = 0; i < n; i++) {
          final noteIdx = (i ~/ stepSamples) % notes.length;
          final prevIdx = (noteIdx - 1 + notes.length) % notes.length;
          final noteT = (i % stepSamples) / sampleRate;
          final prevT = noteT + 0.5;

          final freq = notes[noteIdx];
          final attack = (noteT / 0.010).clamp(0.0, 1.0);
          final bodyEnv = attack * exp(-5.2 * noteT);
          final tineTransient = attack * exp(-28.0 * noteT);
          final currentNote =
              sin(2 * pi * freq * noteT) * 0.30 * bodyEnv +
              sin(2 * pi * (freq * 2.0) * noteT) * 0.07 * bodyEnv +
              sin(2 * pi * (freq * 2.98) * noteT) * 0.05 * tineTransient;

          // Carry-over tail from previous tine for seamless loop & legato warmth
          final prevFreq = notes[prevIdx];
          final prevEnv = exp(-5.2 * prevT);
          final prevTail = sin(2 * pi * prevFreq * prevT) * 0.22 * prevEnv;

          out[i] = currentNote + prevTail;
        }
        break;

      case 'warmCelloDrone':
        // Deep bowed open-fifth cello drone (C2 = 65.41Hz, G2 = 98.00Hz, E3 = 164.81Hz)
        // with natural bowed string harmonic series, gentle 4.5Hz vibrato, and slow bow swell.
        const c2 = 65.41;
        const g2 = 98.00;
        const e3 = 164.81;
        double rosinLp = 0.0;
        for (int i = 0; i < n; i++) {
          final t = i / sampleRate;
          final bowSwell = 0.62 + 0.38 * (0.5 - 0.5 * cos(2 * pi * t / 4.0));
          final vibrato = 0.0025 * sin(2 * pi * 4.5 * t);

          double stringSum = 0.0;
          for (int k = 1; k <= 5; k++) {
            final weight = 1.0 / (k * k * 0.65 + 0.35);
            final phaseMod = k * vibrato;
            stringSum += weight *
                (0.46 * sin(2 * pi * (c2 * k) * t + phaseMod) +
                    0.34 * sin(2 * pi * (g2 * k) * t - phaseMod) +
                    0.20 * sin(2 * pi * (e3 * k) * t + phaseMod * 0.5));
          }

          final white = rnd.nextDouble() * 2 - 1;
          rosinLp = 0.96 * rosinLp + 0.04 * white;
          out[i] = (stringSum * 0.20 + rosinLp * 0.018) * bowSwell;
        }
        break;

      case 'nylonAcousticGuitar':
        // Fingerpicked warm nylon-string arpeggio (Fmaj7 voicing across 8 eighth-notes).
        // Nylon strings have warm fundamental sustain and fast high-partial damping.
        const chordNotes = <double>[
          174.61, // F3 bass thumb
          261.63, // C4
          349.23, // F4
          440.00, // A4
          523.25, // C5
          440.00, // A4
          349.23, // F4
          261.63, // C4
        ];
        final stepSamples = sampleRate ~/ 2; // 0.5s per plucked string
        for (int i = 0; i < n; i++) {
          final idx = (i ~/ stepSamples) % chordNotes.length;
          final prevIdx = (idx - 1 + chordNotes.length) % chordNotes.length;
          final noteT = (i % stepSamples) / sampleRate;
          final prevT = noteT + 0.5;
          final f = chordNotes[idx];
          final pf = chordNotes[prevIdx];

          final attack = (noteT / 0.008).clamp(0.0, 1.0);
          final fundEnv = attack * exp(-3.6 * noteT);
          final harm2Env = attack * exp(-7.5 * noteT);
          final harm3Env = attack * exp(-14.0 * noteT);

          final pluck =
              sin(2 * pi * f * noteT) * 0.26 * fundEnv +
              sin(2 * pi * (f * 2.0) * noteT) * 0.09 * harm2Env +
              sin(2 * pi * (f * 3.0) * noteT) * 0.035 * harm3Env;

          // Warm resonant bass & previous-note sustain bed
          final prevSustain =
              sin(2 * pi * pf * prevT) * 0.18 * exp(-3.6 * prevT);
          final bassHold =
              sin(2 * pi * 174.61 * (i / sampleRate)) *
              0.08 *
              (0.6 + 0.4 * sin(2 * pi * 0.25 * (i / sampleRate)));

          out[i] = pluck + prevSustain + bassHold;
        }
        break;

      default:
        for (int i = 0; i < n; i++) {
          out[i] = (rnd.nextDouble() * 2 - 1) * 0.15;
        }
        break;
    }
  }

  void dispose() {
    for (final p in _mixerPlayers.values) {
      try {
        p.dispose().catchError((_) {});
      } catch (_) {}
    }
    _mixerPlayers.clear();
    if (_player != null) {
      try {
        _player!.dispose().catchError((_) {});
      } catch (_) {}
    }
  }
}
