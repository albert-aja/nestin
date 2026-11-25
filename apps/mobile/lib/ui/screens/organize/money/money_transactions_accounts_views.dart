import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/money_account.dart';
import '../../../../data/models/money_transaction.dart';
import '../../../../providers/money_provider.dart';
import '../../../widgets/money/money_editor_dialogs.dart';

// ---------------------------------------------------------------------------
// Transactions View (Search, Filters, Edit, Delete / Archive)
// ---------------------------------------------------------------------------

/// Optional pre-populated filter state passed when drilling down from reports.
class MoneyTransactionFilterPreset {
  final MoneyTransactionType? type;
  final String? accountId;
  final String? categoryId;
  final DateTimeRange? dateRange;
  final String query;
  final int revision;

  const MoneyTransactionFilterPreset({
    this.type,
    this.accountId,
    this.categoryId,
    this.dateRange,
    this.query = '',
    this.revision = 0,
  });
}

class MoneyTransactionsView extends StatefulWidget {
  final MoneyTransactionFilterPreset? filterPreset;

  const MoneyTransactionsView({
    super.key,
    this.filterPreset,
  });

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
  void initState() {
    super.initState();
    if (widget.filterPreset != null) {
      _applyPreset(widget.filterPreset!);
    }
  }

  @override
  void didUpdateWidget(covariant MoneyTransactionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPreset = widget.filterPreset;
    if (nextPreset != null &&
        nextPreset.revision != oldWidget.filterPreset?.revision) {
      setState(() => _applyPreset(nextPreset));
    }
  }

  void _applyPreset(MoneyTransactionFilterPreset preset) {
    _typeFilter = preset.type;
    _accountFilterId = preset.accountId;
    _categoryFilterId = preset.categoryId;
    _dateRange = preset.dateRange;
    _searchCtrl.text = preset.query;
  }

