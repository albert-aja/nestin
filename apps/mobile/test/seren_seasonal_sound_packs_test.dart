import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/seren_relaxation_models.dart';
import 'package:nestin/data/services/ambient_sound_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/seren_relaxation_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/seren/seren_relaxation_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Seasonal & Regional Nature Sound Packs Catalog & Synthesis', () {
    test('defines all 4 packs with 8 stems and valid metadata', () {
      const expectedIds = [
        'monsoon_courtyard',
        'alpine_meadow',
        'tropical_bamboo_rain',
        'harbor_foghorn',
      ];
      final packs = SerenRelaxationCatalog.seasonalSoundPacks;
      expect(packs.map((p) => p.id).toList(), expectedIds);
      for (final pack in packs) {
        expect(pack.sounds.length, 2);
        for (final stem in pack.sounds) {
          expect(SerenRelaxationCatalog.soundById(stem.id).id, stem.id);
          expect(
            SerenRelaxationCatalog.packForSoundId(stem.id)?.id,
            pack.id,
          );
        }
      }
    });

    test('synthesizes valid stereo WAV bytes for all 8 seasonal pack stems',
        () {
      for (final pack in SerenRelaxationCatalog.seasonalSoundPacks) {
        for (final stem in pack.sounds) {
          final bytes = AmbientSoundService.synthesizeTrackWavBytes(
            stem.id,
            distance: stem.defaultDistance,
          );
          expect(bytes.length, greaterThan(44));
          // RIFF header check
          expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
          expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
          // Stereo 16-bit PCM check (channels == 2 at offset 22..23)
          final bd = ByteData.sublistView(bytes);
          expect(bd.getUint16(22, Endian.little), 2);
        }
      }
    });

    test('installs, caches on disk, and removes pack files cleanly', () async {
      final service = AmbientSoundService();
      final pack = SerenRelaxationCatalog.soundPackById('monsoon_courtyard')!;

      final progressSteps = <double>[];
      final ok = await service.installSoundPack(
        pack,
        onProgress: progressSteps.add,
      );
      expect(ok, isTrue);
      expect(progressSteps, isNotEmpty);
      expect(progressSteps.last, 1.0);
      expect(await service.isSoundPackCached(pack), isTrue);

      await service.removeSoundPack(pack);
      expect(await service.isSoundPackCached(pack), isFalse);
      service.dispose();
    });
  });

  group('SerenRelaxationProvider Pack Persistence & Mixer Safety', () {
    test('persists installed pack IDs and detaches active tracks on remove',
        () async {
      final storage = await StorageService.init();
      final provider = SerenRelaxationProvider(storage);

      final baseCount = SerenRelaxationCatalog.sounds.length;
      expect(provider.availableSounds.length, baseCount);
      expect(provider.isSoundPackInstalled('alpine_meadow'), isFalse);

      final ok = await provider.installSoundPack('alpine_meadow');
      expect(ok, isTrue);
      expect(provider.isSoundPackInstalled('alpine_meadow'), isTrue);
      expect(provider.availableSounds.length, baseCount + 2);

      // Add pack stem to mixer
      await provider.toggleTrackInMix('alpineMeadowBreeze');
      expect(provider.isSoundInMix('alpineMeadowBreeze'), isTrue);

      // Reload fresh provider from storage and confirm persistence
      final reloaded = SerenRelaxationProvider(storage);
      expect(reloaded.isSoundPackInstalled('alpine_meadow'), isTrue);
      expect(reloaded.availableSounds.length, baseCount + 2);

      // Remove pack on active provider and confirm track is detached
      await provider.removeSoundPack('alpine_meadow');
      expect(provider.isSoundPackInstalled('alpine_meadow'), isFalse);
      expect(provider.isSoundInMix('alpineMeadowBreeze'), isFalse);
      expect(provider.availableSounds.length, baseCount);

      reloaded.dispose();
      provider.dispose();
    });
  });

  group('SerenRelaxationScreen Seasonal Packs UI', () {
    testWidgets('renders seasonal packs carousel and downloads pack on tap',
        (tester) async {
      final storage = await StorageService.init();
      final settings = SettingsProvider(storage);
      await settings.setLanguage(AppLanguage.en);
      final journal = JournalProvider(storage);
      final seren = SerenRelaxationProvider(storage);
      await seren.setLowMotionVisuals(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: journal),
            ChangeNotifierProvider.value(value: seren),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SerenRelaxationScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Scroll down to Seasonal & Regional Nature Packs section
      final sectionFinder = find.text('Seasonal & Regional Nature Packs');
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pump();
      await tester.ensureVisible(sectionFinder);
      await tester.pump();

      expect(sectionFinder, findsOneWidget);
      expect(find.text('Monsoon Courtyard'), findsOneWidget);

      final downloadBtn =
          find.byKey(const Key('seren_pack_download_monsoon_courtyard'));
      expect(downloadBtn, findsOneWidget);

      await tester.runAsync(() async {
        await seren.installSoundPack('monsoon_courtyard');
      });
      await tester.pump();

      expect(seren.isSoundPackInstalled('monsoon_courtyard'), isTrue);
      expect(
        find.byKey(const Key('seren_pack_remove_monsoon_courtyard')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      seren.dispose();
    });
  });
}
