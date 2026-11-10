import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AlarmCategoryType {
  wakeUp,
  work,
  personal,
  health,
  activities,
  other,
}

class AlarmCategory {
  final AlarmCategoryType type;
  final String name;
  final IconData icon;
  final Color color;

  const AlarmCategory({
    required this.type,
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<AlarmCategory> predefined = [
    AlarmCategory(
      type: AlarmCategoryType.wakeUp,
      name: 'Wake Up',
      icon: Icons.wb_sunny_rounded,
      color: AppColors.catWakeUp,
    ),
    AlarmCategory(
      type: AlarmCategoryType.work,
      name: 'Work',
      icon: Icons.work_outline_rounded,
      color: AppColors.catWork,
    ),
    AlarmCategory(
      type: AlarmCategoryType.personal,
      name: 'Personal',
      icon: Icons.person_outline_rounded,
      color: AppColors.catPersonal,
    ),
    AlarmCategory(
      type: AlarmCategoryType.health,
      name: 'Health',
      icon: Icons.favorite_outline_rounded,
      color: AppColors.catHealth,
    ),
    AlarmCategory(
      type: AlarmCategoryType.activities,
      name: 'Activities',
      icon: Icons.fitness_center_rounded,
      color: AppColors.catActivities,
    ),
    AlarmCategory(
      type: AlarmCategoryType.other,
      name: 'Other',
      icon: Icons.label_outline_rounded,
      color: AppColors.catOther,
    ),
  ];

  static AlarmCategory fromType(AlarmCategoryType type) {
    return predefined.firstWhere(
      (c) => c.type == type,
      orElse: () => predefined.last,
    );
  }

  static AlarmCategory fromString(String name) {
    return predefined.firstWhere(
      (c) => c.type.name.toLowerCase() == name.toLowerCase(),
      orElse: () => predefined.first,
    );
  }

  String toJson() => type.name;

  static AlarmCategory fromJson(dynamic json) {
    if (json == null) return predefined.first;
    return fromString(json.toString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmCategory &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;
}

