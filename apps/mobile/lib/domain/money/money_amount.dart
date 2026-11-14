enum MoneyCurrency {
  idr('IDR', 'Rp', 'Indonesian Rupiah'),
  usd('USD', r'$', 'US Dollar'),
  eur('EUR', '€', 'Euro'),
  gbp('GBP', '£', 'British Pound'),
  sgd('SGD', r'S$', 'Singapore Dollar'),
  jpy('JPY', '¥', 'Japanese Yen');

  final String code;
  final String symbol;
  final String displayName;

  const MoneyCurrency(this.code, this.symbol, this.displayName);

  static MoneyCurrency fromCode(String? code) {
    return MoneyCurrency.values.firstWhere(
      (c) => c.code.toUpperCase() == (code ?? '').toUpperCase(),
      orElse: () => MoneyCurrency.idr,
    );
  }
}

/// Pure integer fixed-point money utilities (scale = 100 minor units).
/// Never uses IEEE-754 floating-point arithmetic for amounts or balances.
class MoneyAmount {
  MoneyAmount._();

  /// Internal fixed-point scale factor (2 decimal places = 100 minor units).
  static const int scale = 100;

  /// Parses user-entered numeric string into exact integer minor units (`* 100`).
  /// Accepts plain integers ("2000000"), comma/dot grouped ("2,000,000"),
  /// or decimals up to 2 decimal places ("12.50", "12.5").
  /// Returns `null` when invalid or overflowing integer bounds.
  static int? tryParseToMinor(String raw, {bool allowNegative = false}) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    var negative = false;
    if (trimmed.startsWith('-')) {
      if (!allowNegative) return null;
      negative = true;
      trimmed = trimmed.substring(1).trim();
    } else if (trimmed.startsWith('+')) {
      trimmed = trimmed.substring(1).trim();
    }

    // Strip common spaces or currency prefixes safely if pasted.
    trimmed = trimmed.replaceAll(' ', '');
    if (trimmed.isEmpty) return null;

    // Determine decimal vs thousand separators deterministically:
    // Case A: Only digits -> whole units
    // Case B: Ends with .d or .dd -> '.' is decimal, ',' is thousand separator
    // Case C: Ends with ,d or ,dd and no '.' -> ',' is decimal
    // Case D: Multiple dots or commas in 3-digit groups -> thousand separators
    String integerPartStr;
    String fractionPartStr = '';

    final hasDot = trimmed.contains('.');
    final hasComma = trimmed.contains(',');

    if (!hasDot && !hasComma) {
      integerPartStr = trimmed;
    } else if (hasDot && !hasComma) {
      final dotCount = '.'.allMatches(trimmed).length;
      if (dotCount == 1) {
        final parts = trimmed.split('.');
        final after = parts[1];
        if (after.length <= 2) {
          integerPartStr = parts[0];
          fractionPartStr = after;
        } else if (after.length == 3 &&
            parts[0].isNotEmpty &&
            parts[0].length <= 3) {
          // Single dot with 3 digits like "2.000" -> thousand separator if integer only
          integerPartStr = trimmed.replaceAll('.', '');
        } else {
          return null;
        }
      } else {
        // Multiple dots like 2.000.000 -> verify strict 3-digit grouping after first
        final segments = trimmed.split('.');
        if (segments.any((s) => s.isEmpty)) return null;
        for (var i = 1; i < segments.length; i++) {
          if (segments[i].length != 3) return null;
        }
        integerPartStr = segments.join();
      }
    } else if (hasComma && !hasDot) {
      final commaCount = ','.allMatches(trimmed).length;
      if (commaCount == 1) {
        final parts = trimmed.split(',');
        final after = parts[1];
        if (after.length <= 2) {
          integerPartStr = parts[0];
          fractionPartStr = after;
        } else if (after.length == 3 &&
            parts[0].isNotEmpty &&
            parts[0].length <= 3) {
          integerPartStr = trimmed.replaceAll(',', '');
        } else {
          return null;
        }
      } else {
        final segments = trimmed.split(',');
        if (segments.any((s) => s.isEmpty)) return null;
        for (var i = 1; i < segments.length; i++) {
          if (segments[i].length != 3) return null;
        }
        integerPartStr = segments.join();
      }
    } else {
      // Both dot and comma present: whichever occurs last is decimal if <=2 digits follow it
      final lastDot = trimmed.lastIndexOf('.');
      final lastComma = trimmed.lastIndexOf(',');
      if (lastDot > lastComma) {
        final beforeDot = trimmed.substring(0, lastDot).replaceAll(',', '');
        final afterDot = trimmed.substring(lastDot + 1);
        if (afterDot.length > 2) return null;
        integerPartStr = beforeDot;
        fractionPartStr = afterDot;
      } else {
        final beforeComma = trimmed.substring(0, lastComma).replaceAll('.', '');
        final afterComma = trimmed.substring(lastComma + 1);
        if (afterComma.length > 2) return null;
        integerPartStr = beforeComma;
        fractionPartStr = afterComma;
      }
    }

