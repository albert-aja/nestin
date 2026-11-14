import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/money_account.dart';
import '../data/models/money_budget.dart';
import '../data/models/money_category.dart';
import '../data/models/money_settings.dart';
import '../data/models/money_transaction.dart';
import '../data/models/recurring_transaction.dart';
import '../data/services/storage_service.dart';
import '../domain/money/money_amount.dart';
import '../domain/money/money_reports.dart';

class MoneyProvider extends ChangeNotifier {
  final StorageService _storageService;

  String _currentUserId;
  bool _isAuthenticated;
  bool _isPinUnlocked = false;
  DateTime _selectedPeriodMonth;

  // Multi-user full persisted collections + current-user indexed projections
  List<MoneyAccount> _allAccounts = [];
  List<MoneyCategory> _allCategories = [];
  List<MoneyTransaction> _allTransactions = [];
  List<MoneyBudget> _allBudgets = [];
  List<RecurringTransaction> _allRecurring = [];
  MoneySettings _settings = const MoneySettings();

  // In-memory indexes for fast O(1) lookup and query filtering
  final Map<String, MoneyAccount> _accountById = {};
  final Map<String, MoneyCategory> _categoryById = {};
  final Map<String, MoneyTransaction> _txById = {};
  final Map<String, List<MoneyTransaction>> _txByAccount = {};
  final Map<String, List<MoneyTransaction>> _txByCategory = {};
  final Map<String, List<MoneyTransaction>> _txByMonth = {};
  final Set<String> _occurrenceKeyIndex = {};

  MoneyProvider(
    this._storageService, {
    String currentUserId = MoneyAccount.defaultUserId,
    bool isAuthenticated = true,
    bool seedDefaultCategories = true,
    DateTime? initialPeriod,
  }) : _selectedPeriodMonth = DateTime(
          (initialPeriod ?? DateTime.now()).year,
          (initialPeriod ?? DateTime.now()).month,
        ),
        _currentUserId = '',
        _isAuthenticated = false {
    _currentUserId = currentUserId;
    _isAuthenticated = isAuthenticated;
    _initialize(seedDefaultCategories: seedDefaultCategories);
  }

  // --- Authentication / Isolation Context ---

  String get currentUserId => _currentUserId;
  bool get isAuthenticated => _isAuthenticated;
  bool get isPinUnlocked => !_settings.requirePinForMoney || _isPinUnlocked;
  MoneySettings get settings => _settings;
  MoneyCurrency get currency => _settings.currency;
  DateTime get selectedPeriodMonth => _selectedPeriodMonth;

  Future<void> setSessionUser({
    required String userId,
    bool authenticated = true,
    bool seedDefaultCategories = true,
  }) async {
    _currentUserId = userId;
    _isAuthenticated = authenticated;
    _isPinUnlocked = false;
    _settings = _loadOrCreateSettings();
    if (_isAuthenticated && seedDefaultCategories) {
      await _ensureDefaultCategoriesForCurrentUser();
    }
    _rebuildIndexes();
    notifyListeners();
  }

  void unlockMoneyWithPin() {
    _isPinUnlocked = true;
    notifyListeners();
  }

  void lockMoney() {
    _isPinUnlocked = false;
    notifyListeners();
  }

  Future<void> setCurrency(MoneyCurrency currency) async {
    _assertAuthenticated();
    _settings = _settings.copyWith(userId: _currentUserId, currency: currency);
    await _storageService.saveMoneySettings(_settings);
    notifyListeners();
  }

  Future<void> setRequirePinForMoney(bool enabled) async {
    _assertAuthenticated();
    _settings = _settings.copyWith(
      userId: _currentUserId,
      requirePinForMoney: enabled,
    );
    if (!enabled) {
      _isPinUnlocked = true;
    } else {
      _isPinUnlocked = false;
    }
    await _storageService.saveMoneySettings(_settings);
    notifyListeners();
  }

  // --- Initialization & Reload ---

  void _initialize({required bool seedDefaultCategories}) {
    // Run synchronous migration if stored schema predates v1
    _loadRawLists();
    if (_isAuthenticated && seedDefaultCategories) {
      _ensureDefaultCategoriesSync();
    }
    _reconcileAllBalancesInMemory();
    _rebuildIndexes();
  }

  Future<void> reloadFromStorage({bool seedDefaultCategories = true}) async {
    await _storageService.reloadPrefs();
    await _storageService.migrateMoneySchemaIfNeeded();
    _loadRawLists();
    if (_isAuthenticated && seedDefaultCategories) {
      await _ensureDefaultCategoriesForCurrentUser();
    }
    _reconcileAllBalancesInMemory();
    _rebuildIndexes();
    notifyListeners();
  }

  void _loadRawLists() {
    _allAccounts = _storageService.loadMoneyAccounts();
    _allCategories = _storageService.loadMoneyCategories();
    _allTransactions = _storageService.loadMoneyTransactions();
    _allBudgets = _storageService.loadMoneyBudgets();
    _allRecurring = _storageService.loadMoneyRecurring();
    _settings = _loadOrCreateSettings();
  }

  MoneySettings _loadOrCreateSettings() {
    final loaded = _storageService.loadMoneySettings();
    if (loaded.userId == _currentUserId) return loaded;
    return loaded.copyWith(userId: _currentUserId);
  }

  void _ensureDefaultCategoriesSync() {
    final userCats =
        _allCategories.where((c) => c.userId == _currentUserId).toList();
    if (userCats.isEmpty) {
      final defaults = MoneyCategory.defaultsForUser(_currentUserId);
      _allCategories.addAll(defaults);
      _storageService.saveMoneyCategories(_allCategories);
    }
  }

  Future<void> _ensureDefaultCategoriesForCurrentUser() async {
    final userCats =
        _allCategories.where((c) => c.userId == _currentUserId).toList();
    if (userCats.isEmpty) {
      final defaults = MoneyCategory.defaultsForUser(_currentUserId);
      _allCategories.addAll(defaults);
      await _storageService.saveMoneyCategories(_allCategories);
    }
  }

