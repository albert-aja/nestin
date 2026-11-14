import 'package:flutter/material.dart';

class CollectionEntry {
  final String id;
  final String text;
  final bool isChecked;
  final String? notes;
  final String? urlLink;
  final String? category;

  const CollectionEntry({
    required this.id,
    required this.text,
    this.isChecked = false,
    this.notes,
    this.urlLink,
    this.category,
  });

  CollectionEntry copyWith({
    String? id,
    String? text,
    bool? isChecked,
    String? notes,
    String? urlLink,
    String? category,
    bool clearCategory = false,
  }) {
    return CollectionEntry(
      id: id ?? this.id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
      notes: notes ?? this.notes,
      urlLink: urlLink ?? this.urlLink,
      category: clearCategory ? null : (category ?? this.category),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isChecked': isChecked,
        'notes': notes,
        'urlLink': urlLink,
        if (category != null) 'category': category,
      };

  factory CollectionEntry.fromJson(Map<String, dynamic> json) =>
      CollectionEntry(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        isChecked: json['isChecked'] as bool? ?? false,
        notes: json['notes'] as String?,
        urlLink: json['urlLink'] as String?,
        category: json['category'] as String?,
      );
}

class CollectionItem {
  static const List<IconData> availableIcons = [
    Icons.luggage_rounded,
    Icons.flight_takeoff_rounded,
    Icons.terrain_rounded,
    Icons.business_center_rounded,
    Icons.backpack_rounded,
    Icons.beach_access_rounded,
    Icons.shopping_cart_rounded,
    Icons.location_on_rounded,
    Icons.list_rounded,
    Icons.restaurant_rounded,
    Icons.bookmark_rounded,
    Icons.movie_rounded,
    Icons.checklist_rounded,
    Icons.directions_car_rounded,
  ];

  final String id;
  final String title;
  final String description;
  final int iconCodePoint;
  final int colorValue;
  final List<CollectionEntry> entries;
  final bool isReusableTemplate;
  final String? templateKey;
  final int reuseCount;
  final DateTime? lastResetAt;
  final DateTime createdAt;

  const CollectionItem({
    required this.id,
    required this.title,
    this.description = '',
    this.iconCodePoint = 0xe148, // Icons.list_rounded
    this.colorValue = 0xFF3A86FF,
    this.entries = const [],
    this.isReusableTemplate = false,
    this.templateKey,
    this.reuseCount = 0,
    this.lastResetAt,
    required this.createdAt,
  });

  int get totalCount => entries.length;
  int get checkedCount => entries.where((e) => e.isChecked).length;
  bool get hasCheckedEntries => entries.any((e) => e.isChecked);
  bool get isAllChecked => entries.isNotEmpty && checkedCount == totalCount;
  double get progress => totalCount == 0 ? 0.0 : checkedCount / totalCount;

  IconData get displayIcon {
    switch (iconCodePoint) {
      case 0xe59c:
        return Icons.shopping_cart_rounded;
      case 0xe3ab:
        return Icons.location_on_rounded;
      case 0xe148:
        return Icons.list_rounded;
      case 0xe52f:
        return Icons.restaurant_rounded;
      case 0xe163:
        return Icons.bookmark_rounded;
      case 0xe3e3:
        return Icons.movie_rounded;
      case 0xe473:
        return Icons.flight_takeoff_rounded;
      default:
        for (final icon in availableIcons) {
          if (icon.codePoint == iconCodePoint) return icon;
        }
        return Icons.format_list_bulleted_rounded;
    }
  }

  /// Unchecks every entry so a reusable packing/travel checklist can be reused
  /// cleanly for the next trip, incrementing [reuseCount] when items were checked.
  CollectionItem resetForNextTrip({DateTime? nowOverride}) {
    final now = nowOverride ?? DateTime.now();
    final resetEntries =
        entries.map((e) => e.copyWith(isChecked: false)).toList();
    return copyWith(
      entries: resetEntries,
      isReusableTemplate: true,
      reuseCount: hasCheckedEntries ? reuseCount + 1 : reuseCount,
      lastResetAt: now,
    );
  }

