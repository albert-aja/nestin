import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/collection_item.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/providers/collection_provider.dart';
import 'package:nestin/ui/screens/organize/collections_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapCollectionsScreen(CollectionProvider provider) {
    return ChangeNotifierProvider<CollectionProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        ),
        home: const CollectionsListScreen(),
      ),
    );
  }

  group('TravelPackingTemplates & CollectionItem Domain Tests', () {
    test('Includes all 4 pre-built packing presets with categorized entries', () {
      expect(TravelPackingTemplates.presets.length, equals(4));

      final weekend =
          TravelPackingTemplates.findByKey(TravelPackingTemplates.weekendTripKey);
      final flight = TravelPackingTemplates.findByKey(
        TravelPackingTemplates.internationalFlightKey,
      );
      final camping = TravelPackingTemplates.findByKey(
        TravelPackingTemplates.outdoorCampingKey,
      );
      final business =
          TravelPackingTemplates.findByKey(TravelPackingTemplates.businessKey);

      expect(weekend?.title, equals('Weekend Trip'));
      expect(weekend?.items.length, equals(8));
      expect(flight?.title, equals('International Flight'));
      expect(flight?.items.length, equals(9));
      expect(camping?.title, equals('Outdoor Camping'));
      expect(camping?.items.length, equals(9));
      expect(business?.title, equals('Business'));
      expect(business?.items.length, equals(8));
      expect(TravelPackingTemplates.findByKey('unknown_key'), isNull);

      for (final spec in TravelPackingTemplates.presets) {
        expect(spec.items.every((item) => item.category.isNotEmpty), isTrue);
      }
    });

    test('CollectionItem JSON roundtrip preserves template metadata and supports legacy JSON', () {
      final now = DateTime(2026, 11, 14, 9, 30);
      final resetTime = DateTime(2026, 11, 15, 10, 0);
      final item = CollectionItem(
        id: 'pack-1',
        title: 'Bali Getaway',
        description: 'Quick trip essentials',
        iconCodePoint: Icons.luggage_rounded.codePoint,
        colorValue: 0xFF3B82F6,
        isReusableTemplate: true,
        templateKey: TravelPackingTemplates.weekendTripKey,
        reuseCount: 3,
        lastResetAt: resetTime,
        createdAt: now,
        entries: const [
          CollectionEntry(
            id: 'e1',
            text: 'Passport',
            isChecked: true,
            category: 'Documents',
          ),
          CollectionEntry(
            id: 'e2',
            text: 'Charger',
            isChecked: false,
            category: 'Tech',
          ),
        ],
      );

      final revived = CollectionItem.fromJson(item.toJson());
      expect(revived.id, equals('pack-1'));
      expect(revived.isReusableTemplate, isTrue);
      expect(revived.templateKey, equals(TravelPackingTemplates.weekendTripKey));
      expect(revived.reuseCount, equals(3));
      expect(revived.lastResetAt, equals(resetTime));
      expect(revived.entries[0].category, equals('Documents'));
      expect(revived.displayIcon, equals(Icons.luggage_rounded));

      final legacy = CollectionItem.fromJson({
        'id': 'legacy-1',
        'title': 'Legacy List',
        'iconCodePoint': 0xe59c,
        'colorValue': 0xFF10B981,
        'entries': [
          {'id': 'le1', 'text': 'Milk', 'isChecked': true},
        ],
        'createdAt': now.toIso8601String(),
      });
      expect(legacy.isReusableTemplate, isFalse);
      expect(legacy.templateKey, isNull);
      expect(legacy.reuseCount, equals(0));
      expect(legacy.lastResetAt, isNull);
      expect(legacy.entries.single.category, isNull);
      expect(legacy.displayIcon, equals(Icons.shopping_cart_rounded));
    });

    test('resetForNextTrip and duplicateAsNewTrip maintain counts and independent entry IDs', () {
      final t0 = DateTime(2026, 11, 14, 8, 0);
      final t1 = DateTime(2026, 11, 20, 9, 0);
      var seq = 0;

      final spec = TravelPackingTemplates.findByKey(TravelPackingTemplates.businessKey)!;
      final created = spec.instantiate(
        id: 'biz-1',
        entryIdGenerator: () => 'e-${++seq}',
        nowOverride: t0,
      );
      expect(created.isReusableTemplate, isTrue);
      expect(created.hasCheckedEntries, isFalse);

      // Resetting when 0 items checked should not bump reuseCount.
      final resetEmpty = created.resetForNextTrip(nowOverride: t1);
      expect(resetEmpty.reuseCount, equals(0));
      expect(resetEmpty.lastResetAt, equals(t1));

      // Check 2 items then reset -> unchecks all and increments reuseCount.
      final partiallyChecked = resetEmpty.copyWith(
        entries: [
          resetEmpty.entries[0].copyWith(isChecked: true),
          resetEmpty.entries[1].copyWith(isChecked: true),
          ...resetEmpty.entries.sublist(2),
        ],
      );
      expect(partiallyChecked.checkedCount, equals(2));

      final reused = partiallyChecked.resetForNextTrip(nowOverride: t1);
      expect(reused.checkedCount, equals(0));
      expect(reused.reuseCount, equals(1));
      expect(reused.lastResetAt, equals(t1));

      // Duplicating produces fresh entry IDs and defaults to unchecked.
      final cloneUnchecked = partiallyChecked.duplicateAsNewTrip(
        newId: 'biz-copy-1',
        entryIdGenerator: () => 'e-${++seq}',
        title: 'Singapore Conf',
        resetChecks: true,
        nowOverride: t1,
      );
      expect(cloneUnchecked.id, equals('biz-copy-1'));
      expect(cloneUnchecked.checkedCount, equals(0));
      expect(cloneUnchecked.reuseCount, equals(0));
      expect(cloneUnchecked.entries.length, equals(partiallyChecked.entries.length));
      expect(cloneUnchecked.entries.first.id, isNot(equals(partiallyChecked.entries.first.id)));

      final cloneKeepChecks = partiallyChecked.duplicateAsNewTrip(
        newId: 'biz-copy-2',
        entryIdGenerator: () => 'e-${++seq}',
        title: 'London Conf',
        resetChecks: false,
        nowOverride: t1,
      );
      expect(cloneKeepChecks.checkedCount, equals(2));
    });
  });

  group('CollectionProvider Packing & Storage Backup Tests', () {
    test('createFromPackingTemplate, uncheckAllEntries, duplicateCollection, removeEntry and persistence work', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final provider = CollectionProvider(storage);

      expect(provider.collections.length, equals(2));
      expect(provider.reusableCollections, isEmpty);

      final trip1 = await provider.createFromPackingTemplate(
        TravelPackingTemplates.weekendTripKey,
      );
      final trip2 = await provider.createFromPackingTemplate(
        TravelPackingTemplates.weekendTripKey,
      );
      expect(trip1.title, equals('Weekend Trip'));
      expect(trip2.title, equals('Weekend Trip (2)'));
      expect(provider.reusableCollections.length, equals(2));

      // Check two entries on trip1, verify reuse reset unchecks & increments reuseCount.
      await provider.toggleEntryCheck(trip1.id, trip1.entries[0].id);
      await provider.toggleEntryCheck(trip1.id, trip1.entries[1].id);
      expect(
        provider.collections.firstWhere((c) => c.id == trip1.id).checkedCount,
        equals(2),
      );

      final reset = await provider.uncheckAllEntries(trip1.id);
      expect(reset, isNotNull);
      expect(reset!.checkedCount, equals(0));
      expect(reset.reuseCount, equals(1));

      // Check one entry on trip1 and duplicate cleanly with resetChecks = true.
      await provider.toggleEntryCheck(trip1.id, trip1.entries[0].id);
      final dup = await provider.duplicateCollection(
        trip1.id,
        customTitle: 'Bandung Escape',
        resetChecks: true,
      );
      expect(dup, isNotNull);
      expect(dup!.title, equals('Bandung Escape'));
      expect(dup.checkedCount, equals(0));
      expect(dup.entries.length, equals(trip1.entries.length));

      // Mutating copy entry does not affect source list.
      await provider.toggleEntryCheck(dup.id, dup.entries[2].id);
      final refreshedSource =
          provider.collections.firstWhere((c) => c.id == trip1.id);
      expect(refreshedSource.entries[2].isChecked, isFalse);

      // Removing entry & adding categorized entry.
      await provider.removeEntryFromCollection(dup.id, dup.entries.last.id);
      await provider.addEntryToCollection(
        dup.id,
        'Sunglasses case',
        category: 'Accessories',
      );
      final updatedDup =
          provider.collections.firstWhere((c) => c.id == dup.id);
      expect(updatedDup.entries.length, equals(trip1.entries.length));
      expect(updatedDup.entries.last.text, equals('Sunglasses case'));
      expect(updatedDup.entries.last.category, equals('Accessories'));

      // Toggle reusable flag on seeded grocery list.
      final groceryId = provider.collections
          .firstWhere((c) => c.title == 'Weekly Market List')
          .id;
      await provider.toggleReusableTemplate(groceryId);
      expect(
        provider.reusableCollections.any((c) => c.id == groceryId),
        isTrue,
      );

      // Verify full persistence & full JSON backup export/restore roundtrip.
      final backupJson = storage.exportFullBackupJson();
      await storage.saveCollections([]);
      await provider.reloadFromStorage();
      // Empty storage triggers default 2 seeded collections only.
      expect(provider.collections.length, equals(2));

      final restoredOk = await storage.restoreFullBackupJson(backupJson);
      expect(restoredOk, isTrue);
      await provider.reloadFromStorage();

      final restoredTrip1 =
          provider.collections.firstWhere((c) => c.title == 'Weekend Trip');
      expect(restoredTrip1.reuseCount, equals(1));
      expect(restoredTrip1.isReusableTemplate, isTrue);
      expect(
        provider.collections.any((c) => c.title == 'Bandung Escape'),
        isTrue,
      );
    });
  });

  group('CollectionsListScreen Widget Tests', () {
    testWidgets('Displays all 4 packing presets and supports 1-tap add, preview customize, reset & duplicate', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final provider = CollectionProvider(storage);

      await tester.pumpWidget(wrapCollectionsScreen(provider));
      await tester.pumpAndSettle();

      expect(find.text('Travel & Packing Templates'), findsOneWidget);
      expect(find.text('Weekend Trip'), findsOneWidget);
      expect(find.text('International Flight'), findsOneWidget);
      expect(find.text('Outdoor Camping'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('All Lists (2)'), findsOneWidget);
      expect(find.text('Packing & Reusable (0)'), findsOneWidget);

      // 1-tap "+" add on Weekend Trip preset.
      await tester.tap(find.byTooltip('Use Weekend Trip Template'));
      await tester.pumpAndSettle();

      expect(find.text('All Lists (3)'), findsOneWidget);
      expect(find.text('Packing & Reusable (1)'), findsOneWidget);
      expect(find.text('ID / Driver license & transit cards'), findsOneWidget);

      // Open preview sheet for International Flight & customize title.
      await tester.tap(find.text('International Flight'));
      await tester.pumpAndSettle();

      expect(find.text('Passport, visa docs & boarding pass'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Tokyo Autumn Trip');
      await tester.tap(find.text('Add Packing List'));
      await tester.pumpAndSettle();

      expect(find.text('Tokyo Autumn Trip'), findsOneWidget);
      expect(find.text('Packing & Reusable (2)'), findsOneWidget);

      // Check an entry on Tokyo Autumn Trip, verify badge updates to 1/9, then 1-tap Uncheck All / Reuse.
      await tester.tap(find.text('Passport, visa docs & boarding pass'));
      await tester.pumpAndSettle();
      expect(find.text('1/9'), findsOneWidget);

      final resetFinder = find.text('Uncheck All / Reuse for Next Trip').first;
      await tester.ensureVisible(resetFinder);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      expect(find.text('0/9'), findsOneWidget);
      expect(find.text('Reused 1x'), findsOneWidget);

      // Duplicate Tokyo Autumn Trip via Duplicate action -> custom name.
      final duplicateBtn = find.text('Duplicate').first;
      await tester.ensureVisible(duplicateBtn);
      await tester.tap(duplicateBtn);
      await tester.pumpAndSettle();

      expect(find.text('Duplicate Template / List'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Osaka Spring Trip');
      await tester.tap(find.text('Duplicate').last);
      await tester.pumpAndSettle();

      expect(find.text('Osaka Spring Trip'), findsOneWidget);

      // Scroll back up to top filter chips before filtering.
      final filterChip = find.text('Packing & Reusable (3)');
      await tester.scrollUntilVisible(
        filterChip,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(filterChip, findsOneWidget);

      // Filter by Packing & Reusable hides Weekly Market List.
      await tester.tap(filterChip);
      await tester.pumpAndSettle();

      expect(find.text('Weekly Market List'), findsNothing);
      expect(find.text('Tokyo Autumn Trip'), findsOneWidget);
      expect(find.text('Osaka Spring Trip'), findsOneWidget);
    });

    testWidgets('Renders without layout overflow on compact 360px phone screen', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final provider = CollectionProvider(storage);
      await provider.createFromPackingTemplate(
        TravelPackingTemplates.outdoorCampingKey,
      );

      await tester.pumpWidget(wrapCollectionsScreen(provider));
      await tester.pumpAndSettle();

      expect(find.text('Tent, stakes, rainfly & groundsheet'), findsOneWidget);

      // Also scroll to footer reset action to verify zero overflow on narrow cards.
      await tester.scrollUntilVisible(
        find.text('Uncheck All / Reuse for Next Trip').first,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Uncheck All / Reuse for Next Trip'), findsNWidgets(3));
    });
  });
}
