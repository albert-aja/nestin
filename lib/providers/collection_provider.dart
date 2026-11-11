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

  List<CollectionItem> get collections => List.unmodifiable(_collections);
  List<WishlistItem> get wishlist => List.unmodifiable(_wishlist);

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

  Future<void> addEntryToCollection(String collectionId, String text) async {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      final col = _collections[index];
      final newEntries = List<CollectionEntry>.from(col.entries)
        ..add(CollectionEntry(id: const Uuid().v4(), text: text));
      _collections[index] = col.copyWith(entries: newEntries);
      await _storageService.saveCollections(_collections);
      notifyListeners();
    }
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

  Future<void> deleteWishlistItem(String id) async {
    _wishlist.removeWhere((w) => w.id == id);
    await _storageService.saveWishlist(_wishlist);
    notifyListeners();
  }
}

