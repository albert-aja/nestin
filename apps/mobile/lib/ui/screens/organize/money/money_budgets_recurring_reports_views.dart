import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/money_budget.dart';
import '../../../../data/models/money_transaction.dart';
import '../../../../domain/money/money_amount.dart';
import '../../../../domain/money/money_reports.dart';
import '../../../../providers/money_provider.dart';
import '../../../widgets/money/money_editor_dialogs.dart';
import 'money_transactions_accounts_views.dart';

// ---------------------------------------------------------------------------
// Budgets View
// ---------------------------------------------------------------------------

class MoneyBudgetsView extends StatelessWidget {
  const MoneyBudgetsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context);
    final period = provider.selectedPeriodMonth;
    final overview = provider.budgetOverviewForMonth(period.year, period.month);
    final amberInk = AppColors.adaptive(
      context,
      dark: kTwillAmber,
      light: AppColors.twillDark,
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
              title: Text(
                l10n.tr('overall_monthly_limit'),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                l10n.tr('set_a_total_monthly_spending_ceiling'),
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
                child: Text(l10n.tr('set_limit')),
              ),
            ),
          )
        else
          _BudgetCard(
            summary: overview.overallBudget!,
            title:
                l10n.tr('overall_monthly_budget'),
            subtitle: l10n.tr('counts_all_expenses_excludes_income_transfers'),
            provider: provider,
            color: kTwillAmber,
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tr('category_budgets'),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () => showMoneyBudgetDialog(
                context,
                year: period.year,
                month: period.month,
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(l10n.tr('add_budget')),
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
                l10n.tr('no_category_budgets_set_for_this'),
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
              title: cat?.displayName ?? l10n.tr('category'),
              subtitle: l10n.tr('monthly_spending_cap'),
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
    final l10n = context.l10n;
    final limit = summary.budget.limitMinor;
    final spent = summary.spentMinor;
    final rem = summary.remainingMinor;
    final ratio = MoneyAmount.barRatio(spent, limit);

    Color statusColor;
    String statusText;
    switch (summary.status) {
      case BudgetHealthStatus.exceeded:
        statusColor = AppColors.error;
        statusText = l10n.tr('over_budget_2', {'summary_utilizationPercent': summary.utilizationPercent});
        break;
      case BudgetHealthStatus.nearLimit:
        statusColor = AppColors.warning;
        statusText = l10n.tr('approaching_limit', {'summary_utilizationPercent': summary.utilizationPercent});
        break;
      case BudgetHealthStatus.healthy:
        statusColor = AppColors.success;
        statusText = l10n.tr('used', {'summary_utilizationPercent': summary.utilizationPercent});
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
                  l10n.tr('budget', {'provider_limit': provider.formatAmount(limit)}),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                Text(
                  l10n.tr('spent', {'provider_spent': provider.formatAmount(spent)}),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                Text(
                  rem >= 0
                      ? l10n.tr('remaining', {'provider_rem': provider.formatAmount(rem)})
                      : l10n.tr('over_by', {'provider_abs': provider.formatAmount(rem.abs())}),
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
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context);
    final rules = provider.recurringTransactions;
    final due = provider.dueRecurringTemplates();

    final amberInk = AppColors.adaptive(
      context,
      dark: kTwillAmber,
      light: AppColors.twillDark,
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
                        l10n.tr('scheduled_item_s_ready_to_record', {'due_length': due.length}),
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
                  l10n.tr('confirm_each_item_below_to_record'),
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
            Expanded(
              child: Text(
                l10n.tr('recurring_income_bills'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => showMoneyRecurringDialog(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(l10n.tr('new_rule')),
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
                l10n.tr('no_recurring_schedules_yet_add_monthly'),
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
                                '${r.frequency.label} • ${cat?.displayName ?? l10n.tr('category')} • ${acct?.name ?? l10n.tr('wallet')}',
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
                          l10n.tr('next', {'l10n_yyyy': l10n.formatDate(r.nextOccurrenceDate, 'MMM d, yyyy')}),
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
                                        l10n.tr('recorded_transaction', {'r_title': r.title}),
                                      ),
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
                            label: Text(
                              l10n.tr('record_now'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        if (r.isActive)
                          TextButton(
                            onPressed: () =>
                                provider.skipRecurringOccurrence(r.id),
                            child: Text(
                              l10n.tr('skip_next'),
                              style: const TextStyle(fontSize: 11),
                            ),
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
// Basic Financial Reports View (Category Pie Drill-Down & Yearly Ledger)
// ---------------------------------------------------------------------------

typedef MoneyCategoryDrillDownCallback = void Function({
  required String categoryId,
  required DateTimeRange dateRange,
});

class MoneyReportsView extends StatefulWidget {
  final MoneyCategoryDrillDownCallback? onDrillDownCategory;

  const MoneyReportsView({
    super.key,
    this.onDrillDownCategory,
  });

  @override
  State<MoneyReportsView> createState() => _MoneyReportsViewState();
}

class _MoneyReportsViewState extends State<MoneyReportsView> {
  bool _isAnnualMode = false;
  int _monthlyHistoryMonths = 6;

  void _drillDownToCategory(
    BuildContext context,
    MoneyProvider provider,
    String categoryId,
  ) {
    final period = provider.selectedPeriodMonth;
    final dateRange = _isAnnualMode
        ? DateTimeRange(
            start: DateTime(period.year, 1, 1),
            end: DateTime(period.year, 12, 31),
          )
        : DateTimeRange(
            start: DateTime(period.year, period.month, 1),
            end: DateTime(period.year, period.month + 1, 0),
          );

    if (widget.onDrillDownCategory != null) {
      widget.onDrillDownCategory!(
        categoryId: categoryId,
        dateRange: dateRange,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.tr('money_transactions_2')),
          ),
          body: MoneyTransactionsView(
            filterPreset: MoneyTransactionFilterPreset(
              type: MoneyTransactionType.expense,
              categoryId: categoryId,
              dateRange: dateRange,
              revision: 1,
            ),
          ),
        ),
      ),
    );
  }

  void _jumpToMonth(MoneyProvider provider, int year, int month) {
    provider.setSelectedPeriodMonth(DateTime(year, month));
    setState(() => _isAnnualMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context);
    final period = provider.selectedPeriodMonth;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
      children: [
        _ReportScopeToggleBar(
          isAnnualMode: _isAnnualMode,
          onSelectMonthly: () => setState(() => _isAnnualMode = false),
          onSelectAnnual: () => setState(() => _isAnnualMode = true),
        ),
        const SizedBox(height: 8),
        _isAnnualMode
            ? _PeriodYearBar(provider: provider, year: period.year)
            : _PeriodMonthBar(provider: provider),
        const SizedBox(height: 12),
        if (_isAnnualMode)
          ..._buildAnnualOverview(context, l10n, provider, period.year)
        else
          ..._buildMonthlyOverview(context, l10n, provider, period),
      ],
    );
  }

  List<Widget> _buildMonthlyOverview(
    BuildContext context,
    AppLocalizations l10n,
    MoneyProvider provider,
    DateTime period,
  ) {
    final summary = provider.summaryForMonth(period.year, period.month);
    final breakdown =
        provider.expenseBreakdownForMonth(period.year, period.month);
    final history = provider.monthlyCashFlowHistory(
      monthsCount: _monthlyHistoryMonths,
      anchorMonth: period,
    );

    if (summary.isEmpty && provider.activeAccounts.isEmpty) {
      return [
        _EmptyReportsCard(
          message: l10n.tr('no_recorded_financial_data_for_this'),
        ),
      ];
    }

    final maxCompare = summary.totalIncomeMinor > summary.totalExpenseMinor
        ? summary.totalIncomeMinor
        : summary.totalExpenseMinor;

    return [
      // Income vs Expense Summary Card
      _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tr('income_vs_expense_comparison'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _ComparisonBarRow(
              label: l10n.tr('money_income'),
              valueText: provider.formatAmount(summary.totalIncomeMinor),
              ratio: MoneyAmount.barRatio(summary.totalIncomeMinor, maxCompare),
              color: MoneyTransactionType.income.color,
            ),
            const SizedBox(height: 10),
            _ComparisonBarRow(
              label: l10n.tr('expenses'),
              valueText: provider.formatAmount(summary.totalExpenseMinor),
              ratio:
                  MoneyAmount.barRatio(summary.totalExpenseMinor, maxCompare),
              color: MoneyTransactionType.expense.color,
            ),
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    l10n.tr('monthly_net_cash_flow'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
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

      // Interactive Spending by Category Pie Chart + Drill-Down
      _CategoryPieBreakdownCard(
        provider: provider,
        breakdown: breakdown,
        totalExpenseMinor: summary.totalExpenseMinor,
        emptyText: l10n.tr('no_expenses_recorded_for_this_month'),
        onTapCategory: (catId) =>
            _drillDownToCategory(context, provider, catId),
      ),
      const SizedBox(height: 14),

      // 6M / 12M Cash-Flow History
      _CashFlowHistoryCard(
        provider: provider,
        title: _monthlyHistoryMonths == 12
            ? l10n.tr('money_history_12m_title')
            : l10n.tr('k_6_month_income_spending_history'),
        history: history,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompactTogglePill(
              label: l10n.tr('money_history_6m'),
              selected: _monthlyHistoryMonths == 6,
              onTap: () => setState(() => _monthlyHistoryMonths = 6),
            ),
            const SizedBox(width: 4),
            _CompactTogglePill(
              label: l10n.tr('money_history_12m'),
              selected: _monthlyHistoryMonths == 12,
              onTap: () => setState(() => _monthlyHistoryMonths = 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      if (provider.activeAccounts.isNotEmpty)
        _AccountBalanceOverviewCard(provider: provider),
    ];
  }

  List<Widget> _buildAnnualOverview(
    BuildContext context,
    AppLocalizations l10n,
    MoneyProvider provider,
    int year,
  ) {
    final annual = provider.annualLedgerSummaryForYear(year);
    final breakdown = provider.expenseBreakdownForYear(year);

    if (annual.isEmpty && provider.activeAccounts.isEmpty) {
      return [
        _EmptyReportsCard(
          message: l10n.tr('money_no_data_for_year', {'year': year}),
        ),
      ];
    }

    final maxCompare = annual.totalIncomeMinor > annual.totalExpenseMinor
        ? annual.totalIncomeMinor
        : annual.totalExpenseMinor;

    return [
      // Yearly Ledger Summary Card
      _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tr('money_annual_ledger_summary', {'year': year}),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kTwillAmber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.tr('money_annual_active_months', {
                      'count': annual.activeMonthsCount,
                    }),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.adaptive(
                        context,
                        dark: kTwillAmber,
                        light: AppColors.twillDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ComparisonBarRow(
              label: l10n.tr('money_income'),
              valueText: provider.formatAmount(annual.totalIncomeMinor),
              ratio: MoneyAmount.barRatio(annual.totalIncomeMinor, maxCompare),
              color: MoneyTransactionType.income.color,
            ),
            const SizedBox(height: 10),
            _ComparisonBarRow(
              label: l10n.tr('expenses'),
              valueText: provider.formatAmount(annual.totalExpenseMinor),
              ratio: MoneyAmount.barRatio(annual.totalExpenseMinor, maxCompare),
              color: MoneyTransactionType.expense.color,
            ),
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    l10n.tr('money_annual_net_flow'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  provider.formatAmount(
                    annual.netCashFlowMinor,
                    showPlusSign: true,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: annual.netCashFlowMinor >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AnnualMetricPill(
                    label: l10n.tr('money_annual_avg_expense'),
                    value: provider.formatAmount(
                      annual.averageMonthlyExpenseMinor,
                      compact: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AnnualMetricPill(
                    label: l10n.tr('money_annual_net_rate'),
                    value: annual.totalIncomeMinor > 0
                        ? '${annual.netSavingsRatePercent}%'
                        : '--',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AnnualMetricPill(
                    label: l10n.tr('money_annual_tx_count'),
                    value: '${annual.transactionCount}',
                  ),
                ),
              ],
            ),
            if (annual.internalTransferMinor > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.tr('money_annual_transfers_excluded', {
                  'amount': provider.formatAmount(annual.internalTransferMinor),
                }),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),

      // 12-Month Annual Cash-Flow Overview Chart
      _CashFlowHistoryCard(
        provider: provider,
        title: l10n.tr('money_annual_cash_flow_title'),
        history: annual.monthlyPoints,
        onTapMonth: (pt) => _jumpToMonth(provider, pt.year, pt.month),
      ),
      const SizedBox(height: 14),

      // Annual Category Pie Chart + Drill-Down
      _CategoryPieBreakdownCard(
        provider: provider,
        breakdown: breakdown,
        totalExpenseMinor: annual.totalExpenseMinor,
        emptyText: l10n.tr('money_no_expenses_for_year', {'year': year}),
        onTapCategory: (catId) =>
            _drillDownToCategory(context, provider, catId),
      ),
      const SizedBox(height: 14),

      // Month-by-Month Ledger Breakdown
      _AnnualMonthlyLedgerCard(
        provider: provider,
        monthlyPoints: annual.monthlyPoints,
        onTapMonth: (pt) => _jumpToMonth(provider, pt.year, pt.month),
      ),
      const SizedBox(height: 14),

      if (provider.activeAccounts.isNotEmpty)
        _AccountBalanceOverviewCard(provider: provider),
    ];
  }
}

class _ReportScopeToggleBar extends StatelessWidget {
  final bool isAnnualMode;
  final VoidCallback onSelectMonthly;
  final VoidCallback onSelectAnnual;

  const _ReportScopeToggleBar({
    required this.isAnnualMode,
    required this.onSelectMonthly,
    required this.onSelectAnnual,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                key: const ValueKey('money_report_toggle_monthly'),
                selected: !isAnnualMode,
                selectedColor: kTwillAmber,
                backgroundColor: AppColors.cardSurface(context),
                label: Text(
                  l10n.tr('money_report_scope_monthly'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: !isAnnualMode
                        ? Colors.black
                        : AppColors.textPrimary(context),
                  ),
                ),
                onSelected: (_) => onSelectMonthly(),
              ),
              ChoiceChip(
                key: const ValueKey('money_report_toggle_annual'),
                selected: isAnnualMode,
                selectedColor: kTwillAmber,
                backgroundColor: AppColors.cardSurface(context),
                label: Text(
                  l10n.tr('money_report_scope_annual'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isAnnualMode
                        ? Colors.black
                        : AppColors.textPrimary(context),
                  ),
                ),
                onSelected: (_) => onSelectAnnual(),
              ),
            ],
          ),
        ),
        Flexible(
          flex: 0,
          child: Text(
            l10n.tr('money_offline_ledger_badge'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: child,
    );
  }
}

class _EmptyReportsCard extends StatelessWidget {
  final String message;
  const _EmptyReportsCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardSurface(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

class _CategoryPieBreakdownCard extends StatelessWidget {
  final MoneyProvider provider;
  final List<CategorySpendingBreakdown> breakdown;
  final int totalExpenseMinor;
  final String emptyText;
  final ValueChanged<String> onTapCategory;

  const _CategoryPieBreakdownCard({
    required this.provider,
    required this.breakdown,
    required this.totalExpenseMinor,
    required this.emptyText,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tr('spending_by_category'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              l10n.tr('money_pie_tap_hint'),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (breakdown.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            )
          else ...[
            Center(
              child: _InteractiveCategoryPieChart(
                breakdown: breakdown,
                totalExpenseMinor: totalExpenseMinor,
                centerTotalLabel: l10n.tr('money_pie_total_label'),
                centerAmountText:
                    provider.formatAmount(totalExpenseMinor, compact: true),
                onSliceTap: onTapCategory,
              ),
            ),
            const SizedBox(height: 14),
            ...breakdown.map(
              (row) => InkWell(
                key: ValueKey('money_pie_row_${row.category.id}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => onTapCategory(row.category.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
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
                              row.category.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${provider.formatAmount(row.spentMinor)} (${row.percentOfExpenses}%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.textMuted(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: MoneyAmount.barRatio(
                            row.spentMinor,
                            totalExpenseMinor,
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
            ),
          ],
        ],
      ),
    );
  }
}

class _InteractiveCategoryPieChart extends StatelessWidget {
  static const double _chartSize = 172;

  final List<CategorySpendingBreakdown> breakdown;
  final int totalExpenseMinor;
  final String centerTotalLabel;
  final String centerAmountText;
  final ValueChanged<String> onSliceTap;

  const _InteractiveCategoryPieChart({
    required this.breakdown,
    required this.totalExpenseMinor,
    required this.centerTotalLabel,
    required this.centerAmountText,
    required this.onSliceTap,
  });

  String? _hitTestCategory(Offset localPosition) {
    if (breakdown.isEmpty || totalExpenseMinor <= 0) return null;
    const center = Offset(_chartSize / 2, _chartSize / 2);
    const outerRadius = _chartSize / 2 - 4;
    const innerRadius = outerRadius * 0.52;

    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < innerRadius * 0.85 || dist > outerRadius * 1.05) {
      return null;
    }

    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;

    var cursor = 0.0;
    for (var i = 0; i < breakdown.length; i++) {
      final row = breakdown[i];
      final sweep = (row.spentMinor / totalExpenseMinor) * math.pi * 2;
      final end = i == breakdown.length - 1 ? math.pi * 2 : cursor + sweep;
      if (angle >= cursor && angle <= end) {
        return row.category.id;
      }
      cursor = end;
    }
    return breakdown.last.category.id;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('money_category_pie_chart'),
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final categoryId = _hitTestCategory(details.localPosition);
        if (categoryId != null) {
          onSliceTap(categoryId);
        }
      },
      child: SizedBox(
        width: _chartSize,
        height: _chartSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(_chartSize, _chartSize),
              painter: _CategoryPiePainter(
                breakdown: breakdown,
                totalExpenseMinor: totalExpenseMinor,
                dividerColor: AppColors.cardSurface(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerTotalLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    centerAmountText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPiePainter extends CustomPainter {
  final List<CategorySpendingBreakdown> breakdown;
  final int totalExpenseMinor;
  final Color dividerColor;

  _CategoryPiePainter({
    required this.breakdown,
    required this.totalExpenseMinor,
    required this.dividerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (breakdown.isEmpty || totalExpenseMinor <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 4;
    final innerRadius = outerRadius * 0.52;
    final ringRadius = (outerRadius + innerRadius) / 2;
    final ringThickness = outerRadius - innerRadius;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);

    final gapRadians = breakdown.length > 1 ? 0.025 : 0.0;
    var startAngle = -math.pi / 2;

    for (final row in breakdown) {
      final rawSweep = (row.spentMinor / totalExpenseMinor) * math.pi * 2;
      final drawSweep = math.max(0.01, rawSweep - gapRadians);

      final paint = Paint()
        ..color = row.category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle + gapRadians / 2,
        drawSweep,
        false,
        paint,
      );
      startAngle += rawSweep;
    }

    // Subtle crisp inner & outer divider rings for daylight/dark legibility
    final ringBorder = Paint()
      ..color = dividerColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, innerRadius, ringBorder);
  }

  @override
  bool shouldRepaint(covariant _CategoryPiePainter oldDelegate) {
    return oldDelegate.totalExpenseMinor != totalExpenseMinor ||
        oldDelegate.breakdown != breakdown ||
        oldDelegate.dividerColor != dividerColor;
  }
}

class _CashFlowHistoryCard extends StatelessWidget {
  final MoneyProvider provider;
  final String title;
  final List<MonthlyCashFlowPoint> history;
  final Widget? trailing;
  final ValueChanged<MonthlyCashFlowPoint>? onTapMonth;

  const _CashFlowHistoryCard({
    required this.provider,
    required this.title,
    required this.history,
    this.trailing,
    this.onTapMonth,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    var maxHistory = 0;
    for (final pt in history) {
      if (pt.incomeMinor > maxHistory) maxHistory = pt.incomeMinor;
      if (pt.expenseMinor > maxHistory) maxHistory = pt.expenseMinor;
    }

    final barWidth = history.length >= 10 ? 5.5 : 10.0;
    final barGap = history.length >= 10 ? 1.5 : 3.0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 124,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: history.map((pt) {
                final incRatio = MoneyAmount.barRatio(pt.incomeMinor, maxHistory);
                final expRatio =
                    MoneyAmount.barRatio(pt.expenseMinor, maxHistory);
                final monthLabel = l10n.formatDate(
                  DateTime(pt.year, pt.month),
                  'MMM',
                );
                final shortLabel = history.length >= 10 && monthLabel.length > 3
                    ? monthLabel.substring(0, 3)
                    : monthLabel;

                final column = Column(
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
                            width: barWidth,
                          ),
                          SizedBox(width: barGap),
                          _MiniBar(
                            ratio: expRatio,
                            color: MoneyTransactionType.expense.color,
                            width: barWidth,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: history.length >= 10 ? 9 : 10,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                );

                return Expanded(
                  child: onTapMonth == null
                      ? column
                      : InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => onTapMonth!(pt),
                          child: column,
                        ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnualMonthlyLedgerCard extends StatelessWidget {
  final MoneyProvider provider;
  final List<MonthlyCashFlowPoint> monthlyPoints;
  final ValueChanged<MonthlyCashFlowPoint> onTapMonth;

  const _AnnualMonthlyLedgerCard({
    required this.provider,
    required this.monthlyPoints,
    required this.onTapMonth,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tr('money_annual_monthly_breakdown'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...monthlyPoints.map((pt) {
            final net = pt.netMinor;
            final hasData = pt.incomeMinor > 0 || pt.expenseMinor > 0;
            return InkWell(
              key: ValueKey('money_annual_month_${pt.year}_${pt.month}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onTapMonth(pt),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        l10n.formatDate(DateTime(pt.year, pt.month), 'MMM'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              hasData ? FontWeight.w700 : FontWeight.w500,
                          color: hasData
                              ? AppColors.textPrimary(context)
                              : AppColors.textMuted(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '+${provider.formatAmount(pt.incomeMinor, compact: true)} / -${provider.formatAmount(pt.expenseMinor, compact: true)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.formatAmount(net, showPlusSign: true),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: net == 0
                            ? AppColors.textMuted(context)
                            : (net > 0 ? AppColors.success : AppColors.error),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: AppColors.textMuted(context),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AccountBalanceOverviewCard extends StatelessWidget {
  final MoneyProvider provider;
  const _AccountBalanceOverviewCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tr('account_balance_overview'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
                    child: Text(
                      a.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
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
    );
  }
}

class _AnnualMetricPill extends StatelessWidget {
  final String label;
  final String value;
  const _AnnualMetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.recessedSurface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CompactTogglePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CompactTogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? kTwillAmber : AppColors.recessedSurface(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.black : AppColors.textSecondary(context),
          ),
        ),
      ),
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
  final double width;
  const _MiniBar({
    required this.ratio,
    required this.color,
    this.width = 10,
  });

  @override
  Widget build(BuildContext context) {
    final h = (ratio * 84).clamp(4.0, 84.0);
    return Container(
      width: width,
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
    final label = context.l10n
        .formatDate(provider.selectedPeriodMonth, 'MMMM yyyy');
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

class _PeriodYearBar extends StatelessWidget {
  final MoneyProvider provider;
  final int year;
  const _PeriodYearBar({required this.provider, required this.year});

  @override
  Widget build(BuildContext context) {
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
            onPressed: provider.previousPeriodYear,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$year',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: provider.nextPeriodYear,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
