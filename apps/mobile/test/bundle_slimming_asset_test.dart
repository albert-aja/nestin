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
            'All 18 source art sheets must be archived under source_art/mascots/sheets.',
      );

      final files = sourceArtSheetsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg'))
          .toList();
      expect(
        files.length,
        greaterThanOrEqualTo(22),
        reason: 'Expected at least 22 raw sheet JPG files in source_art/mascots/sheets.',
      );

      final familyDir = Directory('source_art/mascots/family');
      expect(familyDir.existsSync(), isTrue);
      final familyFiles = familyDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg'))
          .toList();
      expect(
        familyFiles.length,
        greaterThanOrEqualTo(5),
        reason: 'Expected at least 5 family photo JPG canvases in source_art/mascots/family.',
      );
    });

    test('Sliced sprite library contains 132 transparent PNGs totaling < 10 MB', () {
      final spritesDir = Directory('assets/mascots/sprites');
      expect(spritesDir.existsSync(), isTrue);

      final expectedCounts = {
        'roo': 24,
        'seren': 24,
        'echo': 18,
        'pippin': 18,
        'twill': 18,
        'scout': 18,
        'duos': 6,
        'ensembles': 6,
      };

      int totalPngCount = 0;
      int totalByteLength = 0;

      expectedCounts.forEach((dir, count) {
        final spriteSubdir = Directory('assets/mascots/sprites/$dir');
        expect(spriteSubdir.existsSync(), isTrue, reason: 'Missing sprite directory for $dir');

        final pngs = spriteSubdir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.png'))
            .toList();
        expect(pngs.length, count,
            reason: 'Expected $count sprites for $dir, found ${pngs.length}');

        totalPngCount += pngs.length;
        for (final png in pngs) {
          totalByteLength += png.lengthSync();
        }
      });

      expect(totalPngCount, 132);
      // Total size must be under 10.0 MB (actual is ~8.46 MB)
      expect(totalByteLength, lessThan(10 * 1024 * 1024));
    });

    test('pubspec.yaml registers sprite directories and excludes sheets', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec.contains('- assets/mascots/sprites/roo/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/seren/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/echo/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/pippin/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/twill/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/scout/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/duos/'), isTrue);
      expect(pubspec.contains('- assets/mascots/sprites/ensembles/'), isTrue);
      expect(pubspec.contains('- assets/mascots/flock_mascots.jpg'), isTrue);

      // Must not register sheets
      expect(pubspec.contains('sheets'), isFalse,
          reason: 'pubspec.yaml must not register sheets in assets list.');
    });
  });
}
