import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/money_budget.dart';
import '../../../../data/models/money_transaction.dart';
import '../../../../domain/money/money_amount.dart';
import '../../../../providers/money_provider.dart';
import '../../../widgets/money/money_editor_dialogs.dart';

// ---------------------------------------------------------------------------
// Budgets View
// ---------------------------------------------------------------------------

class MoneyBudgetsView extends StatelessWidget {
  const MoneyBudgetsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MoneyProvider>(context);
    final period = provider.selectedPeriodMonth;
    final overview = provider.budgetOverviewForMonth(period.year, period.month);
    final amberInk = AppColors.adaptive(
      context,
      dark: kTwillAmber,
      light: const Color(0xFFB45309),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
      children: [
        _PeriodMonthBar(provider: provider),
        const SizedBox(height: 12),
        if (overview.overallBudget == null)
          Card(
            color: AppColors.cardSurface(context),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: kTwillAmber.withValues(alpha: 0.16),
                child: Icon(Icons.shield_outlined, color: amberInk),
              ),
              title: const Text('Overall Monthly Limit',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text(
                'Set a total monthly spending ceiling across all expense categories',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
              trailing: TextButton(
                onPressed: () => showMoneyBudgetDialog(
                  context,
                  year: period.year,
                  month: period.month,
                ),
                child: const Text('Set Limit'),
              ),
            ),
          )
        else
          _BudgetCard(
            summary: overview.overallBudget!,
            title: 'Overall Monthly Budget',
            subtitle: 'Counts all expenses • Excludes income & transfers',
            provider: provider,
            color: kTwillAmber,
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Category Budgets',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () => showMoneyBudgetDialog(
                context,
                year: period.year,
                month: period.month,
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Budget'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (overview.categoryBudgets.isEmpty)
          Card(
            color: AppColors.cardSurface(context),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No category budgets set for this month yet. Tap "Add Budget" to set a cap for Food & Drinks, Shopping, or other categories.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          )
        else
          ...overview.categoryBudgets.map((summary) {
            final cat =
                provider.findCategoryById(summary.budget.categoryId);
            return _BudgetCard(
              summary: summary,
              title: cat?.name ?? 'Category',
              subtitle: 'Monthly spending cap',
              provider: provider,
              color: cat?.color ?? kTwillAmber,
            );
          }),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetUtilizationSummary summary;
  final String title;
  final String subtitle;
  final MoneyProvider provider;
  final Color color;

  const _BudgetCard({
    required this.summary,
    required this.title,
    required this.subtitle,
    required this.provider,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final limit = summary.budget.limitMinor;
    final spent = summary.spentMinor;
    final rem = summary.remainingMinor;
    final ratio = MoneyAmount.barRatio(spent, limit);

    Color statusColor;
    String statusText;
    switch (summary.status) {
      case BudgetHealthStatus.exceeded:
        statusColor = AppColors.error;
        statusText = 'Over budget (${summary.utilizationPercent}%)';
        break;
      case BudgetHealthStatus.nearLimit:
        statusColor = AppColors.warning;
        statusText = 'Approaching limit (${summary.utilizationPercent}%)';
        break;
      case BudgetHealthStatus.healthy:
        statusColor = AppColors.success;
        statusText = '${summary.utilizationPercent}% used';
        break;
    }

    return Card(
      color: AppColors.cardSurface(context),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  onPressed: () => showMoneyBudgetDialog(
                    context,
                    year: summary.budget.year,
                    month: summary.budget.month,
                    existing: summary.budget,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: AppColors.textSecondary(context),
                  ),
                  onPressed: () => provider.deleteBudget(summary.budget.id),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.trackSurface(context),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Budget: ${provider.formatAmount(limit)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                Text(
                  'Spent: ${provider.formatAmount(spent)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                Text(
                  rem >= 0
                      ? 'Remaining: ${provider.formatAmount(rem)}'
                      : 'Over by: ${provider.formatAmount(rem.abs())}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rem >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recurring Transactions View
// ---------------------------------------------------------------------------

class MoneyRecurringView extends StatelessWidget {
  const MoneyRecurringView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MoneyProvider>(context);
    final rules = provider.recurringTransactions;
    final due = provider.dueRecurringTemplates();

    final amberInk = AppColors.adaptive(
      context,
      dark: kTwillAmber,
      light: const Color(0xFFB45309),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
      children: [
        if (due.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kTwillAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kTwillAmber.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        color: amberInk, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${due.length} Scheduled Item(s) Ready to Record',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: amberInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Confirm each item below to record its transaction and update balances.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recurring Income & Bills',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => showMoneyRecurringDialog(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Rule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kTwillAmber,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (rules.isEmpty)
          Card(
            color: AppColors.cardSurface(context),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No recurring schedules yet. Add monthly salary, rent, or subscriptions to review and confirm on due dates without duplicates.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          )
        else
          ...rules.map((r) {
            final acct = provider.findAccountById(r.accountId);
            final cat = provider.findCategoryById(r.categoryId);
            final isDue = r.isDueOnOrBefore(DateTime.now());
            final alreadyProcessed = r.hasAlreadyProcessed(r.nextOccurrenceDate);

            return Card(
              color: AppColors.cardSurface(context),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(r.type.icon, color: r.type.color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              Text(
                                '${r.frequency.label} • ${cat?.name ?? 'Category'} • ${acct?.name ?? 'Wallet'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          provider.formatAmount(r.amountMinor),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: r.type.color,
                          ),
                        ),
                        Switch(
                          value: r.isActive,
                          activeThumbColor: kTwillAmber,
                          onChanged: (v) =>
                              provider.setRecurringActive(r.id, v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Next: ${DateFormat('MMM d, yyyy').format(r.nextOccurrenceDate)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDue
                                ? amberInk
                                : AppColors.textSecondary(context),
                          ),
                        ),
                        if (r.isActive && !alreadyProcessed)
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await provider.executeRecurringOccurrence(r.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Recorded "${r.title}" transaction.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check_rounded, size: 14),
                            label: const Text('Record Now',
                                style: TextStyle(fontSize: 11)),
                          ),
                        if (r.isActive)
                          TextButton(
                            onPressed: () =>
                                provider.skipRecurringOccurrence(r.id),
                            child: const Text('Skip Next',
                                style: TextStyle(fontSize: 11)),
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.textSecondary(context),
                          ),
                          onPressed: () => provider.deleteRecurring(r.id),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Basic Financial Reports View
// ---------------------------------------------------------------------------

class MoneyReportsView extends StatelessWidget {
  const MoneyReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MoneyProvider>(context);
    final period = provider.selectedPeriodMonth;
    final summary = provider.summaryForMonth(period.year, period.month);
    final breakdown =
        provider.expenseBreakdownForMonth(period.year, period.month);
    final history = provider.monthlyCashFlowHistory(
      monthsCount: 6,
      anchorMonth: period,
    );

    final maxCompare = summary.totalIncomeMinor > summary.totalExpenseMinor
        ? summary.totalIncomeMinor
        : summary.totalExpenseMinor;

    var maxHistory = 0;
    for (final pt in history) {
      if (pt.incomeMinor > maxHistory) maxHistory = pt.incomeMinor;
      if (pt.expenseMinor > maxHistory) maxHistory = pt.expenseMinor;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
      children: [
        _PeriodMonthBar(provider: provider),
        const SizedBox(height: 12),
        if (summary.isEmpty && provider.activeAccounts.isEmpty)
          Card(
            color: AppColors.cardSurface(context),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No recorded financial data for this month yet. Add an account and record transactions to see reports.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          )
        else ...[
          // Income vs Expense Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Income vs Expense Comparison',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _ComparisonBarRow(
                  label: 'Income',
                  valueText: provider.formatAmount(summary.totalIncomeMinor),
                  ratio: MoneyAmount.barRatio(
                      summary.totalIncomeMinor, maxCompare),
                  color: MoneyTransactionType.income.color,
                ),
                const SizedBox(height: 10),
                _ComparisonBarRow(
                  label: 'Expenses',
                  valueText: provider.formatAmount(summary.totalExpenseMinor),
                  ratio: MoneyAmount.barRatio(
                      summary.totalExpenseMinor, maxCompare),
                  color: MoneyTransactionType.expense.color,
                ),
                const Divider(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monthly Net Cash Flow',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(
                      provider.formatAmount(
                        summary.netCashFlowMinor,
                        showPlusSign: true,
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: summary.netCashFlowMinor >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Spending by Category
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spending by Category',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (breakdown.isEmpty)
                  Text(
                    'No expenses recorded for this month.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  )
                else
                  ...breakdown.map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(row.category.icon,
                                  size: 15, color: row.category.color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  row.category.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${provider.formatAmount(row.spentMinor)} (${row.percentOfExpenses}%)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: MoneyAmount.barRatio(
                                row.spentMinor,
                                summary.totalExpenseMinor,
                              ),
                              minHeight: 6,
                              backgroundColor: AppColors.trackSurface(context),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  row.category.color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 6-Month Spending History
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '6-Month Income & Spending History',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: history.map((pt) {
                      final incRatio =
                          MoneyAmount.barRatio(pt.incomeMinor, maxHistory);
                      final expRatio =
                          MoneyAmount.barRatio(pt.expenseMinor, maxHistory);
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _MiniBar(
                                    ratio: incRatio,
                                    color: MoneyTransactionType.income.color,
                                  ),
                                  const SizedBox(width: 3),
                                  _MiniBar(
                                    ratio: expRatio,
                                    color: MoneyTransactionType.expense.color,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('MMM')
                                  .format(DateTime(pt.year, pt.month)),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Account Balance Overview
          if (provider.activeAccounts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Balance Overview',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...provider.activeAccounts.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(a.icon, size: 16, color: a.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(a.name,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          Text(
                            provider.formatAmount(a.currentBalanceMinor),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ComparisonBarRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double ratio;
  final Color color;

  const _ComparisonBarRow({
    required this.label,
    required this.valueText,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            Text(valueText,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.trackSurface(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double ratio;
  final Color color;
  const _MiniBar({required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    final h = (ratio * 84).clamp(4.0, 84.0);
    return Container(
      width: 10,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _PeriodMonthBar extends StatelessWidget {
  final MoneyProvider provider;
  const _PeriodMonthBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final label =
        DateFormat('MMMM yyyy').format(provider.selectedPeriodMonth);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: provider.previousPeriodMonth,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: provider.nextPeriodMonth,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
