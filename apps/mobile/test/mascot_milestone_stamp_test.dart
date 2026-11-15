import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/collection_item.dart';
import 'package:nestin/data/models/reading_item.dart';
import 'package:nestin/data/models/routine_item.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/data/services/widget_sync_service.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/hydration_provider.dart';
import 'package:nestin/providers/reading_provider.dart';
import 'package:nestin/providers/routine_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/providers/wearable_provider.dart';
import 'package:nestin/ui/screens/organize/collections_list_screen.dart';
import 'package:nestin/ui/screens/time/routines_screen.dart';
import 'package:nestin/ui/widgets/hydration_sparkline_card.dart';
import 'package:nestin/ui/widgets/mascot_milestone_stamp_overlay.dart';
import 'package:nestin/ui/widgets/reading_progress_slider.dart';

Future<
    ({
      StorageService storage,
      SettingsProvider settings,
      CollectionProvider collections,
      RoutineProvider routines,
      HydrationProvider hydration,
      WearableProvider wearable,
      ReadingProvider reading,
    })> _createStampTestEnv({
  AppLanguage language = AppLanguage.en,
  List<CollectionItem>? collections,
  List<RoutineItem>? routines,
}) async {
  SharedPreferences.setMockInitialValues({});
  await AppLocalizations.ensureDateFormatting();
  final storage = await StorageService.init();
  final settings = SettingsProvider(storage);
  await settings.setLanguage(language);

  if (collections != null) {
    await storage.saveCollections(collections);
  }
  if (routines != null) {
    await storage.saveRoutines(routines);
  }

  final notif = NotificationService();
  return (
    storage: storage,
    settings: settings,
    collections: CollectionProvider(storage),
    routines: RoutineProvider(storage),
    hydration: HydrationProvider(storage, notif),
    wearable: WearableProvider(storage),
    reading: ReadingProvider(storage),
  );
}

