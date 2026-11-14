import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/money_account.dart';
import '../../../../data/models/money_transaction.dart';
import '../../../../providers/money_provider.dart';
import '../../../widgets/money/money_editor_dialogs.dart';

// ---------------------------------------------------------------------------
// Transactions View (Search, Filters, Edit, Delete / Archive)
// ---------------------------------------------------------------------------

class MoneyTransactionsView extends StatefulWidget {
  const MoneyTransactionsView({super.key});

  @override
  State<MoneyTransactionsView> createState() => _MoneyTransactionsViewState();
}

class _MoneyTransactionsViewState extends State<MoneyTransactionsView> {
  final TextEditingController _searchCtrl = TextEditingController();
  MoneyTransactionType? _typeFilter;
  String? _accountFilterId;
  String? _categoryFilterId;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );
    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MoneyProvider>(context);
    final filtered = provider.filterTransactions(
      type: _typeFilter,
      accountId: _accountFilterId,
      categoryId: _categoryFilterId,
      startDate: _dateRange?.start,
      endDate: _dateRange?.end,
      query: _searchCtrl.text,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search descriptions, categories, wallets...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    selected: _typeFilter == null,
                    label: const Text('All Types', style: TextStyle(fontSize: 11)),
                    onSelected: (_) => setState(() => _typeFilter = null),
                  ),
                  ...MoneyTransactionType.values.map(
                    (t) => ChoiceChip(
                      selected: _typeFilter == t,
                      selectedColor: t.color.withValues(alpha: 0.25),
                      label: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: _typeFilter == t ? t.color : null,
                        ),
                      ),
                      onSelected: (_) => setState(
                          () => _typeFilter = _typeFilter == t ? null : t),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.date_range_rounded, size: 14),
                    label: Text(
                      _dateRange == null
                          ? 'Date Range'
                          : '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: _dateRange != null
                        ? () => setState(() => _dateRange = null)
                        : _pickDateRange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: _accountFilterId,
                      dropdownColor: AppColors.cardSurface(context),
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Accounts',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12)),
                        ),
                        ...provider.accounts.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Text(a.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _accountFilterId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: _categoryFilterId,
                      dropdownColor: AppColors.cardSurface(context),
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Categories',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12)),
                        ),
                        ...provider.categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _categoryFilterId = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 44, color: AppColors.textSecondary(context)),
                        const SizedBox(height: 10),
                        const Text(
                          'No matching transactions',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Record an income, expense, or internal transfer to start tracking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => showMoneyTransactionSheet(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Transaction'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTwillAmber,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => MoneyTransactionTile(
                    tx: filtered[index],
                    provider: provider,
                  ),
                ),
        ),
      ],
    );
  }
}

class MoneyTransactionTile extends StatelessWidget {
  final MoneyTransaction tx;
  final MoneyProvider provider;

  const MoneyTransactionTile({
    super.key,
    required this.tx,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final account = provider.findAccountById(tx.accountId);
    final toAccount =
        tx.toAccountId != null ? provider.findAccountById(tx.toAccountId!) : null;
    final category = provider.findCategoryById(tx.categoryId);

    final title = tx.type == MoneyTransactionType.transfer
        ? '${account?.name ?? 'Account'} -> ${toAccount?.name ?? 'Account'}'
        : (tx.description.isNotEmpty
            ? tx.description
            : (category?.name ?? tx.type.label));

    final subtitleParts = <String>[
      if (tx.type != MoneyTransactionType.transfer && category != null)
        category.name,
      if (tx.type != MoneyTransactionType.transfer && account != null)
        account.name,
      if (tx.type == MoneyTransactionType.transfer && tx.description.isNotEmpty)
        tx.description,
      DateFormat('MMM d, yyyy').format(tx.transactionDate),
    ];

    final signedText = tx.type == MoneyTransactionType.transfer
        ? provider.formatAmount(tx.amountMinor)
        : (tx.type == MoneyTransactionType.income
            ? '+${provider.formatAmount(tx.amountMinor)}'
            : '-${provider.formatAmount(tx.amountMinor)}');

    final leadingColor = category?.color ?? tx.type.color;
    final leadingIcon = category?.icon ?? tx.type.icon;

    return Card(
      color: AppColors.cardSurface(context),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => showMoneyTransactionDetailDialog(context, provider, tx),
        leading: CircleAvatar(
          backgroundColor: leadingColor.withValues(alpha: 0.16),
          child: Icon(leadingIcon, color: leadingColor, size: 18),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitleParts.join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary(context),
          ),
        ),
        trailing: Text(
          signedText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: tx.type.color,
          ),
        ),
      ),
    );
  }
}