    if (integerPartStr.isEmpty) integerPartStr = '0';
    if (!_digitsOnly(integerPartStr) || !_digitsOnly(fractionPartStr)) {
      return null;
    }

    final intPart = int.tryParse(integerPartStr);
    if (intPart == null) return null;

    var fracMinor = 0;
    if (fractionPartStr.length == 1) {
      fracMinor = int.parse(fractionPartStr) * 10;
    } else if (fractionPartStr.length == 2) {
      fracMinor = int.parse(fractionPartStr);
    }

    // Prevent overflow on extreme inputs
    if (intPart > 90000000000000) return null;

    final minor = intPart * scale + fracMinor;
    return negative ? -minor : minor;
  }

  static bool _digitsOnly(String value) {
    for (var i = 0; i < value.length; i++) {
      final code = value.codeUnitAt(i);
      if (code < 48 || code > 57) return false;
    }
    return true;
  }

  /// Formats integer minor units purely with integer arithmetic.
  /// Example (IDR): `200000000` -> `Rp2,000,000`, `-75000000` -> `-Rp750,000`.
  /// Non-zero minor decimals append `.XX` (e.g. `$12.50`).
  static String formatMinor(
    int amountMinor, {
    MoneyCurrency currency = MoneyCurrency.idr,
    bool showPlusSign = false,
    bool forceDecimals = false,
  }) {
    final isNegative = amountMinor < 0;
    final absMinor = amountMinor.abs();
    final whole = absMinor ~/ scale;
    final rem = absMinor % scale;

    final groupedWhole = _groupWithCommas(whole);
    final sign = isNegative ? '-' : (showPlusSign && amountMinor > 0 ? '+' : '');
    if (rem != 0 || forceDecimals) {
      final frac = rem.toString().padLeft(2, '0');
      return '$sign${currency.symbol}$groupedWhole.$frac';
    }
    return '$sign${currency.symbol}$groupedWhole';
  }

  /// Editable plain numeric representation without currency symbol.
  static String formatInputMinor(int amountMinor) {
    final absMinor = amountMinor.abs();
    final whole = absMinor ~/ scale;
    final rem = absMinor % scale;
    final sign = amountMinor < 0 ? '-' : '';
    if (rem == 0) return '$sign$whole';
    final frac = rem.toString().padLeft(2, '0');
    return '$sign$whole.$frac';
  }

  static String formatCompactMinor(
    int amountMinor, {
    MoneyCurrency currency = MoneyCurrency.idr,
  }) {
    final isNegative = amountMinor < 0;
    final absWhole = amountMinor.abs() ~/ scale;
    final sign = isNegative ? '-' : '';
    if (absWhole >= 1000000000) {
      final b = absWhole ~/ 1000000000;
      final dec = (absWhole % 1000000000) ~/ 100000000;
      return '$sign${currency.symbol}$b${dec > 0 ? ".$dec" : ""}B';
    }
    if (absWhole >= 1000000) {
      final m = absWhole ~/ 1000000;
      final dec = (absWhole % 1000000) ~/ 100000;
      return '$sign${currency.symbol}$m${dec > 0 ? ".$dec" : ""}M';
    }
    if (absWhole >= 10000) {
      final k = absWhole ~/ 1000;
      return '$sign${currency.symbol}${k}K';
    }
    return formatMinor(amountMinor, currency: currency);
  }

  /// Exact integer percentage (0..n). Avoids floating point until UI ratio.
  static int percentOf(int partMinor, int totalMinor) {
    if (totalMinor <= 0) return 0;
    return (partMinor * 100) ~/ totalMinor;
  }

  /// Clamped 0.0..1.0 ratio strictly for Flutter visual progress bars.
  static double barRatio(int partMinor, int totalMinor) {
    if (totalMinor <= 0 || partMinor <= 0) return 0.0;
    if (partMinor >= totalMinor) return 1.0;
    final permille = (partMinor * 1000) ~/ totalMinor;
    return permille / 1000.0;
  }

  static String _groupWithCommas(int number) {
    final str = number.toString();
    if (str.length <= 3) return str;
    final buffer = StringBuffer();
    final mod = str.length % 3;
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (i - mod) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
