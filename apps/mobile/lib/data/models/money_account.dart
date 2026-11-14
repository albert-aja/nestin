import 'package:flutter/material.dart';

enum MoneyAccountType {
  cash('Cash', Icons.payments_rounded, Color(0xFF10B981)),
  bankAccount('Bank Account', Icons.account_balance_rounded, Color(0xFF3B82F6)),
  eWallet('E-Wallet', Icons.account_balance_wallet_rounded, Color(0xFFF59E0B)),
  other('Other', Icons.savings_rounded, Color(0xFF8B5CF6));

  final String label;
  final IconData defaultIcon;
  final Color defaultColor;

  const MoneyAccountType(this.label, this.defaultIcon, this.defaultColor);

  static MoneyAccountType fromName(String? name) {
    return MoneyAccountType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => MoneyAccountType.other,
    );
  }
}

class MoneyAccount {
  static const String defaultUserId = 'local_owner';

  final String id;
  final String userId;
  final String name;
  final MoneyAccountType type;

  /// Initial opening balance stored in exact minor units (never treated as income).
  final int initialBalanceMinor;

  /// Current balance in exact minor units, kept synchronized with initial + transactions.
  final int currentBalanceMinor;
  final String description;
  final int iconCodePoint;
  final int colorValue;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MoneyAccount({
    required this.id,
    this.userId = defaultUserId,
    required this.name,
    required this.type,
    required this.initialBalanceMinor,
    required this.currentBalanceMinor,
    this.description = '',
    required this.iconCodePoint,
    required this.colorValue,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get color => Color(colorValue);
  IconData get icon => resolveAccountIcon(iconCodePoint, type);

  static const List<IconData> _knownIcons = [
    Icons.payments_rounded,
    Icons.account_balance_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.savings_rounded,
    Icons.credit_card_rounded,
    Icons.wallet_rounded,
  ];

  static IconData resolveAccountIcon(int codePoint, MoneyAccountType fallback) {
    for (final ic in _knownIcons) {
      if (ic.codePoint == codePoint) return ic;
    }
    return fallback.defaultIcon;
  }

  MoneyAccount copyWith({
    String? id,
    String? userId,
    String? name,
    MoneyAccountType? type,
    int? initialBalanceMinor,
    int? currentBalanceMinor,
    String? description,
    int? iconCodePoint,
    int? colorValue,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoneyAccount(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      initialBalanceMinor: initialBalanceMinor ?? this.initialBalanceMinor,
      currentBalanceMinor: currentBalanceMinor ?? this.currentBalanceMinor,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isArchived: isArchived ?? this.isArchived,
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
      'initialBalanceMinor': initialBalanceMinor,
      'currentBalanceMinor': currentBalanceMinor,
      'description': description,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MoneyAccount.fromJson(Map<String, dynamic> json) {
    final accountType = MoneyAccountType.fromName(json['type'] as String?);
    final initialMinor = (json['initialBalanceMinor'] as num?)?.toInt() ?? 0;
    final currentMinor =
        (json['currentBalanceMinor'] as num?)?.toInt() ?? initialMinor;

    return MoneyAccount(
      id: json['id'] as String,
      userId: (json['userId'] as String?)?.isNotEmpty == true
          ? json['userId'] as String
          : defaultUserId,
      name: json['name'] as String? ?? 'Wallet',
      type: accountType,
      initialBalanceMinor: initialMinor,
      currentBalanceMinor: currentMinor,
      description: json['description'] as String? ?? '',
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
          accountType.defaultIcon.codePoint,
      colorValue: (json['colorValue'] as num?)?.toInt() ??
          accountType.defaultColor.toARGB32(),
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
