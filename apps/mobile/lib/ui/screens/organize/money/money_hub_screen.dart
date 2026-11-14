import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/money_budget.dart';
import '../../../../data/models/money_transaction.dart';
import '../../../../domain/money/money_amount.dart';
import '../../../../providers/money_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../widgets/money/money_editor_dialogs.dart';
import '../../../widgets/security_pin_gate_sheet.dart';
import 'money_budgets_recurring_reports_views.dart';
import 'money_transactions_accounts_views.dart';

import '../../../../core/l10n/app_localizations.dart';

extension MoneySectionL10n on MoneySection {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        MoneySection.overview => l10n.tr('money_overview'),
        MoneySection.transactions => l10n.tr('money_transactions'),
        MoneySection.accounts => l10n.tr('money_accounts'),
        MoneySection.budgets => l10n.tr('money_budgets'),
        MoneySection.recurring => l10n.tr('money_recurring'),
        MoneySection.reports => l10n.tr('money_reports'),
      };
}

enum MoneySection {
  overview('Overview', Icons.dashboard_rounded),
  transactions('Transactions', Icons.receipt_long_rounded),
  accounts('Accounts', Icons.account_balance_wallet_rounded),
  budgets('Budgets', Icons.pie_chart_rounded),
  recurring('Recurring', Icons.autorenew_rounded),
  reports('Reports', Icons.bar_chart_rounded);

  final String label;
  final IconData icon;
  const MoneySection(this.label, this.icon);
}

class MoneyHubScreen extends StatefulWidget {
  final MoneySection initialSection;
  final bool standalone;

  const MoneyHubScreen({
    super.key,
    this.initialSection = MoneySection.overview,
    this.standalone = false,
  });

  static Future<void> push(
    BuildContext context, {
    MoneySection initialSection = MoneySection.overview,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MoneyHubScreen(
          initialSection: initialSection,
          standalone: true,
        ),
      ),
    );
  }

  @override
  State<MoneyHubScreen> createState() => _MoneyHubScreenState();
}

class _MoneyHubScreenState extends State<MoneyHubScreen> {
  late MoneySection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MoneyProvider>(context);

