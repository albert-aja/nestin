import 'dart:math' show cos, pi, sin;
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/l10n/app_translations.dart';
import 'package:nestin/data/models/seren_relaxation_models.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/data/services/seren_tts_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/seren_relaxation_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/seren/seren_relaxation_screen.dart';

class FakeAmbientSoundService extends AmbientSoundService {
  int syncCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int volumeApplyCalls = 0;
  int refreshVariantCalls = 0;
  bool lastShouldPlay = false;

  @override
  Future<void> syncMixerTracks(
    List<SoundMixerTrackConfig> tracks, {
    required double masterVolume,
    required bool shouldPlay,
    double duckFactor = 1.0,
    double fadeMultiplier = 1.0,
  }) async {
    syncCalls++;
    lastShouldPlay = shouldPlay;
  }

  @override
  Future<void> refreshTrackVariant(
    SoundMixerTrackConfig track, {
    required double masterVolume,
    required bool isPlaying,
    double duckFactor = 1.0,
    double fadeMultiplier = 1.0,
  }) async {
    refreshVariantCalls++;
  }

  @override
  Future<void> applyMixerVolumes(
    List<SoundMixerTrackConfig> tracks, {
    required double masterVolume,
    double duckFactor = 1.0,
    double fadeMultiplier = 1.0,
  }) async {
    volumeApplyCalls++;
  }

  @override
  Future<void> pauseMixer() async {
    pauseCalls++;
  }

