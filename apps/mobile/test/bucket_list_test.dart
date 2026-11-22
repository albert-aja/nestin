import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nestin/core/l10n/app_language.dart';
import 'package:nestin/core/l10n/app_localizations.dart';
import 'package:nestin/core/theme/app_theme.dart';
import 'package:nestin/data/models/bucket_list_item.dart';
import 'package:nestin/data/models/entity_link.dart';
import 'package:nestin/data/models/saved_place.dart';
import 'package:nestin/data/services/notification_service.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/bucket_list_provider.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/providers/cross_module_link_provider.dart';
import 'package:nestin/providers/geofence_provider.dart';
import 'package:nestin/providers/journal_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/explore/bucket_list_screen.dart';
import 'package:nestin/ui/widgets/bucket_list_summary_card.dart';

class _BucketTestEnv {
  final StorageService storage;
  final NotificationService notifications;
  final SettingsProvider settings;
  final BucketListProvider bucketList;
  final JournalProvider journal;
  final GeofenceProvider geofence;
  final CrossModuleLinkProvider links;
  final CollectionProvider collections;

  _BucketTestEnv({
    required this.storage,
    required this.notifications,
    required this.settings,
    required this.bucketList,
    required this.journal,
    required this.geofence,
    required this.links,
    required this.collections,
  });