  /// Produces an independent copy of this list with fresh entry IDs.
  CollectionItem duplicateAsNewTrip({
    required String newId,
    required String Function() entryIdGenerator,
    required String title,
    bool resetChecks = true,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final clonedEntries = entries
        .map(
          (e) => e.copyWith(
            id: entryIdGenerator(),
            isChecked: resetChecks ? false : e.isChecked,
          ),
        )
        .toList();
    return CollectionItem(
      id: newId,
      title: title,
      description: description,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      entries: clonedEntries,
      isReusableTemplate: isReusableTemplate,
      templateKey: templateKey,
      reuseCount: 0,
      lastResetAt: null,
      createdAt: now,
    );
  }

  CollectionItem copyWith({
    String? id,
    String? title,
    String? description,
    int? iconCodePoint,
    int? colorValue,
    List<CollectionEntry>? entries,
    bool? isReusableTemplate,
    String? templateKey,
    bool clearTemplateKey = false,
    int? reuseCount,
    DateTime? lastResetAt,
    bool clearLastResetAt = false,
    DateTime? createdAt,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      entries: entries ?? this.entries,
      isReusableTemplate: isReusableTemplate ?? this.isReusableTemplate,
      templateKey:
          clearTemplateKey ? null : (templateKey ?? this.templateKey),
      reuseCount: reuseCount ?? this.reuseCount,
      lastResetAt:
          clearLastResetAt ? null : (lastResetAt ?? this.lastResetAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'entries': entries.map((e) => e.toJson()).toList(),
      'isReusableTemplate': isReusableTemplate,
      'templateKey': templateKey,
      'reuseCount': reuseCount,
      'lastResetAt': lastResetAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    final list = rawEntries
        .map((e) => CollectionEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return CollectionItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'List',
      description: json['description'] as String? ?? '',
      iconCodePoint: json['iconCodePoint'] as int? ?? 0xe148,
      colorValue: json['colorValue'] as int? ?? 0xFF3A86FF,
      entries: list,
      isReusableTemplate: json['isReusableTemplate'] as bool? ?? false,
      templateKey: json['templateKey'] as String?,
      reuseCount: (json['reuseCount'] as num?)?.toInt() ?? 0,
      lastResetAt: json['lastResetAt'] != null
          ? DateTime.parse(json['lastResetAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class PackingTemplateItemSpec {
  final String text;
  final String category;

  const PackingTemplateItemSpec({
    required this.text,
    required this.category,
  });
}

class PackingTemplateSpec {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final int colorValue;
  final List<PackingTemplateItemSpec> items;

  const PackingTemplateSpec({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.colorValue,
    required this.items,
  });

  CollectionItem instantiate({
    required String id,
    required String Function() entryIdGenerator,
    String? customTitle,
    bool markReusable = true,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final trimmed = customTitle?.trim() ?? '';
    return CollectionItem(
      id: id,
      title: trimmed.isNotEmpty ? trimmed : title,
      description: description,
      iconCodePoint: icon.codePoint,
      colorValue: colorValue,
      isReusableTemplate: markReusable,
      templateKey: key,
      entries: items
          .map(
            (item) => CollectionEntry(
              id: entryIdGenerator(),
              text: item.text,
              category: item.category,
            ),
          )
          .toList(),
      createdAt: now,
    );
  }
}

/// Pre-built reusable travel & trip packing checklist templates.
class TravelPackingTemplates {
  static const String weekendTripKey = 'weekend_trip';
  static const String internationalFlightKey = 'international_flight';
  static const String outdoorCampingKey = 'outdoor_camping';
  static const String businessKey = 'business';

  static const List<PackingTemplateSpec> presets = [
    PackingTemplateSpec(
      key: weekendTripKey,
      title: 'Weekend Trip',
      description: '2-3 day quick getaway clothing, tech & essentials',
      icon: Icons.luggage_rounded,
      colorValue: 0xFF3B82F6,
      items: [
        PackingTemplateItemSpec(
          text: 'ID / Driver license & transit cards',
          category: 'Documents',
        ),
        PackingTemplateItemSpec(
          text: 'Phone charger & portable power bank',
          category: 'Tech',
        ),
        PackingTemplateItemSpec(
          text: '2-3 outfits, sleepwear & extra socks',
          category: 'Clothing',
        ),
        PackingTemplateItemSpec(
          text: 'Light jacket & comfortable walking shoes',
          category: 'Clothing',
        ),
        PackingTemplateItemSpec(
          text: 'Toothbrush, toothpaste & mini toiletries',
          category: 'Toiletries',
        ),
        PackingTemplateItemSpec(
          text: 'Reusable water bottle & sunglasses',
          category: 'Essentials',
        ),
        PackingTemplateItemSpec(
          text: 'Earphones / book or e-reader',
          category: 'Tech',
        ),
        PackingTemplateItemSpec(
          text: 'Foldable laundry pouch for worn clothes',
          category: 'Essentials',
        ),
      ],
    ),
    PackingTemplateSpec(
      key: internationalFlightKey,
      title: 'International Flight',
      description: 'Passport, adapters, cabin comfort & carry-on essentials',
      icon: Icons.flight_takeoff_rounded,
      colorValue: 0xFFF59E0B,
      items: [
        PackingTemplateItemSpec(
          text: 'Passport, visa docs & boarding pass',
          category: 'Documents',
        ),
        PackingTemplateItemSpec(
          text: 'Foreign currency, cards & offline itinerary',
          category: 'Documents',
        ),
        PackingTemplateItemSpec(
          text: 'Universal plug adapter & multi-port charger',
          category: 'Tech',
        ),
        PackingTemplateItemSpec(
          text: 'Noise-cancelling headphones',
          category: 'Tech',
        ),
        PackingTemplateItemSpec(
          text: 'Travel neck pillow & sleep eye mask',
          category: 'Cabin Comfort',
        ),
        PackingTemplateItemSpec(
          text: 'Clear <=100ml liquids & skincare bag',
          category: 'Toiletries',
        ),
        PackingTemplateItemSpec(
          text: 'Prescription meds & travel first-aid pouch',
          category: 'Health',
        ),
        PackingTemplateItemSpec(
          text: 'Spare shirt & underwear inside carry-on',
          category: 'Clothing',
        ),
        PackingTemplateItemSpec(
          text: 'Pen for customs forms & eSIM / roaming ready',
          category: 'Essentials',
        ),
      ],
    ),
    PackingTemplateSpec(
      key: outdoorCampingKey,
      title: 'Outdoor Camping',
      description: 'Shelter, warmth, trail safety & camp kitchen gear',
      icon: Icons.terrain_rounded,
      colorValue: 0xFF10B981,
      items: [
        PackingTemplateItemSpec(
          text: 'Tent, stakes, rainfly & groundsheet',
          category: 'Shelter',
        ),
        PackingTemplateItemSpec(
          text: 'Sleeping bag & insulated sleeping pad',
          category: 'Shelter',
        ),
        PackingTemplateItemSpec(
          text: 'Headlamp / lantern & spare batteries',
          category: 'Gear',
        ),
        PackingTemplateItemSpec(
          text: 'Thermal layers, rain shell & hiking boots',
          category: 'Clothing',
        ),
        PackingTemplateItemSpec(
          text: 'Camp stove, fuel canister & mess kit',
          category: 'Camp Kitchen',
        ),
        PackingTemplateItemSpec(
          text: 'Water filter / bottles & trail snacks',
          category: 'Hydration & Food',
        ),
        PackingTemplateItemSpec(
          text: 'First-aid kit, bug spray & sunscreen',
          category: 'Safety',
        ),
        PackingTemplateItemSpec(
          text: 'Multi-tool, paracord & waterproof dry bags',
          category: 'Gear',
        ),
        PackingTemplateItemSpec(
          text: 'Offline trail map, whistle & power bank',
          category: 'Safety',
        ),
      ],
    ),
    PackingTemplateSpec(
      key: businessKey,
      title: 'Business',
      description: 'Work laptop, presentation kit & conference wardrobe',
      icon: Icons.business_center_rounded,
      colorValue: 0xFF6366F1,
      items: [
        PackingTemplateItemSpec(
          text: 'Laptop, USB-C charger & HDMI display dongle',
          category: 'Tech',
        ),
        PackingTemplateItemSpec(
          text: 'Business attire, blazer & dress shoes',
          category: 'Clothing',
        ),
        PackingTemplateItemSpec(
          text: 'Lint roller / compact travel steamer',
          category: 'Clothing',
        ),
        PackingTemplateItemSpec(
          text: 'Company ID badge & business cards',
          category: 'Work',
        ),
        PackingTemplateItemSpec(
          text: 'Notebook, pens & presentation clicker',
          category: 'Work',
        ),
        PackingTemplateItemSpec(
          text: 'Call headset & backup hotspot / power bank',
          category: 'Tech',
        ),
        PackingTemplateItemSpec(
          text: 'Compact umbrella & stain remover pen',
          category: 'Essentials',
        ),
        PackingTemplateItemSpec(
          text: 'Travel grooming kit & receipts folder',
          category: 'Work',
        ),
      ],
    ),
  ];

  static PackingTemplateSpec? findByKey(String key) {
    for (final spec in presets) {
      if (spec.key == key) return spec;
    }
    return null;
  }
}
