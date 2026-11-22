import 'package:material_ui/material_ui.dart';

enum BucketCategory {
  travelPlaces,
  natureOutdoors,
  cafesFood,
  cultureLearning,
  creativeMilestones,
  lifeExperiences,
}

extension BucketCategoryExt on BucketCategory {
  String label(bool isIndonesian) => isIndonesian ? labelId : labelEn;

  String get labelEn {
    switch (this) {
      case BucketCategory.travelPlaces:
        return 'Places to Visit';
      case BucketCategory.natureOutdoors:
        return 'Nature & Trails';
      case BucketCategory.cafesFood:
        return 'Cafes & Culinary';
      case BucketCategory.cultureLearning:
        return 'Culture & Wonder';
      case BucketCategory.creativeMilestones:
        return 'Creative Goals';
      case BucketCategory.lifeExperiences:
        return 'Life Experiences';
    }
  }

  String get labelId {
    switch (this) {
      case BucketCategory.travelPlaces:
        return 'Tempat Impian';
      case BucketCategory.natureOutdoors:
        return 'Alam & Pendakian';
      case BucketCategory.cafesFood:
        return 'Kafe & Kuliner';
      case BucketCategory.cultureLearning:
        return 'Budaya & Wawasan';
      case BucketCategory.creativeMilestones:
        return 'Target Kreatif';
      case BucketCategory.lifeExperiences:
        return 'Pengalaman Hidup';
    }
  }

  String get emoji {
    switch (this) {
      case BucketCategory.travelPlaces:
        return '✈️';
      case BucketCategory.natureOutdoors:
        return '🏔️';
      case BucketCategory.cafesFood:
        return '☕';
      case BucketCategory.cultureLearning:
        return '🏛️';
      case BucketCategory.creativeMilestones:
        return '🎨';
      case BucketCategory.lifeExperiences:
        return '🌟';
    }
  }

  IconData get icon {
    switch (this) {
      case BucketCategory.travelPlaces:
        return Icons.flight_takeoff_rounded;
      case BucketCategory.natureOutdoors:
        return Icons.terrain_rounded;
      case BucketCategory.cafesFood:
        return Icons.local_cafe_rounded;
      case BucketCategory.cultureLearning:
        return Icons.museum_rounded;
      case BucketCategory.creativeMilestones:
        return Icons.palette_rounded;
      case BucketCategory.lifeExperiences:
        return Icons.auto_awesome_rounded;
    }
  }

  int get colorValue {
    switch (this) {
      case BucketCategory.travelPlaces:
        return 0xFF10B981;
      case BucketCategory.natureOutdoors:
        return 0xFF059669;
      case BucketCategory.cafesFood:
        return 0xFFF59E0B;
      case BucketCategory.cultureLearning:
        return 0xFF3B82F6;
      case BucketCategory.creativeMilestones:
        return 0xFF8B5CF6;
      case BucketCategory.lifeExperiences:
        return 0xFFE04A3A;
    }
  }

  Color get color => Color(colorValue);
}

enum BucketTargetSeason {
  anytime,
  spring,
  summer,
  autumn,
  winter,
  drySeason,
  rainySeason,
}

extension BucketTargetSeasonExt on BucketTargetSeason {
  String label(bool isIndonesian) => isIndonesian ? labelId : labelEn;

  String get labelEn {
    switch (this) {
      case BucketTargetSeason.anytime:
        return 'Flexible';
      case BucketTargetSeason.spring:
        return 'Spring';
      case BucketTargetSeason.summer:
        return 'Summer';
      case BucketTargetSeason.autumn:
        return 'Autumn';
      case BucketTargetSeason.winter:
        return 'Winter';
      case BucketTargetSeason.drySeason:
        return 'Dry Season';
      case BucketTargetSeason.rainySeason:
        return 'Rainy Season';
    }
  }

  String get labelId {
    switch (this) {
      case BucketTargetSeason.anytime:
        return 'Fleksibel';
      case BucketTargetSeason.spring:
        return 'Musim Semi';
      case BucketTargetSeason.summer:
        return 'Musim Panas';
      case BucketTargetSeason.autumn:
        return 'Musim Gugur';
      case BucketTargetSeason.winter:
        return 'Musim Dingin';
      case BucketTargetSeason.drySeason:
        return 'Musim Kemarau';
      case BucketTargetSeason.rainySeason:
        return 'Musim Hujan';
    }
  }

  String get emoji {
    switch (this) {
      case BucketTargetSeason.anytime:
        return '🧭';
      case BucketTargetSeason.spring:
        return '🌸';
      case BucketTargetSeason.summer:
        return '☀️';
      case BucketTargetSeason.autumn:
        return '🍂';
      case BucketTargetSeason.winter:
        return '❄️';
      case BucketTargetSeason.drySeason:
        return '🌤️';
      case BucketTargetSeason.rainySeason:
        return '🌧️';
    }
  }

