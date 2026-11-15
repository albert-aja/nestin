import '../../core/l10n/app_localizations.dart';

enum MealInstruction {
  anytime,
  beforeMeal,
  withMeal,
  afterMeal,
  emptyStomach,
}

extension MealInstructionExtension on MealInstruction {
  String get label {
    final l10n = AppLocalizations.current;
    switch (this) {
      case MealInstruction.anytime:
        return l10n.tr('any_time');
      case MealInstruction.beforeMeal:
        return l10n.tr('before_food');
      case MealInstruction.withMeal:
        return l10n.tr('with_food');
      case MealInstruction.afterMeal:
        return l10n.tr('after_food');
      case MealInstruction.emptyStomach:
        return l10n.tr('empty_stomach');
    }
  }

  String get shortLabel {
    final l10n = AppLocalizations.current;
    switch (this) {
      case MealInstruction.anytime:
        return l10n.tr('anytime');
      case MealInstruction.beforeMeal:
        return l10n.tr('before_meal');
      case MealInstruction.withMeal:
        return l10n.tr('with_meal');
      case MealInstruction.afterMeal:
        return l10n.tr('after_meal');
      case MealInstruction.emptyStomach:
        return l10n.tr('empty_stomach_2');
    }
  }

  String get iconEmoji {
    switch (this) {
      case MealInstruction.anytime:
        return '⏰';
      case MealInstruction.beforeMeal:
        return '⏳';
      case MealInstruction.withMeal:
        return '🍽️';
      case MealInstruction.afterMeal:
        return '☕';
      case MealInstruction.emptyStomach:
        return '💧';
    }
  }
}

class MedicationItem {
  final String id;
  final String name;
  final double dosageAmount;
  final String dosageUnit;
  final MealInstruction mealInstruction;
  final List<String> scheduleTimes; // e.g. ["08:00", "20:00"]
  final List<int> daysOfWeek; // 1 = Monday to 7 = Sunday
  final int? currentStock;
  final int? refillThreshold;
  final bool refillWarningEnabled;
  final String? notes;
  final bool isActive;
  final String colorHex;
  final DateTime createdAt;

  const MedicationItem({
    required this.id,
    required this.name,
    this.dosageAmount = 1.0,
    this.dosageUnit = 'pills',
    this.mealInstruction = MealInstruction.anytime,
    this.scheduleTimes = const ['08:00'],
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.currentStock,
    this.refillThreshold = 5,
    this.refillWarningEnabled = true,
    this.notes,
    this.isActive = true,
    this.colorHex = '#8B5CF6',
    required this.createdAt,
  });

  bool get isLowStock =>
      refillWarningEnabled &&
      currentStock != null &&
      refillThreshold != null &&
      currentStock! <= refillThreshold!;

  static String localizeUnit(String unit, {double? quantity}) {
    final l10n = AppLocalizations.current;
    switch (unit.toLowerCase()) {
      case 'pills':
      case 'pill':
        return quantity == 1.0 ? l10n.tr('unit_pill') : l10n.tr('unit_pills');
      case 'drops':
        return quantity == 1.0 ? l10n.tr('unit_drop') : l10n.tr('unit_drops');
      case 'puffs':
        return quantity == 1.0 ? l10n.tr('unit_puff') : l10n.tr('unit_puffs');
      case 'capsules':
        return quantity == 1.0 ? l10n.tr('unit_capsule') : l10n.tr('unit_capsules');
      default:
        return unit;
    }
  }

  String get localizedUnitLabel => localizeUnit(dosageUnit);

  String get dosageString {
    final cleanAmount = dosageAmount % 1 == 0
        ? dosageAmount.toInt().toString()
        : dosageAmount.toString();
    return '$cleanAmount ${localizeUnit(dosageUnit, quantity: dosageAmount)}';
  }

  bool isScheduledForDate(DateTime date) {
    if (!isActive) return false;
    return daysOfWeek.contains(date.weekday);
  }

  MedicationItem copyWith({
    String? id,
    String? name,
    double? dosageAmount,
    String? dosageUnit,
    MealInstruction? mealInstruction,
    List<String>? scheduleTimes,
    List<int>? daysOfWeek,
    int? currentStock,
    bool clearStock = false,
    int? refillThreshold,
    bool? refillWarningEnabled,
    String? notes,
    bool clearNotes = false,
    bool? isActive,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return MedicationItem(
      id: id ?? this.id,
      name: name ?? this.name,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      mealInstruction: mealInstruction ?? this.mealInstruction,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      currentStock: clearStock ? null : (currentStock ?? this.currentStock),
      refillThreshold: refillThreshold ?? this.refillThreshold,
      refillWarningEnabled: refillWarningEnabled ?? this.refillWarningEnabled,
      notes: clearNotes ? null : (notes ?? this.notes),
      isActive: isActive ?? this.isActive,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosageAmount': dosageAmount,
      'dosageUnit': dosageUnit,
      'mealInstruction': mealInstruction.name,
      'scheduleTimes': scheduleTimes,
      'daysOfWeek': daysOfWeek,
      'currentStock': currentStock,
      'refillThreshold': refillThreshold,
      'refillWarningEnabled': refillWarningEnabled,
      'notes': notes,
      'isActive': isActive,
      'colorHex': colorHex,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    MealInstruction parsedMeal = MealInstruction.anytime;
    if (json['mealInstruction'] != null) {
      try {
        parsedMeal = MealInstruction.values.byName(json['mealInstruction'] as String);
      } catch (_) {
        parsedMeal = MealInstruction.anytime;
      }
    }

    return MedicationItem(
      id: json['id'] as String,
      name: json['name'] as String,
      dosageAmount: (json['dosageAmount'] as num?)?.toDouble() ?? 1.0,
      dosageUnit: json['dosageUnit'] as String? ?? 'pills',
      mealInstruction: parsedMeal,
      scheduleTimes: (json['scheduleTimes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['08:00'],
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
      currentStock: json['currentStock'] as int?,
      refillThreshold: json['refillThreshold'] as int? ?? 5,
      refillWarningEnabled: json['refillWarningEnabled'] as bool? ?? true,
      notes: json['notes'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      colorHex: json['colorHex'] as String? ?? '#8B5CF6',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

