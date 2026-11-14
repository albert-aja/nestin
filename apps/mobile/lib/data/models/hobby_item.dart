import 'hobby_milestone.dart';

class HobbyItem {
  final String id;
  final String name;
  final String category; // e.g. "Music", "Art", "Language", "Tech", "Craft", "Fitness"
  final String iconEmoji; // e.g. 🎸, 🎨, 💻, 🗣️, 🎹, 📷
  final String colorHex;
  final int? targetHours; // e.g. 50, 100
  final int totalMinutesPracticed;
  final String? notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  HobbyItem({
    required this.id,
    required this.name,
    this.category = 'General',
    this.iconEmoji = '🎨',
    this.colorHex = '#10B981',
    this.targetHours,
    this.totalMinutesPracticed = 0,
    this.notes,
    this.isArchived = false,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  double get totalHoursPracticed => totalMinutesPracticed / 60.0;

  String get formattedHours {
    final hours = totalHoursPracticed;
    if (hours % 1 == 0) {
      return '${hours.toInt()} hrs';
    }
    return '${hours.toStringAsFixed(1)} hrs';
  }

  double get progressToTarget {
    if (targetHours == null || targetHours! <= 0) return 0.0;
    return (totalHoursPracticed / targetHours!).clamp(0.0, 1.0);
  }

  List<HobbyMilestone> get unlockedMilestones {
    return HobbyMilestone.standardMilestones
        .where((m) => m.isUnlocked(totalHoursPracticed))
        .toList();
  }

  HobbyMilestone? get nextMilestone {
    for (final m in HobbyMilestone.standardMilestones) {
      if (!m.isUnlocked(totalHoursPracticed)) {
        return m;
      }
    }
    return null; // All completed
  }

  double get progressToNextMilestone {
    final next = nextMilestone;
    if (next == null) return 1.0;

    // Previous milestone threshold
    int prevHours = 0;
    for (final m in HobbyMilestone.standardMilestones) {
      if (m.requiredHours < next.requiredHours && m.isUnlocked(totalHoursPracticed)) {
        prevHours = m.requiredHours;
      }
    }

    final span = next.requiredHours - prevHours;
    if (span <= 0) return 1.0;
    final current = totalHoursPracticed - prevHours;
    return (current / span).clamp(0.0, 1.0);
  }

  HobbyItem copyWith({
    String? id,
    String? name,
    String? category,
    String? iconEmoji,
    String? colorHex,
    int? targetHours,
    bool clearTargetHours = false,
    int? totalMinutesPracticed,
    String? notes,
    bool clearNotes = false,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HobbyItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      colorHex: colorHex ?? this.colorHex,
      targetHours: clearTargetHours ? null : (targetHours ?? this.targetHours),
      totalMinutesPracticed: totalMinutesPracticed ?? this.totalMinutesPracticed,
      notes: clearNotes ? null : (notes ?? this.notes),
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'iconEmoji': iconEmoji,
      'colorHex': colorHex,
      'targetHours': targetHours,
      'totalMinutesPracticed': totalMinutesPracticed,
      'notes': notes,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HobbyItem.fromJson(Map<String, dynamic> json) {
    return HobbyItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'General',
      iconEmoji: json['iconEmoji'] as String? ?? '🎨',
      colorHex: json['colorHex'] as String? ?? '#10B981',
      targetHours: json['targetHours'] as int?,
      totalMinutesPracticed: (json['totalMinutesPracticed'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
