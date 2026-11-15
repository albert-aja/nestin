import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/money_account.dart';
import '../../../data/models/money_budget.dart';
import '../../../data/models/money_category.dart';
import '../../../data/models/money_transaction.dart';
import '../../../data/models/recurring_transaction.dart';
import '../../../domain/money/money_amount.dart';
import '../../../domain/money/money_reports.dart';
import '../../../providers/money_provider.dart';
import '../../../providers/settings_provider.dart';

const Color kTwillAmber = Color(0xFFF59E0B);

Future<void> showMoneyTransactionSheet(
  BuildContext context, {
  MoneyTransactionType initialType = MoneyTransactionType.expense,
  MoneyTransaction? existing,
  String? preselectedAccountId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MoneyTransactionEditorSheet(
      initialType: existing?.type ?? initialType,
      existing: existing,
      preselectedAccountId: preselectedAccountId,
    ),
  );
}

Future<void> showMoneyAccountDialog(
  BuildContext context, {
  MoneyAccount? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MoneyAccountEditorSheet(existing: existing),
  );
}

Future<void> showMoneyBudgetDialog(
  BuildContext context, {
  required int year,
  required int month,
  MoneyBudget? existing,
  String? presetCategoryId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MoneyBudgetEditorSheet(
      year: year,
      month: month,
      existing: existing,
      presetCategoryId: presetCategoryId,
    ),
  );
}

Future<void> showMoneyRecurringDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MoneyRecurringEditorSheet(),
  );
}

Future<void> showMoneyCategoriesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MoneyCategoriesSheet(),
  );
}

Future<void> showMoneySettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _MoneySettingsDialog(),
  );
}

// ---------------------------------------------------------------------------
// 1. Transaction & Internal Transfer Sheet
// ---------------------------------------------------------------------------

class _MoneyTransactionEditorSheet extends StatefulWidget {
  final MoneyTransactionType initialType;
  final MoneyTransaction? existing;
  final String? preselectedAccountId;

  const _MoneyTransactionEditorSheet({
    required this.initialType,
    this.existing,
    this.preselectedAccountId,
  });

  @override
  State<_MoneyTransactionEditorSheet> createState() =>
      _MoneyTransactionEditorSheetState();
}