  bool get _hasActiveFilters =>
      _typeFilter != null ||
      _accountFilterId != null ||
      _categoryFilterId != null ||
      _dateRange != null ||
      _searchCtrl.text.trim().isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _typeFilter = null;
      _accountFilterId = null;
      _categoryFilterId = null;
      _dateRange = null;
      _searchCtrl.clear();
    });
  }

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
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context);
    final effectiveAccountId = _accountFilterId != null &&
            provider.accounts.any((a) => a.id == _accountFilterId)
        ? _accountFilterId
        : null;
    final effectiveCategoryId = _categoryFilterId != null &&
            provider.categories.any((c) => c.id == _categoryFilterId)
        ? _categoryFilterId
        : null;

    final filtered = provider.filterTransactions(
      type: _typeFilter,
      accountId: effectiveAccountId,
      categoryId: effectiveCategoryId,
      startDate: _dateRange?.start,
      endDate: _dateRange?.end,
      query: _searchCtrl.text,
    );

    var filteredNetMinor = 0;
    for (final tx in filtered) {
      if (tx.type == MoneyTransactionType.income) {
        filteredNetMinor += tx.amountMinor;
      } else if (tx.type == MoneyTransactionType.expense) {
        filteredNetMinor -= tx.amountMinor;
      }
    }

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
                  hintText: l10n.tr('search_descriptions_categories_wallets'),
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
                    label: Text(
                      l10n.tr('all_types'),
                      style: const TextStyle(fontSize: 11),
                    ),
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
                          ? l10n.tr('date_range')
                          : '${l10n.formatDate(_dateRange!.start, 'MMM d')} - ${l10n.formatDate(_dateRange!.end, 'MMM d')}',
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
                      key: ValueKey('acct_${effectiveAccountId ?? "all"}'),
                      isExpanded: true,
                      initialValue: effectiveAccountId,
                      dropdownColor: AppColors.cardSurface(context),
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: l10n.tr('account'),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            l10n.tr('all_accounts'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
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
                      key: ValueKey('cat_${effectiveCategoryId ?? "all"}'),
                      isExpanded: true,
                      initialValue: effectiveCategoryId,
                      dropdownColor: AppColors.cardSurface(context),
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: l10n.tr('category'),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            l10n.tr('all_categories'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        ...provider.categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.displayName,
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
              if (_hasActiveFilters) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tr('money_filtered_summary', {
                          'count': filtered.length,
                          'net': provider.formatAmount(
                            filteredNetMinor,
                            showPlusSign: true,
                          ),
                        }),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clearAllFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 14),
                      label: Text(
                        l10n.tr('money_clear_filters'),
                        style: const TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ],
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
                        Text(
                          l10n.tr('no_matching_transactions'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.tr('record_an_income_expense_or_internal'),
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
                          label: Text(
                            l10n.tr('add_transaction'),
                          ),
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
    final l10n = context.l10n;
    final account = provider.findAccountById(tx.accountId);
    final toAccount =
        tx.toAccountId != null ? provider.findAccountById(tx.toAccountId!) : null;
    final category = provider.findCategoryById(tx.categoryId);

    final fallbackAccount = l10n.tr('account_2');
    final title = tx.type == MoneyTransactionType.transfer
        ? '${account?.name ?? fallbackAccount} -> ${toAccount?.name ?? fallbackAccount}'
        : (tx.description.isNotEmpty
            ? tx.description
            : (category?.displayName ?? tx.type.label));

    final subtitleParts = <String>[
      if (tx.type != MoneyTransactionType.transfer && category != null)
        category.displayName,
      if (tx.type != MoneyTransactionType.transfer && account != null)
        account.name,
      if (tx.type == MoneyTransactionType.transfer && tx.description.isNotEmpty)
        tx.description,
      l10n.formatDate(tx.transactionDate, 'MMM d, yyyy'),
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
  final l10n = context.l10n;
  final account = provider.findAccountById(tx.accountId);
  final toAccount =
      tx.toAccountId != null ? provider.findAccountById(tx.toAccountId!) : null;
  final category = provider.findCategoryById(tx.categoryId);
  final unknownLabel = l10n.tr('unknown');

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardSurface(ctx),
      title: Row(
        children: [
          Icon(tx.type.icon, color: tx.type.color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.tr('details', {'tx_label': tx.type.label}),
            ),
          ),
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
          Text(
            l10n.tr('date', {'l10n_yyyy': l10n.formatDate(tx.transactionDate, 'MMM d, yyyy')}),
            style: const TextStyle(fontSize: 12),
          ),
          if (tx.type == MoneyTransactionType.transfer) ...[
            Text(
              l10n.tr('from', {'account_unknownLabel': account?.name ?? unknownLabel}),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              l10n.tr('to', {'toAccount_unknownLabel': toAccount?.name ?? unknownLabel}),
              style: const TextStyle(fontSize: 12),
            ),
            if (tx.transferGroupId != null)
              Text(
                l10n.tr('transfer_ref', {'tx_transferGroupId': tx.transferGroupId}),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
          ] else ...[
            Text(
              l10n.tr('account_3', {'account_unknownLabel': account?.name ?? unknownLabel}),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              l10n.tr('category_2', {'category_Kategori': category?.displayName ?? l10n.tr('uncategorized')}),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (tx.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.tr('note', {'tx_description': tx.description}),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(ctx),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await provider.deleteTransaction(tx.id);
          },
          child: Text(
            l10n.tr('delete'),
            style: const TextStyle(color: AppColors.error),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            showMoneyTransactionSheet(context, existing: tx);
          },
          child: Text(l10n.tr('edit')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.tr('close')),
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
    final l10n = context.l10n;
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
                      l10n.tr('combined_active_balance'),
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
                label: Text(l10n.tr('new_account')),
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
                  l10n.tr('show_archived', {'provider_length': provider.archivedAccounts.length}),
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
                      light: AppColors.twillDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.tr('no_wallets_added_yet'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tr('add_your_cash_bank_account_or'),
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
                          l10n.tr('archived_2'),
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
                  l10n.tr('opening', {'acct_label': acct.type.label, 'provider_initialBalanceMinor': provider.formatAmount(acct.initialBalanceMinor)}),
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
                      l10n.tr('tap_history'),
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
    final l10n = context.l10n;
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
                      l10n.tr('created', {'acct_label': acct.type.label, 'l10n_yyyy': l10n.formatDate(acct.createdAt, 'MMM d, yyyy')}),
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
                  l10n.tr('opening_initial_balance', {'provider_initialBalanceMinor': provider.formatAmount(acct.initialBalanceMinor)}),
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
                      label: Text(l10n.tr('edit')),
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
                      label: Text(
                        acct.isArchived
                            ? l10n.tr('restore')
                            : l10n.tr('archive'),
                      ),
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
                        label: Text(l10n.tr('add_entry_2')),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.tr('account_history', {'history_length': history.length}),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      l10n.tr('no_transactions_on_this_account_yet'),
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
