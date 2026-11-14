import 'money_account.dart';
import 'money_transaction.dart';

enum RecurrenceFrequency {
  daily('Daily'),
  weekly('Weekly'),
  biweekly('Bi-weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  final String label;

  const RecurrenceFrequency(this.label);

  static RecurrenceFrequency fromName(String? name) {
    return RecurrenceFrequency.values.firstWhere(
      (f) => f.name == name,
      orElse: () => RecurrenceFrequency.monthly,
    );
  }
}

class RecurringTransaction {
  final String id;
  final String userId;
  final String title;

  /// Only `income` or `expense` allowed for recurring templates.
  final MoneyTransactionType type;

  /// Fixed amount in integer minor units (> 0).
  final int amountMinor;
  final String categoryId;
  final String accountId;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextOccurrenceDate;
  final bool isActive;
  final String description;
  final DateTime? lastProcessedDate;

  /// Unique occurrence keys already recorded or skipped (e.g. "rec_1:2026-11-01")
  /// to guarantee duplicate prevention.
  final List<String> processedOccurrenceKeys;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringTransaction({
    required this.id,
    this.userId = MoneyAccount.defaultUserId,
    required this.title,
    required this.type,
    required this.amountMinor,
    required this.categoryId,
    required this.accountId,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.nextOccurrenceDate,
    this.isActive = true,
    this.description = '',
    this.lastProcessedDate,
    this.processedOccurrenceKeys = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  static String occurrenceKeyFor(String templateId, DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$templateId:$y-$m-$d';
  }

  String get currentOccurrenceKey =>
      occurrenceKeyFor(id, nextOccurrenceDate);

  bool isDueOnOrBefore(DateTime referenceDate) {
    if (!isActive) return false;
    final refDay = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final nextDay = DateTime(
      nextOccurrenceDate.year,
      nextOccurrenceDate.month,
      nextOccurrenceDate.day,
    );
    if (nextDay.isAfter(refDay)) return false;
    if (endDate != null) {
      final endDay = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (nextDay.isAfter(endDay)) return false;
    }
    return true;
  }

  bool hasAlreadyProcessed(DateTime occurrenceDate) {
    return processedOccurrenceKeys
        .contains(occurrenceKeyFor(id, occurrenceDate));
  }

  static DateTime advanceDate(DateTime date, RecurrenceFrequency frequency) {
    final clean = DateTime(date.year, date.month, date.day);
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return DateTime(clean.year, clean.month, clean.day + 1);
      case RecurrenceFrequency.weekly:
        return DateTime(clean.year, clean.month, clean.day + 7);
      case RecurrenceFrequency.biweekly:
        return DateTime(clean.year, clean.month, clean.day + 14);
      case RecurrenceFrequency.monthly:
        final nextMonth = clean.month == 12 ? 1 : clean.month + 1;
        final nextYear = clean.month == 12 ? clean.year + 1 : clean.year;
        final maxDay = _daysInMonth(nextYear, nextMonth);
        return DateTime(
          nextYear,
          nextMonth,
          clean.day > maxDay ? maxDay : clean.day,
        );
      case RecurrenceFrequency.yearly:
        final nextYear = clean.year + 1;
        final maxDay = _daysInMonth(nextYear, clean.month);
        return DateTime(
          nextYear,
          clean.month,
          clean.day > maxDay ? maxDay : clean.day,
        );
    }
  }

  static int _daysInMonth(int year, int month) {
    // Day 0 of next month is the last day of `month`.
    return DateTime(year, month + 1, 0).day;
  }

  RecurringTransaction copyWith({
    String? id,
    String? userId,
    String? title,
    MoneyTransactionType? type,
    int? amountMinor,
    String? categoryId,
    String? accountId,
    RecurrenceFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? clearEndDate,
    DateTime? nextOccurrenceDate,
    bool? isActive,
    String? description,
    DateTime? lastProcessedDate,
    List<String>? processedOccurrenceKeys,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate == true ? null : (endDate ?? this.endDate),
      nextOccurrenceDate: nextOccurrenceDate ?? this.nextOccurrenceDate,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
      processedOccurrenceKeys:
          processedOccurrenceKeys ?? this.processedOccurrenceKeys,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'type': type.name,
      'amountMinor': amountMinor,
      'categoryId': categoryId,
      'accountId': accountId,
      'frequency': frequency.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'nextOccurrenceDate': nextOccurrenceDate.toIso8601String(),
      'isActive': isActive,
      'description': description,
      'lastProcessedDate': lastProcessedDate?.toIso8601String(),
      'processedOccurrenceKeys': processedOccurrenceKeys,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    final parsedType = MoneyTransactionType.fromName(json['type'] as String?);
    final safeType = parsedType == MoneyTransactionType.transfer
        ? MoneyTransactionType.expense
        : parsedType;
    final start = json['startDate'] != null
        ? DateTime.parse(json['startDate'] as String)
        : DateTime.now();

    return RecurringTransaction(
      id: json['id'] as String,
      userId: (json['userId'] as String?)?.isNotEmpty == true
          ? json['userId'] as String
          : MoneyAccount.defaultUserId,
      title: json['title'] as String? ?? 'Recurring Entry',
      type: safeType,
      amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
      categoryId: json['categoryId'] as String? ?? '',
      accountId: json['accountId'] as String? ?? '',
      frequency: RecurrenceFrequency.fromName(json['frequency'] as String?),
      startDate: start,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      nextOccurrenceDate: json['nextOccurrenceDate'] != null
          ? DateTime.parse(json['nextOccurrenceDate'] as String)
          : start,
      isActive: json['isActive'] as bool? ?? true,
      description: json['description'] as String? ?? '',
      lastProcessedDate: json['lastProcessedDate'] != null
          ? DateTime.tryParse(json['lastProcessedDate'] as String)
          : null,
      processedOccurrenceKeys: (json['processedOccurrenceKeys'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
