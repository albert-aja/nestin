import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/collection_item.dart';
import '../data/models/wishlist_item.dart';
import '../data/models/alarm_category.dart';
import '../data/models/task_item.dart';
import '../data/services/storage_service.dart';

class CollectionProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<CollectionItem> _collections = [];
  List<WishlistItem> _wishlist = [];

  CollectionProvider(this._storageService) {
    _loadAll();
  }

  static const Uuid _uuid = Uuid();

  List<CollectionItem> get collections => List.unmodifiable(_collections);
  List<CollectionItem> get reusableCollections =>
      List.unmodifiable(_collections.where((c) => c.isReusableTemplate));
  List<WishlistItem> get wishlist => List.unmodifiable(_wishlist);
  List<PackingTemplateSpec> get availablePackingTemplates =>
      TravelPackingTemplates.presets;

  Future<void> reloadFromStorage() async {
    await _storageService.reloadPrefs();
    _loadAll();
    notifyListeners();
  }

  void _loadAll() {
    _collections = _storageService.loadCollections();
    _wishlist = _storageService.loadWishlist();
    final now = DateTime.now();

    if (_collections.isEmpty) {
      _collections = [
        CollectionItem(
          id: const Uuid().v4(),
          title: 'Weekly Market List',
          description: 'Groceries and pantry staples',
          iconCodePoint: 0xe59c, // shopping_cart_rounded
          colorValue: 0xFF10B981,
          entries: const [
            CollectionEntry(id: 'c1', text: 'Almond milk', isChecked: true),
            CollectionEntry(id: 'c2', text: 'Fresh berries', isChecked: false),
            CollectionEntry(id: 'c3', text: 'Whole grain sourdough', isChecked: false),
            CollectionEntry(id: 'c4', text: 'Greek yogurt', isChecked: false),
          ],
          createdAt: now,
        ),
        CollectionItem(
          id: const Uuid().v4(),
          title: 'Places to Visit & Cafes',
          description: 'Cozy spots recommended by friends',
          iconCodePoint: 0xe3ab, // location_on_rounded
          colorValue: 0xFFFF9E1B,
          entries: const [
            CollectionEntry(id: 'c5', text: 'Sunrise Hill Lookout', isChecked: true),
            CollectionEntry(id: 'c6', text: 'Old Town Heritage Library', isChecked: false),
            CollectionEntry(id: 'c7', text: 'Botanical Garden Conservatory', isChecked: false),
          ],
          createdAt: now,
        ),
      ];
      _storageService.saveCollections(_collections);
    }

    if (_wishlist.isEmpty) {
      _wishlist = [
        WishlistItem(
          id: const Uuid().v4(),
          title: 'Active Noise Cancelling Headphones',
          description: 'For deep work sprint sessions and travel',
          targetPrice: 249.0,
          category: AlarmCategory.fromType(AlarmCategoryType.work),
          priority: TaskPriority.high,
          isPurchased: false,
          createdAt: now,
        ),
        WishlistItem(
          id: const Uuid().v4(),
          title: 'Ergonomic Desk Mat & Wrist Rest',
          description: 'Improve typing comfort and wrist alignment',
          targetPrice: 45.0,
          category: AlarmCategory.fromType(AlarmCategoryType.health),
          priority: TaskPriority.medium,
          isPurchased: false,
          createdAt: now,
        ),
      ];
      _storageService.saveWishlist(_wishlist);
    }
  }

  // --- Collection Actions ---

  Future<void> addCollection(CollectionItem collection) async {
    _collections.add(collection);
    await _storageService.saveCollections(_collections);
    notifyListeners();
  }

  Future<void> updateCollection(CollectionItem collection) async {
    final index = _collections.indexWhere((c) => c.id == collection.id);
    if (index != -1) {
      _collections[index] = collection;
      await _storageService.saveCollections(_collections);
      notifyListeners();
    }
  }

  Future<void> toggleEntryCheck(String collectionId, String entryId) async {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      final col = _collections[index];
      final updated = col.entries.map((e) {
        if (e.id == entryId) {
          return e.copyWith(isChecked: !e.isChecked);
        }
        return e;
      }).toList();

      _collections[index] = col.copyWith(entries: updated);
      await _storageService.saveCollections(_collections);
      notifyListeners();
    }
  }

  Future<void> addEntryToCollection(
    String collectionId,
    String text, {
    String? category,
    String? notes,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      final col = _collections[index];
      final newEntries = List<CollectionEntry>.from(col.entries)
        ..add(
          CollectionEntry(
            id: _uuid.v4(),
            text: trimmed,
            category: category,
            notes: notes,
          ),
        );
      _collections[index] = col.copyWith(entries: newEntries);
      await _storageService.saveCollections(_collections);
      notifyListeners();
    }
  }

  Future<void> removeEntryFromCollection(
    String collectionId,
    String entryId,
  ) async {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) return;
    final col = _collections[index];
    final nextEntries = col.entries.where((e) => e.id != entryId).toList();
    if (nextEntries.length == col.entries.length) return;
    _collections[index] = col.copyWith(entries: nextEntries);
    await _storageService.saveCollections(_collections);
    notifyListeners();
  }

  Future<void> toggleReusableTemplate(String collectionId) async {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) return;
    final col = _collections[index];
    _collections[index] =
        col.copyWith(isReusableTemplate: !col.isReusableTemplate);
    await _storageService.saveCollections(_collections);
    notifyListeners();
  }

  String _generateUniqueTitle(String desiredBase) {
    final base = desiredBase.trim().isEmpty ? 'Packing List' : desiredBase.trim();
    final existing =
        _collections.map((c) => c.title.toLowerCase()).toSet();
    if (!existing.contains(base.toLowerCase())) return base;
    var suffix = 2;
    while (existing.contains('$base ($suffix)'.toLowerCase())) {
      suffix++;
    }
    return '$base ($suffix)';
  }

  /// Instantiates a pre-built travel/packing preset (`weekend_trip`,
  /// `international_flight`, `outdoor_camping`, `business`) at the top of lists.
  Future<CollectionItem> createFromPackingTemplate(
    String templateKey, {
    String? customTitle,
    bool markReusable = true,
    DateTime? nowOverride,
  }) async {
    final spec = TravelPackingTemplates.findByKey(templateKey);
    if (spec == null) {
      throw ArgumentError.value(
        templateKey,
        'templateKey',
        'Unknown packing template key',
      );
    }
    final title = _generateUniqueTitle(
      customTitle != null && customTitle.trim().isNotEmpty
          ? customTitle
          : spec.title,
    );
    final created = spec.instantiate(
      id: _uuid.v4(),
      entryIdGenerator: () => _uuid.v4(),
      customTitle: title,
      markReusable: markReusable,
      nowOverride: nowOverride,
    );
    _collections.insert(0, created);
    await _storageService.saveCollections(_collections);
    notifyListeners();
    return created;
  }

  /// Unchecks all items on [collectionId] so a checklist can be reused cleanly
  /// for the next trip while tracking [CollectionItem.reuseCount].
  Future<CollectionItem?> uncheckAllEntries(
    String collectionId, {
    DateTime? nowOverride,
  }) async {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) return null;
    final updated = _collections[index].resetForNextTrip(nowOverride: nowOverride);
    _collections[index] = updated;
    await _storageService.saveCollections(_collections);
    notifyListeners();
    return updated;
  }

  /// Duplicates [collectionId] with independent entry IDs right after the source
  /// template/list, resetting checked state by default for a fresh trip.
  Future<CollectionItem?> duplicateCollection(
    String collectionId, {
    String? customTitle,
    bool resetChecks = true,
    DateTime? nowOverride,
  }) async {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) return null;
    final source = _collections[index];
    final desired = customTitle != null && customTitle.trim().isNotEmpty
        ? customTitle.trim()
        : '${source.title} (Copy)';
    final uniqueTitle = _generateUniqueTitle(desired);

    final duplicated = source.duplicateAsNewTrip(
      newId: _uuid.v4(),
      entryIdGenerator: () => _uuid.v4(),
      title: uniqueTitle,
      resetChecks: resetChecks,
      nowOverride: nowOverride,
    );
    _collections.insert(index + 1, duplicated);
    await _storageService.saveCollections(_collections);
    notifyListeners();
    return duplicated;
  }

  Future<void> deleteCollection(String id) async {
    _collections.removeWhere((c) => c.id == id);
    await _storageService.saveCollections(_collections);
    notifyListeners();
  }

  // --- Wishlist Actions ---

  Future<void> addWishlistItem(WishlistItem item) async {
    _wishlist.add(item);
    await _storageService.saveWishlist(_wishlist);
    notifyListeners();
  }

  Future<void> toggleWishlistPurchased(String id) async {
    final index = _wishlist.indexWhere((w) => w.id == id);
    if (index != -1) {
      _wishlist[index] = _wishlist[index].copyWith(
        isPurchased: !_wishlist[index].isPurchased,
      );
      await _storageService.saveWishlist(_wishlist);
      notifyListeners();
    }
  }

  int indexOfWishlistItem(String id) =>
      _wishlist.indexWhere((w) => w.id == id);

  /// Restores a deleted or previously modified wishlist [item] at [index].
  Future<void> restoreWishlistItem(WishlistItem item, {int? index}) async {
    final existingIndex = _wishlist.indexWhere((w) => w.id == item.id);
    if (existingIndex != -1) {
      _wishlist[existingIndex] = item;
    } else {
      final insertAt = (index ?? _wishlist.length).clamp(0, _wishlist.length);
      _wishlist.insert(insertAt, item);
    }
    await _storageService.saveWishlist(_wishlist);
    notifyListeners();
  }

  Future<void> deleteWishlistItem(String id) async {
    _wishlist.removeWhere((w) => w.id == id);
    await _storageService.saveWishlist(_wishlist);
    notifyListeners();
  }
}