class _MoneyTransactionEditorSheetState
    extends State<_MoneyTransactionEditorSheet> {
  late MoneyTransactionType _type;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _selectedDate;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _selectedDate = widget.existing?.transactionDate ?? DateTime.now();
    _amountCtrl = TextEditingController(
      text: widget.existing != null
          ? MoneyAmount.formatInputMinor(widget.existing!.amountMinor)
          : '',
    );
    _noteCtrl =
        TextEditingController(text: widget.existing?.description ?? '');

    final provider = Provider.of<MoneyProvider>(context, listen: false);
    final activeAccts = provider.activeAccounts;
    _accountId = widget.existing?.accountId ??
        widget.preselectedAccountId ??
        (activeAccts.isNotEmpty ? activeAccts.first.id : null);
    _toAccountId = widget.existing?.toAccountId ??
        (activeAccts.length > 1 ? activeAccts[1].id : null);
    _categoryId = widget.existing?.categoryId;
    _ensureValidCategory(provider);
  }

  void _ensureValidCategory(MoneyProvider provider) {
    if (_type == MoneyTransactionType.transfer) {
      _categoryId = null;
      return;
    }
    final catType = _type == MoneyTransactionType.income
        ? MoneyCategoryType.income
        : MoneyCategoryType.expense;
    final matching = provider.categoriesByType(catType);
    if (matching.isEmpty) {
      _categoryId = null;
      return;
    }
    if (!matching.any((c) => c.id == _categoryId)) {
      _categoryId = matching.first.id;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context, listen: false);
    final amountMinor = MoneyAmount.tryParseToMinor(_amountCtrl.text);
    if (amountMinor == null || amountMinor <= 0) {
      setState(() => _errorText = l10n.tr('enter_a_valid_positive_amount_0'));
      return;
    }
    if (_accountId == null) {
      setState(() => _errorText = l10n.tr('create_an_active_wallet_or_account'));
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      if (widget.existing != null) {
        await provider.editTransaction(
          transactionId: widget.existing!.id,
          type: _type,
          amountMinor: amountMinor,
          categoryId: _categoryId,
          accountId: _accountId!,
          toAccountId: _toAccountId,
          transactionDate: _selectedDate,
          description: _noteCtrl.text,
        );
      } else if (_type == MoneyTransactionType.transfer) {
        if (_toAccountId == null) {
          throw MoneyValidationException(
            l10n.tr('select_a_destination_account_for_transfer'),
          );
        }
        await provider.executeTransfer(
          fromAccountId: _accountId!,
          toAccountId: _toAccountId!,
          amountMinor: amountMinor,
          transactionDate: _selectedDate,
          description: _noteCtrl.text,
        );
      } else {
        if (_categoryId == null) {
          throw MoneyValidationException(
            l10n.tr('select_a_category'),
          );
        }
        await provider.addTransaction(
          type: _type,
          amountMinor: amountMinor,
          categoryId: _categoryId!,
          accountId: _accountId!,
          transactionDate: _selectedDate,
          description: _noteCtrl.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = e
              .toString()
              .replaceFirst('MoneyValidationException: ', '')
              .replaceFirst('MoneyAuthorizationException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context);
    final activeAccts = provider.activeAccounts;
    final existingAcct = _accountId != null ? provider.findAccountById(_accountId!) : null;
    final acctMap = <String, MoneyAccount>{
      for (final a in activeAccts) a.id: a,
    };
    if (existingAcct != null) {
      acctMap[existingAcct.id] = existingAcct;
    }
    final selectableAccounts = acctMap.values.toList();

    final catType = _type == MoneyTransactionType.income
        ? MoneyCategoryType.income
        : MoneyCategoryType.expense;
    final categories = provider.categoriesByType(catType);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? l10n.tr('record_transaction')
                        : l10n.tr('edit_transaction'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: MoneyTransactionType.values.map((t) {
                final selected = _type == t;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      selected: selected,
                      selectedColor: t.color,
                      backgroundColor: AppColors.elevatedSurface(context),
                      label: Center(
                        child: Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _type = t;
                          _errorText = null;
                          _ensureValidCategory(provider);
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            if (selectableAccounts.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kTwillAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kTwillAmber.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('no_wallets_yet'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.adaptive(
                          context,
                          dark: kTwillAmber,
                          light: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('create_a_cash_bank_or_e'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showMoneyAccountDialog(context);
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        l10n.tr('create_first_account'),
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
              TextField(
                controller: _amountCtrl,
                autofocus: widget.existing == null,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
                decoration: InputDecoration(
                  labelText: l10n.tr('amount', {'provider_code': provider.currency.code}),
                  prefixText: '${provider.currency.symbol} ',
                  prefixIcon: Icon(_type.icon, color: _type.color),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectableAccounts.any((a) => a.id == _accountId)
                    ? _accountId
                    : null,
                dropdownColor: AppColors.elevatedSurface(context),
                decoration: InputDecoration(
                  labelText: _type == MoneyTransactionType.transfer
                      ? l10n.tr('from_account_source')
                      : l10n.tr('account_4'),
                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                ),
                items: selectableAccounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.name} (${provider.formatAmount(a.currentBalanceMinor)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _accountId = val),
              ),
              const SizedBox(height: 12),
              if (_type == MoneyTransactionType.transfer) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      activeAccts.any((a) => a.id == _toAccountId)
                          ? _toAccountId
                          : null,
                  dropdownColor: AppColors.elevatedSurface(context),
                  decoration: InputDecoration(
                    labelText: l10n.tr('to_account_destination'),
                    prefixIcon: const Icon(Icons.swap_horiz_rounded),
                  ),
                  items: activeAccts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            '${a.name} (${provider.formatAmount(a.currentBalanceMinor)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _toAccountId = val),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue:
                            categories.any((c) => c.id == _categoryId)
                                ? _categoryId
                                : null,
                        dropdownColor: AppColors.elevatedSurface(context),
                        decoration: InputDecoration(
                          labelText: l10n.tr('category'),
                          prefixIcon: const Icon(Icons.category_rounded),
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(c.icon, size: 16, color: c.color),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        c.displayName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _categoryId = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: l10n.tr('manage_categories'),
                      onPressed: () => showMoneyCategoriesSheet(context),
                      icon: const Icon(Icons.tune_rounded, color: kTwillAmber),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.tr('date_2'),
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.formatDate(_selectedDate, 'EEE, MMM d, yyyy'),
                        style: TextStyle(color: AppColors.textPrimary(context)),
                      ),
                      Text(
                        l10n.tr('change'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.adaptive(
                            context,
                            dark: kTwillAmber,
                            light: const Color(0xFFB45309),
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('description_note'),
                  hintText: _type == MoneyTransactionType.transfer
                      ? l10n.tr('e_g_move_cash_to_e')
                      : l10n.tr('e_g_lunch_monthly_salary_groceries'),
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  widget.existing == null
                      ? (_type == MoneyTransactionType.transfer
                          ? l10n.tr('transfer_money')
                          : l10n.tr('save_2', {'type_label': _type.label}))
                      : l10n.tr('update_transaction'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Account Create / Edit Sheet
// ---------------------------------------------------------------------------

class _MoneyAccountEditorSheet extends StatefulWidget {
  final MoneyAccount? existing;
  const _MoneyAccountEditorSheet({this.existing});

  @override
  State<_MoneyAccountEditorSheet> createState() =>
      _MoneyAccountEditorSheetState();
}

class _MoneyAccountEditorSheetState extends State<_MoneyAccountEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  late final TextEditingController _descCtrl;
  late MoneyAccountType _type;
  late int _colorValue;
  String? _errorText;

  static const List<int> _palette = [
    0xFF10B981,
    0xFF3B82F6,
    0xFFF59E0B,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFF06B6D4,
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _balanceCtrl = TextEditingController(
      text: widget.existing != null
          ? MoneyAmount.formatInputMinor(widget.existing!.initialBalanceMinor)
          : '0',
    );
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _type = widget.existing?.type ?? MoneyAccountType.cash;
    _colorValue =
        widget.existing?.colorValue ?? _type.defaultColor.toARGB32();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context, listen: false);
    final initialMinor = _balanceCtrl.text.trim().isEmpty
        ? 0
        : MoneyAmount.tryParseToMinor(_balanceCtrl.text);
    if (initialMinor == null || initialMinor < 0) {
      setState(() => _errorText = l10n.tr('initial_balance_must_be_0_or'));
      return;
    }

    try {
      if (widget.existing == null) {
        await provider.createAccount(
          name: _nameCtrl.text,
          type: _type,
          initialBalanceMinor: initialMinor,
          description: _descCtrl.text,
          iconCodePoint: _type.defaultIcon.codePoint,
          colorValue: _colorValue,
        );
      } else {
        await provider.updateAccount(
          accountId: widget.existing!.id,
          name: _nameCtrl.text,
          type: _type,
          initialBalanceMinor: initialMinor,
          description: _descCtrl.text,
          iconCodePoint: _type.defaultIcon.codePoint,
          colorValue: _colorValue,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e
              .toString()
              .replaceFirst('MoneyValidationException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currency = Provider.of<MoneyProvider>(context).currency;
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? l10n.tr('create_wallet_account')
                        : l10n.tr('edit_account'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              autofocus: widget.existing == null,
              decoration: InputDecoration(
                labelText: l10n.tr('account_name'),
                hintText: l10n.tr('e_g_daily_cash_main_bank'),
                prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: MoneyAccountType.values.map((t) {
                final selected = _type == t;
                final selColor = Color(_colorValue);
                final selFg =
                    ThemeData.estimateBrightnessForColor(selColor) ==
                            Brightness.light
                        ? Colors.black
                        : Colors.white;
                return ChoiceChip(
                  selected: selected,
                  selectedColor: selColor,
                  backgroundColor: AppColors.elevatedSurface(context),
                  avatar: Icon(t.defaultIcon,
                      size: 16, color: selected ? selFg : t.defaultColor),
                  label: Text(
                    t.label,
                    style: TextStyle(
                      color: selected ? selFg : AppColors.textPrimary(context),
                    ),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _type = t;
                      if (widget.existing == null) {
                        _colorValue = t.defaultColor.toARGB32();
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balanceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.tr('opening_initial_balance_2', {'currency_code': currency.code}),
                helperText: l10n.tr('tracked_separately_from_monthly_income_transactions'),
                prefixText: '${currency.symbol} ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: l10n.tr('description_optional_2'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: _palette.map((c) {
                final selected = _colorValue == c;
                final bg = Color(c);
                final checkFg =
                    ThemeData.estimateBrightnessForColor(bg) == Brightness.light
                        ? Colors.black
                        : Colors.white;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _colorValue = c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: bg,
                      child: selected
                          ? Icon(Icons.check_rounded, size: 16, color: checkFg)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kTwillAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                widget.existing == null
                    ? l10n.tr('create_account')
                    : l10n.tr('save_changes'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Monthly Budget Editor Sheet
// ---------------------------------------------------------------------------

class _MoneyBudgetEditorSheet extends StatefulWidget {
  final int year;
  final int month;
  final MoneyBudget? existing;
  final String? presetCategoryId;

  const _MoneyBudgetEditorSheet({
    required this.year,
    required this.month,
    this.existing,
    this.presetCategoryId,
  });

  @override
  State<_MoneyBudgetEditorSheet> createState() =>
      _MoneyBudgetEditorSheetState();
}

class _MoneyBudgetEditorSheetState extends State<_MoneyBudgetEditorSheet> {
  late final TextEditingController _limitCtrl;
  late final TextEditingController _noteCtrl;
  String? _categoryId;
  late int _warningPercent;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _limitCtrl = TextEditingController(
      text: widget.existing != null
          ? MoneyAmount.formatInputMinor(widget.existing!.limitMinor)
          : '',
    );
    _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
    _categoryId = widget.existing?.categoryId ?? widget.presetCategoryId;
    _warningPercent = widget.existing?.warningThresholdPercent ?? 80;
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context, listen: false);
    final limitMinor = MoneyAmount.tryParseToMinor(_limitCtrl.text);
    if (limitMinor == null || limitMinor <= 0) {
      setState(() => _errorText = l10n.tr('budget_limit_must_be_greater_than'));
      return;
    }

    try {
      await provider.setMonthlyBudget(
        year: widget.year,
        month: widget.month,
        categoryId: _categoryId,
        limitMinor: limitMinor,
        warningThresholdPercent: _warningPercent,
        note: _noteCtrl.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e
              .toString()
              .replaceFirst('MoneyValidationException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context);
    final expenseCategories =
        provider.categoriesByType(MoneyCategoryType.expense);
    final monthLabel = l10n.formatDate(
      DateTime(widget.year, widget.month),
      'MMMM yyyy',
    );

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tr('budget_2', {'monthLabel': monthLabel}),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _categoryId == null ||
                      expenseCategories.any((c) => c.id == _categoryId)
                  ? _categoryId
                  : null,
              dropdownColor: AppColors.elevatedSurface(context),
              decoration: InputDecoration(
                labelText: l10n.tr('budget_scope'),
                prefixIcon: const Icon(Icons.pie_chart_outline_rounded),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    l10n.tr('overall_monthly_spending_limit'),
                  ),
                ),
                ...expenseCategories.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.displayName),
                  ),
                ),
              ],
              onChanged: widget.existing != null
                  ? null
                  : (val) => setState(() => _categoryId = val),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limitCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.tr('monthly_limit', {'provider_code': provider.currency.code}),
                prefixText: '${provider.currency.symbol} ',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tr('warning_alert_threshold'),
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary(context)),
                  ),
                ),
                Text(
                  '$_warningPercent%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.adaptive(
                      context,
                      dark: kTwillAmber,
                      light: const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _warningPercent.toDouble(),
              min: 50,
              max: 95,
              divisions: 9,
              activeColor: kTwillAmber,
              onChanged: (v) => setState(() => _warningPercent = v.round()),
            ),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: l10n.tr('note_optional'),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kTwillAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                l10n.tr('save_budget_limit'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Recurring Transaction Editor Sheet
// ---------------------------------------------------------------------------

class _MoneyRecurringEditorSheet extends StatefulWidget {
  const _MoneyRecurringEditorSheet();

  @override
  State<_MoneyRecurringEditorSheet> createState() =>
      _MoneyRecurringEditorSheetState();
}

class _MoneyRecurringEditorSheetState
    extends State<_MoneyRecurringEditorSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  MoneyTransactionType _type = MoneyTransactionType.expense;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _accountId;
  String? _categoryId;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<MoneyProvider>(context, listen: false);
    if (provider.activeAccounts.isNotEmpty) {
      _accountId = provider.activeAccounts.first.id;
    }
    _syncCategory(provider);
  }

  void _syncCategory(MoneyProvider provider) {
    final cats = provider.categoriesByType(
      _type == MoneyTransactionType.income
          ? MoneyCategoryType.income
          : MoneyCategoryType.expense,
    );
    if (cats.isEmpty) {
      _categoryId = null;
    } else if (!cats.any((c) => c.id == _categoryId)) {
      _categoryId = cats.first.id;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context, listen: false);
    final minor = MoneyAmount.tryParseToMinor(_amountCtrl.text);
    if (minor == null || minor <= 0) {
      setState(() => _errorText = l10n.tr('amount_must_be_greater_than_zero'));
      return;
    }
    if (_accountId == null || _categoryId == null) {
      setState(() => _errorText = l10n.tr('account_and_category_are_required'));
      return;
    }

    try {
      await provider.createRecurring(
        title: _titleCtrl.text,
        type: _type,
        amountMinor: minor,
        categoryId: _categoryId!,
        accountId: _accountId!,
        frequency: _frequency,
        startDate: _startDate,
        endDate: _endDate,
        description: _descCtrl.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e
              .toString()
              .replaceFirst('MoneyValidationException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context);
    final activeAccts = provider.activeAccounts;
    final cats = provider.categoriesByType(
      _type == MoneyTransactionType.income
          ? MoneyCategoryType.income
          : MoneyCategoryType.expense,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tr('new_recurring_schedule'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              l10n.tr('templates_queue_upcoming_entries_for_your'),
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected: _type == MoneyTransactionType.expense,
                    selectedColor: MoneyTransactionType.expense.color,
                    backgroundColor: AppColors.elevatedSurface(context),
                    label: Center(
                      child: Text(
                        MoneyTransactionType.expense.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _type == MoneyTransactionType.expense
                              ? Colors.white
                              : AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    onSelected: (_) => setState(() {
                      _type = MoneyTransactionType.expense;
                      _syncCategory(provider);
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    selected: _type == MoneyTransactionType.income,
                    selectedColor: MoneyTransactionType.income.color,
                    backgroundColor: AppColors.elevatedSurface(context),
                    label: Center(
                      child: Text(
                        MoneyTransactionType.income.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _type == MoneyTransactionType.income
                              ? Colors.white
                              : AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    onSelected: (_) => setState(() {
                      _type = MoneyTransactionType.income;
                      _syncCategory(provider);
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.tr('title_e_g_monthly_salary_internet'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.tr('amount', {'provider_code': provider.currency.code}),
                prefixText: '${provider.currency.symbol} ',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: activeAccts.any((a) => a.id == _accountId)
                  ? _accountId
                  : null,
              dropdownColor: AppColors.elevatedSurface(context),
              decoration: InputDecoration(
                labelText: l10n.tr('account_4'),
              ),
              items: activeAccts
                  .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                  .toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue:
                  cats.any((c) => c.id == _categoryId) ? _categoryId : null,
              dropdownColor: AppColors.elevatedSurface(context),
              decoration: InputDecoration(
                labelText: l10n.tr('category'),
              ),
              items: cats
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.displayName)))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<RecurrenceFrequency>(
              isExpanded: true,
              initialValue: _frequency,
              dropdownColor: AppColors.elevatedSurface(context),
              decoration: InputDecoration(
                labelText: l10n.tr('frequency'),
              ),
              items: RecurrenceFrequency.values
                  .map(
                      (f) => DropdownMenuItem(value: f, child: Text(f.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _frequency = v);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null && mounted) {
                        setState(() => _startDate = d);
                      }
                    },
                    icon: const Icon(Icons.event_rounded, size: 16),
                    label: Text(
                      l10n.tr('start', {'l10n_yy': l10n.formatDate(_startDate, 'MMM d, yy')}),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (_endDate != null) {
                        setState(() => _endDate = null);
                        return;
                      }
                      final d = await showDatePicker(
                        context: context,
                        initialDate:
                            _startDate.add(const Duration(days: 30)),
                        firstDate: _startDate,
                        lastDate: DateTime(2100),
                      );
                      if (d != null && mounted) {
                        setState(() => _endDate = d);
                      }
                    },
                    icon: Icon(
                      _endDate == null
                          ? Icons.event_available_rounded
                          : Icons.close_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _endDate == null
                          ? l10n.tr('end_optional')
                          : l10n.tr('end', {'l10n_yy': l10n.formatDate(_endDate!, 'MMM d, yy')}),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: activeAccts.isEmpty ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kTwillAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                l10n.tr('save_recurring_rule'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Category Manager Sheet (Create, Edit, Safe Delete)
// ---------------------------------------------------------------------------

class _MoneyCategoriesSheet extends StatefulWidget {
  const _MoneyCategoriesSheet();

  @override
  State<_MoneyCategoriesSheet> createState() => _MoneyCategoriesSheetState();
}

class _MoneyCategoriesSheetState extends State<_MoneyCategoriesSheet> {
  MoneyCategoryType _type = MoneyCategoryType.expense;

  void _openCategoryEditor({MoneyCategory? existing}) {
    showDialog<void>(
      context: context,
      builder: (_) => _MoneyCategoryEditorDialog(
        type: existing?.type ?? _type,
        existing: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context);
    final items = provider.categoriesByType(_type);

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
              Expanded(
                child: Text(
                  l10n.tr('transaction_categories'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _openCategoryEditor(),
                icon: Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.adaptive(
                    context,
                    dark: kTwillAmber,
                    light: const Color(0xFFB45309),
                  ),
                ),
                tooltip: l10n.tr('new_category'),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Row(
            children: MoneyCategoryType.values.map((t) {
              final selected = _type == t;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    selected: selected,
                    selectedColor: t.semanticColor,
                    backgroundColor: AppColors.elevatedSurface(context),
                    label: Center(
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    onSelected: (_) => setState(() => _type = t),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final cat = items[index];
                final inUse = provider.isCategoryInUse(cat.id);
                return Card(
                  color: AppColors.elevatedSurface(context),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cat.color.withValues(alpha: 0.18),
                      child: Icon(cat.icon, color: cat.color, size: 18),
                    ),
                    title: Text(
                      cat.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      inUse
                          ? l10n.tr('in_use_protected_from_deletion')
                          : (cat.isDefault
                              ? l10n.tr('default_category')
                              : l10n.tr('custom')),
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _openCategoryEditor(existing: cat),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: inUse
                                ? AppColors.textMuted(context)
                                    .withValues(alpha: 0.45)
                                : AppColors.error,
                          ),
                          onPressed: () async {
                            try {
                              await provider.deleteCategory(cat.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceFirst(
                                          'MoneyValidationException: ', ''),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyCategoryEditorDialog extends StatefulWidget {
  final MoneyCategoryType type;
  final MoneyCategory? existing;

  const _MoneyCategoryEditorDialog({required this.type, this.existing});

  @override
  State<_MoneyCategoryEditorDialog> createState() =>
      _MoneyCategoryEditorDialogState();
}

class _MoneyCategoryEditorDialogState
    extends State<_MoneyCategoryEditorDialog> {
  late final TextEditingController _nameCtrl;
  late int _iconCodePoint;
  late int _colorValue;
  String? _errorText;

  static final List<IconData> _icons = [
    Icons.restaurant_rounded,
    Icons.directions_car_rounded,
    Icons.shopping_bag_rounded,
    Icons.home_rounded,
    Icons.bolt_rounded,
    Icons.favorite_rounded,
    Icons.movie_rounded,
    Icons.school_rounded,
    Icons.work_rounded,
    Icons.card_giftcard_rounded,
    Icons.pets_rounded,
    Icons.flight_rounded,
  ];

  static const List<int> _colors = [
    0xFFF59E0B,
    0xFF10B981,
    0xFF3B82F6,
    0xFFEF4444,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFF06B6D4,
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _iconCodePoint =
        widget.existing?.iconCodePoint ?? _icons.first.codePoint;
    _colorValue = widget.existing?.colorValue ?? _colors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<MoneyProvider>(context, listen: false);
    return AlertDialog(
      backgroundColor: AppColors.cardSurface(context),
      title: Text(
        widget.existing == null
            ? l10n.tr('new_category_2', {'widget_label': widget.type.label})
            : l10n.tr('edit_category'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.tr('category_name'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.tr('icon'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((ic) {
                final selected = _iconCodePoint == ic.codePoint;
                return InkWell(
                  onTap: () => setState(() => _iconCodePoint = ic.codePoint),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected
                          ? Color(_colorValue).withValues(alpha: 0.25)
                          : AppColors.elevatedSurface(context),
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(color: Color(_colorValue))
                          : null,
                    ),
                    child: Icon(ic, size: 18, color: Color(_colorValue)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.tr('color'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _colors.map((c) {
                final selected = _colorValue == c;
                final bg = Color(c);
                final checkFg =
                    ThemeData.estimateBrightnessForColor(bg) == Brightness.light
                        ? Colors.black
                        : Colors.white;
                return GestureDetector(
                  onTap: () => setState(() => _colorValue = c),
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: bg,
                    child: selected
                        ? Icon(Icons.check_rounded, size: 14, color: checkFg)
                        : null,
                  ),
                );
              }).toList(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              if (widget.existing == null) {
                await provider.createCategory(
                  name: _nameCtrl.text,
                  type: widget.type,
                  iconCodePoint: _iconCodePoint,
                  colorValue: _colorValue,
                );
              } else {
                await provider.updateCategory(
                  categoryId: widget.existing!.id,
                  name: _nameCtrl.text,
                  iconCodePoint: _iconCodePoint,
                  colorValue: _colorValue,
                );
              }
              if (context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if (mounted) {
                setState(() {
                  _errorText = e
                      .toString()
                      .replaceFirst('MoneyValidationException: ', '');
                });
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kTwillAmber,
            foregroundColor: Colors.black,
          ),
          child: Text(l10n.tr('save')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Money Settings Dialog (Currency & Privacy PIN Lock)
// ---------------------------------------------------------------------------

class _MoneySettingsDialog extends StatelessWidget {
  const _MoneySettingsDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = Provider.of<MoneyProvider>(context);
    SettingsProvider? settings;
    try {
      settings = Provider.of<SettingsProvider>(context);
    } catch (_) {}

    return AlertDialog(
      backgroundColor: AppColors.cardSurface(context),
      title: Text(l10n.tr('twill_money_settings')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<MoneyCurrency>(
            isExpanded: true,
            initialValue: money.currency,
            dropdownColor: AppColors.elevatedSurface(context),
            decoration: InputDecoration(
              labelText: l10n.tr('display_currency'),
            ),
            items: MoneyCurrency.values
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c.symbol} (${c.code}) • ${c.localizedName}'),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) money.setCurrency(val);
            },
          ),
          if (settings != null && settings.hasPin) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.tr('require_pin_for_money_hub'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                l10n.tr('uses_your_nestin_security_pin_before'),
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary(context)),
              ),
              value: money.settings.requirePinForMoney,
              onChanged: (val) => money.setRequirePinForMoney(val),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.tr('done')),
        ),
      ],
    );
  }
}
