import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('APK Bundle Slimming & Mascot Asset Tests', () {
    test('Raw sheets are excluded from runtime assets directory', () {
      final runtimeSheetsDir = Directory('assets/mascots/sheets');
      expect(
        runtimeSheetsDir.existsSync(),
        isFalse,
        reason:
            'Raw expression sheets (~8 MB) must not live inside assets/ to keep mobile APKs slim.',
      );
    });

    test('Source art sheets are safely preserved under source_art/mascots/sheets', () {
      final sourceArtSheetsDir = Directory('source_art/mascots/sheets');
      expect(
        sourceArtSheetsDir.existsSync(),
        isTrue,
        reason:
            'All 14 source art sheets must be archived under source_art/mascots/sheets.',
      );

      final files = sourceArtSheetsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg'))
          .toList();
      expect(files.length, 14, reason: 'Expected all 14 raw sheet JPG files in source_art.');
    });

    test('Sliced sprite library contains 84 transparent PNGs totaling < 2 MB', () {
      final spritesDir = Directory('assets/mascots/sprites');
      expect(spritesDir.existsSync(), isTrue);

      final expectedCounts = {
        'roo': 18,
        'seren': 18,
        'echo': 12,
        'pippin': 12,
        'twill': 12,
        'scout': 12,
      };

      int totalPngCount = 0;
      int totalByteLength = 0;

      expectedCounts.forEach((bird, count) {
        final birdDir = Directory('assets/mascots/sprites/$bird');
        expect(birdDir.existsSync(), isTrue, reason: 'Missing sprite directory for $bird');

        final pngs = birdDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.png'))
            .toList();
        expect(pngs.length, count,
            reason: 'Expected $count sprites for $bird, found ${pngs.length}');

        totalPngCount += pngs.length;
        for (final png in pngs) {
          totalByteLength += png.lengthSync();
        }
      });

      expect(totalPngCount, 84);
      // Total size must be under 2.0 MB (actual is ~1.8 MB)
      expect(totalByteLength, lessThan(2 * 1024 * 1024));
    });

    test('pubspec.yaml registers sprite directories and excludes sheets', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec.contains('- assets/mascots/sprites/roo/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/seren/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/echo/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/pippin/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/twill/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/scout/'), isTrue);
      expect(pubspec.contains('- assets/mascots/flock_mascots.jpg'), isTrue);

      // Must not register sheets
      expect(pubspec.contains('sheets'), isFalse,
          reason: 'pubspec.yaml must not register sheets in assets list.');
    });
  });
}