  @override
  Future<void> stopMixer() async {
    stopCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late FakeAmbientSoundService fakeAudioService;
  late SerenTtsService ttsService;
  late SerenRelaxationProvider provider;
  late JournalProvider journalProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = await StorageService.init();
    AppLocalizations.currentLanguage = AppLanguage.en;
    fakeAudioService = FakeAmbientSoundService();
    ttsService = SerenTtsService();
    provider = SerenRelaxationProvider(
      storageService,
      ambientSoundService: fakeAudioService,
      ttsService: ttsService,
    );
    journalProvider = JournalProvider(storageService);
  });

  tearDown(() {
    provider.dispose();
  });

  group('Seren Ambient Sound Library & Spatial DSP Synthesis', () {
    test('Catalog provides 25 sounds across 4 categories (including 8 Calm Music stems) in EN and ID', () {
      expect(SerenRelaxationCatalog.sounds.length, 25);
      for (final cat in AmbientSoundCategory.values) {
        expect(provider.soundsForCategory(cat), isNotEmpty);
      }

      final musicIds = provider
          .soundsForCategory(AmbientSoundCategory.music)
          .map((s) => s.id)
          .toList();
      expect(
        musicIds,
        containsAll(<String>[
          'calmInstrumental',
          'gentlePiano',
          'ambientPad',
          'morningMelody',
          'singingBowls',
          'softKalimba',
          'warmCelloDrone',
          'nylonAcousticGuitar',
        ]),
      );

      AppLocalizations.currentLanguage = AppLanguage.en;
      expect(SerenRelaxationCatalog.soundById('rain').title, 'Gentle Rain');
      expect(SerenRelaxationCatalog.soundById('singingBowls').title, 'Singing Bowls');
      expect(SerenRelaxationCatalog.soundById('softKalimba').title, 'Soft Kalimba');
      expect(SerenRelaxationCatalog.soundById('warmCelloDrone').title, 'Warm Cello Drone');
      expect(
        SerenRelaxationCatalog.soundById('nylonAcousticGuitar').title,
        'Nylon Acoustic Guitar',
      );

      AppLocalizations.currentLanguage = AppLanguage.id;
      expect(SerenRelaxationCatalog.soundById('rain').title, 'Hujan Lembut');
      expect(
        SerenRelaxationCatalog.soundById('singingBowls').title,
        'Mangkuk Nada (Singing Bowls)',
      );
      expect(SerenRelaxationCatalog.soundById('softKalimba').title, 'Kalimba Lembut');
      expect(
        SerenRelaxationCatalog.soundById('warmCelloDrone').title,
        'Dengung Cello Hangat',
      );
      expect(
        SerenRelaxationCatalog.soundById('nylonAcousticGuitar').title,
        'Gitar Akustik Nilon',
      );

      // Verify all 25 sounds and all 9 curated presets have full EN & ID translations
      for (final code in ['en', 'id']) {
        final map = kNestinTranslations[code]!;
        for (final sound in SerenRelaxationCatalog.sounds) {
          expect(map[sound.titleKey], isNotNull, reason: 'Missing $code ${sound.titleKey}');
          expect(map[sound.descriptionKey], isNotNull, reason: 'Missing $code ${sound.descriptionKey}');
        }
        for (final preset in SerenRelaxationCatalog.curatedPresets) {
          if (preset.nameKey != null) {
            expect(map[preset.nameKey!], isNotNull, reason: 'Missing $code ${preset.nameKey}');
          }
          if (preset.descriptionKey != null) {
            expect(map[preset.descriptionKey!], isNotNull, reason: 'Missing $code ${preset.descriptionKey}');
          }
        }
      }
    });

    test('Instrument-Specific Calm Music Stems synthesize distinct stereo PCM waveforms and blend in presets', () async {
      final bowlsWav = AmbientSoundService.synthesizeTrackWavBytes('singingBowls');
      final kalimbaWav = AmbientSoundService.synthesizeTrackWavBytes('softKalimba');
      final celloWav = AmbientSoundService.synthesizeTrackWavBytes('warmCelloDrone');
      final guitarWav = AmbientSoundService.synthesizeTrackWavBytes('nylonAcousticGuitar');

      for (final bytes in [bowlsWav, kalimbaWav, celloWav, guitarWav]) {
        expect(bytes.length, greaterThan(44));
        final headerView = ByteData.sublistView(bytes, 0, 44);
        expect(headerView.getUint16(22, Endian.little), 2); // Stereo
        // Confirm non-silent audio payload
        final pcmView = ByteData.sublistView(bytes, 44);
        var maxSample = 0;
        for (int offset = 0; offset < pcmView.lengthInBytes; offset += 2) {
          final sample = pcmView.getInt16(offset, Endian.little).abs();
          if (sample > maxSample) maxSample = sample;
        }
        expect(maxSample, greaterThan(1500));
      }

      // Each instrumental stem produces a unique waveform signature
      expect(bowlsWav, isNot(equals(kalimbaWav)));
      expect(kalimbaWav, isNot(equals(celloWav)));
      expect(celloWav, isNot(equals(guitarWav)));

      // Verify new instrumental-nature presets load cleanly into multi-track mixer
      final kalimbaPreset = SerenRelaxationCatalog.curatedPresets
          .firstWhere((p) => p.id == 'preset_kalimba_forest_stream');
      await provider.loadSoundscape(kalimbaPreset);
      expect(
        provider.activeTracks.map((t) => t.soundId).toList(),
        ['softKalimba', 'forest', 'riverStream'],
      );

      final bowlsPreset = SerenRelaxationCatalog.curatedPresets
          .firstWhere((p) => p.id == 'preset_bowls_cello_rain');
      await provider.loadSoundscape(bowlsPreset);
      expect(
        provider.activeTracks.map((t) => t.soundId).toList(),
        ['singingBowls', 'warmCelloDrone', 'rainWindow'],
      );
    });

    test('Distance & Stereo synthesis produces distinct 2-channel PCM WAV data', () {
      final nearBytes = AmbientSoundService.synthesizeTrackWavBytes(
        'rain',
        distance: SoundDistance.near,
        stereoPosition: StereoPosition.center,
      );
      final farBytes = AmbientSoundService.synthesizeTrackWavBytes(
        'rain',
        distance: SoundDistance.far,
        stereoPosition: StereoPosition.center,
      );
      final leftBytes = AmbientSoundService.synthesizeTrackWavBytes(
        'rain',
        distance: SoundDistance.balanced,
        stereoPosition: StereoPosition.left,
      );
      final rightBytes = AmbientSoundService.synthesizeTrackWavBytes(
        'rain',
        distance: SoundDistance.balanced,
        stereoPosition: StereoPosition.right,
      );

      // Verify RIFF WAV header & 2-channel stereo format (channels == 2 at byte 22)
      expect(nearBytes.length, greaterThan(44));
      final headerView = ByteData.sublistView(nearBytes, 0, 44);
      expect(headerView.getUint16(22, Endian.little), 2);

      // Verify Near vs Far produce genuinely different acoustic waveforms
      expect(nearBytes, isNot(equals(farBytes)));
      // Verify Left vs Right produce genuinely different stereo channel balances
      expect(leftBytes, isNot(equals(rightBytes)));
    });

    test('Dual-buffer 1.5s loop crossfade polisher & Per-track Warmth EQ shape waveforms cleanly', () async {
      expect(AmbientSoundService.crossfadeOverlapSeconds, 1.5);

      // Direct verification of equal-power dual-buffer crossfade math
      final primary = Float64List.fromList([0.0, 0.2, 0.4, 0.6, 0.8, 1.0]);
      final tail = Float64List.fromList([1.0, 1.0, 1.0, 1.0]);
      AmbientSoundService.applyDualBufferLoopCrossfade(primary, tail);
      expect(primary[0], closeTo(1.0, 1e-6)); // Start matches continuous tail[0]
      expect(primary[3], closeTo(0.6, 1e-6)); // End of overlap seamlessly matches body[3]
      // Midpoint i=1 (u = 1/3): cos(pi/6) * 1.0 + sin(pi/6) * 0.2
      expect(
        primary[1],
        closeTo(cos(pi / 6.0) * 1.0 + sin(pi / 6.0) * 0.2, 1e-6),
      );
      expect(primary[4], closeTo(0.8, 1e-6));
      expect(primary[5], closeTo(1.0, 1e-6));

      // Warmth (-1.0) vs Neutral (0.0) vs Bright (+1.0) produce distinct WAV waveforms
      final warmWav = AmbientSoundService.synthesizeTrackWavBytes(
        'rain',
        toneWarmth: -1.0,
      );
      final neutralWav = AmbientSoundService.synthesizeTrackWavBytes(
        'rain',
        toneWarmth: 0.0,
      );
      final brightWav = AmbientSoundService.synthesizeTrackWavBytes(
        'rain',
        toneWarmth: 1.0,
      );

      expect(warmWav, isNot(equals(neutralWav)));
      expect(brightWav, isNot(equals(neutralWav)));
      expect(warmWav, isNot(equals(brightWav)));

      // Warm EQ (-1.0) measurably lowers sample-to-sample high-frequency delta vs Bright EQ (+1.0)
      double avgAbsDelta(Uint8List wav) {
        final view = ByteData.sublistView(wav, 44);
        double total = 0;
        var prev = view.getInt16(0, Endian.little);
        int count = 0;
        for (int off = 4; off < view.lengthInBytes && count < 10000; off += 4) {
          final cur = view.getInt16(off, Endian.little);
          total += (cur - prev).abs();
          prev = cur;
          count++;
        }
        return total / count;
      }

      expect(avgAbsDelta(warmWav), lessThan(avgAbsDelta(neutralWav)));
      expect(avgAbsDelta(neutralWav), lessThan(avgAbsDelta(brightWav)));

      // Provider updates toneWarmth, persists in custom soundscape JSON, and triggers refresh
      await provider.playSingleSound('rain');
      final beforeCalls = fakeAudioService.refreshVariantCalls;
      await provider.setTrackToneWarmth('rain', -0.7);
      expect(provider.activeTracks.first.toneWarmth, closeTo(-0.7, 0.001));
      expect(provider.activeTracks.first.toneLabel, 'Warm');
      expect(fakeAudioService.refreshVariantCalls, beforeCalls + 1);

      final roundtrip = SoundMixerTrackConfig.fromJson(
        provider.activeTracks.first.toJson(),
      );
      expect(roundtrip.toneWarmth, closeTo(-0.7, 0.001));
    });

    test('Multi-track mixer supports adding/removing tracks, distance, stereo, and volumes', () async {
      await provider.playSingleSound('rain');
      expect(provider.isMixerPlaying, isTrue);
      expect(provider.activeTracks.length, 1);
      expect(provider.activeTracks.first.soundId, 'rain');

      // Add second and third tracks
      await provider.toggleTrackInMix('thunderstorm');
      await provider.toggleTrackInMix('fireplace');
      expect(provider.activeTracks.length, 3);

      // Adjust individual track volume, distance, and stereo position
      await provider.setTrackVolume('fireplace', 0.85);
      await provider.setTrackDistance('thunderstorm', SoundDistance.far);
      await provider.setTrackStereoPosition('fireplace', StereoPosition.right);

      final thunderTrack = provider.activeTracks
          .firstWhere((t) => t.soundId == 'thunderstorm');
      final fireTrack =
          provider.activeTracks.firstWhere((t) => t.soundId == 'fireplace');
      expect(thunderTrack.distance, SoundDistance.far);
      expect(fireTrack.stereoPosition, StereoPosition.right);
      expect(fireTrack.volume, closeTo(0.85, 0.001));
      expect(fakeAudioService.refreshVariantCalls, greaterThanOrEqualTo(2));

      // Verify effective volume formula incorporates distance attenuation, master, duck, and fade
      final effectiveVol = provider.computeTrackEffectiveVolume(fireTrack);
      expect(
        effectiveVol,
        closeTo(
          0.85 *
              SoundDistance.near.acousticAttenuation *
              provider.masterVolume,
          0.01,
        ),
      );

      // Mute track
      await provider.toggleTrackMute('fireplace');
      final mutedFire =
          provider.activeTracks.firstWhere((t) => t.soundId == 'fireplace');
      expect(mutedFire.isMuted, isTrue);
      expect(provider.computeTrackEffectiveVolume(mutedFire), 0.0);
    });

    test('Custom Soundscape CRUD persists and restores across sessions', () async {
      await provider.playSingleSound('oceanWaves');
      await provider.toggleTrackInMix('gentleWind');

      final saved =
          await provider.saveCurrentMixAsSoundscape('Midnight Coastal Mix');
      expect(provider.customSoundscapes.length, 1);
      expect(saved.displayName, 'Midnight Coastal Mix');

      await provider.renameCustomSoundscape(saved.id, 'Calm Harbor Mix');
      expect(provider.customSoundscapes.first.displayName, 'Calm Harbor Mix');

      final duplicate =
          await provider.duplicateSoundscape(provider.customSoundscapes.first);
      expect(provider.customSoundscapes.length, 2);
      expect(duplicate.displayName, contains('Calm Harbor Mix'));

      // Reload from StorageService
      final restoredProvider = SerenRelaxationProvider(
        storageService,
        ambientSoundService: fakeAudioService,
        ttsService: ttsService,
      );
      expect(restoredProvider.customSoundscapes.length, 2);

      await restoredProvider.deleteCustomSoundscape(duplicate.id);
      expect(restoredProvider.customSoundscapes.length, 1);
      restoredProvider.dispose();
    });
  });

  group('Sleep Timer, Guided Sessions, TTS Narration & Mindful Journal', () {
    test('Sleep timer counts down, fades volume over last 30s, and stops at 0', () async {
      await provider.startMixerPlayback();
      await provider.startPlaybackTimer(1); // 60 seconds
      expect(provider.isTimerActive, isTrue);
      expect(provider.timerRemainingSeconds, 60);
      expect(provider.fadeMultiplier, 1.0);

      // Advance 45 seconds -> 15 seconds remaining (inside 30s fade-out window)
      for (int i = 0; i < 45; i++) {
        await provider.tickTimerSecond();
      }
      expect(provider.timerRemainingSeconds, 15);
      expect(provider.fadeMultiplier, closeTo(0.5, 0.05));

      // Advance remaining 15 seconds -> stops all playback
      for (int i = 0; i < 15; i++) {
        await provider.tickTimerSecond();
      }
      expect(provider.isTimerActive, isFalse);
      expect(provider.isMixerPlaying, isFalse);
      expect(fakeAudioService.stopCalls, greaterThanOrEqualTo(1));
    });

    test('Guided breathing session progresses phases and supports pause/resume/stop', () async {
      final boxSession = SerenRelaxationCatalog.guidedSessions
          .firstWhere((s) => s.id == 'breath_box');
      await provider.startGuidedSession(boxSession, durationMinutes: 2);
      expect(provider.isGuidedSessionRunning, isTrue);
      expect(provider.guidedPhaseIndex, 0);

      // Tick 4 seconds to advance from Inhale (4s) to Hold (4s)
      for (int i = 0; i < 4; i++) {
        provider.tickGuidedSessionSecond();
      }
      expect(provider.guidedPhaseIndex, 1);

      provider.pauseGuidedSession();
      expect(provider.isGuidedSessionPaused, isTrue);
      provider.tickGuidedSessionSecond();
      expect(provider.guidedPhaseIndex, 1); // unchanged while paused

      provider.resumeGuidedSession();
      expect(provider.isGuidedSessionPaused, isFalse);

      provider.stopGuidedSession();
      expect(provider.isGuidedSessionRunning, isFalse);
    });

    test('TTS story narration highlights paragraphs and ducks ambient audio', () async {
      await provider.playSingleSound('rain');
      await provider.openReadingItem('story_lantern_cove', startTts: true);
      expect(provider.isTtsPlaying, isTrue);
      expect(provider.currentReadingParagraphIndex, 0);
      expect(provider.effectiveDuckFactor, closeTo(0.35, 0.01));

      await provider.nextReadingParagraph();
      expect(provider.currentReadingParagraphIndex, 1);

      await provider.pauseReadingTts();
      expect(provider.isTtsPaused, isTrue);
      expect(provider.effectiveDuckFactor, 1.0);

      await provider.resumeReadingTts();
      expect(provider.isTtsPlaying, isTrue);

      await provider.stopReadingTts();
      expect(provider.isTtsPlaying, isFalse);
    });

    test('Mindful prompts support skipping and saving to Echo JournalProvider', () async {
      final prompt = SerenRelaxationCatalog.mindfulPrompts.first;
      provider.skipMindfulPrompt(prompt.id);
      expect(provider.skippedMindfulPromptIds.contains(prompt.id), isTrue);

      provider.resetSkippedMindfulPrompts();
      expect(provider.skippedMindfulPromptIds, isEmpty);

      final savedEntry = await provider.saveMindfulReflectionToJournal(
        prompt: prompt,
        responseText: 'Taking a calm, unhurried breath before starting today.',
        journalProvider: journalProvider,
      );
      expect(savedEntry.tags, contains('Seren'));
      expect(
        journalProvider.journalEntries
            .where((e) => e.tags.contains('Seren'))
            .length,
        1,
      );
    });

    test('Audio interruption gracefully pauses active mixer, TTS, and guided session', () async {
      await provider.playSingleSound('rain');
      await provider.openReadingItem('story_lantern_cove', startTts: true);
      await provider.startGuidedSession(
        SerenRelaxationCatalog.guidedSessions.first,
      );

      await provider.handleAudioInterruption();
      expect(provider.isMixerPlaying, isFalse);
      expect(provider.isTtsPaused, isTrue);
      expect(provider.isGuidedSessionPaused, isTrue);
    });

    test('Extended Anthology catalog has 20+ multi-chapter long-form readings with full EN/ID parity', () {
      final readings = SerenRelaxationCatalog.readings;
      expect(readings.length, 30);

      final multiChapter = readings.where((r) => r.isMultiChapter).toList();
      expect(multiChapter.length, greaterThanOrEqualTo(20));

      for (final item in multiChapter) {
        expect(item.chapterCount, greaterThanOrEqualTo(3));
        expect(item.estimatedMinutes, inInclusiveRange(10, 20));
        expect(
          SerenRelaxationCatalog.sounds.any((s) => s.id == item.pairedSoundId),
          isTrue,
          reason: 'Invalid pairedSoundId ${item.pairedSoundId} for ${item.id}',
        );
        if (item.pairedVisualId != null) {
          expect(
            SerenRelaxationCatalog.visuals.any((v) => v.id == item.pairedVisualId),
            isTrue,
            reason: 'Invalid pairedVisualId ${item.pairedVisualId} for ${item.id}',
          );
        }

        // Verify EN and ID strings resolve cleanly (no raw translation keys leaked)
        for (final code in ['en', 'id']) {
          final map = kNestinTranslations[code]!;
          expect(map[item.titleKey], isNotNull, reason: 'Missing $code key ${item.titleKey}');
          expect(map[item.subtitleKey], isNotNull, reason: 'Missing $code key ${item.subtitleKey}');
          for (final chapter in item.chapters) {
            expect(map[chapter.titleKey], isNotNull, reason: 'Missing $code key ${chapter.titleKey}');
            for (final pKey in chapter.paragraphKeys) {
              expect(map[pKey], isNotNull, reason: 'Missing $code key $pKey');
              expect(map[pKey]!.length, greaterThan(40));
            }
          }
        }
      }
    });

    test('Multi-chapter navigation updates activeReadingChapterIndex, paragraph index, and TTS position', () async {
      await provider.openReadingItem('anthology_clockmaker_harbor');
      expect(provider.activeReading?.id, 'anthology_clockmaker_harbor');
      expect(provider.activeReadingChapterIndex, 0);
      expect(provider.activeReadingParagraphIndex, 0);

      await provider.jumpToReadingChapter(1);
      expect(provider.activeReadingChapterIndex, 1);
      expect(provider.activeReadingParagraphIndex, 3);
      expect(provider.prefs.readingLastParagraphIndex['anthology_clockmaker_harbor'], 3);

      await provider.nextReadingChapter();
      expect(provider.activeReadingChapterIndex, 2);
      expect(provider.activeReadingParagraphIndex, 6);

      await provider.previousReadingChapter();
      expect(provider.activeReadingChapterIndex, 1);
      expect(provider.activeReadingParagraphIndex, 3);

      await provider.jumpToReadingChapter(2, startTts: true);
      expect(provider.isTtsPlaying, isTrue);
      expect(provider.currentReadingParagraphIndex, 6);
      expect(provider.activeReadingChapterIndex, 2);
      await provider.stopReadingTts();
    });

    test('Hardware audio route & Bluetooth disconnect over com.nestin.app/tts pauses active playback cleanly', () async {
      await provider.playSingleSound('rain');
      await provider.startReadingTts(
        item: SerenRelaxationCatalog.readings.first,
      );
      expect(provider.isMixerPlaying, isTrue);
      expect(provider.isTtsPlaying, isTrue);
      expect(provider.pauseOnHeadphoneDisconnect, isTrue);
      expect(provider.pausedByHardwareDisconnect, isFalse);

      // Dispatch genuine platform binary message over com.nestin.app/tts
      final payload = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onAudioRouteDisconnected', {
          'reason': 'device_removed',
          'routeType': 'bluetooth',
          'deviceName': 'Sony WH-1000XM5',
        }),
      );
      await TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .handlePlatformMessage('com.nestin.app/tts', payload, (_) {});
      await Future<void>.delayed(Duration.zero);

      expect(provider.isMixerPlaying, isFalse);
      expect(provider.isTtsPlaying, isFalse);
      expect(provider.isTtsPaused, isTrue);
      expect(provider.pausedByHardwareDisconnect, isTrue);
      expect(provider.lastRouteDisconnectEvent?.isBluetooth, isTrue);
      expect(provider.lastRouteDisconnectEvent?.deviceName, 'Sony WH-1000XM5');

      // Resuming playback clears disconnect banner automatically
      await provider.startMixerPlayback();
      expect(provider.pausedByHardwareDisconnect, isFalse);

      // Disabling preference prevents pause when wired headphones unplug
      await provider.setPauseOnHeadphoneDisconnect(false);
      expect(provider.pauseOnHeadphoneDisconnect, isFalse);
      final wiredPayload = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onAudioRouteDisconnected', {
          'reason': 'becoming_noisy',
          'routeType': 'wired',
        }),
      );
      await TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .handlePlatformMessage('com.nestin.app/tts', wiredPayload, (_) {});
      await Future<void>.delayed(Duration.zero);
      expect(provider.isMixerPlaying, isTrue);
      expect(provider.pausedByHardwareDisconnect, isFalse);

      // Verify preference persists cleanly in JSON
      final roundtrip =
          SerenRelaxationPreferences.fromJson(provider.prefs.toJson());
      expect(roundtrip.pauseOnHeadphoneDisconnect, isFalse);
    });

    test('Native OS MediaSession / MPNowPlayingInfoCenter syncs state and handles lock-screen transport commands', () async {
      expect(provider.isMediaSessionActive, isFalse);

      await provider.playSingleSound('rain');
      await provider.startPlaybackTimer(15);
      expect(provider.isMediaSessionActive, isTrue);

      final synced = ttsService.lastSyncedMediaSession;
      expect(synced, isNotNull);
      expect(synced!.isActive, isTrue);
      expect(synced.isPlaying, isTrue);
      expect(synced.title, 'Gentle Rain');
      expect(synced.timerRemainingSeconds, 15 * 60);
      expect(synced.timerBadge, 'Sleep timer: 15:00');

      Future<void> dispatchTransport(String action) async {
        final payload = const StandardMethodCodec().encodeMethodCall(
          MethodCall('onMediaTransportAction', {'action': action}),
        );
        await TestDefaultBinaryMessengerBinding
            .instance.defaultBinaryMessenger
            .handlePlatformMessage('com.nestin.app/tts', payload, (_) {});
      }

      // Lock-screen Pause keeps session active (pinned) in Paused state so Play button works
      await dispatchTransport('pause');
      expect(provider.isMixerPlaying, isFalse);
      expect(provider.isMediaSessionActive, isTrue);
      expect(ttsService.lastSyncedMediaSession?.isPlaying, isFalse);

      // Lock-screen Play resumes playback
      await dispatchTransport('play');
      expect(provider.isMixerPlaying, isTrue);
      expect(ttsService.lastSyncedMediaSession?.isPlaying, isTrue);

      // Lock-screen Next cycles curated preset
      await dispatchTransport('next');
      expect(provider.activeSoundscapeId, provider.curatedPresets.first.id);

      // Lock-screen Stop halts playback and deactivates media session notification
      await dispatchTransport('stop');
      expect(provider.isMixerPlaying, isFalse);
      expect(provider.isMediaSessionActive, isFalse);
      expect(ttsService.lastSyncedMediaSession?.isActive, isFalse);

      // Disabling lock-screen controls preference clears session and persists in JSON
      await provider.playSingleSound('forest');
      expect(provider.isMediaSessionActive, isTrue);
      await provider.setLockScreenControlsEnabled(false);
      expect(provider.isMediaSessionActive, isFalse);
      expect(ttsService.lastSyncedMediaSession?.isActive, isFalse);

      final roundtrip =
          SerenRelaxationPreferences.fromJson(provider.prefs.toJson());
      expect(roundtrip.lockScreenControlsEnabled, isFalse);
    });
  });

  group('SerenRelaxationScreen Widget Tests (EN & ID)', () {
    testWidgets('Renders all 5 tabs in English and Bahasa Indonesia', (tester) async {
      final settingsProvider = SettingsProvider(storageService);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: journalProvider),
          ],
          child: const MaterialApp(
            home: SerenRelaxationScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Seren Daily Relaxation'), findsOneWidget);
      expect(find.text('Multi-Track Ambient Sound Mixer'), findsOneWidget);

      // Navigate across tabs
      await tester.tap(find.text('Guided Calm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Slow Coherent Breathing'), findsWidgets);

      await tester.tap(find.text('Visuals'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Low-Motion / Static Visuals'), findsOneWidget);

      await tester.tap(find.text('Stories & TTS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('The Lantern by the Quiet Cove'), findsWidgets);

      await tester.tap(find.text('Mindful'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Quiet Morning Intention'), findsWidgets);

      // Switch to Bahasa Indonesia and verify localized labels
      await settingsProvider.setLanguage(AppLanguage.id);
      provider.setTimeOfDayMode(RelaxationTimeOfDayMode.evening);
      await tester.pump();
      expect(find.text('Relaksasi Harian Seren'), findsOneWidget);
    });

    testWidgets('Per-track Warmth EQ slider & 1.5s crossfade badge update interactively in EN & ID', (tester) async {
      final settingsProvider = SettingsProvider(storageService);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: journalProvider),
          ],
          child: const MaterialApp(
            home: SerenRelaxationScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1.5s Crossfade Loop'), findsOneWidget);
      expect(find.byKey(const Key('seren_track_warmth_rain')), findsOneWidget);
      final badgeFinder = find.byKey(const Key('seren_track_warmth_badge_rain'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('Balanced'), findsWidgets);

      await provider.setTrackToneWarmth('rain', -0.8);
      await tester.pump();
      expect(find.text('Warm'), findsOneWidget);

      await provider.setTrackToneWarmth('rain', 0.8);
      await tester.pump();
      expect(find.text('Bright'), findsOneWidget);

      // Switch to Bahasa Indonesia and verify localized tone & crossfade labels
      await settingsProvider.setLanguage(AppLanguage.id);
      await tester.pump();
      expect(find.text('Putaran Crossfade 1,5 dtk'), findsOneWidget);
      expect(find.text('Cerah'), findsOneWidget);

      // Scroll badge into view and tap to reset tone back to balanced/seimbang
      await tester.ensureVisible(badgeFinder);
      await tester.pump();
      await tester.tap(badgeFinder);
      await tester.pump();
      expect(provider.activeTracks.first.toneWarmth, 0.0);
      expect(find.text('Seimbang'), findsWidgets);
    });

    testWidgets('Headphone/Bluetooth disconnect banner & preference switch render in EN & ID', (tester) async {
      final settingsProvider = SettingsProvider(storageService);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: journalProvider),
          ],
          child: const MaterialApp(
            home: SerenRelaxationScreen(),
          ),
        ),
      );
      await tester.pump();

      await provider.playSingleSound('rain');
      await provider.handleAudioInterruption(
        disconnectEvent: AudioRouteDisconnectEvent(
          reason: 'old_device_unavailable',
          routeType: 'bluetooth',
          deviceName: 'Pixel Buds',
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('seren_headphone_disconnect_banner')), findsOneWidget);
      expect(
        find.text('Paused safely — Bluetooth audio disconnected (Pixel Buds)'),
        findsOneWidget,
      );

      // Switch to ID and verify localized disconnect message
      await settingsProvider.setLanguage(AppLanguage.id);
      await tester.pump();
      expect(
        find.text('Dijeda dengan aman — audio Bluetooth terputus (Pixel Buds)'),
        findsOneWidget,
      );

      // Dismiss banner
      await tester.tap(find.byKey(const Key('seren_dismiss_disconnect_banner')));
      await tester.pump();
      expect(find.byKey(const Key('seren_headphone_disconnect_banner')), findsNothing);

      // Active playback shows localized lock-screen media controls badge in ID and EN
      await provider.startMixerPlayback();
      await tester.pump();
      expect(find.byKey(const Key('seren_media_session_active_badge')), findsOneWidget);
      expect(find.text('Kontrol layar kunci aktif'), findsOneWidget);

      await settingsProvider.setLanguage(AppLanguage.en);
      await tester.pump();
      expect(find.text('Lock-screen controls active'), findsOneWidget);

      await provider.stopAllPlayback();
      await tester.pump();
      expect(find.byKey(const Key('seren_media_session_active_badge')), findsNothing);
    });

    testWidgets('Anthology filter chips and multi-chapter reader controls work in EN and ID', (tester) async {
      final settingsProvider = SettingsProvider(storageService);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: journalProvider),
          ],
          child: const MaterialApp(
            home: SerenRelaxationScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Stories & TTS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Open multi-chapter anthology story via provider and jump chapter via UI pill
      await provider.openReadingItem('travelogue_java_night_express');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Across the Mist of Java by Midnight Local Train'), findsWidgets);
      expect(find.byKey(const Key('seren_active_chapter_badge')), findsOneWidget);
      expect(find.text('Chapter 1 of 3'), findsOneWidget);
      expect(find.byKey(const Key('seren_chapter_heading_travelogue_java_night_express_0')), findsOneWidget);

      final ch2Pill = find.byKey(const Key('seren_chapter_pill_travelogue_java_night_express_1'));
      await tester.ensureVisible(ch2Pill);
      await tester.pump();
      await tester.tap(ch2Pill);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(provider.activeReadingChapterIndex, 1);
      expect(find.text('Chapter 2 of 3'), findsOneWidget);

      // Filter by Travelogues & switch locale to Bahasa Indonesia
      final travelFilter = find.byKey(const Key('seren_reading_filter_travelogues'));
      await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
      await tester.pump();
      await tester.ensureVisible(travelFilter);
      await tester.pump();
      await tester.tap(travelFilter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('seren_reading_tile_travelogue_java_night_express')), findsOneWidget);

      await settingsProvider.setLanguage(AppLanguage.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Bab 2 dari 3'), findsOneWidget);
    });
  });
}
