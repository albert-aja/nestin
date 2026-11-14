import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/dashboard_config.dart';
import 'package:nestin/data/models/reading_item.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/dashboard_provider.dart';
import 'package:nestin/providers/reading_provider.dart';
import 'package:nestin/ui/widgets/reading_progress_card.dart';
import 'package:nestin/ui/widgets/reading_tracker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingItem Model Tests', () {
    test('Computes progressFraction, percentageCompletion, and pagesRemaining',
        () {
      final now = DateTime(2026, 11, 14, 9, 0);
      final book = ReadingItem(
        id: 'b1',
        title: 'Atomic Habits',
        author: 'James Clear',
        category: 'Self-Growth',
        currentPage: 160,
        totalPages: 320,
        status: ReadingStatus.currentlyReading,
        createdAt: now,
      );

      expect(book.safeCurrentPage, equals(160));
      expect(book.progressFraction, closeTo(0.5, 0.001));
      expect(book.percentageCompletion, equals(50));
      expect(book.formattedPercentage, equals('50%'));
      expect(book.pagesRemaining, equals(160));
      expect(book.isCompleted, isFalse);
      expect(book.formattedProgress, equals('160 / 320 pages (50%)'));
    });

    test('Zero-division and bounds guards protect getters', () {
      final now = DateTime(2026, 11, 14, 9, 0);
      final zeroTotal = ReadingItem(
        id: 'b_zero',
        title: 'Draft Article',
        currentPage: 25,
        totalPages: 0,
        createdAt: now,
      );
      expect(zeroTotal.safeCurrentPage, equals(0));
      expect(zeroTotal.progressFraction, equals(0.0));
      expect(zeroTotal.percentageCompletion, equals(0));
      expect(zeroTotal.pagesRemaining, equals(0));
      expect(zeroTotal.isCompleted, isFalse);

      final overPage = ReadingItem(
        id: 'b_over',
        title: 'Short Essay',
        currentPage: 150,
        totalPages: 100,
        createdAt: now,
      );
      expect(overPage.safeCurrentPage, equals(100));
      expect(overPage.progressFraction, equals(1.0));
      expect(overPage.percentageCompletion, equals(100));
      expect(overPage.pagesRemaining, equals(0));
      expect(overPage.isCompleted, isTrue);

      final negativePage = ReadingItem(
        id: 'b_neg',
        title: 'Novel',
        currentPage: -10,
        totalPages: 200,
        createdAt: now,
      );
      expect(negativePage.safeCurrentPage, equals(0));
      expect(negativePage.progressFraction, equals(0.0));
      expect(negativePage.percentageCompletion, equals(0));
      expect(negativePage.pagesRemaining, equals(200));
    });

    test('JSON serialization roundtrip preserves all ReadingItem fields', () {
      final created = DateTime(2026, 11, 1, 10, 0);
      final started = DateTime(2026, 11, 2, 20, 0);
      final finished = DateTime(2026, 11, 10, 22, 15);
      final item = ReadingItem(
        id: 'b_json',
        title: 'Deep Work',
        author: 'Cal Newport',
        category: 'Productivity',
        format: ReadingFormat.ebook,
        currentPage: 296,
        totalPages: 296,
        status: ReadingStatus.finished,
        rating: 5,
        notes: 'Batch shallow work and guard deep focus blocks.',
        startedAt: started,
        finishedAt: finished,
        createdAt: created,
        updatedAt: finished,
      );

      final restored = ReadingItem.fromJson(item.toJson());
      expect(restored.id, equals('b_json'));
      expect(restored.title, equals('Deep Work'));
      expect(restored.author, equals('Cal Newport'));
      expect(restored.category, equals('Productivity'));
      expect(restored.format, equals(ReadingFormat.ebook));
      expect(restored.currentPage, equals(296));
      expect(restored.totalPages, equals(296));
      expect(restored.status, equals(ReadingStatus.finished));
      expect(restored.rating, equals(5));
      expect(restored.notes, contains('deep focus'));
      expect(restored.startedAt, equals(started));
      expect(restored.finishedAt, equals(finished));
    });
  });

  group('ReadingProvider State & Persistence Tests', () {
    late StorageService storage;
    late ReadingProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
      provider = ReadingProvider(storage);
    });

    test('Initializes starter books and computes aggregate stats', () {
      expect(provider.totalBooksCount, equals(3));
      expect(provider.currentlyReadingCount, equals(1));
      expect(provider.wantToReadCount, equals(1));
      expect(provider.finishedBooksCount, equals(1));
      expect(provider.totalPagesRead, equals(144 + 0 + 296));
      expect(provider.primaryActiveBook?.title, equals('Atomic Habits'));
    });

    test('updatePageProgress updates pages, status transitions, and persists',
        () async {
      final queueBook = provider.wantToReadItems.first;
      expect(queueBook.currentPage, equals(0));
      expect(queueBook.status, equals(ReadingStatus.wantToRead));

      // Moving past page 0 transitions wantToRead -> currentlyReading
      final finished1 = await provider.updatePageProgress(queueBook.id, 100);
      expect(finished1, isFalse);
      final reading = provider.findById(queueBook.id)!;
      expect(reading.currentPage, equals(100));
      expect(reading.status, equals(ReadingStatus.currentlyReading));
      expect(reading.startedAt, isNotNull);
      expect(reading.percentageCompletion, equals(25));

      // Reaching totalPages transitions to finished and returns true
      final finished2 =
          await provider.updatePageProgress(queueBook.id, queueBook.totalPages);
      expect(finished2, isTrue);
      final completed = provider.findById(queueBook.id)!;
      expect(completed.currentPage, equals(queueBook.totalPages));
      expect(completed.status, equals(ReadingStatus.finished));
      expect(completed.percentageCompletion, equals(100));
      expect(completed.finishedAt, isNotNull);

      // Re-reading by stepping back reverts finished -> currentlyReading
      final finished3 = await provider.updatePageProgress(queueBook.id, 200);
      expect(finished3, isFalse);
      final reopened = provider.findById(queueBook.id)!;
      expect(reopened.status, equals(ReadingStatus.currentlyReading));
      expect(reopened.finishedAt, isNull);

      // Verify persistence across new provider instance
      final reloaded = ReadingProvider(storage);
      expect(reloaded.findById(queueBook.id)?.currentPage, equals(200));
    });

    test('incrementPages clamps cleanly between 0 and totalPages', () async {
      final active = provider.primaryActiveBook!;
      await provider.incrementPages(active.id, 20);
      expect(provider.findById(active.id)?.currentPage, equals(164));

      await provider.incrementPages(active.id, -500);
      expect(provider.findById(active.id)?.currentPage, equals(0));

      final justCompleted = await provider.incrementPages(active.id, 9999);
      expect(justCompleted, isTrue);
      expect(
          provider.findById(active.id)?.currentPage, equals(active.totalPages));
    });

    test('addBook, updateBook, setStatus, updateNotesAndRating, deleteBook',
        () async {
      final now = DateTime.now();
      await provider.addBook(
        ReadingItem(
          id: 'b_custom',
          title: 'Designing Data-Intensive Applications',
          author: 'Martin Kleppmann',
          category: 'Tech',
          format: ReadingFormat.ebook,
          currentPage: 61,
          totalPages: 611,
          createdAt: now,
        ),
      );

      final added = provider.findById('b_custom')!;
      expect(added.status, equals(ReadingStatus.currentlyReading));
      expect(added.percentageCompletion, equals(10));

      await provider.updateNotesAndRating(
        'b_custom',
        notes: 'Great chapter on replication.',
        rating: 5,
      );
      expect(provider.findById('b_custom')?.rating, equals(5));
      expect(provider.findById('b_custom')?.notes, contains('replication'));

      await provider.setStatus('b_custom', ReadingStatus.finished);
      expect(provider.findById('b_custom')?.currentPage, equals(611));
      expect(provider.findById('b_custom')?.percentageCompletion, equals(100));

      await provider.setStatus('b_custom', ReadingStatus.wantToRead);
      expect(provider.findById('b_custom')?.currentPage, equals(0));

      await provider.deleteBook('b_custom');
      expect(provider.findById('b_custom'), isNull);
    });
  });

  group('StorageService & DashboardConfig Reading Integration Tests', () {
    test('exportFullBackupJson and restoreFullBackupJson preserve readingItems',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      final now = DateTime(2026, 11, 14, 8, 30);
      await storage.saveReadingItems([
        ReadingItem(
          id: 'b_backup',
          title: 'Clean Architecture',
          author: 'Robert C. Martin',
          category: 'Tech',
          currentPage: 120,
          totalPages: 400,
          status: ReadingStatus.currentlyReading,
          createdAt: now,
        ),
      ]);

      final jsonBackup = storage.exportFullBackupJson();
      expect(jsonBackup, contains('"readingItems"'));
      expect(jsonBackup, contains('Clean Architecture'));

      await storage.saveReadingItems([]);
      expect(storage.loadReadingItems(), isEmpty);

      final restored = await storage.restoreFullBackupJson(jsonBackup);
      expect(restored, isTrue);

      final items = storage.loadReadingItems();
      expect(items.length, equals(1));
      expect(items.first.title, equals('Clean Architecture'));
      expect(items.first.currentPage, equals(120));
      expect(items.first.percentageCompletion, equals(30));
    });

    test('DashboardConfig migrates legacy order and toggles showReading',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final dash = DashboardProvider(storage);

      expect(dash.config.showReading, isTrue);
      expect(
          dash.config.sectionOrder, contains(DashboardConfig.sectionReading));

      await dash.toggleReading(false);
      expect(dash.config.showReading, isFalse);

      // Legacy config JSON lacking sectionReading still injects it safely
      final legacy = DashboardConfig.fromJson({
        'showWeather': true,
        'sectionOrder': ['weather', 'wellness', 'mood'],
      });
      expect(legacy.sectionOrder, contains(DashboardConfig.sectionReading));
      expect(legacy.showReading, isTrue);
    });
  });

  group('Reading Progress UI Widget Tests', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
    });

    testWidgets(
        'ReadingProgressCard displays active book, slider, and updates percentage',
        (WidgetTester tester) async {
      final provider = ReadingProvider(storage);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ReadingProvider>.value(
              value: provider,
              child: const SingleChildScrollView(
                child: ReadingProgressCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Atomic Habits starts at 144 / 320 (45%)
      expect(find.text('Reading Progress Tracker'), findsOneWidget);
      expect(find.text('Atomic Habits'), findsOneWidget);
      expect(find.text('Page 144 / 320'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Tap quick +10 p button -> 154 / 320 (48%)
      await tester.tap(find.text('+10 p'));
      await tester.pumpAndSettle();

      expect(find.text('Page 154 / 320'), findsOneWidget);
      expect(find.text('48%'), findsOneWidget);

      // Interact directly with Slider callback -> 240 / 320 (75%)
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChangeStart?.call(154.0);
      slider.onChanged?.call(240.0);
      slider.onChangeEnd?.call(240.0);
      await tester.pumpAndSettle();

      expect(find.text('Page 240 / 320'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets(
        'Sliding to totalPages celebrates completion and updates Finished count',
        (WidgetTester tester) async {
      final provider = ReadingProvider(storage, seedDefaults: false);
      await provider.addBook(
        ReadingItem(
          id: 'short_book',
          title: 'The Little Prince',
          author: 'Antoine de Saint-Exupery',
          currentPage: 90,
          totalPages: 100,
          status: ReadingStatus.currentlyReading,
          createdAt: DateTime(2026, 11, 14),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ReadingProvider>.value(
              value: provider,
              child: const SingleChildScrollView(
                child: ReadingProgressCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page 90 / 100'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);

      // Tap +10 p to reach 100 / 100
      await tester.tap(find.text('+10 p'));
      await tester.pumpAndSettle();

      expect(find.text('Book Finished!'), findsOneWidget);
      expect(find.text('Save Takeaway'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Page 100 / 100'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(provider.finishedBooksCount, equals(1));
    });

    testWidgets(
        'ReadingTrackerSheet switches tabs, opens page dialog, and adds new book',
        (WidgetTester tester) async {
      final provider = ReadingProvider(storage);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ReadingProvider>.value(
              value: provider,
              child: const ReadingTrackerSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reading Progress Tracker'), findsOneWidget);
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Reading (1)'), findsOneWidget);
      expect(find.text('Queue (1)'), findsOneWidget);
      expect(find.text('Finished (1)'), findsOneWidget);

      // Switch to Queue tab
      await tester.tap(find.text('Queue (1)'));
      await tester.pumpAndSettle();
      expect(find.text('The Creative Act'), findsOneWidget);

      // Open exact page jump dialog by tapping Page pill
      await tester.tap(find.text('Page 0 / 406'));
      await tester.pumpAndSettle();
      expect(find.text('Update Progress'), findsOneWidget);

      final pageField = find.byType(TextField).first;
      await tester.enterText(pageField, '203');
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);

      await tester.tap(find.text('Save Page'));
      await tester.pumpAndSettle();

      // Moved from Queue (0) to Reading (2)
      expect(find.text('Queue (0)'), findsOneWidget);
      expect(find.text('Reading (2)'), findsOneWidget);

      // Add a new book via CTA
      await tester.tap(find.text('Add Book / Reading'));
      await tester.pumpAndSettle();
      expect(find.text('Add Book / Reading'), findsNWidgets(2)); // Title + CTA

      await tester.enterText(find.byType(TextField).at(0), 'Dune');
      await tester.enterText(find.byType(TextField).at(1), 'Frank Herbert');
      await tester.enterText(find.byType(TextField).at(2), '100');
      await tester.enterText(find.byType(TextField).at(3), '400');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Book'));
      await tester.pumpAndSettle();

      expect(find.text('All (4)'), findsOneWidget);
      expect(provider.findById(provider.items.first.id)?.title, equals('Dune'));
      expect(provider.items.first.percentageCompletion, equals(25));
    });

    testWidgets('ReadingProgressCard renders empty state cleanly',
        (WidgetTester tester) async {
      final emptyProvider = ReadingProvider(storage, seedDefaults: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ReadingProvider>.value(
              value: emptyProvider,
              child: const ReadingProgressCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+ Add Book'), findsOneWidget);
    });
  });
}