  String? displayBadge({bool isIndonesian = false, int? year}) {
    if (this == BucketTargetSeason.anytime && year == null) {
      return null;
    }
    if (this == BucketTargetSeason.anytime && year != null) {
      return '📅 $year';
    }
    final seasonText = label(isIndonesian);
    return year != null ? '$emoji $seasonText $year' : '$emoji $seasonText';
  }
}

/// Visual dream-goal or place-to-visit entry managed by Pippin and promotable to
/// Echo's milestone [MemoryItem] upon completion.
class BucketListItem {
  final String id;
  final String title;
  final String inspirationNote;
  final BucketCategory category;
  final BucketTargetSeason targetSeason;
  final int? targetYear;
  final String? locationLabel;
  final String? savedPlaceId;
  final String? savedPlaceName;
  final bool isStarred;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? promotedMemoryId;
  final DateTime? promotedToMemoryAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BucketListItem({
    required this.id,
    required this.title,
    this.inspirationNote = '',
    this.category = BucketCategory.travelPlaces,
    this.targetSeason = BucketTargetSeason.anytime,
    this.targetYear,
    this.locationLabel,
    this.savedPlaceId,
    this.savedPlaceName,
    this.isStarred = false,
    this.isCompleted = false,
    this.completedAt,
    this.promotedMemoryId,
    this.promotedToMemoryAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasSavedPlaceLink =>
      savedPlaceId != null && savedPlaceId!.trim().isNotEmpty;

  bool get isPromotedToMemory =>
      promotedMemoryId != null && promotedMemoryId!.trim().isNotEmpty;

  bool get hasInspirationNote => inspirationNote.trim().isNotEmpty;

  String? targetWindowLabel({bool isIndonesian = false}) =>
      targetSeason.displayBadge(isIndonesian: isIndonesian, year: targetYear);

  String resolvedLocationLabel({String? livePlaceName}) {
    if (livePlaceName != null && livePlaceName.trim().isNotEmpty) {
      return livePlaceName.trim();
    }
    if (savedPlaceName != null && savedPlaceName!.trim().isNotEmpty) {
      return savedPlaceName!.trim();
    }
    return locationLabel?.trim() ?? '';
  }

  BucketListItem copyWith({
    String? id,
    String? title,
    String? inspirationNote,
    BucketCategory? category,
    BucketTargetSeason? targetSeason,
    int? targetYear,
    bool clearTargetYear = false,
    String? locationLabel,
    bool clearLocationLabel = false,
    String? savedPlaceId,
    String? savedPlaceName,
    bool clearSavedPlace = false,
    bool? isStarred,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? promotedMemoryId,
    DateTime? promotedToMemoryAt,
    bool clearPromotedMemory = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BucketListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      inspirationNote: inspirationNote ?? this.inspirationNote,
      category: category ?? this.category,
      targetSeason: targetSeason ?? this.targetSeason,
      targetYear: clearTargetYear ? null : (targetYear ?? this.targetYear),
      locationLabel:
          clearLocationLabel ? null : (locationLabel ?? this.locationLabel),
      savedPlaceId:
          clearSavedPlace ? null : (savedPlaceId ?? this.savedPlaceId),
      savedPlaceName:
          clearSavedPlace ? null : (savedPlaceName ?? this.savedPlaceName),
      isStarred: isStarred ?? this.isStarred,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      promotedMemoryId: clearPromotedMemory
          ? null
          : (promotedMemoryId ?? this.promotedMemoryId),
      promotedToMemoryAt: clearPromotedMemory
          ? null
          : (promotedToMemoryAt ?? this.promotedToMemoryAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'inspirationNote': inspirationNote,
      'category': category.name,
      'targetSeason': targetSeason.name,
      'targetYear': targetYear,
      'locationLabel': locationLabel,
      'savedPlaceId': savedPlaceId,
      'savedPlaceName': savedPlaceName,
      'isStarred': isStarred,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'promotedMemoryId': promotedMemoryId,
      'promotedToMemoryAt': promotedToMemoryAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BucketListItem.fromJson(Map<String, dynamic> json) {
    final parsedCategory = BucketCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => BucketCategory.travelPlaces,
    );
    final parsedSeason = BucketTargetSeason.values.firstWhere(
      (s) => s.name == json['targetSeason'],
      orElse: () => BucketTargetSeason.anytime,
    );
    final now = DateTime.now();
    return BucketListItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Dream Goal',
      inspirationNote: json['inspirationNote'] as String? ?? '',
      category: parsedCategory,
      targetSeason: parsedSeason,
      targetYear: (json['targetYear'] as num?)?.toInt(),
      locationLabel: json['locationLabel'] as String?,
      savedPlaceId: json['savedPlaceId'] as String?,
      savedPlaceName: json['savedPlaceName'] as String?,
      isStarred: json['isStarred'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      promotedMemoryId: json['promotedMemoryId'] as String?,
      promotedToMemoryAt: json['promotedToMemoryAt'] != null
          ? DateTime.tryParse(json['promotedToMemoryAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'] as String) ?? now)
          : now,
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt'] as String) ?? now)
          : now,
    );
  }
}
