import 'package:flutter/material.dart';
import 'money_account.dart';

enum MoneyCategoryType {
  income('Income', Color(0xFF10B981)),
  expense('Expense', Color(0xFFEF4444));

  final String label;
  final Color semanticColor;

  const MoneyCategoryType(this.label, this.semanticColor);

  static MoneyCategoryType fromName(String? name) {
    return MoneyCategoryType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => MoneyCategoryType.expense,
    );
  }
}

class MoneyCategory {
  final String id;
  final String userId;
  final String name;
  final MoneyCategoryType type;
  final int iconCodePoint;
  final int colorValue;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MoneyCategory({
    required this.id,
    this.userId = MoneyAccount.defaultUserId,
    required this.name,
    required this.type,
    required this.iconCodePoint,
    required this.colorValue,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get color => Color(colorValue);
  IconData get icon => resolveCategoryIcon(iconCodePoint);

  static const List<IconData> _knownIcons = [
    Icons.work_rounded,
    Icons.storefront_rounded,
    Icons.laptop_mac_rounded,
    Icons.trending_up_rounded,
    Icons.card_giftcard_rounded,
    Icons.attach_money_rounded,
    Icons.restaurant_rounded,
    Icons.directions_car_rounded,
    Icons.shopping_bag_rounded,
    Icons.home_rounded,
    Icons.bolt_rounded,
    Icons.favorite_rounded,
    Icons.movie_rounded,
    Icons.school_rounded,
    Icons.family_restroom_rounded,
    Icons.autorenew_rounded,
    Icons.more_horiz_rounded,
    Icons.pets_rounded,
    Icons.flight_rounded,
    Icons.category_rounded,
  ];

  static IconData resolveCategoryIcon(int codePoint) {
    for (final ic in _knownIcons) {
      if (ic.codePoint == codePoint) return ic;
    }
    return Icons.category_rounded;
  }

  MoneyCategory copyWith({
    String? id,
    String? userId,
    String? name,
    MoneyCategoryType? type,
    int? iconCodePoint,
    int? colorValue,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoneyCategory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type.name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MoneyCategory.fromJson(Map<String, dynamic> json) {
    return MoneyCategory(
      id: json['id'] as String,
      userId: (json['userId'] as String?)?.isNotEmpty == true
          ? json['userId'] as String
          : MoneyAccount.defaultUserId,
      name: json['name'] as String? ?? 'Other',
      type: MoneyCategoryType.fromName(json['type'] as String?),
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.category_rounded.codePoint,
      colorValue: (json['colorValue'] as num?)?.toInt() ??
          const Color(0xFFF59E0B).toARGB32(),
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  static List<MoneyCategory> defaultsForUser(String userId) {
    final now = DateTime.now();
    return [
      // Suggested Income Categories
      MoneyCategory(
        id: 'cat_${userId}_inc_salary',
        userId: userId,
        name: 'Salary',
        type: MoneyCategoryType.income,
        iconCodePoint: Icons.work_rounded.codePoint,
        colorValue: const Color(0xFF10B981).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_inc_business',
        userId: userId,
        name: 'Business Income',
        type: MoneyCategoryType.income,
        iconCodePoint: Icons.storefront_rounded.codePoint,
        colorValue: const Color(0xFF06B6D4).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_inc_freelance',
        userId: userId,
        name: 'Freelance',
        type: MoneyCategoryType.income,
        iconCodePoint: Icons.laptop_mac_rounded.codePoint,
        colorValue: const Color(0xFF3B82F6).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_inc_investment',
        userId: userId,
        name: 'Investment Returns',
        type: MoneyCategoryType.income,
        iconCodePoint: Icons.trending_up_rounded.codePoint,
        colorValue: const Color(0xFF8B5CF6).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_inc_gifts',
        userId: userId,
        name: 'Gifts',
        type: MoneyCategoryType.income,
        iconCodePoint: Icons.card_giftcard_rounded.codePoint,
        colorValue: const Color(0xFFEC4899).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_inc_other',
        userId: userId,
        name: 'Other Income',
        type: MoneyCategoryType.income,
        iconCodePoint: Icons.attach_money_rounded.codePoint,
        colorValue: const Color(0xFF14B8A6).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),

      // Suggested Expense Categories
      MoneyCategory(
        id: 'cat_${userId}_exp_food',
        userId: userId,
        name: 'Food & Drinks',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.restaurant_rounded.codePoint,
        colorValue: const Color(0xFFF59E0B).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_transport',
        userId: userId,
        name: 'Transportation',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.directions_car_rounded.codePoint,
        colorValue: const Color(0xFF3B82F6).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_shopping',
        userId: userId,
        name: 'Shopping',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.shopping_bag_rounded.codePoint,
        colorValue: const Color(0xFFEC4899).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_housing',
        userId: userId,
        name: 'Housing',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.home_rounded.codePoint,
        colorValue: const Color(0xFF8B5CF6).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_utilities',
        userId: userId,
        name: 'Utilities',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.bolt_rounded.codePoint,
        colorValue: const Color(0xFF06B6D4).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_health',
        userId: userId,
        name: 'Health',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.favorite_rounded.codePoint,
        colorValue: const Color(0xFFEF4444).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_entertainment',
        userId: userId,
        name: 'Entertainment',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.movie_rounded.codePoint,
        colorValue: const Color(0xFFA855F7).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_education',
        userId: userId,
        name: 'Education',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.school_rounded.codePoint,
        colorValue: const Color(0xFF0EA5E9).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_family',
        userId: userId,
        name: 'Family',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.family_restroom_rounded.codePoint,
        colorValue: const Color(0xFFF97316).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_subscriptions',
        userId: userId,
        name: 'Subscriptions',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.autorenew_rounded.codePoint,
        colorValue: const Color(0xFF6366F1).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      MoneyCategory(
        id: 'cat_${userId}_exp_other',
        userId: userId,
        name: 'Other Expenses',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.more_horiz_rounded.codePoint,
        colorValue: const Color(0xFF6B7280).toARGB32(),
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