Widget _wrapWithProviders({
  required SettingsProvider settings,
  required CollectionProvider collections,
  required RoutineProvider routines,
  required HydrationProvider hydration,
  required WearableProvider wearable,
  required ReadingProvider reading,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<CollectionProvider>.value(value: collections),
      ChangeNotifierProvider<RoutineProvider>.value(value: routines),
      ChangeNotifierProvider<HydrationProvider>.value(value: hydration),
      ChangeNotifierProvider<WearableProvider>.value(value: wearable),
      ChangeNotifierProvider<ReadingProvider>.value(value: reading),
    ],
    child: Consumer<SettingsProvider>(
      builder: (_, s, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: s.themeMode,
        locale: s.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone trigger detection in providers', () {
    test('CollectionProvider.toggleEntryCheck returns true only on 100% completion',
        () async {
      final now = DateTime(2026, 11, 14, 12, 0);
      final env = await _createStampTestEnv(
        collections: [
          CollectionItem(
            id: 'bucket-1',
            title: '2026 Bucket List',
            entries: const [
              CollectionEntry(id: 'e1', text: 'See Aurora', isChecked: true),
              CollectionEntry(id: 'e2', text: 'Climb Rinjani', isChecked: false),
            ],
            createdAt: now,
          ),
        ],
      );

      final done = await env.collections.toggleEntryCheck('bucket-1', 'e2');
      expect(done, isTrue);

      // Unchecking breaks completion -> false
      final unchecked =
          await env.collections.toggleEntryCheck('bucket-1', 'e2');
      expect(unchecked, isFalse);
    });

    test('RoutineProvider.toggleStep returns milestone streak only on 7-day multiples',
        () async {
      final env = await _createStampTestEnv(
        routines: [
          RoutineItem(
            id: 'r-6',
            title: 'Morning Stretch',
            type: RoutineType.morning,
            steps: const ['Hydrate', 'Stretch'],
            completedStepIndices: const {0},
            streakCount: 6,
            createdAt: DateTime(2026, 11, 14),
          ),
          RoutineItem(
            id: 'r-2',
            title: 'Evening Read',
            type: RoutineType.evening,
            steps: const ['Tea', 'Read'],
            completedStepIndices: const {0},
            streakCount: 2,
            createdAt: DateTime(2026, 11, 14),
          ),
        ],
      );

      final hit7 = await env.routines.toggleStep('r-6', 1);
      expect(hit7, 7);

      // Unchecking and rechecking does not re-increment beyond 7 into false milestone
      final uncheck = await env.routines.toggleStep('r-6', 1);
      expect(uncheck, isNull);

      final hit3 = await env.routines.toggleStep('r-2', 1);
      expect(hit3, isNull);
      expect(env.routines.routines.last.streakCount, 3);
    });

    test('HydrationProvider.addGlass returns true only when crossing daily goal',
        () async {
      final env = await _createStampTestEnv();
      await env.hydration.setDailyGoal(2);

      expect(await env.hydration.addGlass(), isFalse); // 1/2
      expect(await env.hydration.addGlass(), isTrue); // 2/2 reached!
      expect(await env.hydration.addGlass(), isFalse); // 3/2 already met
    });
  });

  group('Mascot Milestone Stamp Overlays & Dialogs', () {
    testWidgets(
        'Completing a Bucket List checklist surfaces Pippin STAMPED! overlay & auto-dismisses',
        (tester) async {
      addTearDown(MascotMilestoneStampOverlay.dismissActive);
      final now = DateTime(2026, 11, 14, 14, 0);
      final env = await _createStampTestEnv(
        collections: [
          CollectionItem(
            id: 'bucket-places',
            title: 'Places to Visit & Cafes',
            entries: const [
              CollectionEntry(
                  id: 'b1', text: 'Sunrise Lookout', isChecked: true),
              CollectionEntry(
                  id: 'b2', text: 'Heritage Library', isChecked: false),
            ],
            createdAt: now,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          settings: env.settings,
          collections: env.collections,
          routines: env.routines,
          hydration: env.hydration,
          wearable: env.wearable,
          reading: env.reading,
          child: const CollectionsListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Heritage Library'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('STAMPED!'), findsOneWidget);
      expect(find.text('Pippin Stamped Your Passport!'), findsOneWidget);
      expect(find.text('Places to Visit & Cafes'), findsWidgets);

      // Verify auto-dismiss clears overlay cleanly
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      expect(find.text('Pippin Stamped Your Passport!'), findsNothing);
    });

    testWidgets(
        'Reaching 7-day habit streak in RoutinesScreen surfaces Roo ON FIRE! stamp',
        (tester) async {
      addTearDown(MascotMilestoneStampOverlay.dismissActive);
      final env = await _createStampTestEnv(
        routines: [
          RoutineItem(
            id: 'habit-7',
            title: 'Sunrise Walk',
            type: RoutineType.morning,
            steps: const ['Drink water', '20m walk'],
            completedStepIndices: const {0},
            streakCount: 6,
            createdAt: DateTime(2026, 11, 14),
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          settings: env.settings,
          collections: env.collections,
          routines: env.routines,
          hydration: env.hydration,
          wearable: env.wearable,
          reading: env.reading,
          child: const RoutinesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('20m walk'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ON FIRE!'), findsOneWidget);
      expect(find.text('Roo Says: 7-Day Streak!'), findsOneWidget);

      // Tap overlay to dismiss early
      await tester.tap(find.text('ON FIRE!'));
      await tester.pumpAndSettle();
      expect(find.text('Roo Says: 7-Day Streak!'), findsNothing);
    });

    testWidgets(
        'Hitting hydration goal via HydrationSparklineCard surfaces Seren REFRESHED! crown in ID & EN',
        (tester) async {
      addTearDown(MascotMilestoneStampOverlay.dismissActive);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => true,
      );
      WidgetSyncService.instance.methodInvoker = (_, _) async => true;
      addTearDown(() {
        WidgetSyncService.instance.methodInvoker = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null,
        );
      });
      final env = await _createStampTestEnv(language: AppLanguage.id);
      await env.hydration.setDailyGoal(1); // 1 glass = 250ml

      await tester.pumpWidget(
        _wrapWithProviders(
          settings: env.settings,
          collections: env.collections,
          routines: env.routines,
          hydration: env.hydration,
          wearable: env.wearable,
          reading: env.reading,
          child: const Scaffold(
            body: SingleChildScrollView(child: HydrationSparklineCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+250ml'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('SEGAR!'), findsOneWidget);
      expect(find.text('Mahkota Hidrasi Tercapai!'), findsOneWidget);

      await tester.tap(find.text('SEGAR!'));
      await tester.pumpAndSettle();
      expect(find.text('Mahkota Hidrasi Tercapai!'), findsNothing);
    });

    testWidgets(
        'Reading completion dialog embeds animated Pippin STAMPED! passport badge',
        (tester) async {
      final env = await _createStampTestEnv();
      final finishedBook = ReadingItem(
        id: 'book-done',
        title: 'Deep Focus',
        author: 'Pippin Press',
        totalPages: 240,
        currentPage: 240,
        status: ReadingStatus.finished,
        createdAt: DateTime(2026, 11, 14),
        updatedAt: DateTime(2026, 11, 14),
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          settings: env.settings,
          collections: env.collections,
          routines: env.routines,
          hydration: env.hydration,
          wearable: env.wearable,
          reading: env.reading,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    showReadingCelebrationDialog(context, finishedBook),
                child: const Text('Celebrate'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Celebrate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(MascotMilestoneStampBadge), findsOneWidget);
      expect(find.text('STAMPED!'), findsOneWidget);
      expect(find.text('Book Finished!'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  });
}
