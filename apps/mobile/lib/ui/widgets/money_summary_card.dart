import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/money_transaction.dart';
import '../../providers/money_provider.dart';
import '../screens/organize/money/money_hub_screen.dart';
import 'money/money_editor_dialogs.dart';

class MoneySummaryCard extends StatelessWidget {
  final VoidCallback? onOpenMoneyHub;
  final bool isCompact;

  const MoneySummaryCard({
    super.key,
    this.onOpenMoneyHub,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<MoneyProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();
        final summary = provider.summaryForMonth(now.year, now.month);
        final dueRecurring = provider.dueRecurringTemplates().length;

        return InkWell(
          onTap: onOpenMoneyHub ?? () => MoneyHubScreen.push(context),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: EdgeInsets.all(isCompact ? 14 : 16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: kTwillAmber.withValues(alpha: 0.38),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: kTwillAmber.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.pick(
                                    'Twill Money Manager',
                                    'Manajer Keuangan Twill',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ),
                              if (dueRecurring > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kTwillAmber.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.pick(
                                      '$dueRecurring Due',
                                      '$dueRecurring Jatuh Tempo',
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.adaptive(
                                        context,
                                        dark: kTwillAmber,
                                        light: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.activeAccounts.isEmpty
                                ? l10n.pick(
                                    'No accounts yet • Tap to set up wallets',
                                    'Belum ada akun • Ketuk untuk atur dompet',
                                  )
                                : l10n.pick(
                                    'Balance: ${provider.formatAmount(provider.combinedActiveBalanceMinor)} • ${provider.activeAccounts.length} wallets',
                                    'Saldo: ${provider.formatAmount(provider.combinedActiveBalanceMinor)} • ${provider.activeAccounts.length} dompet',
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary(context),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.border(context)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CardMiniStat(
                        label: l10n.pick('Month In', 'Masuk'),
                        value: provider.formatAmount(
                          summary.totalIncomeMinor,
                          compact: true,
                        ),
                        color: MoneyTransactionType.income.color,
                      ),
                    ),
                    Expanded(
                      child: _CardMiniStat(
                        label: l10n.pick('Month Out', 'Keluar'),
                        value: provider.formatAmount(
                          summary.totalExpenseMinor,
                          compact: true,
                        ),
                        color: MoneyTransactionType.expense.color,
                      ),
                    ),
                    Expanded(
                      child: _CardMiniStat(
                        label: l10n.pick('Net', 'Bersih'),
                        value: provider.formatAmount(
                          summary.netCashFlowMinor,
                          compact: true,
                        ),
                        color: summary.netCashFlowMinor >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showMoneyTransactionSheet(
                          context,
                          initialType: MoneyTransactionType.expense,
                        ),
                        icon: const Icon(Icons.north_east_rounded,
                            size: 14, color: AppColors.error),
                        label: Text(l10n.tr('money_expense'),
                            style: const TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary(context),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showMoneyTransactionSheet(
                          context,
                          initialType: MoneyTransactionType.income,
                        ),
                        icon: const Icon(Icons.south_west_rounded,
                            size: 14, color: AppColors.success),
                        label: Text(l10n.tr('money_income'),
                            style: const TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary(context),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showMoneyTransactionSheet(
                          context,
                          initialType: MoneyTransactionType.transfer,
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded,
                            size: 14, color: AppColors.info),
                        label: Text(l10n.tr('money_transfer'),
                            style: const TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary(context),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CardMiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context)),
        ),
        const SizedBox(height: 2),
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
    );
  }
}
