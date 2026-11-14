import 'alarm_category.dart';
import 'task_item.dart';

class WishlistItem {
  final String id;
  final String title;
  final String description;
  final double? targetPrice;
  final AlarmCategory category;
  final String? urlLink;
  final TaskPriority priority;
  final bool isPurchased;
  final DateTime? targetDate;
  final DateTime createdAt;

  const WishlistItem({
    required this.id,
    required this.title,
    this.description = '',
    this.targetPrice,
    required this.category,
    this.urlLink,
    this.priority = TaskPriority.medium,
    this.isPurchased = false,
    this.targetDate,
    required this.createdAt,
  });

  String formattedPrice() {
    if (targetPrice == null) return '';
    return '\$${targetPrice!.toStringAsFixed(targetPrice! % 1 == 0 ? 0 : 2)}';
  }

  WishlistItem copyWith({
    String? id,
    String? title,
    String? description,
    double? targetPrice,
    bool? clearPrice,
    AlarmCategory? category,
    String? urlLink,
    TaskPriority? priority,
    bool? isPurchased,
    DateTime? targetDate,
    bool? clearTargetDate,
    DateTime? createdAt,
  }) {
    return WishlistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetPrice: clearPrice == true ? null : (targetPrice ?? this.targetPrice),
      category: category ?? this.category,
      urlLink: urlLink ?? this.urlLink,
      priority: priority ?? this.priority,
      isPurchased: isPurchased ?? this.isPurchased,
      targetDate: clearTargetDate == true ? null : (targetDate ?? this.targetDate),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetPrice': targetPrice,
      'category': category.toJson(),
      'urlLink': urlLink,
      'priority': priority.name,
      'isPurchased': isPurchased,
      'targetDate': targetDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    final priorityName = json['priority'] as String? ?? 'medium';
    final prio = TaskPriority.values.firstWhere(
      (p) => p.name == priorityName,
      orElse: () => TaskPriority.medium,
    );

    return WishlistItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Item',
      description: json['description'] as String? ?? '',
      targetPrice: (json['targetPrice'] as num?)?.toDouble(),
      category: AlarmCategory.fromJson(json['category']),
      urlLink: json['urlLink'] as String?,
      priority: prio,
      isPurchased: json['isPurchased'] as bool? ?? false,
      targetDate: json['targetDate'] != null
          ? DateTime.tryParse(json['targetDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

