import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';
import '../data/models/bucket_list_item.dart';
import '../data/models/entity_link.dart';
import '../data/models/memory_item.dart';
import '../data/models/saved_place.dart';
import '../data/services/storage_service.dart';
import 'cross_module_link_provider.dart';
import 'journal_provider.dart';

class BucketListProvider extends ChangeNotifier {
  final StorageService _storageService;
  static const Uuid _uuid = Uuid();

  List<BucketListItem> _items = [];

  BucketListProvider(
    this._storageService, {
    bool seedDefaults = true,
  }) {
    _load(seedDefaults: seedDefaults);
  }

  // --- Read-Only Getters ---

  List<BucketListItem> get items {
    final sorted = List<BucketListItem>.from(_items);
    sorted.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (!a.isCompleted && a.isStarred != b.isStarred) {
        return a.isStarred ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return List.unmodifiable(sorted);
  }

  List<BucketListItem> get pendingItems =>
      items.where((i) => !i.isCompleted).toList(growable: false);

  List<BucketListItem> get completedItems =>
      items.where((i) => i.isCompleted).toList(growable: false);

  List<BucketListItem> get starredPendingItems =>
      pendingItems.where((i) => i.isStarred).toList(growable: false);

  List<BucketListItem> get promotedItems =>
      items.where((i) => i.isPromotedToMemory).toList(growable: false);

  int get totalCount => _items.length;
  int get completedCount => _items.where((i) => i.isCompleted).length;
  int get pendingCount => _items.where((i) => !i.isCompleted).length;
  int get promotedCount => _items.where((i) => i.isPromotedToMemory).length;

  double get completionProgress =>
      _items.isEmpty ? 0.0 : completedCount / _items.length;

  int countForCategory(BucketCategory category) =>
      _items.where((i) => i.category == category).length;

  BucketListItem? findById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  // --- Initialization & Persistence ---

  void _load({required bool seedDefaults}) {
    final hasKey = _storageService.hasSavedBucketListItems();
    _items = _storageService.loadBucketListItems();

    if (seedDefaults && !hasKey && _items.isEmpty) {
      final now = DateTime.now();
      _items = [
        BucketListItem(
          id: _uuid.v4(),
          title: 'Watch sunrise over Mt. Bromo caldera',
          inspirationNote:
              'Pack warm fleece layers and thermos tea; scout a quiet ridge viewpoint before first light.',
          category: BucketCategory.natureOutdoors,
          targetSeason: BucketTargetSeason.drySeason,
          targetYear: now.year + 1,
          locationLabel: 'East Java Highlands',
          isStarred: true,
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
        BucketListItem(
          id: _uuid.v4(),
          title: 'Spend an unhurried morning in a hidden bookshop cafe',
          inspirationNote:
              'Bring a pocket sketchbook, order single-origin pour-over, and savour slow reading notes.',
          category: BucketCategory.cafesFood,
          targetSeason: BucketTargetSeason.spring,
          targetYear: now.year + 1,
          locationLabel: 'Old Town Art Quarter',
          isStarred: false,
          createdAt: now.subtract(const Duration(days: 8)),
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
        BucketListItem(
          id: _uuid.v4(),
          title: 'Evening lantern walk through historic backstreets',
          inspirationNote:
              'Collect neighborhood stamp-book marks and capture quiet twilight reflections.',
          category: BucketCategory.travelPlaces,
          targetSeason: BucketTargetSeason.autumn,
          targetYear: now.year + 2,
          locationLabel: 'Higashiyama Heritage District',
          isStarred: true,
          createdAt: now.subtract(const Duration(days: 6)),
          updatedAt: now.subtract(const Duration(days: 3)),
        ),
        BucketListItem(
          id: _uuid.v4(),
          title: 'Clear-sky stargazing picnic away from city glare',
          inspirationNote:
              'Brought wool blanket, star-chart app offline guide, and cinnamon cocoa under Orion.',
          category: BucketCategory.lifeExperiences,
          targetSeason: BucketTargetSeason.summer,
          targetYear: now.year,
          locationLabel: 'Highland Meadow Ridge',
          isCompleted: true,
          completedAt: now.subtract(const Duration(days: 5)),
          createdAt: now.subtract(const Duration(days: 18)),
          updatedAt: now.subtract(const Duration(days: 5)),
        ),
      ];
      _storageService.saveBucketListItems(_items);
    }
  }

  Future<void> reloadFromStorage() async {
    await _storageService.reloadPrefs();
    _items = _storageService.loadBucketListItems();
    notifyListeners();
  }

  // --- CRUD & State Transitions ---

  Future<BucketListItem> addItem({
    required String title,
    String inspirationNote = '',
    BucketCategory category = BucketCategory.travelPlaces,
    BucketTargetSeason targetSeason = BucketTargetSeason.anytime,
    int? targetYear,
    String? locationLabel,
    SavedPlace? linkedPlace,
    bool isStarred = false,
  }) async {
    final now = DateTime.now();
    final trimmedLocation = locationLabel?.trim();
    final item = BucketListItem(
      id: _uuid.v4(),
      title: title.trim(),
      inspirationNote: inspirationNote.trim(),
      category: category,
      targetSeason: targetSeason,
      targetYear: targetYear,
      locationLabel:
          (trimmedLocation == null || trimmedLocation.isEmpty)
              ? null
              : trimmedLocation,
      savedPlaceId: linkedPlace?.id,
      savedPlaceName: linkedPlace?.name,
      isStarred: isStarred,
      createdAt: now,
      updatedAt: now,
    );
    _items.insert(0, item);
    await _storageService.saveBucketListItems(_items);
    notifyListeners();
    return item;
  }

  Future<void> updateItem(BucketListItem updated) async {
    final idx = _items.indexWhere((i) => i.id == updated.id);
    if (idx == -1) return;
    _items[idx] = updated.copyWith(updatedAt: DateTime.now());
    await _storageService.saveBucketListItems(_items);
    notifyListeners();
  }

  Future<void> toggleStarred(String id) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final current = _items[idx];
    _items[idx] = current.copyWith(
      isStarred: !current.isStarred,
      updatedAt: DateTime.now(),
    );
    await _storageService.saveBucketListItems(_items);
    notifyListeners();
  }

  /// Flips completion status for [id]. Returns `true` when transitioning from
  /// uncompleted to completed so the UI can play Pippin's `STAMPED!` celebration.
  Future<bool> toggleCompleted(String id) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return false;

    final current = _items[idx];
    final nextDone = !current.isCompleted;
    final now = DateTime.now();
    _items[idx] = nextDone
        ? current.copyWith(
            isCompleted: true,
            completedAt: now,
            updatedAt: now,
          )
        : current.copyWith(
            isCompleted: false,
            clearCompletedAt: true,
            updatedAt: now,
          );
    await _storageService.saveBucketListItems(_items);
    notifyListeners();
    return nextDone;
  }

  Future<void> linkSavedPlace(String itemId, SavedPlace place) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final current = _items[idx];
    _items[idx] = current.copyWith(
      savedPlaceId: place.id,
      savedPlaceName: place.name,
      locationLabel: (current.locationLabel == null ||
              current.locationLabel!.trim().isEmpty)
          ? (place.address.trim().isNotEmpty ? place.address.trim() : place.name)
          : current.locationLabel,
      updatedAt: DateTime.now(),
    );
    await _storageService.saveBucketListItems(_items);
    notifyListeners();
  }

