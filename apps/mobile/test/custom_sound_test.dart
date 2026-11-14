import 'package:flutter_test/flutter_test.dart';
import 'package:nestin/data/models/custom_sound.dart';
import 'package:nestin/data/models/alarm.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/alarm_schedule.dart';

void main() {
  group('CustomSound Model Tests', () {
    test('Formats file sizes cleanly', () {
      final small = CustomSound(
        id: 'c1',
        name: 'Chime.wav',
        filePath: '/data/user/0/com.nestin.app/custom_sounds/c1.wav',
        fileSizeBytes: 850,
        importedAt: DateTime.now(),
      );
      expect(small.formattedSize, '850 B');

      final medium = CustomSound(
        id: 'c2',
        name: 'Morning_Beats.mp3',
        filePath: '/data/user/0/com.nestin.app/custom_sounds/c2.mp3',
        fileSizeBytes: 204800, // 200 KB
        importedAt: DateTime.now(),
      );
      expect(medium.formattedSize, '200.0 KB');

      final large = CustomSound(
        id: 'c3',
        name: 'Full_Song.mp3',
        filePath: '/data/user/0/com.nestin.app/custom_sounds/c3.mp3',
        fileSizeBytes: 3145728, // 3 MB
        importedAt: DateTime.now(),
      );
      expect(large.formattedSize, '3.00 MB');
    });

    test('Serializes to and from JSON', () {
      final now = DateTime(2026, 11, 10, 21, 0);
      final sound = CustomSound(
        id: 'custom_123',
        name: 'Favorite_Alarm.mp3',
        filePath: '/storage/emulated/0/Nestin/Favorite_Alarm.mp3',
        fileSizeBytes: 1048576,
        importedAt: now,
      );

      final json = sound.toJson();
      expect(json['id'], 'custom_123');
      expect(json['name'], 'Favorite_Alarm.mp3');
      expect(json['filePath'], '/storage/emulated/0/Nestin/Favorite_Alarm.mp3');

      final parsed = CustomSound.fromJson(json);
      expect(parsed.id, sound.id);
      expect(parsed.name, sound.name);
      expect(parsed.filePath, sound.filePath);
      expect(parsed.fileSizeBytes, sound.fileSizeBytes);
      expect(parsed.importedAt, sound.importedAt);
    });

    test('Alarm correctly persists soundFilePath', () {
      final alarm = Alarm(
        id: 'alarm_custom_sound',
        title: 'Song Alarm',
        hour: 6,
        minute: 30,
        category: AlarmCategory.fromType(AlarmCategoryType.wakeUp),
        schedule: AlarmSchedule.daily(),
        sound: 'custom_123',
        soundFilePath: '/data/user/0/com.nestin.app/custom_sounds/c1.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = alarm.toJson();
      expect(json['soundFilePath'], '/data/user/0/com.nestin.app/custom_sounds/c1.mp3');

      final restored = Alarm.fromJson(json);
      expect(restored.soundFilePath, '/data/user/0/com.nestin.app/custom_sounds/c1.mp3');
      expect(restored.sound, 'custom_123');
    });
  });
}

