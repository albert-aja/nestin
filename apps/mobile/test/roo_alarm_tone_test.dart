import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/data/services/audio_service.dart';
import 'package:nestin/data/services/roo_alarm_tone_service.dart';
import 'package:nestin/providers/sound_provider.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => 1,
    );
  });

  group('RooAlarmToneService Audio Synthesis Tests', () {
    test('Synthesizes valid Roo Morning Crow ("rooster_dawn") WAV bytes', () {
      final wavBytes = RooAlarmToneService.synthesizeRoosterCrowWavBytes(sampleRate: 44100);

      expect(wavBytes, isNotNull);
      expect(wavBytes.length, greaterThan(44));

      // Validate RIFF header
      final headerStr = String.fromCharCodes(wavBytes.sublist(0, 4));
      expect(headerStr, equals('RIFF'));

      final formatStr = String.fromCharCodes(wavBytes.sublist(8, 12));
      expect(formatStr, equals('WAVE'));

      final subchunk1Str = String.fromCharCodes(wavBytes.sublist(12, 16));
      expect(subchunk1Str, equals('fmt '));

      final byteData = ByteData.sublistView(wavBytes);
      final audioFormat = byteData.getUint16(20, Endian.little);
      final numChannels = byteData.getUint16(22, Endian.little);
      final sampleRate = byteData.getUint32(24, Endian.little);
      final bitsPerSample = byteData.getUint16(34, Endian.little);

      expect(audioFormat, equals(1)); // PCM
      expect(numChannels, equals(1)); // Mono
      expect(sampleRate, equals(44100));
      expect(bitsPerSample, equals(16)); // 16-bit

      final dataTag = String.fromCharCodes(wavBytes.sublist(36, 40));
      expect(dataTag, equals('data'));

      final dataLength = byteData.getUint32(40, Endian.little);
      expect(dataLength, equals(wavBytes.length - 44));
    });

    test('Synthesizes all built-in tone types without errors', () {
      for (final tone in RooAlarmToneService.builtInTones) {
        final id = tone['id']!;
        final bytes = RooAlarmToneService.synthesizeToneWavBytes(id, sampleRate: 22050);

        expect(bytes.length, greaterThan(1000));
        expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
        expect(String.fromCharCodes(bytes.sublist(8, 12)), equals('WAVE'));
      }
    });

    test('getOrCreateToneFile creates and caches tone file locally', () async {
      final filePath = await RooAlarmToneService.getOrCreateToneFile('rooster_dawn');

      expect(filePath, isNotNull);
      final file = File(filePath!);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    test('getToneDisplayName resolves human-readable names with Roo default', () {
      expect(
        RooAlarmToneService.getToneDisplayName('rooster_dawn'),
        contains('Roo Morning Crow'),
      );
      expect(
        RooAlarmToneService.getToneDisplayName('rooster_crow'),
        contains('Roo Crisp Dawn Crow'),
      );
      expect(
        RooAlarmToneService.getToneDisplayName('gentle_breeze'),
        contains('Seren Gentle Breeze'),
      );
      expect(
        RooAlarmToneService.getToneDisplayName('unknown_id'),
        equals('Roo Morning Crow (Default)'),
      );
    });

    test('Bundled assets/sounds directory contains all pre-rendered tone WAVs', () {
      final soundsDir = Directory('assets/sounds');
      expect(soundsDir.existsSync(), isTrue);

      final expectedFiles = [
        'rooster_dawn.wav',
        'rooster_crow.wav',
        'gentle_breeze.wav',
        'digital_pulse.wav',
        'bell_chime.wav',
        'energetic_beat.wav',
      ];

      for (final name in expectedFiles) {
        final file = File('${soundsDir.path}/$name');
        expect(file.existsSync(), isTrue, reason: 'Expected $name to exist in assets/sounds/');
        expect(file.lengthSync(), greaterThan(50000));
      }
    });
  });

  group('AudioService & Roo Morning Crow Integration Tests', () {
    late AudioService audioService;

    setUp(() {
      audioService = AudioService();
    });

    tearDown(() async {
      await audioService.stop();
      audioService.dispose();
    });

    test('AudioService.availableTones includes Roo Morning Crow and built-in tones', () {
      expect(
        AudioService.availableTones.any((t) => t['id'] == 'rooster_dawn'),
        isTrue,
      );
      expect(
        AudioService.availableTones.any((t) => t['id'] == 'rooster_crow'),
        isTrue,
      );
      final rooTone = AudioService.availableTones.firstWhere((t) => t['id'] == 'rooster_dawn');
      expect(rooTone['name'], contains('Roo Morning Crow'));
    });

    test('startAlarm starts Roo Morning Crow with volume ramping', () async {
      await audioService.startAlarm(
        soundId: 'rooster_dawn',
        targetVolume: 0.8,
        gradualVolume: true,
        gradualDurationSeconds: 10,
      );

      expect(audioService.isPlaying, isTrue);
      expect(audioService.currentVolume, closeTo(0.05, 0.01));

      await audioService.stop();
      expect(audioService.isPlaying, isFalse);
    });

    test('previewTone plays tone and stops cleanly', () async {
      await audioService.previewTone('rooster_dawn', 0.9);
      await audioService.stop();
      expect(audioService.isPlaying, isFalse);
    });
  });

  group('SoundProvider Roo Tone Tests', () {
    test('getSoundDisplayName resolves Roo Morning Crow for rooster_dawn', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final soundProvider = SoundProvider(storage);

      final displayName = soundProvider.getSoundDisplayName('rooster_dawn');
      expect(displayName, contains('Roo Morning Crow'));
    });
  });
}