    Widget content;
    if (!provider.isAuthenticated) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.pick(
              'Sign in or select an active profile to access Twill Money.',
              'Masuk atau pilih profil aktif untuk mengakses Keuangan Twill.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
      );
    } else if (!provider.isPinUnlocked) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_rounded,
                color: AppColors.adaptive(
                  context,
                  dark: kTwillAmber,
                  light: const Color(0xFFB45309),
                ),
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.pick(
                  'Twill Money Locked',
                  'Keuangan Twill Terkunci',
                ),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.pick(
                  'Enter your Nestin security PIN to view balances and transactions.',
                  'Masukkan PIN keamanan Nestin untuk melihat saldo dan transaksi.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  SettingsProvider? settings;
                  try {
                    settings =
                        Provider.of<SettingsProvider>(context, listen: false);
                  } catch (_) {}
                  if (settings == null || !settings.hasPin) {
                    provider.unlockMoneyWithPin();
                    return;
                  }
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => SecurityPinGateSheet(
                      title: ctx.l10n.pick(
                        'Unlock Twill Money',
                        'Buka Keuangan Twill',
                      ),
                      subtitle: ctx.l10n.pick(
                        'Enter your 4-digit PIN to access money data',
                        'Masukkan 4-digit PIN untuk mengakses data keuangan',
                      ),
                      onUnlocked: () {
                        provider.unlockMoneyWithPin();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.key_rounded, size: 18),
                label: Text(
                  context.l10n.pick('Unlock with PIN', 'Buka dengan PIN'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTwillAmber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: [
          _buildHeaderBar(context, provider),
          _buildSectionSelector(),
          Expanded(
            child: switch (_section) {
              MoneySection.overview => _MoneyOverviewView(
                  onJumpSection: (sec) => setState(() => _section = sec),
                ),
              MoneySection.transactions => const MoneyTransactionsView(),
              MoneySection.accounts => const MoneyAccountsView(),
              MoneySection.budgets => const MoneyBudgetsView(),
              MoneySection.recurring => const MoneyRecurringView(),
              MoneySection.reports => const MoneyReportsView(),
            },
          ),
        ],
      );
    }

    if (widget.standalone) {
      final l10n = context.l10n;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.pick(
              'Twill Money Management',
              'Pengelolaan Keuangan Twill',
            ),
          ),
        ),
        body: content,
        floatingActionButton: FloatingActionButton(
          onPressed: () => showMoneyTransactionSheet(context),
          backgroundColor: kTwillAmber,
          foregroundColor: Colors.black,
          tooltip: l10n.pick('Add Transaction', 'Tambah Transaksi'),
          child: const Icon(Icons.add_rounded),
        ),
      );
    }

    return content;
  }

  Widget _buildHeaderBar(BuildContext context, MoneyProvider provider) {
    final l10n = context.l10n;
    final dueCount = provider.dueRecurringTemplates().length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kTwillAmber.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/mascots/sprites/twill/budgeted.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: kTwillAmber,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick('Twill Money Organizer', 'Pengatur Keuangan Twill'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  dueCount > 0
                      ? l10n.pick(
                          '$dueCount recurring due • ${provider.activeAccounts.length} wallets',
                          '$dueCount rutin jatuh tempo • ${provider.activeAccounts.length} dompet',
                        )
                      : l10n.pick(
                          '${provider.activeAccounts.length} active wallet(s) • Local ledger',
                          '${provider.activeAccounts.length} dompet aktif • Catatan lokal',
                        ),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          ActionChip(
            label: Text(
              provider.currency.symbol,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: AppColors.adaptive(
                  context,
                  dark: kTwillAmber,
                  light: const Color(0xFFB45309),
                ),
              ),
            ),
            onPressed: () => showMoneySettingsDialog(context),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: context.l10n.pick('Categories', 'Kategori'),
            icon: const Icon(Icons.category_outlined, size: 20),
            onPressed: () => showMoneyCategoriesSheet(context),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: MoneySection.values.map((s) {
          final selected = _section == s;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              selected: selected,
              selectedColor: kTwillAmber,
              backgroundColor: AppColors.cardSurface(context),
              avatar: Icon(
                s.icon,
                size: 14,
                color: selected
                    ? Colors.black
                    : AppColors.textSecondary(context),
              ),
              label: Text(
                s.localizedLabel(l10n),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.black : AppColors.textPrimary(context),
                ),
              ),
              onSelected: (_) => setState(() => _section = s),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Money Overview Dashboard View
// ---------------------------------------------------------------------------

class _MoneyOverviewView extends StatelessWidget {
  final ValueChanged<MoneySection> onJumpSection;

  const _MoneyOverviewView({required this.onJumpSection});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MoneyProvider>(context);
    final period = provider.selectedPeriodMonth;
    final summary = provider.summaryForMonth(period.year, period.month);
    final budgets = provider.budgetOverviewForMonth(period.year, period.month);
    final breakdown =
        provider.expenseBreakdownForMonth(period.year, period.month);
    final recentTxs = provider.transactions.take(5).toList();
    final hasAnyAccounts = provider.activeAccounts.isNotEmpty;

    final isDark = AppColors.isDark(context);
    final amberInk = AppColors.adaptive(
      context,
      dark: kTwillAmber,
      light: const Color(0xFFB45309),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
        // Month Switcher
        Container(
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
                    context.l10n.formatDate(period, 'MMMM yyyy'),
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
        ),
        const SizedBox(height: 12),

        // Balance + Period Summary Hero Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF231F18), Color(0xFF1A1B20)]
                  : const [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: kTwillAmber.withValues(alpha: isDark ? 0.38 : 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.tr('money_combined_balance'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onJumpSection(MoneySection.accounts),
                    child: Text(
                        context.l10n.pick('Wallets ->', 'Dompet ->'),
                        style: TextStyle(fontSize: 11, color: amberInk)),
                  ),
                ],
              ),
              Text(
                provider.formatAmount(provider.combinedActiveBalanceMinor),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetricTile(
                      label: context.l10n.tr('money_income'),
                      value: provider.formatAmount(summary.totalIncomeMinor),
                      color: MoneyTransactionType.income.color,
                      icon: MoneyTransactionType.income.icon,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryMetricTile(
                      label: context.l10n.pick('Expenses', 'Pengeluaran'),
                      value: provider.formatAmount(summary.totalExpenseMinor),
                      color: MoneyTransactionType.expense.color,
                      icon: MoneyTransactionType.expense.icon,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryMetricTile(
                      label: context.l10n.pick('Net Flow', 'Arus Bersih'),
                      value: provider.formatAmount(
                        summary.netCashFlowMinor,
                        showPlusSign: true,
                      ),
                      color: summary.netCashFlowMinor >= 0
                          ? AppColors.success
                          : AppColors.error,
                      icon: Icons.trending_flat_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Quick Action Shortcuts (+ Income, + Expense, Transfer)
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => showMoneyTransactionSheet(
                  context,
                  initialType: MoneyTransactionType.income,
                ),
                icon: const Icon(Icons.south_west_rounded, size: 15),
                label: Text('+ ${context.l10n.tr('money_income')}',
                    style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      MoneyTransactionType.income.color.withValues(alpha: 0.18),
                  foregroundColor: MoneyTransactionType.income.color,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => showMoneyTransactionSheet(
                  context,
                  initialType: MoneyTransactionType.expense,
                ),
                icon: const Icon(Icons.north_east_rounded, size: 15),
                label: Text('+ ${context.l10n.tr('money_expense')}',
                    style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      MoneyTransactionType.expense.color.withValues(alpha: 0.18),
                  foregroundColor: MoneyTransactionType.expense.color,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => showMoneyTransactionSheet(
                  context,
                  initialType: MoneyTransactionType.transfer,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                label: Text(context.l10n.tr('money_transfer'),
                    style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      MoneyTransactionType.transfer.color.withValues(alpha: 0.18),
                  foregroundColor: MoneyTransactionType.transfer.color,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (!hasAnyAccounts && provider.transactions.isEmpty) ...[
          // Meaningful Empty State for New Users
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 76,
                  child: Image.asset(
                    'assets/mascots/sprites/twill/saving_up.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.savings_outlined,
                      color: amberInk,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.pick(
                    'Welcome to Twill Money',
                    'Selamat Datang di Keuangan Twill',
                  ),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.pick(
                    'Start by creating your first wallet (Cash, Bank Account, or E-Wallet) to track balances, budgets, and daily spending offline.',
                    'Mulai dengan membuat dompet pertama (Tunai, Rekening Bank, atau E-Wallet) untuk melacak saldo, anggaran, dan belanja harian secara lokal.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => showMoneyAccountDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    context.l10n.pick(
                      'Create First Account',
                      'Buat Akun Pertama',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTwillAmber,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Monthly Income vs Expense Mini Chart
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.pick(
                          'Monthly Income vs. Expense',
                          'Pemasukan vs. Pengeluaran Bulanan',
                        ),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onJumpSection(MoneySection.reports),
                      child: Text(
                          context.l10n.pick('Reports ->', 'Laporan ->'),
                          style: TextStyle(fontSize: 11, color: amberInk)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _DualBarSummary(
                  incomeMinor: summary.totalIncomeMinor,
                  expenseMinor: summary.totalExpenseMinor,
                  provider: provider,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Top Category Breakdown
          if (breakdown.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.pick(
                      'Spending Breakdown by Category',
                      'Rincian Pengeluaran per Kategori',
                    ),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...breakdown.take(4).map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(row.category.icon,
                                  size: 14, color: row.category.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  row.category.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
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
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Budget Utilization Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.pick(
                          'Budget Utilization',
                          'Penggunaan Anggaran',
                        ),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onJumpSection(MoneySection.budgets),
                      child: Text(
                          context.l10n.pick('Manage ->', 'Kelola ->'),
                          style: TextStyle(fontSize: 11, color: amberInk)),
                    ),
                  ],
                ),
                if (!budgets.hasAnyBudgets)
                  Text(
                    context.l10n.pick(
                      'No monthly budget configured yet. Tap Manage to set limits.',
                      'Belum ada anggaran bulanan. Ketuk Kelola untuk mengatur batas.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  )
                else ...[
                  if (budgets.overallBudget != null)
                    _CompactBudgetLine(
                      label: context.l10n.pick(
                        'Overall Monthly Limit',
                        'Batas Bulanan Keseluruhan',
                      ),
                      summary: budgets.overallBudget!,
                      provider: provider,
                    ),
                  ...budgets.categoryBudgets.take(3).map(
                        (b) => _CompactBudgetLine(
                          label:
                              provider.findCategoryById(b.budget.categoryId)
                                      ?.name ??
                                  context.l10n.pick('Category', 'Kategori'),
                          summary: b,
                          provider: provider,
                        ),
                      ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Recent Transactions
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.pick(
                    'Recent Transactions',
                    'Transaksi Terbaru',
                  ),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => onJumpSection(MoneySection.transactions),
                child: Text(
                    context.l10n.pick('See All ->', 'Lihat Semua ->'),
                    style: TextStyle(fontSize: 11, color: amberInk)),
              ),
            ],
          ),
          if (recentTxs.isEmpty)
            Card(
              color: AppColors.cardSurface(context),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  context.l10n.pick(
                    'No transactions recorded yet.',
                    'Belum ada transaksi tercatat.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            )
          else
            ...recentTxs.map(
              (tx) => MoneyTransactionTile(tx: tx, provider: provider),
            ),
        ],
      ],
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryMetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.recessedSurface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DualBarSummary extends StatelessWidget {
  final int incomeMinor;
  final int expenseMinor;
  final MoneyProvider provider;

  const _DualBarSummary({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = incomeMinor > expenseMinor ? incomeMinor : expenseMinor;
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                context.l10n.tr('money_income'),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: MoneyAmount.barRatio(incomeMinor, maxVal),
                  minHeight: 8,
                  backgroundColor: AppColors.trackSurface(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      MoneyTransactionType.income.color),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              provider.formatAmount(incomeMinor, compact: true),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MoneyTransactionType.income.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                context.l10n.tr('money_expense'),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: MoneyAmount.barRatio(expenseMinor, maxVal),
                  minHeight: 8,
                  backgroundColor: AppColors.trackSurface(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      MoneyTransactionType.expense.color),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              provider.formatAmount(expenseMinor, compact: true),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MoneyTransactionType.expense.color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactBudgetLine extends StatelessWidget {
  final String label;
  final BudgetUtilizationSummary summary;
  final MoneyProvider provider;

  const _CompactBudgetLine({
    required this.label,
    required this.summary,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = summary.status == BudgetHealthStatus.exceeded
        ? AppColors.error
        : (summary.status == BudgetHealthStatus.nearLimit
            ? AppColors.warning
            : AppColors.success);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${provider.formatAmount(summary.spentMinor, compact: true)} / ${provider.formatAmount(summary.budget.limitMinor, compact: true)}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: MoneyAmount.barRatio(
                  summary.spentMinor, summary.budget.limitMinor),
              minHeight: 6,
              backgroundColor: AppColors.trackSurface(context),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
