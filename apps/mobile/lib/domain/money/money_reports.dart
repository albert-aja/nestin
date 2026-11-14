import '../../data/models/money_budget.dart';
import '../../data/models/money_category.dart';

class MoneyValidationException implements Exception {
  final String message;
  const MoneyValidationException(this.message);

  @override
  String toString() => 'MoneyValidationException: $message';
}

class MoneyAuthorizationException implements Exception {
  final String message;
  const MoneyAuthorizationException(this.message);

  @override
  String toString() => 'MoneyAuthorizationException: $message';
}

class MoneyIntegrityException implements Exception {
  final String message;
  const MoneyIntegrityException(this.message);

  @override
  String toString() => 'MoneyIntegrityException: $message';
}

class MoneyPeriodSummary {
  final int year;
  final int month;
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int netCashFlowMinor;
  final int internalTransferMinor;
  final int transactionCount;

  const MoneyPeriodSummary({
    required this.year,
    required this.month,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.netCashFlowMinor,
    required this.internalTransferMinor,
    required this.transactionCount,
  });

  bool get isEmpty =>
      totalIncomeMinor == 0 &&
      totalExpenseMinor == 0 &&
      internalTransferMinor == 0 &&
      transactionCount == 0;
}

class CategorySpendingBreakdown {
  final MoneyCategory category;
  final int spentMinor;
  final int percentOfExpenses;

  const CategorySpendingBreakdown({
    required this.category,
    required this.spentMinor,
    required this.percentOfExpenses,
  });
}

class MonthlyCashFlowPoint {
  final int year;
  final int month;
  final int incomeMinor;
  final int expenseMinor;

  const MonthlyCashFlowPoint({
    required this.year,
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  int get netMinor => incomeMinor - expenseMinor;
}

class MonthlyBudgetOverview {
  final BudgetUtilizationSummary? overallBudget;
  final List<BudgetUtilizationSummary> categoryBudgets;

  const MonthlyBudgetOverview({
    required this.overallBudget,
    required this.categoryBudgets,
  });

  bool get hasAnyBudgets =>
      overallBudget != null || categoryBudgets.isNotEmpty;

  int get nearOrExceededCount {
    var count = 0;
    if (overallBudget != null &&
        overallBudget!.status != BudgetHealthStatus.healthy) {
      count++;
    }
    for (final b in categoryBudgets) {
      if (b.status != BudgetHealthStatus.healthy) count++;
    }
    return count;
  }
}
