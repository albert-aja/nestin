import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:nestin/data/models/hobby_milestone.dart';
import 'package:nestin/data/models/hobby_item.dart';
import 'package:nestin/data/models/hobby_practice_session.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/hobby_provider.dart';
import 'package:nestin/ui/widgets/hobby_practice_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HobbyMilestone Model Tests', () {
    test('Standard milestones contain 8 tiers with 50-hour milestone', () {
      final milestones = HobbyMilestone.standardMilestones;
      expect(milestones.length, equals(8));

      // 50-hour milestone
      final halfCentury = milestones.firstWhere((m) => m.id == 'half_century');
      expect(halfCentury.requiredHours, equals(50));
      expect(halfCentury.title, equals('Half Century Club'));
      expect(halfCentury.iconEmoji, equals('🏆'));
    });

    test('isUnlocked verifies threshold correctly', () {
      final milestone = HobbyMilestone.standardMilestones
          .firstWhere((m) => m.id == 'half_century');

      expect(milestone.isUnlocked(49.9), isFalse);
      expect(milestone.isUnlocked(50.0), isTrue);
      expect(milestone.isUnlocked(75.0), isTrue);
    });

    test('All milestone thresholds follow ascending order', () {
      final thresholds =
          HobbyMilestone.standardMilestones.map((m) => m.requiredHours).toList();
      expect(thresholds, equals([1, 5, 10, 25, 50, 100, 250, 500]));
    });
  });

  group('HobbyItem Model Tests', () {
    test('totalHoursPracticed converts minutes accurately', () {
      final hobby = HobbyItem(
        id: 'h1',
        name: 'Guitar',
        category: 'Music',
        totalMinutesPracticed: 1560, // 26.0 hours
        targetHours: 50,
        createdAt: DateTime.now(),
      );

      expect(hobby.totalHoursPracticed, equals(26.0));
      expect(hobby.progressToTarget, closeTo(0.52, 0.001));
    });

    test('unlockedMilestones and nextMilestone detect progression', () {
      final guitar = HobbyItem(
        id: 'h1',
        name: 'Guitar',
        category: 'Music',
        totalMinutesPracticed: 1560, // 26h
        targetHours: 50,
        createdAt: DateTime.now(),
      );

      // At 26h: 1h, 5h, 10h, 25h are unlocked (4 milestones)
      expect(guitar.unlockedMilestones.length, equals(4));
      expect(guitar.unlockedMilestones.map((m) => m.id),
          containsAll(['first_spark', 'curious_seed', 'dedicated_start', 'quarter_century']));

      // Next milestone should be 50h (half_century)
      expect(guitar.nextMilestone?.id, equals('half_century'));
      expect(guitar.nextMilestone?.requiredHours, equals(50));

      // Progress towards 50h from 25h: (26 - 25) / (50 - 25) = 1/25 = 0.04
      expect(guitar.progressToNextMilestone, closeTo(0.04, 0.001));
    });

    test('JSON serialization roundtrip preserves all fields', () {
      final now = DateTime(2026, 11, 13, 10, 0);
      final hobby = HobbyItem(
        id: 'h_test',
        name: 'Violin',
        category: 'Music',
        iconEmoji: '🎻',
        colorHex: '#8B5CF6',
        targetHours: 100,
        totalMinutesPracticed: 300,
        notes: 'Suzuki method practice',
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      final json = hobby.toJson();
      final restored = HobbyItem.fromJson(json);

      expect(restored.id, equals(hobby.id));
      expect(restored.name, equals('Violin'));
      expect(restored.category, equals('Music'));
      expect(restored.iconEmoji, equals('🎻'));
      expect(restored.colorHex, equals('#8B5CF6'));
      expect(restored.targetHours, equals(100));
      expect(restored.totalMinutesPracticed, equals(300));
      expect(restored.notes, equals('Suzuki method practice'));
      expect(restored.isArchived, isFalse);
    });
  });

  group('HobbyPracticeSession Model Tests', () {
    test('formattedDuration formats minutes and hours cleanly', () {
      final now = DateTime.now();

      final s1 = HobbyPracticeSession(
        id: 's1',
        hobbyId: 'h1',
        hobbyName: 'Guitar',
        durationMinutes: 45,
        sessionDate: now,
        createdAt: now,
      );
      expect(s1.formattedDuration, equals('45m'));

      final s2 = HobbyPracticeSession(
        id: 's2',
        hobbyId: 'h1',
        hobbyName: 'Guitar',
        durationMinutes: 60,
        sessionDate: now,
        createdAt: now,
      );
      expect(s2.formattedDuration, equals('1h'));

      final s3 = HobbyPracticeSession(
        id: 's3',
        hobbyId: 'h1',
        hobbyName: 'Guitar',
        durationMinutes: 90,
        sessionDate: now,
        createdAt: now,
      );
      expect(s3.formattedDuration, equals('1h 30m'));

      final s4 = HobbyPracticeSession(
        id: 's4',
        hobbyId: 'h1',
        hobbyName: 'Guitar',
        durationMinutes: 120,
        sessionDate: now,
        createdAt: now,
      );
      expect(s4.formattedDuration, equals('2h'));
    });

    test('JSON serialization roundtrip preserves session details', () {
      final now = DateTime(2026, 11, 13, 14, 30);
      final session = HobbyPracticeSession(
        id: 's_json',
        hobbyId: 'h1',
        hobbyName: 'Guitar',
        durationMinutes: 75,
        sessionDate: now,
        focusTag: 'Fingerpicking',
        notes: 'Practiced Blackbird intro smoothly',
        rating: 5,
        createdAt: now,
      );

      final json = session.toJson();
      final restored = HobbyPracticeSession.fromJson(json);

      expect(restored.id, equals(session.id));
      expect(restored.hobbyId, equals(session.hobbyId));
      expect(restored.hobbyName, equals('Guitar'));
      expect(restored.durationMinutes, equals(75));
      expect(restored.focusTag, equals('Fingerpicking'));
      expect(restored.notes, equals('Practiced Blackbird intro smoothly'));
      expect(restored.rating, equals(5));
    });
  });

  group('HobbyProvider State & Practice Logging Tests', () {
    late StorageService storageService;
    late HobbyProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      provider = HobbyProvider(storageService);
    });

    test('Initializes starter hobbies and sessions when empty', () {
      expect(provider.hobbies.length, equals(2));
      expect(provider.hobbies[0].name, equals('Acoustic Guitar'));
      expect(provider.hobbies[1].name, equals('Digital Illustration'));
      expect(provider.sessions.length, equals(3));
      expect(provider.totalCumulativeHours, greaterThan(30.0));
      expect(provider.totalBadgesUnlocked, greaterThanOrEqualTo(5));
    });

    test('Log practice session increments hours and records session', () async {
      final initialHours = provider.hobbies[0].totalHoursPracticed;
      final initialSessions = provider.sessions.length;

      final unlocked = await provider.logPracticeSession(
        hobbyId: provider.hobbies[0].id,
        durationMinutes: 60,
        focusTag: 'Scales',
        notes: 'Arpeggios',
        rating: 4,
      );

      // Session added
      expect(provider.sessions.length, equals(initialSessions + 1));
      expect(provider.sessions.first.durationMinutes, equals(60));
      expect(provider.sessions.first.focusTag, equals('Scales'));

      // Total hours increased by 1.0
      expect(provider.hobbies[0].totalHoursPracticed, equals(initialHours + 1.0));
      // No milestone unlocked (went from 26h to 27h)
      expect(unlocked, isEmpty);
    });

    test('Log practice session crossing 50-hour mark unlocks Half Century badge', () async {
      final guitarId = provider.hobbies[0].id;
      // Guitar starts at 1560 min (26h). To reach 50h (3000 min), need 1440 min (24h).
      final unlocked = await provider.logPracticeSession(
        hobbyId: guitarId,
        durationMinutes: 1440, // 24 hours
        focusTag: 'Milestone Push',
        notes: 'Reached the 50 hour mark!',
      );

      // Total hours should be 50.0
      expect(provider.hobbies[0].totalHoursPracticed, equals(50.0));

      // Returned newly unlocked milestones should contain half_century
      expect(unlocked.length, equals(1));
      expect(unlocked.first.id, equals('half_century'));
      expect(unlocked.first.requiredHours, equals(50));
      expect(unlocked.first.title, equals('Half Century Club'));
    });

    test('Delete session rolls back practice minutes', () async {
      final guitarId = provider.hobbies[0].id;
      final hoursBefore = provider.hobbies[0].totalHoursPracticed;

      await provider.logPracticeSession(
        hobbyId: guitarId,
        durationMinutes: 120, // +2h
      );

      expect(provider.hobbies[0].totalHoursPracticed, equals(hoursBefore + 2.0));
      final loggedSessionId = provider.sessions.first.id;

      // Delete the session
      await provider.deleteSession(loggedSessionId);

      // Hours rolled back
      expect(provider.hobbies[0].totalHoursPracticed, equals(hoursBefore));
    });

    test('Add, update, toggleArchive, and delete hobby', () async {
      final newHobby = HobbyItem(
        id: 'h_piano',
        name: 'Piano Practice',
        category: 'Music',
        iconEmoji: '🎹',
        targetHours: 100,
        createdAt: DateTime.now(),
      );

      await provider.addHobby(newHobby);
      expect(provider.hobbies.any((h) => h.id == 'h_piano'), isTrue);

      // Archive toggle
      await provider.toggleArchive('h_piano');
      expect(provider.activeHobbies.any((h) => h.id == 'h_piano'), isFalse);

      await provider.toggleArchive('h_piano');
      expect(provider.activeHobbies.any((h) => h.id == 'h_piano'), isTrue);

      // Delete hobby
      await provider.deleteHobby('h_piano');
      expect(provider.hobbies.any((h) => h.id == 'h_piano'), isFalse);
    });
  });

  group('StorageService Backup & Restore for Hobbies', () {
    test('exportFullBackupJson and restoreFullBackupJson handle hobbies & sessions', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      final now = DateTime(2026, 11, 13, 12, 0);
      final hobbies = <HobbyItem>[
        HobbyItem(
          id: 'h_b1',
          name: 'Guitar',
          category: 'Music',
          totalMinutesPracticed: 3000, // 50 hours
          targetHours: 100,
          createdAt: now,
        ),
      ];
      final sessions = <HobbyPracticeSession>[
        HobbyPracticeSession(
          id: 's_b1',
          hobbyId: 'h_b1',
          hobbyName: 'Guitar',
          durationMinutes: 60,
          sessionDate: now,
          createdAt: now,
        ),
      ];

      await storage.saveHobbies(hobbies);
      await storage.saveHobbySessions(sessions);

      // Export full backup
      final jsonBackup = storage.exportFullBackupJson();
      expect(jsonBackup, contains('"hobbies"'));
      expect(jsonBackup, contains('"hobbySessions"'));
      expect(jsonBackup, contains('Guitar'));
      expect(jsonBackup, contains('s_b1'));

      // Clear prefs
      await prefs.clear();
      final emptyStorage = StorageService(prefs);
      expect(emptyStorage.loadHobbies(), isEmpty);
      expect(emptyStorage.loadHobbySessions(), isEmpty);

      // Restore
      final restored = await emptyStorage.restoreFullBackupJson(jsonBackup);
      expect(restored, isTrue);

      final restoredHobbies = emptyStorage.loadHobbies();
      final restoredSessions = emptyStorage.loadHobbySessions();

      expect(restoredHobbies.length, equals(1));
      expect(restoredHobbies.first.name, equals('Guitar'));
      expect(restoredHobbies.first.totalHoursPracticed, equals(50.0));
      expect(restoredSessions.length, equals(1));
      expect(restoredSessions.first.id, equals('s_b1'));
    });
  });

  group('HobbyPracticeSheet Widget Tests', () {
    late StorageService storageService;
    late HobbyProvider hobbyProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      hobbyProvider = HobbyProvider(storageService);
    });

    testWidgets('Renders HobbyPracticeSheet with statistics and hobbies',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<HobbyProvider>.value(
                  value: hobbyProvider,
                ),
              ],
              child: const HobbyPracticeSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title & Tabs check
      expect(find.text('Hobby Practice Space'), findsOneWidget);
      expect(find.textContaining('Hobbies & Milestones'), findsOneWidget);
      expect(find.textContaining('Session Logs'), findsOneWidget);

      // Stats check
      expect(find.text('Total Practiced'), findsOneWidget);
      expect(find.text('Badges'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);

      // Hobby cards check
      expect(find.text('Acoustic Guitar'), findsOneWidget);
      expect(find.text('Digital Illustration'), findsOneWidget);

      // 1-tap quick log buttons check
      expect(find.text('+30m'), findsWidgets);
      expect(find.text('+60m'), findsWidgets);

      // Milestone badge labels
      expect(find.textContaining('Half Century Club (50h)'), findsOneWidget);
    });

    testWidgets('Tapping +30m logs practice session and updates state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<HobbyProvider>.value(
                  value: hobbyProvider,
                ),
              ],
              child: const HobbyPracticeSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final initialSessions = hobbyProvider.sessions.length;

      // Find first +30m button and tap it
      final quickLogBtn = find.text('+30m').first;
      await tester.tap(quickLogBtn);
      await tester.pumpAndSettle();

      // Verify sessions increased
      expect(hobbyProvider.sessions.length, equals(initialSessions + 1));
      expect(hobbyProvider.sessions.first.durationMinutes, equals(30));

      // Switch to Session Logs tab
      await tester.tap(find.textContaining('Session Logs'));
      await tester.pumpAndSettle();

      // Recent practice session should be visible
      expect(find.text('Acoustic Guitar'), findsWidgets);
      expect(find.text('30m'), findsWidgets);
    });
  });
}
