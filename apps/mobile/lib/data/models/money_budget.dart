import 'money_account.dart';

enum BudgetHealthStatus {
  healthy,
  nearLimit,
  exceeded,
}

class MoneyBudget {
  final String id;
  final String userId;
  final int year;
  final int month;

  /// Null represents the overall monthly spending budget limit;
  /// non-null targets an individual expense category.
  final String? categoryId;

  /// Monthly spending cap in exact integer minor units (> 0).
  final int limitMinor;
  final int warningThresholdPercent;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MoneyBudget({
    required this.id,
    this.userId = MoneyAccount.defaultUserId,
    required this.year,
    required this.month,
    this.categoryId,
    required this.limitMinor,
    this.warningThresholdPercent = 80,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverallBudget => categoryId == null;

  String get monthKey =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  MoneyBudget copyWith({
    String? id,
    String? userId,
    int? year,
    int? month,
    String? categoryId,
    bool? clearCategoryId,
    int? limitMinor,
    int? warningThresholdPercent,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoneyBudget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      year: year ?? this.year,
      month: month ?? this.month,
      categoryId: clearCategoryId == true ? null : (categoryId ?? this.categoryId),
      limitMinor: limitMinor ?? this.limitMinor,
      warningThresholdPercent:
          warningThresholdPercent ?? this.warningThresholdPercent,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'year': year,
      'month': month,
      'categoryId': categoryId,
      'limitMinor': limitMinor,
      'warningThresholdPercent': warningThresholdPercent,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MoneyBudget.fromJson(Map<String, dynamic> json) {
    return MoneyBudget(
      id: json['id'] as String,
      userId: (json['userId'] as String?)?.isNotEmpty == true
          ? json['userId'] as String
          : MoneyAccount.defaultUserId,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: ((json['month'] as num?)?.toInt() ?? DateTime.now().month)
          .clamp(1, 12),
      categoryId: json['categoryId'] as String?,
      limitMinor: (json['limitMinor'] as num?)?.toInt() ?? 0,
      warningThresholdPercent:
          ((json['warningThresholdPercent'] as num?)?.toInt() ?? 80)
              .clamp(10, 99),
      note: json['note'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

class BudgetUtilizationSummary {
  final MoneyBudget budget;
  final int spentMinor;
  final int remainingMinor;
  final int utilizationPercent;
  final BudgetHealthStatus status;

  const BudgetUtilizationSummary({
    required this.budget,
    required this.spentMinor,
    required this.remainingMinor,
    required this.utilizationPercent,
    required this.status,
  });

  factory BudgetUtilizationSummary.compute({
    required MoneyBudget budget,
    required int spentMinor,
  }) {
    final limit = budget.limitMinor;
    final remaining = limit - spentMinor;
    final percent = limit <= 0 ? 0 : (spentMinor * 100) ~/ limit;

    BudgetHealthStatus status = BudgetHealthStatus.healthy;
    if (spentMinor > limit) {
      status = BudgetHealthStatus.exceeded;
    } else if (limit > 0 && percent >= budget.warningThresholdPercent) {
      status = BudgetHealthStatus.nearLimit;
    }

    return BudgetUtilizationSummary(
      budget: budget,
      spentMinor: spentMinor,
      remainingMinor: remaining,
      utilizationPercent: percent,
      status: status,
    );
  }
}