  // --- User-Scoped Getters ---

  List<MoneyAccount> get accounts {
    if (!_isAuthenticated) return const [];
    return _allAccounts
        .where((a) => a.userId == _currentUserId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<MoneyAccount> get activeAccounts =>
      accounts.where((a) => !a.isArchived).toList();

  List<MoneyAccount> get archivedAccounts =>
      accounts.where((a) => a.isArchived).toList();

  int get combinedActiveBalanceMinor => activeAccounts.fold<int>(
      0, (sum, acct) => sum + acct.currentBalanceMinor);

  int get combinedAllAccountsBalanceMinor =>
      accounts.fold<int>(0, (sum, acct) => sum + acct.currentBalanceMinor);

  List<MoneyCategory> get categories {
    if (!_isAuthenticated) return const [];
    return _allCategories
        .where((c) => c.userId == _currentUserId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<MoneyCategory> categoriesByType(MoneyCategoryType type) =>
      categories.where((c) => c.type == type).toList();

  List<MoneyTransaction> get transactions {
    if (!_isAuthenticated) return const [];
    return _allTransactions
        .where((t) => t.userId == _currentUserId && !t.isArchived)
        .toList()
      ..sort((a, b) {
        final dateCmp = b.transactionDate.compareTo(a.transactionDate);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  List<MoneyTransaction> get archivedTransactions {
    if (!_isAuthenticated) return const [];
    return _allTransactions
        .where((t) => t.userId == _currentUserId && t.isArchived)
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
  }

  List<MoneyBudget> get budgets {
    if (!_isAuthenticated) return const [];
    return _allBudgets.where((b) => b.userId == _currentUserId).toList();
  }

  List<RecurringTransaction> get recurringTransactions {
    if (!_isAuthenticated) return const [];
    return _allRecurring
        .where((r) => r.userId == _currentUserId)
        .toList()
      ..sort((a, b) => a.nextOccurrenceDate.compareTo(b.nextOccurrenceDate));
  }

  // --- Period Switching ---

  void setSelectedPeriodMonth(DateTime monthDate) {
    _selectedPeriodMonth = DateTime(monthDate.year, monthDate.month);
    notifyListeners();
  }

  void previousPeriodMonth() {
    final prevMonth = _selectedPeriodMonth.month == 1
        ? DateTime(_selectedPeriodMonth.year - 1, 12)
        : DateTime(_selectedPeriodMonth.year, _selectedPeriodMonth.month - 1);
    setSelectedPeriodMonth(prevMonth);
  }

  void nextPeriodMonth() {
    final nextMonth = _selectedPeriodMonth.month == 12
        ? DateTime(_selectedPeriodMonth.year + 1, 1)
        : DateTime(_selectedPeriodMonth.year, _selectedPeriodMonth.month + 1);
    setSelectedPeriodMonth(nextMonth);
  }

  // --- Authorized Direct Lookups ---

  MoneyAccount requireAccount(String accountId) {
    _assertAuthenticated();
    final acct = _accountById[accountId];
    if (acct == null) {
      // Check if an account with this ID exists under another user
      final foreign = _allAccounts.any((a) => a.id == accountId);
      if (foreign) {
        throw const MoneyAuthorizationException(
            'Unauthorized access to another user\'s account.');
      }
      throw const MoneyValidationException('Selected account was not found.');
    }
    return acct;
  }

  MoneyAccount? findAccountById(String id) {
    if (!_isAuthenticated) return null;
    return _accountById[id];
  }

  MoneyCategory? findCategoryById(String? id) {
    if (!_isAuthenticated || id == null) return null;
    return _categoryById[id];
  }

  MoneyTransaction requireTransaction(String transactionId) {
    _assertAuthenticated();
    final tx = _txById[transactionId];
    if (tx == null) {
      final foreign = _allTransactions.any((t) => t.id == transactionId);
      if (foreign) {
        throw const MoneyAuthorizationException(
            'Unauthorized access to another user\'s transaction.');
      }
      throw const MoneyValidationException('Transaction not found.');
    }
    return tx;
  }

  List<MoneyTransaction> transactionsForAccount(
    String accountId, {
    bool includeArchivedTransactions = false,
  }) {
    requireAccount(accountId);
    final raw = _txByAccount[accountId] ?? const [];
    final list = includeArchivedTransactions
        ? List<MoneyTransaction>.from(raw)
        : raw.where((t) => !t.isArchived).toList();
    list.sort((a, b) {
      final cmp = b.transactionDate.compareTo(a.transactionDate);
      return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  // --- Formatting Helper ---

  String formatAmount(
    int amountMinor, {
    bool showPlusSign = false,
    bool compact = false,
  }) {
    if (compact) {
      return MoneyAmount.formatCompactMinor(
        amountMinor,
        currency: _settings.currency,
      );
    }
    return MoneyAmount.formatMinor(
      amountMinor,
      currency: _settings.currency,
      showPlusSign: showPlusSign,
    );
  }

  // --- Accounts CRUD & Archival ---

  Future<MoneyAccount> createAccount({
    required String name,
    required MoneyAccountType type,
    int initialBalanceMinor = 0,
    String description = '',
    int? iconCodePoint,
    int? colorValue,
  }) async {
    _assertAuthenticated();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const MoneyValidationException('Account name cannot be empty.');
    }
    if (initialBalanceMinor < 0) {
      throw const MoneyValidationException(
          'Initial balance cannot be negative.');
    }
    final duplicate = _allAccounts.any((a) =>
        a.userId == _currentUserId &&
        a.name.toLowerCase() == cleanName.toLowerCase());
    if (duplicate) {
      throw MoneyValidationException(
          'An account named "$cleanName" already exists.');
    }

    final now = DateTime.now();
    final account = MoneyAccount(
      id: 'acct_${const Uuid().v4().substring(0, 12)}',
      userId: _currentUserId,
      name: cleanName,
      type: type,
      initialBalanceMinor: initialBalanceMinor,
      currentBalanceMinor: initialBalanceMinor,
      description: description.trim(),
      iconCodePoint: iconCodePoint ?? type.defaultIcon.codePoint,
      colorValue: colorValue ?? type.defaultColor.toARGB32(),
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    _allAccounts.add(account);
    await _storageService.saveMoneyAccounts(_allAccounts);
    _rebuildIndexes();
    notifyListeners();
    return account;
  }

  Future<MoneyAccount> updateAccount({
    required String accountId,
    required String name,
    required MoneyAccountType type,
    required int initialBalanceMinor,
    String? description,
    int? iconCodePoint,
    int? colorValue,
  }) async {
    final existing = requireAccount(accountId);
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const MoneyValidationException('Account name cannot be empty.');
    }
    if (initialBalanceMinor < 0) {
      throw const MoneyValidationException(
          'Initial balance cannot be negative.');
    }
    final duplicate = _allAccounts.any((a) =>
        a.userId == _currentUserId &&
        a.id != accountId &&
        a.name.toLowerCase() == cleanName.toLowerCase());
    if (duplicate) {
      throw MoneyValidationException(
          'Another account named "$cleanName" already exists.');
    }

    final idx = _allAccounts.indexWhere((a) => a.id == accountId);
    final updated = existing.copyWith(
      name: cleanName,
      type: type,
      initialBalanceMinor: initialBalanceMinor,
      description: description?.trim() ?? existing.description,
      iconCodePoint: iconCodePoint ?? existing.iconCodePoint,
      colorValue: colorValue ?? existing.colorValue,
      updatedAt: DateTime.now(),
    );

    _allAccounts[idx] = updated;
    _reconcileAccountBalance(accountId);
    await _storageService.saveMoneyAccounts(_allAccounts);
    _rebuildIndexes();
    notifyListeners();
    return _accountById[accountId]!;
  }

  Future<void> setAccountArchived(String accountId, bool archived) async {
    final existing = requireAccount(accountId);
    if (existing.isArchived == archived) return;

    final idx = _allAccounts.indexWhere((a) => a.id == accountId);
    _allAccounts[idx] = existing.copyWith(
      isArchived: archived,
      updatedAt: DateTime.now(),
    );
    await _storageService.saveMoneyAccounts(_allAccounts);
    _rebuildIndexes();
    notifyListeners();
  }

  // --- Categories CRUD ---

  Future<MoneyCategory> createCategory({
    required String name,
    required MoneyCategoryType type,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    _assertAuthenticated();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const MoneyValidationException('Category name cannot be empty.');
    }
    final duplicate = _allCategories.any((c) =>
        c.userId == _currentUserId &&
        c.type == type &&
        c.name.toLowerCase() == cleanName.toLowerCase());
    if (duplicate) {
      throw MoneyValidationException(
          'A ${type.label.toLowerCase()} category named "$cleanName" already exists.');
    }

    final now = DateTime.now();
    final category = MoneyCategory(
      id: 'cat_${const Uuid().v4().substring(0, 12)}',
      userId: _currentUserId,
      name: cleanName,
      type: type,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    );

    _allCategories.add(category);
    await _storageService.saveMoneyCategories(_allCategories);
    _rebuildIndexes();
    notifyListeners();
    return category;
  }

  Future<MoneyCategory> updateCategory({
    required String categoryId,
    required String name,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    final existing = _requireCategory(categoryId);
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const MoneyValidationException('Category name cannot be empty.');
    }
    final duplicate = _allCategories.any((c) =>
        c.userId == _currentUserId &&
        c.id != categoryId &&
        c.type == existing.type &&
        c.name.toLowerCase() == cleanName.toLowerCase());
    if (duplicate) {
      throw MoneyValidationException(
          'Another category named "$cleanName" already exists.');
    }

    final idx = _allCategories.indexWhere((c) => c.id == categoryId);
    final updated = existing.copyWith(
      name: cleanName,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      updatedAt: DateTime.now(),
    );
    _allCategories[idx] = updated;
    await _storageService.saveMoneyCategories(_allCategories);
    _rebuildIndexes();
    notifyListeners();
    return updated;
  }

  bool isCategoryInUse(String categoryId) {
    if (!_isAuthenticated) return false;
    final usedInTx = _allTransactions.any(
        (t) => t.userId == _currentUserId && t.categoryId == categoryId);
    final usedInBudgets = _allBudgets.any(
        (b) => b.userId == _currentUserId && b.categoryId == categoryId);
    final usedInRecurring = _allRecurring.any(
        (r) => r.userId == _currentUserId && r.categoryId == categoryId);
    return usedInTx || usedInBudgets || usedInRecurring;
  }

  Future<void> deleteCategory(String categoryId) async {
    _requireCategory(categoryId);
    if (isCategoryInUse(categoryId)) {
      throw const MoneyValidationException(
          'Cannot delete a category referenced by historical transactions, budgets, or recurring templates.');
    }
    _allCategories.removeWhere((c) => c.id == categoryId);
    await _storageService.saveMoneyCategories(_allCategories);
    _rebuildIndexes();
    notifyListeners();
  }

  // --- Transactions CRUD (Income & Expense) ---

  Future<MoneyTransaction> addTransaction({
    required MoneyTransactionType type,
    required int amountMinor,
    required String categoryId,
    required String accountId,
    required DateTime transactionDate,
    String description = '',
    String? recurringTemplateId,
    String? occurrenceKey,
  }) async {
    _assertAuthenticated();
    if (type == MoneyTransactionType.transfer) {
      throw const MoneyValidationException(
          'Use executeTransfer for internal transfers.');
    }
    if (amountMinor <= 0) {
      throw const MoneyValidationException(
          'Transaction amount must be greater than zero.');
    }

    final account = requireAccount(accountId);
    if (account.isArchived) {
      throw const MoneyValidationException(
          'Cannot record new transactions on an archived account.');
    }

    final category = _requireCategory(categoryId);
    if ((type == MoneyTransactionType.income &&
            category.type != MoneyCategoryType.income) ||
        (type == MoneyTransactionType.expense &&
            category.type != MoneyCategoryType.expense)) {
      throw MoneyValidationException(
          'Category "${category.name}" does not match transaction type ${type.label}.');
    }

    if (occurrenceKey != null &&
        _occurrenceKeyIndex.contains(occurrenceKey)) {
      throw const MoneyValidationException(
          'Duplicate occurrence already recorded.');
    }

    final now = DateTime.now();
    final tx = MoneyTransaction(
      id: 'tx_${const Uuid().v4().substring(0, 12)}',
      userId: _currentUserId,
      type: type,
      amountMinor: amountMinor,
      categoryId: categoryId,
      accountId: accountId,
      transactionDate: transactionDate,
      description: description.trim(),
      recurringTemplateId: recurringTemplateId,
      occurrenceKey: occurrenceKey,
      createdAt: now,
      updatedAt: now,
    );

    final snapshotAccounts = List<MoneyAccount>.from(_allAccounts);
    final snapshotTxs = List<MoneyTransaction>.from(_allTransactions);

    try {
      _allTransactions.add(tx);
      _reconcileAccountBalance(accountId);
      await _storageService.commitMoneyLedgerAtomically(
        accounts: _allAccounts,
        transactions: _allTransactions,
      );
      _rebuildIndexes();
      notifyListeners();
      return tx;
    } catch (e) {
      _allAccounts = snapshotAccounts;
      _allTransactions = snapshotTxs;
      _rebuildIndexes();
      rethrow;
    }
  }

  Future<MoneyTransaction> editTransaction({
    required String transactionId,
    MoneyTransactionType? type,
    required int amountMinor,
    String? categoryId,
    required String accountId,
    String? toAccountId,
    required DateTime transactionDate,
    String description = '',
  }) async {
    final existing = requireTransaction(transactionId);
    final nextType = type ?? existing.type;

    if (amountMinor <= 0) {
      throw const MoneyValidationException(
          'Transaction amount must be greater than zero.');
    }

    final sourceAccount = requireAccount(accountId);
    if (accountId != existing.accountId && sourceAccount.isArchived) {
      throw const MoneyValidationException(
          'Cannot move a transaction into an archived account.');
    }

    String? validatedCategoryId = categoryId ?? existing.categoryId;
    String? validatedToAccountId = toAccountId ?? existing.toAccountId;

    if (nextType == MoneyTransactionType.transfer) {
      if (validatedToAccountId == null || validatedToAccountId.isEmpty) {
        throw const MoneyValidationException(
            'Destination account is required for transfers.');
      }
      if (validatedToAccountId == accountId) {
        throw const MoneyValidationException(
            'Cannot transfer money from an account to itself.');
      }
      final dest = requireAccount(validatedToAccountId);
      if (validatedToAccountId != existing.toAccountId && dest.isArchived) {
        throw const MoneyValidationException(
            'Cannot transfer into an archived destination account.');
      }
      validatedCategoryId = null;
    } else {
      if (validatedCategoryId == null || validatedCategoryId.isEmpty) {
        throw const MoneyValidationException('Category is required.');
      }
      final category = _requireCategory(validatedCategoryId);
      if ((nextType == MoneyTransactionType.income &&
              category.type != MoneyCategoryType.income) ||
          (nextType == MoneyTransactionType.expense &&
              category.type != MoneyCategoryType.expense)) {
        throw MoneyValidationException(
            'Category "${category.name}" does not match ${nextType.label}.');
      }
      validatedToAccountId = null;
    }

    final snapshotAccounts = List<MoneyAccount>.from(_allAccounts);
    final snapshotTxs = List<MoneyTransaction>.from(_allTransactions);

    try {
      final idx = _allTransactions.indexWhere((t) => t.id == transactionId);
      final updated = existing.copyWith(
        type: nextType,
        amountMinor: amountMinor,
        categoryId: validatedCategoryId,
        clearCategoryId: nextType == MoneyTransactionType.transfer,
        accountId: accountId,
        toAccountId: validatedToAccountId,
        clearToAccountId: nextType != MoneyTransactionType.transfer,
        transactionDate: transactionDate,
        description: description.trim(),
        updatedAt: DateTime.now(),
      );
      _allTransactions[idx] = updated;

      _reconcileAllBalancesInMemory();
      await _storageService.commitMoneyLedgerAtomically(
        accounts: _allAccounts,
        transactions: _allTransactions,
      );
      _rebuildIndexes();
      notifyListeners();
      return updated;
    } catch (e) {
      _allAccounts = snapshotAccounts;
      _allTransactions = snapshotTxs;
      _rebuildIndexes();
      rethrow;
    }
  }

  /// Removes a transaction (or marks archived) and reverses its balance effect cleanly.
  Future<void> deleteTransaction(
    String transactionId, {
    bool softArchive = false,
  }) async {
    final existing = requireTransaction(transactionId);

    final snapshotAccounts = List<MoneyAccount>.from(_allAccounts);
    final snapshotTxs = List<MoneyTransaction>.from(_allTransactions);

    try {
      if (softArchive) {
        final idx = _allTransactions.indexWhere((t) => t.id == transactionId);
        _allTransactions[idx] = existing.copyWith(
          isArchived: true,
          updatedAt: DateTime.now(),
        );
      } else {
        _allTransactions.removeWhere((t) => t.id == transactionId);
      }

      _reconcileAccountBalance(existing.accountId);
      if (existing.toAccountId != null) {
        _reconcileAccountBalance(existing.toAccountId!);
      }

      await _storageService.commitMoneyLedgerAtomically(
        accounts: _allAccounts,
        transactions: _allTransactions,
      );
      _rebuildIndexes();
      notifyListeners();
    } catch (e) {
      _allAccounts = snapshotAccounts;
      _allTransactions = snapshotTxs;
      _rebuildIndexes();
      rethrow;
    }
  }

  // --- Atomic Internal Transfers ---

  Future<MoneyTransaction> executeTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required DateTime transactionDate,
    String description = '',
    @visibleForTesting void Function(String stage)? failureInjector,
  }) async {
    _assertAuthenticated();
    if (amountMinor <= 0) {
      throw const MoneyValidationException(
          'Transfer amount must be greater than zero.');
    }
    if (fromAccountId == toAccountId) {
      throw const MoneyValidationException(
          'Cannot transfer money from an account to itself.');
    }

    final source = requireAccount(fromAccountId);
    final destination = requireAccount(toAccountId);

    if (source.isArchived || destination.isArchived) {
      throw const MoneyValidationException(
          'Transfers require active (non-archived) accounts.');
    }

    final snapshotAccounts = List<MoneyAccount>.from(_allAccounts);
    final snapshotTxs = List<MoneyTransaction>.from(_allTransactions);

    final now = DateTime.now();
    final transferGroupId = 'trf_${const Uuid().v4().substring(0, 10)}';
    final tx = MoneyTransaction(
      id: 'tx_${const Uuid().v4().substring(0, 12)}',
      userId: _currentUserId,
      type: MoneyTransactionType.transfer,
      amountMinor: amountMinor,
      categoryId: null,
      accountId: fromAccountId,
      toAccountId: toAccountId,
      transferGroupId: transferGroupId,
      transactionDate: transactionDate,
      description: description.trim().isEmpty
          ? '${source.name} -> ${destination.name}'
          : description.trim(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      // Step 1: Record transfer and apply source debit
      final srcIdx = _allAccounts.indexWhere((a) => a.id == fromAccountId);
      final dstIdx = _allAccounts.indexWhere((a) => a.id == toAccountId);
      if (srcIdx == -1 || dstIdx == -1) {
        throw const MoneyIntegrityException('Transfer account lookup failed.');
      }

      _allTransactions.add(tx);
      _allAccounts[srcIdx] = _allAccounts[srcIdx].copyWith(
        currentBalanceMinor:
            _allAccounts[srcIdx].currentBalanceMinor - amountMinor,
        updatedAt: now,
      );

      failureInjector?.call('after_debit');

      // Step 2: Apply destination credit atomically
      _allAccounts[dstIdx] = _allAccounts[dstIdx].copyWith(
        currentBalanceMinor:
            _allAccounts[dstIdx].currentBalanceMinor + amountMinor,
        updatedAt: now,
      );

      failureInjector?.call('after_credit');

      // Re-verify full ledger invariants before commit
      _reconcileAccountBalance(fromAccountId);
      _reconcileAccountBalance(toAccountId);

      await _storageService.commitMoneyLedgerAtomically(
        accounts: _allAccounts,
        transactions: _allTransactions,
      );

      _rebuildIndexes();
      notifyListeners();
      return tx;
    } catch (e) {
      // Atomic rollback of both account balances & transaction list
      _allAccounts = snapshotAccounts;
      _allTransactions = snapshotTxs;
      _rebuildIndexes();
      rethrow;
    }
  }

  // --- Transaction Filtering & Search ---

  List<MoneyTransaction> filterTransactions({
    MoneyTransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String query = '',
  }) {
    if (!_isAuthenticated) return const [];
    final q = query.trim().toLowerCase();
    final startDay = startDate != null
        ? DateTime(startDate.year, startDate.month, startDate.day)
        : null;
    final endDay = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999)
        : null;

    return transactions.where((tx) {
      if (type != null && tx.type != type) return false;
      if (accountId != null && !tx.involvesAccount(accountId)) return false;
      if (categoryId != null && tx.categoryId != categoryId) return false;
      if (startDay != null && tx.transactionDate.isBefore(startDay)) {
        return false;
      }
      if (endDay != null && tx.transactionDate.isAfter(endDay)) {
        return false;
      }
      if (q.isNotEmpty) {
        final descMatch = tx.description.toLowerCase().contains(q);
        final catName = findCategoryById(tx.categoryId)?.name.toLowerCase() ?? '';
        final srcName = findAccountById(tx.accountId)?.name.toLowerCase() ?? '';
        final dstName =
            tx.toAccountId != null
                ? (findAccountById(tx.toAccountId!)?.name.toLowerCase() ?? '')
                : '';
        if (!descMatch &&
            !catName.contains(q) &&
            !srcName.contains(q) &&
            !dstName.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // --- Budgets ---

  Future<MoneyBudget> setMonthlyBudget({
    required int year,
    required int month,
    String? categoryId,
    required int limitMinor,
    int warningThresholdPercent = 80,
    String note = '',
  }) async {
    _assertAuthenticated();
    if (limitMinor <= 0) {
      throw const MoneyValidationException(
          'Budget limit must be greater than zero.');
    }
    if (month < 1 || month > 12) {
      throw const MoneyValidationException('Budget month must be 1..12.');
    }
    if (categoryId != null) {
      final cat = _requireCategory(categoryId);
      if (cat.type != MoneyCategoryType.expense) {
        throw const MoneyValidationException(
            'Budgets can only target expense categories.');
      }
    }

    final existingIdx = _allBudgets.indexWhere((b) =>
        b.userId == _currentUserId &&
        b.year == year &&
        b.month == month &&
        b.categoryId == categoryId);

    final now = DateTime.now();
    late MoneyBudget saved;
    if (existingIdx != -1) {
      saved = _allBudgets[existingIdx].copyWith(
        limitMinor: limitMinor,
        warningThresholdPercent: warningThresholdPercent.clamp(10, 99),
        note: note.trim(),
        updatedAt: now,
      );
      _allBudgets[existingIdx] = saved;
    } else {
      saved = MoneyBudget(
        id: 'bdg_${const Uuid().v4().substring(0, 12)}',
        userId: _currentUserId,
        year: year,
        month: month,
        categoryId: categoryId,
        limitMinor: limitMinor,
        warningThresholdPercent: warningThresholdPercent.clamp(10, 99),
        note: note.trim(),
        createdAt: now,
        updatedAt: now,
      );
      _allBudgets.add(saved);
    }

    await _storageService.saveMoneyBudgets(_allBudgets);
    notifyListeners();
    return saved;
  }

  Future<void> deleteBudget(String budgetId) async {
    _assertAuthenticated();
    final idx = _allBudgets.indexWhere((b) => b.id == budgetId);
    if (idx == -1) return;
    if (_allBudgets[idx].userId != _currentUserId) {
      throw const MoneyAuthorizationException(
          'Unauthorized deletion of another user\'s budget.');
    }
    _allBudgets.removeAt(idx);
    await _storageService.saveMoneyBudgets(_allBudgets);
    notifyListeners();
  }

  MonthlyBudgetOverview budgetOverviewForMonth(int year, int month) {
    if (!_isAuthenticated) {
      return const MonthlyBudgetOverview(overallBudget: null, categoryBudgets: []);
    }

    final monthKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final monthTxs = (_txByMonth[monthKey] ?? const [])
        .where((t) => !t.isArchived && t.type == MoneyTransactionType.expense);

    var totalExpenseMinor = 0;
    final expenseByCategory = <String, int>{};
    for (final tx in monthTxs) {
      totalExpenseMinor += tx.amountMinor;
      if (tx.categoryId != null) {
        expenseByCategory[tx.categoryId!] =
            (expenseByCategory[tx.categoryId!] ?? 0) + tx.amountMinor;
      }
    }

    BudgetUtilizationSummary? overall;
    final categorySummaries = <BudgetUtilizationSummary>[];

    for (final budget in budgets.where((b) => b.year == year && b.month == month)) {
      if (budget.isOverallBudget) {
        overall = BudgetUtilizationSummary.compute(
          budget: budget,
          spentMinor: totalExpenseMinor,
        );
      } else {
        final spent = expenseByCategory[budget.categoryId!] ?? 0;
        categorySummaries.add(BudgetUtilizationSummary.compute(
          budget: budget,
          spentMinor: spent,
        ));
      }
    }

    categorySummaries.sort((a, b) => b.utilizationPercent.compareTo(a.utilizationPercent));

    return MonthlyBudgetOverview(
      overallBudget: overall,
      categoryBudgets: categorySummaries,
    );
  }

  // --- Recurring Transactions (Template + Explicit Confirmation Workflow) ---

  Future<RecurringTransaction> createRecurring({
    required String title,
    required MoneyTransactionType type,
    required int amountMinor,
    required String categoryId,
    required String accountId,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    String description = '',
    bool isActive = true,
  }) async {
    _assertAuthenticated();
    if (title.trim().isEmpty) {
      throw const MoneyValidationException('Recurring title cannot be empty.');
    }
    if (type == MoneyTransactionType.transfer) {
      throw const MoneyValidationException(
          'Recurring templates support income or expense only.');
    }
    if (amountMinor <= 0) {
      throw const MoneyValidationException(
          'Recurring amount must be greater than zero.');
    }
    final acct = requireAccount(accountId);
    if (acct.isArchived) {
      throw const MoneyValidationException(
          'Recurring account cannot be archived.');
    }
    final cat = _requireCategory(categoryId);
    if ((type == MoneyTransactionType.income &&
            cat.type != MoneyCategoryType.income) ||
        (type == MoneyTransactionType.expense &&
            cat.type != MoneyCategoryType.expense)) {
      throw const MoneyValidationException(
          'Recurring category does not match transaction type.');
    }
    final cleanStart = DateTime(startDate.year, startDate.month, startDate.day);
    final cleanEnd =
        endDate != null ? DateTime(endDate.year, endDate.month, endDate.day) : null;
    if (cleanEnd != null && cleanEnd.isBefore(cleanStart)) {
      throw const MoneyValidationException(
          'End date cannot be before start date.');
    }

    final now = DateTime.now();
    final template = RecurringTransaction(
      id: 'rec_${const Uuid().v4().substring(0, 12)}',
      userId: _currentUserId,
      title: title.trim(),
      type: type,
      amountMinor: amountMinor,
      categoryId: categoryId,
      accountId: accountId,
      frequency: frequency,
      startDate: cleanStart,
      endDate: cleanEnd,
      nextOccurrenceDate: cleanStart,
      isActive: isActive,
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
    );

    // IMPORTANT: Never silently modify account balances when defining recurring rules.
    _allRecurring.add(template);
    await _storageService.saveMoneyRecurring(_allRecurring);
    notifyListeners();
    return template;
  }

  Future<void> setRecurringActive(String recurringId, bool active) async {
    final existing = _requireRecurring(recurringId);
    final idx = _allRecurring.indexWhere((r) => r.id == recurringId);
    _allRecurring[idx] = existing.copyWith(
      isActive: active,
      updatedAt: DateTime.now(),
    );
    await _storageService.saveMoneyRecurring(_allRecurring);
    notifyListeners();
  }

  Future<void> deleteRecurring(String recurringId) async {
    _requireRecurring(recurringId);
    _allRecurring.removeWhere((r) => r.id == recurringId);
    await _storageService.saveMoneyRecurring(_allRecurring);
    notifyListeners();
  }

  List<RecurringTransaction> dueRecurringTemplates({DateTime? asOf}) {
    final ref = asOf ?? DateTime.now();
    return recurringTransactions
        .where((r) => r.isDueOnOrBefore(ref))
        .toList();
  }

  /// Explicitly executes one scheduled recurring occurrence, records an actual
  /// transaction, updates account balance atomically, advances next occurrence,
  /// and prevents duplicate execution via `occurrenceKey`.
  Future<MoneyTransaction> executeRecurringOccurrence(
    String recurringId, {
    DateTime? overrideExecutionDate,
  }) async {
    final template = _requireRecurring(recurringId);
    if (!template.isActive) {
      throw const MoneyValidationException(
          'Inactive recurring template cannot be executed.');
    }

    final scheduledDay = DateTime(
      template.nextOccurrenceDate.year,
      template.nextOccurrenceDate.month,
      template.nextOccurrenceDate.day,
    );
    if (template.endDate != null) {
      final endDay = DateTime(
        template.endDate!.year,
        template.endDate!.month,
        template.endDate!.day,
      );
      if (scheduledDay.isAfter(endDay)) {
        throw const MoneyValidationException(
            'Recurring template has passed its end date.');
      }
    }

    final occurrenceKey =
        RecurringTransaction.occurrenceKeyFor(template.id, scheduledDay);
    if (template.hasAlreadyProcessed(scheduledDay) ||
        _occurrenceKeyIndex.contains(occurrenceKey)) {
      throw const MoneyValidationException(
          'This recurring occurrence was already processed.');
    }

    final acct = requireAccount(template.accountId);
    if (acct.isArchived) {
      throw const MoneyValidationException(
          'Target account for recurring template is archived.');
    }
    _requireCategory(template.categoryId);

    final snapshotAccounts = List<MoneyAccount>.from(_allAccounts);
    final snapshotTxs = List<MoneyTransaction>.from(_allTransactions);
    final snapshotRecurring = List<RecurringTransaction>.from(_allRecurring);

    final now = DateTime.now();
    final txDate = overrideExecutionDate ?? scheduledDay;
    final tx = MoneyTransaction(
      id: 'tx_${const Uuid().v4().substring(0, 12)}',
      userId: _currentUserId,
      type: template.type,
      amountMinor: template.amountMinor,
      categoryId: template.categoryId,
      accountId: template.accountId,
      transactionDate: txDate,
      description: template.description.isNotEmpty
          ? '${template.title} • ${template.description}'
          : template.title,
      recurringTemplateId: template.id,
      occurrenceKey: occurrenceKey,
      createdAt: now,
      updatedAt: now,
    );

    final nextDate =
        RecurringTransaction.advanceDate(scheduledDay, template.frequency);
    final exceedsEnd = template.endDate != null &&
        nextDate.isAfter(DateTime(
          template.endDate!.year,
          template.endDate!.month,
          template.endDate!.day,
        ));

    final updatedTemplate = template.copyWith(
      nextOccurrenceDate: nextDate,
      lastProcessedDate: scheduledDay,
      isActive: exceedsEnd ? false : template.isActive,
      processedOccurrenceKeys: [
        ...template.processedOccurrenceKeys,
        occurrenceKey,
      ],
      updatedAt: now,
    );

    try {
      _allTransactions.add(tx);
      final recIdx = _allRecurring.indexWhere((r) => r.id == recurringId);
      _allRecurring[recIdx] = updatedTemplate;
      _reconcileAccountBalance(template.accountId);

      await _storageService.commitMoneyLedgerAtomically(
        accounts: _allAccounts,
        transactions: _allTransactions,
        recurring: _allRecurring,
      );
      _rebuildIndexes();
      notifyListeners();
      return tx;
    } catch (e) {
      _allAccounts = snapshotAccounts;
      _allTransactions = snapshotTxs;
      _allRecurring = snapshotRecurring;
      _rebuildIndexes();
      rethrow;
    }
  }

  Future<void> skipRecurringOccurrence(String recurringId) async {
    final template = _requireRecurring(recurringId);
    final scheduledDay = DateTime(
      template.nextOccurrenceDate.year,
      template.nextOccurrenceDate.month,
      template.nextOccurrenceDate.day,
    );
    final key =
        RecurringTransaction.occurrenceKeyFor(template.id, scheduledDay);
    final nextDate =
        RecurringTransaction.advanceDate(scheduledDay, template.frequency);
    final exceedsEnd = template.endDate != null &&
        nextDate.isAfter(DateTime(
          template.endDate!.year,
          template.endDate!.month,
          template.endDate!.day,
        ));

    final recIdx = _allRecurring.indexWhere((r) => r.id == recurringId);
    _allRecurring[recIdx] = template.copyWith(
      nextOccurrenceDate: nextDate,
      isActive: exceedsEnd ? false : template.isActive,
      processedOccurrenceKeys: template.processedOccurrenceKeys.contains(key)
          ? template.processedOccurrenceKeys
          : [...template.processedOccurrenceKeys, key],
      updatedAt: DateTime.now(),
    );
    await _storageService.saveMoneyRecurring(_allRecurring);
    notifyListeners();
  }

  // --- Financial Summaries & Reports ---

  MoneyPeriodSummary summaryForMonth(int year, int month) {
    if (!_isAuthenticated) {
      return MoneyPeriodSummary(
        year: year,
        month: month,
        totalIncomeMinor: 0,
        totalExpenseMinor: 0,
        netCashFlowMinor: 0,
        internalTransferMinor: 0,
        transactionCount: 0,
      );
    }

    final monthKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final monthTxs = (_txByMonth[monthKey] ?? const [])
        .where((t) => !t.isArchived)
        .toList();

    var incomeMinor = 0;
    var expenseMinor = 0;
    var transferMinor = 0;

    for (final tx in monthTxs) {
      switch (tx.type) {
        case MoneyTransactionType.income:
          incomeMinor += tx.amountMinor;
          break;
        case MoneyTransactionType.expense:
          expenseMinor += tx.amountMinor;
          break;
        case MoneyTransactionType.transfer:
          transferMinor += tx.amountMinor;
          break;
      }
    }

    return MoneyPeriodSummary(
      year: year,
      month: month,
      totalIncomeMinor: incomeMinor,
      totalExpenseMinor: expenseMinor,
      netCashFlowMinor: incomeMinor - expenseMinor,
      internalTransferMinor: transferMinor,
      transactionCount: monthTxs.length,
    );
  }

  List<CategorySpendingBreakdown> expenseBreakdownForMonth(
    int year,
    int month,
  ) {
    if (!_isAuthenticated) return const [];

    final monthKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final expenseTxs = (_txByMonth[monthKey] ?? const []).where(
        (t) => !t.isArchived && t.type == MoneyTransactionType.expense);

    final byCat = <String, int>{};
    var totalExpenseMinor = 0;
    for (final tx in expenseTxs) {
      if (tx.categoryId == null) continue;
      byCat[tx.categoryId!] = (byCat[tx.categoryId!] ?? 0) + tx.amountMinor;
      totalExpenseMinor += tx.amountMinor;
    }

    final rows = <CategorySpendingBreakdown>[];
    byCat.forEach((catId, spentMinor) {
      final cat = findCategoryById(catId);
      if (cat != null) {
        rows.add(
          CategorySpendingBreakdown(
            category: cat,
            spentMinor: spentMinor,
            percentOfExpenses:
                MoneyAmount.percentOf(spentMinor, totalExpenseMinor),
          ),
        );
      }
    });

    rows.sort((a, b) => b.spentMinor.compareTo(a.spentMinor));
    return rows;
  }

  List<MonthlyCashFlowPoint> monthlyCashFlowHistory({
    int monthsCount = 6,
    DateTime? anchorMonth,
  }) {
    if (!_isAuthenticated) return const [];
    final anchor = anchorMonth ?? _selectedPeriodMonth;
    final points = <MonthlyCashFlowPoint>[];
    for (var offset = monthsCount - 1; offset >= 0; offset--) {
      final d = DateTime(anchor.year, anchor.month - offset);
      final s = summaryForMonth(d.year, d.month);
      points.add(
        MonthlyCashFlowPoint(
          year: d.year,
          month: d.month,
          incomeMinor: s.totalIncomeMinor,
          expenseMinor: s.totalExpenseMinor,
        ),
      );
    }
    return points;
  }

  // --- Internal Validation, Reconciliation & Index Builders ---

  void _assertAuthenticated() {
    if (!_isAuthenticated || _currentUserId.trim().isEmpty) {
      throw const MoneyAuthorizationException(
          'Authentication required for financial operations.');
    }
  }

  MoneyCategory _requireCategory(String categoryId) {
    _assertAuthenticated();
    final cat = _categoryById[categoryId];
    if (cat == null) {
      final foreign = _allCategories.any((c) => c.id == categoryId);
      if (foreign) {
        throw const MoneyAuthorizationException(
            'Unauthorized access to another user\'s category.');
      }
      throw const MoneyValidationException('Selected category does not exist.');
    }
    return cat;
  }

  RecurringTransaction _requireRecurring(String recurringId) {
    _assertAuthenticated();
    final idx = _allRecurring.indexWhere((r) => r.id == recurringId);
    if (idx == -1) {
      throw const MoneyValidationException('Recurring rule not found.');
    }
    final rec = _allRecurring[idx];
    if (rec.userId != _currentUserId) {
      throw const MoneyAuthorizationException(
          'Unauthorized access to another user\'s recurring transaction.');
    }
    return rec;
  }

  void _reconcileAllBalancesInMemory() {
    for (var i = 0; i < _allAccounts.length; i++) {
      _reconcileAccountBalance(_allAccounts[i].id);
    }
  }

  void _reconcileAccountBalance(String accountId) {
    final idx = _allAccounts.indexWhere((a) => a.id == accountId);
    if (idx == -1) return;
    final acct = _allAccounts[idx];
    var balanceMinor = acct.initialBalanceMinor;

    for (final tx in _allTransactions) {
      if (tx.userId != acct.userId || tx.isArchived) continue;
      switch (tx.type) {
        case MoneyTransactionType.income:
          if (tx.accountId == acct.id) balanceMinor += tx.amountMinor;
          break;
        case MoneyTransactionType.expense:
          if (tx.accountId == acct.id) balanceMinor -= tx.amountMinor;
          break;
        case MoneyTransactionType.transfer:
          if (tx.accountId == acct.id) balanceMinor -= tx.amountMinor;
          if (tx.toAccountId == acct.id) balanceMinor += tx.amountMinor;
          break;
      }
    }

    if (acct.currentBalanceMinor != balanceMinor) {
      _allAccounts[idx] = acct.copyWith(currentBalanceMinor: balanceMinor);
    }
  }

  void _rebuildIndexes() {
    _accountById.clear();
    _categoryById.clear();
    _txById.clear();
    _txByAccount.clear();
    _txByCategory.clear();
    _txByMonth.clear();
    _occurrenceKeyIndex.clear();

    if (!_isAuthenticated) return;

    for (final acct in _allAccounts) {
      if (acct.userId == _currentUserId) {
        _accountById[acct.id] = acct;
      }
    }

    for (final cat in _allCategories) {
      if (cat.userId == _currentUserId) {
        _categoryById[cat.id] = cat;
      }
    }

    for (final tx in _allTransactions) {
      if (tx.userId != _currentUserId) continue;
      _txById[tx.id] = tx;
      _txByAccount.putIfAbsent(tx.accountId, () => []).add(tx);
      if (tx.toAccountId != null && tx.toAccountId != tx.accountId) {
        _txByAccount.putIfAbsent(tx.toAccountId!, () => []).add(tx);
      }
      if (tx.categoryId != null) {
        _txByCategory.putIfAbsent(tx.categoryId!, () => []).add(tx);
      }
      _txByMonth.putIfAbsent(tx.monthKey, () => []).add(tx);
      if (tx.occurrenceKey != null) {
        _occurrenceKeyIndex.add(tx.occurrenceKey!);
      }
    }
  }
}