  static Future<_BucketTestEnv> create({
    AppLanguage language = AppLanguage.en,
    ThemeMode themeMode = ThemeMode.dark,
    bool seedDefaults = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.ensureDateFormatting();
    final storage = await StorageService.init();
    final notifications = NotificationService();
    final settings = SettingsProvider(storage);
    await settings.setLanguage(language);
    await settings.setThemeMode(themeMode);

    return _BucketTestEnv(
      storage: storage,
      notifications: notifications,
      settings: settings,
      bucketList: BucketListProvider(storage, seedDefaults: seedDefaults),
      journal: JournalProvider(storage),
      geofence: GeofenceProvider(
        storage,
        notifications,
        seedDefaults: true,
        autoInitializeNative: false,
      ),
      links: CrossModuleLinkProvider(storage),
      collections: CollectionProvider(storage),
    );
  }

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<NotificationService>.value(value: notifications),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<BucketListProvider>.value(value: bucketList),
        ChangeNotifierProvider<JournalProvider>.value(value: journal),
        ChangeNotifierProvider<GeofenceProvider>.value(value: geofence),
        ChangeNotifierProvider<CrossModuleLinkProvider>.value(value: links),
        ChangeNotifierProvider<CollectionProvider>.value(value: collections),
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
}

void main() {
  group('BucketListItem & Backup Serialization Tests', () {
    test('Target season/year badges format EN & ID cleanly and roundtrip JSON',
        () {
      final now = DateTime(2026, 6, 15, 9, 0);
      final item = BucketListItem(
        id: 'dream-1',
        title: 'Cherry blossoms along Philosopher Path',
        inspirationNote: 'Walk early around 6:30am with matcha thermos.',
        category: BucketCategory.travelPlaces,
        targetSeason: BucketTargetSeason.spring,
        targetYear: 2028,
        locationLabel: 'Kyoto, Japan',
        savedPlaceId: 'place-kyoto',
        savedPlaceName: 'Philosopher Path',
        isStarred: true,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(item.targetWindowLabel(isIndonesian: false), '🌸 Spring 2028');
      expect(
        item.targetWindowLabel(isIndonesian: true),
        '🌸 Musim Semi 2028',
      );

      final restored = BucketListItem.fromJson(item.toJson());
      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.inspirationNote, item.inspirationNote);
      expect(restored.category, BucketCategory.travelPlaces);
      expect(restored.targetSeason, BucketTargetSeason.spring);
      expect(restored.targetYear, 2028);
      expect(restored.savedPlaceId, 'place-kyoto');
      expect(restored.savedPlaceName, 'Philosopher Path');
      expect(restored.isStarred, isTrue);
    });

    test('StorageService backup export & restore preserves bucketListItems',
        () async {
      final env = await _BucketTestEnv.create(seedDefaults: false);
      final place = env.geofence.places.first;
      await env.bucketList.addItem(
        title: 'Sunrise camp on Rinjani rim',
        inspirationNote: 'Bring trekking poles and wool beanie.',
        category: BucketCategory.natureOutdoors,
        targetSeason: BucketTargetSeason.drySeason,
        targetYear: 2027,
        linkedPlace: place,
        isStarred: true,
      );

      final backupJson = env.storage.exportFullBackupJson();

      SharedPreferences.setMockInitialValues({});
      final freshStorage = await StorageService.init();
      final ok = await freshStorage.restoreFullBackupJson(backupJson);
      expect(ok, isTrue);

      final restoredProvider =
          BucketListProvider(freshStorage, seedDefaults: false);
      expect(restoredProvider.totalCount, 1);
      final restored = restoredProvider.items.single;
      expect(restored.title, 'Sunrise camp on Rinjani rim');
      expect(restored.targetSeason, BucketTargetSeason.drySeason);
      expect(restored.targetYear, 2027);
      expect(restored.savedPlaceId, place.id);
      expect(restored.isStarred, isTrue);
    });
  });

  group('BucketListProvider SavedPlace Link & Echo Memory Promotion Tests', () {
    test(
        'Completing and 1-tap promoting creates Echo MemoryItem + bidirectional link idempotently',
        () async {
      final env = await _BucketTestEnv.create(seedDefaults: false);
      final savedPlace = SavedPlace(
        id: 'place-kintsugi',
        name: 'Kintsugi Craft Studio',
        address: 'Old Quarter Lane 14',
        latitude: 35.0116,
        longitude: 135.7681,
        category: PlaceCategory.custom,
        createdAt: DateTime(2026, 5, 1),
      );
      await env.geofence.addPlace(savedPlace);

      final item = await env.bucketList.addItem(
        title: 'Learn traditional ceramic repair',
        inspirationNote: 'Practice gold lacquer seams on a heirloom bowl.',
        category: BucketCategory.creativeMilestones,
        targetSeason: BucketTargetSeason.autumn,
        targetYear: 2027,
        linkedPlace: savedPlace,
      );

      final completedNow = await env.bucketList.toggleCompleted(item.id);
      expect(completedNow, isTrue);
      expect(env.bucketList.findById(item.id)!.isCompleted, isTrue);

      final initialMemoryCount = env.journal.memories.length;
      final promoted = await env.bucketList.promoteToEchoMemory(
        item.id,
        env.journal,
        linkedPlace: savedPlace,
        linkProvider: env.links,
      );

      expect(promoted, isNotNull);
      expect(env.journal.memories.length, initialMemoryCount + 1);
      expect(promoted!.title, item.title);
      expect(promoted.isMilestone, isTrue);
      expect(promoted.tags, containsAll(['Bucket List', 'Creative Goals', 'Kintsugi Craft Studio']));
      expect(promoted.description, contains('gold lacquer seams'));
      expect(promoted.description, contains('📍 Kintsugi Craft Studio'));

      final updatedItem = env.bucketList.findById(item.id)!;
      expect(updatedItem.isPromotedToMemory, isTrue);
      expect(updatedItem.promotedMemoryId, promoted.id);

      // Bidirectional link registered
      final itemLinks =
          env.links.linksFor(LinkEntityType.bucketList, item.id);
      expect(itemLinks.length, 1);
      expect(itemLinks.single.entityType, LinkEntityType.memory);
      expect(itemLinks.single.entityId, promoted.id);

      // Second promotion call is idempotent while memory exists
      final secondCall = await env.bucketList.promoteToEchoMemory(
        item.id,
        env.journal,
        linkedPlace: savedPlace,
        linkProvider: env.links,
      );
      expect(secondCall!.id, promoted.id);
      expect(env.journal.memories.length, initialMemoryCount + 1);
    });

    test('Delete and restoreItem preserves bucket-list dream recovery',
        () async {
      final env = await _BucketTestEnv.create(seedDefaults: true);
      final first = env.bucketList.items.first;
      final originalCount = env.bucketList.totalCount;

      final idx = env.bucketList.indexOfItem(first.id);
      await env.bucketList.deleteItem(first.id);
      expect(env.bucketList.totalCount, originalCount - 1);

      await env.bucketList.restoreItem(first, atIndex: idx);
      expect(env.bucketList.totalCount, originalCount);
      expect(env.bucketList.findById(first.id)?.title, first.title);
    });
  });

  group('BucketListScreen UI & Integration Tests', () {
    testWidgets(
        'Creates dream with category, season/year, SavedPlace link, inspiration note & promotes to Echo Memory in 1 tap',
        (tester) async {
      final env = await _BucketTestEnv.create(seedDefaults: false);
      final cafePlace = SavedPlace(
        id: 'place-cafe-bandung',
        name: 'Hidden Courtyard Roasters',
        address: 'Laneway 8',
        latitude: -6.9175,
        longitude: 107.6191,
        category: PlaceCategory.custom,
        createdAt: DateTime(2026, 5, 1),
      );
      await env.geofence.addPlace(cafePlace);

      await tester.pumpWidget(env.wrap(const BucketListScreen()));
      await tester.pumpAndSettle();

      // Open Add Dream sheet via FAB
      await tester.tap(find.byKey(const Key('bucket_add_dream_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('bucket_editor_title_field')),
        'Roast beans workshop in Bandung',
      );
      await tester.enterText(
        find.byKey(const Key('bucket_editor_note_field')),
        'Ask the barista about honey-process roasting notes.',
      );

      // Pick category & season & year & SavedPlace
      await tester.ensureVisible(find.text('☕ Cafes & Culinary').last);
      await tester.tap(find.text('☕ Cafes & Culinary').last);
      await tester.pump();

      await tester.ensureVisible(find.text('☀️ Summer'));
      await tester.tap(find.text('☀️ Summer'));
      await tester.pump();

      final targetYearText = '${DateTime.now().year + 1}';
      await tester.ensureVisible(find.text(targetYearText));
      await tester.tap(find.text(targetYearText));
      await tester.pump();

      await tester.ensureVisible(find.text('📍 ${cafePlace.name}'));
      await tester.tap(find.text('📍 ${cafePlace.name}'));
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('bucket_editor_save_btn')),
      );
      await tester.tap(find.byKey(const Key('bucket_editor_save_btn')));
      await tester.pumpAndSettle();

      expect(env.bucketList.totalCount, 1);
      final created = env.bucketList.items.single;

      expect(find.text('Roast beans workshop in Bandung'), findsOneWidget);
      expect(find.text('☕ Cafes & Culinary'), findsOneWidget);
      expect(find.text('☀️ Summer $targetYearText'), findsOneWidget);
      expect(
        find.textContaining('Hidden Courtyard Roasters'),
        findsWidgets,
      );

      // Check off dream -> triggers Pippin celebration stamp & reveals 1-tap promote button
      await tester.tap(find.byKey(Key('bucket_check_${created.id}')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('STAMPED!'), findsOneWidget);

      // Let 2.4s celebration auto-dismiss cleanly
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final promoteBtn = find.byKey(Key('bucket_promote_btn_${created.id}'));
      expect(promoteBtn, findsOneWidget);

      final beforeMemCount = env.journal.memories.length;
      await tester.ensureVisible(promoteBtn);
      await tester.pumpAndSettle();
      await tester.tap(promoteBtn);
      await tester.pumpAndSettle();

      expect(env.journal.memories.length, beforeMemCount + 1);
      expect(env.journal.memories.first.title, 'Roast beans workshop in Bandung');
      expect(
        find.byKey(Key('bucket_promoted_badge_${created.id}')),
        findsOneWidget,
      );

      // Navigate into Echo's Memories from promoted badge View button
      await tester.tap(find.text('View').first);
      await tester.pumpAndSettle();
      expect(find.text('Echo\'s Memories'), findsOneWidget);
      expect(find.text('Roast beans workshop in Bandung'), findsOneWidget);
    });

    testWidgets(
        'Renders cleanly without overflow on 360px viewport in Light/Dark and EN/ID plus Explore summary card',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final env = await _BucketTestEnv.create(
        language: AppLanguage.id,
        themeMode: ThemeMode.light,
        seedDefaults: true,
      );

      await tester.pumpWidget(
        env.wrap(
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: BucketListSummaryCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Bucket List & Tempat Impian'), findsOneWidget);

      // Tap summary card to enter full BucketListScreen in Indonesian Light mode
      await tester.tap(find.byKey(const Key('explore_bucket_list_card')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Papan Impian Pippin'), findsOneWidget);

      // Search filters results smoothly
      await tester.enterText(
        find.byKey(const Key('bucket_search_field')),
        'Bromo',
      );
      await tester.pumpAndSettle();
      expect(find.text('Watch sunrise over Mt. Bromo caldera'), findsOneWidget);
      expect(
        find.text('Evening lantern walk through historic backstreets'),
        findsNothing,
      );
    });
  });
}
