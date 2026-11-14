import '../../domain/money/money_amount.dart';
import 'money_account.dart';

class MoneySettings {
  static const int currentSchemaVersion = 1;

  final String userId;
  final MoneyCurrency currency;
  final bool requirePinForMoney;
  final int schemaVersion;

  const MoneySettings({
    this.userId = MoneyAccount.defaultUserId,
    this.currency = MoneyCurrency.idr,
    this.requirePinForMoney = false,
    this.schemaVersion = currentSchemaVersion,
  });

  MoneySettings copyWith({
    String? userId,
    MoneyCurrency? currency,
    bool? requirePinForMoney,
    int? schemaVersion,
  }) {
    return MoneySettings(
      userId: userId ?? this.userId,
      currency: currency ?? this.currency,
      requirePinForMoney: requirePinForMoney ?? this.requirePinForMoney,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'currencyCode': currency.code,
      'requirePinForMoney': requirePinForMoney,
      'schemaVersion': schemaVersion,
    };
  }

  factory MoneySettings.fromJson(Map<String, dynamic> json) {
    return MoneySettings(
      userId: (json['userId'] as String?)?.isNotEmpty == true
          ? json['userId'] as String
          : MoneyAccount.defaultUserId,
      currency: MoneyCurrency.fromCode(json['currencyCode'] as String?),
      requirePinForMoney: json['requirePinForMoney'] as bool? ?? false,
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
    );
  }
}