void showMoneyTransactionDetailDialog(
  BuildContext context,
  MoneyProvider provider,
  MoneyTransaction tx,
) {
  final account = provider.findAccountById(tx.accountId);
  final toAccount =
      tx.toAccountId != null ? provider.findAccountById(tx.toAccountId!) : null;
  final category = provider.findCategoryById(tx.categoryId);

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardSurface(ctx),
      title: Row(
        children: [
          Icon(tx.type.icon, color: tx.type.color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('${tx.type.label} Details')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.formatAmount(tx.amountMinor),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: tx.type.color,
            ),
          ),
          const SizedBox(height: 10),
          Text('Date: ${DateFormat('MMM d, yyyy').format(tx.transactionDate)}',
              style: const TextStyle(fontSize: 12)),
          if (tx.type == MoneyTransactionType.transfer) ...[
            Text('From: ${account?.name ?? 'Unknown'}',
                style: const TextStyle(fontSize: 12)),
            Text('To: ${toAccount?.name ?? 'Unknown'}',
                style: const TextStyle(fontSize: 12)),
            if (tx.transferGroupId != null)
              Text('Transfer Ref: ${tx.transferGroupId}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(ctx),
                  )),
          ] else ...[
            Text('Account: ${account?.name ?? 'Unknown'}',
                style: const TextStyle(fontSize: 12)),
            Text('Category: ${category?.name ?? 'Uncategorized'}',
                style: const TextStyle(fontSize: 12)),
          ],
          if (tx.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Note: ${tx.description}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(ctx),
                )),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await provider.deleteTransaction(tx.id);
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            showMoneyTransactionSheet(context, existing: tx);
          },
          child: const Text('Edit'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Wallets & Accounts View
// ---------------------------------------------------------------------------

class MoneyAccountsView extends StatefulWidget {
  const MoneyAccountsView({super.key});

  @override
  State<MoneyAccountsView> createState() => _MoneyAccountsViewState();
}

class _MoneyAccountsViewState extends State<MoneyAccountsView> {
  bool _showArchived = false;

  void _openAccountDetails(MoneyAccount account) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountDetailSheet(accountId: account.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MoneyProvider>(context);
    final list = _showArchived ? provider.accounts : provider.activeAccounts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kTwillAmber.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Combined Active Balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.formatAmount(provider.combinedActiveBalanceMinor),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => showMoneyAccountDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTwillAmber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
        if (provider.archivedAccounts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilterChip(
                selected: _showArchived,
                label: Text(
                  'Show Archived (${provider.archivedAccounts.length})',
                  style: const TextStyle(fontSize: 11),
                ),
                onSelected: (v) => setState(() => _showArchived = v),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        if (list.isEmpty)
          Card(
            color: AppColors.cardSurface(context),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 40,
                    color: AppColors.adaptive(
                      context,
                      dark: kTwillAmber,
                      light: const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No Wallets Added Yet',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your Cash, Bank Account, or E-Wallet balances so Twill can keep them organized.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...list.map(
            (acct) => Card(
              color: AppColors.cardSurface(context),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _openAccountDetails(acct),
                leading: CircleAvatar(
                  backgroundColor: acct.color.withValues(alpha: 0.18),
                  child: Icon(acct.icon, color: acct.color),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        acct.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    if (acct.isArchived) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.border(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Archived',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${acct.type.label} • Opening ${provider.formatAmount(acct.initialBalanceMinor)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      provider.formatAmount(acct.currentBalanceMinor),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: acct.currentBalanceMinor < 0
                            ? AppColors.error
                            : AppColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      'Tap history',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AccountDetailSheet extends StatelessWidget {
  final String accountId;
  const _AccountDetailSheet({required this.accountId});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MoneyProvider>(context);
    final acct = provider.findAccountById(accountId);
    if (acct == null) return const SizedBox.shrink();
    final history = provider.transactionsForAccount(accountId);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: acct.color.withValues(alpha: 0.18),
                child: Icon(acct.icon, color: acct.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acct.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${acct.type.label} • Created ${DateFormat('MMM d, yyyy').format(acct.createdAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.formatAmount(acct.currentBalanceMinor),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Opening initial balance: ${provider.formatAmount(acct.initialBalanceMinor)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                if (acct.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(acct.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      )),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          showMoneyAccountDialog(context, existing: acct),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Edit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await provider.setAccountArchived(
                            acct.id, !acct.isArchived);
                      },
                      icon: Icon(
                        acct.isArchived
                            ? Icons.unarchive_rounded
                            : Icons.archive_outlined,
                        size: 15,
                      ),
                      label: Text(acct.isArchived ? 'Restore' : 'Archive'),
                    ),
                    if (!acct.isArchived)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          showMoneyTransactionSheet(
                            context,
                            preselectedAccountId: acct.id,
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text('Add Entry'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Account History (${history.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'No transactions on this account yet.',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) => MoneyTransactionTile(
                      tx: history[index],
                      provider: provider,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
