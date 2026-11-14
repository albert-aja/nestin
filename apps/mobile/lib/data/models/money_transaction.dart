import 'package:flutter/material.dart';
import 'money_account.dart';

enum MoneyTransactionType {
  income('Income', Icons.south_west_rounded, Color(0xFF10B981)),
  expense('Expense', Icons.north_east_rounded, Color(0xFFEF4444)),
  transfer('Transfer', Icons.swap_horiz_rounded, Color(0xFF3B82F6));

  final String label;
  final IconData icon;
  final Color color;

  const MoneyTransactionType(this.label, this.icon, this.color);

  static MoneyTransactionType fromName(String? name) {
    return MoneyTransactionType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => MoneyTransactionType.expense,
    );
  }
}

class MoneyTransaction {
  final String id;
  final String userId;
  final MoneyTransactionType type;

  /// Strictly positive integer minor units (> 0).
  final int amountMinor;

  /// Category ID (required for income and expense; null for internal transfers).
  final String? categoryId;

  /// Affected account (destination for income, source for expense and transfer).
  final String accountId;

  /// Destination account ID exclusively for internal transfers.
  final String? toAccountId;

  /// Logical transfer identifier linking atomic source/destination adjustment.
  final String? transferGroupId;

  /// Calendar transaction date (supports historical/backdated records).
  final DateTime transactionDate;
  final String description;
  final bool isArchived;
  final String? recurringTemplateId;
  final String? occurrenceKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MoneyTransaction({
    required this.id,
    this.userId = MoneyAccount.defaultUserId,
    required this.type,
    required this.amountMinor,
    this.categoryId,
    required this.accountId,
    this.toAccountId,
    this.transferGroupId,
    required this.transactionDate,
    this.description = '',
    this.isArchived = false,
    this.recurringTemplateId,
    this.occurrenceKey,
    required this.createdAt,
    required this.updatedAt,
  });

  String get monthKey =>
      '${transactionDate.year.toString().padLeft(4, '0')}-${transactionDate.month.toString().padLeft(2, '0')}';

  bool involvesAccount(String targetAccountId) =>
      accountId == targetAccountId || toAccountId == targetAccountId;

  MoneyTransaction copyWith({
    String? id,
    String? userId,
    MoneyTransactionType? type,
    int? amountMinor,
    String? categoryId,
    bool? clearCategoryId,
    String? accountId,
    String? toAccountId,
    bool? clearToAccountId,
    String? transferGroupId,
    bool? clearTransferGroupId,
    DateTime? transactionDate,
    String? description,
    bool? isArchived,
    String? recurringTemplateId,
    String? occurrenceKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoneyTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      categoryId: clearCategoryId == true ? null : (categoryId ?? this.categoryId),
      accountId: accountId ?? this.accountId,
      toAccountId:
          clearToAccountId == true ? null : (toAccountId ?? this.toAccountId),
      transferGroupId: clearTransferGroupId == true
          ? null
          : (transferGroupId ?? this.transferGroupId),
      transactionDate: transactionDate ?? this.transactionDate,
      description: description ?? this.description,
      isArchived: isArchived ?? this.isArchived,
      recurringTemplateId: recurringTemplateId ?? this.recurringTemplateId,
      occurrenceKey: occurrenceKey ?? this.occurrenceKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'amountMinor': amountMinor,
      'categoryId': categoryId,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'transferGroupId': transferGroupId,
      'transactionDate': transactionDate.toIso8601String(),
      'description': description,
      'isArchived': isArchived,
      'recurringTemplateId': recurringTemplateId,
      'occurrenceKey': occurrenceKey,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MoneyTransaction.fromJson(Map<String, dynamic> json) {
    return MoneyTransaction(
      id: json['id'] as String,
      userId: (json['userId'] as String?)?.isNotEmpty == true
          ? json['userId'] as String
          : MoneyAccount.defaultUserId,
      type: MoneyTransactionType.fromName(json['type'] as String?),
      amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
      categoryId: json['categoryId'] as String?,
      accountId: json['accountId'] as String? ?? '',
      toAccountId: json['toAccountId'] as String?,
      transferGroupId: json['transferGroupId'] as String?,
      transactionDate: json['transactionDate'] != null
          ? DateTime.parse(json['transactionDate'] as String)
          : DateTime.now(),
      description: json['description'] as String? ?? '',
      isArchived: json['isArchived'] as bool? ?? false,
      recurringTemplateId: json['recurringTemplateId'] as String?,
      occurrenceKey: json['occurrenceKey'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