  Future<void> unlinkSavedPlace(String itemId) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(
      clearSavedPlace: true,
      updatedAt: DateTime.now(),
    );
    await _storageService.saveBucketListItems(_items);
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _storageService.saveBucketListItems(_items);
    notifyListeners();
  }

  Future<void> restoreItem(BucketListItem item, {int? atIndex}) async {
    if (_items.any((i) => i.id == item.id)) return;
    final targetIndex =
        atIndex == null ? 0 : atIndex.clamp(0, _items.length).toInt();
    _items.insert(targetIndex, item);
    await _storageService.saveBucketListItems(_items);
    notifyListeners();
  }

  int indexOfItem(String id) => _items.indexWhere((i) => i.id == id);

  /// 1-tap promotion from a bucket-list dream goal into Echo's milestone
  /// [MemoryItem]. Idempotent if the linked memory still exists in [journalProvider].
  Future<MemoryItem?> promoteToEchoMemory(
    String itemId,
    JournalProvider journalProvider, {
    SavedPlace? linkedPlace,
    CrossModuleLinkProvider? linkProvider,
    String? extraReflection,
  }) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return null;

    var item = _items[idx];

    if (item.isPromotedToMemory) {
      for (final existing in journalProvider.memories) {
        if (existing.id == item.promotedMemoryId) {
          return existing;
        }
      }
    }

    final now = DateTime.now();
    final achievedDate = item.completedAt ?? now;
    if (!item.isCompleted) {
      item = item.copyWith(
        isCompleted: true,
        completedAt: achievedDate,
        updatedAt: now,
      );
    }

    final placeName = item.resolvedLocationLabel(
      livePlaceName: linkedPlace?.name,
    );
    final windowLabel = item.targetWindowLabel();

    final descParts = <String>[
      if (extraReflection != null && extraReflection.trim().isNotEmpty)
        extraReflection.trim(),
      if (item.hasInspirationNote) item.inspirationNote.trim(),
      if (placeName.isNotEmpty) '📍 $placeName',
      if (windowLabel != null) '🎯 Target: $windowLabel',
      '🧭 Achieved from Pippin\'s Life Bucket List',
    ];

    final tagSet = <String>{
      'Bucket List',
      item.category.labelEn,
      if (placeName.isNotEmpty) placeName,
    };

    final memory = MemoryItem(
      id: _uuid.v4(),
      title: item.title,
      description: descParts.join('\n\n'),
      date: achievedDate,
      tags: tagSet.toList(growable: false),
      isMilestone: true,
      createdAt: now,
    );

    await journalProvider.addMemory(memory);

    if (linkProvider != null) {
      await linkProvider.addLink(
        sourceType: LinkEntityType.bucketList,
        sourceId: item.id,
        sourceTitle: item.title,
        targetType: LinkEntityType.memory,
        targetId: memory.id,
        targetTitle: memory.title,
        relationship: 'achieved_memory',
      );
    }

    _items[idx] = item.copyWith(
      isCompleted: true,
      completedAt: achievedDate,
      promotedMemoryId: memory.id,
      promotedToMemoryAt: now,
      updatedAt: now,
    );
    await _storageService.saveBucketListItems(_items);
    notifyListeners();
    return memory;
  }
}
