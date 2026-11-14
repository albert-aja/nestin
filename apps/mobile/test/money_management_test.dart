import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/dashboard_config.dart';
import 'package:nestin/data/models/money_account.dart';
import 'package:nestin/data/models/money_budget.dart';
import 'package:nestin/data/models/money_category.dart';
import 'package:nestin/data/models/money_transaction.dart';
import 'package:nestin/data/models/recurring_transaction.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/domain/money/money_amount.dart';
import 'package:nestin/domain/money/money_reports.dart';
import 'package:nestin/providers/dashboard_provider.dart';
import 'package:nestin/providers/money_provider.dart';
import 'package:nestin/providers/settings_provider.dart';
import 'package:nestin/ui/screens/organize/money/money_hub_screen.dart';
import 'package:nestin/ui/widgets/money_summary_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exact Decimal Arithmetic (MoneyAmount)', () {
    test('Parses integer and decimal strings strictly without float drift', () {
      expect(MoneyAmount.tryParseToMinor('2000000'), equals(200000000));
      expect(MoneyAmount.tryParseToMinor('2,000,000'), equals(200000000));
      expect(MoneyAmount.tryParseToMinor('2.000.000'), equals(200000000));
      expect(MoneyAmount.tryParseToMinor('12.50'), equals(1250));
      expect(MoneyAmount.tryParseToMinor('12,5'), equals(1250));
      expect(MoneyAmount.tryParseToMinor('0'), equals(0));
      expect(MoneyAmount.tryParseToMinor('-50'), isNull);
      expect(MoneyAmount.tryParseToMinor('abc'), isNull);
    });

    test('Formats IDR & USD cleanly from minor units', () {
      expect(
        MoneyAmount.formatMinor(200000000, currency: MoneyCurrency.idr),
        equals('Rp2,000,000'),
      );
      expect(
        MoneyAmount.formatMinor(-75000000, currency: MoneyCurrency.idr),
        equals('-Rp750,000'),
      );
      expect(
        MoneyAmount.formatMinor(1250, currency: MoneyCurrency.usd),
        equals(r'$12.50'),
      );
      expect(
        MoneyAmount.formatMinor(1500, currency: MoneyCurrency.usd, showPlusSign: true),
        equals(r'+$15'),
      );
    });
  });

  group('Accounts, Categories & Balances', () {
    late StorageService storage;
    late MoneyProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      provider = MoneyProvider(storage);
    });

    test('Seeds suggested income & expense categories for new user', () {
      final incNames = provider
          .categoriesByType(MoneyCategoryType.income)
          .map((c) => c.name)
          .toList();
      final expNames = provider
          .categoriesByType(MoneyCategoryType.expense)
          .map((c) => c.name)
          .toList();

      expect(incNames, containsAll(['Salary', 'Business Income', 'Freelance', 'Other Income']));
      expect(expNames, containsAll(['Food & Drinks', 'Transportation', 'Housing', 'Subscriptions']));
    });

    test('Initial balance is separate from income & updates properly on archival', () async {
      final wallet = await provider.createAccount(
        name: 'Daily Cash',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 50000000, // Rp500,000
      );
      final bank = await provider.createAccount(
        name: 'Main Bank',
        type: MoneyAccountType.bankAccount,
        initialBalanceMinor: 150000000, // Rp1,500,000
      );

      expect(provider.combinedActiveBalanceMinor, equals(200000000));

      // Initial balance MUST NOT appear as transaction income in reports
      final now = DateTime.now();
      final summary = provider.summaryForMonth(now.year, now.month);
      expect(summary.totalIncomeMinor, equals(0));
      expect(summary.totalExpenseMinor, equals(0));

      // Prevent duplicate account names
      await expectLater(
        () => provider.createAccount(
          name: 'daily cash',
          type: MoneyAccountType.cash,
        ),
        throwsA(isA<MoneyValidationException>()),
      );

      // Update initial balance recalculates current balance
      await provider.updateAccount(
        accountId: wallet.id,
        name: 'Daily Cash',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 75000000,
      );
      expect(
        provider.findAccountById(wallet.id)?.currentBalanceMinor,
        equals(75000000),
      );
      expect(provider.combinedActiveBalanceMinor, equals(225000000));

      // Archive bank account -> excluded from active balance & blocks new entries
      await provider.setAccountArchived(bank.id, true);
      expect(provider.combinedActiveBalanceMinor, equals(75000000));

      final foodCat = provider
          .categoriesByType(MoneyCategoryType.expense)
          .firstWhere((c) => c.name == 'Food & Drinks');
      await expectLater(
        () => provider.addTransaction(
          type: MoneyTransactionType.expense,
          amountMinor: 2500000,
          categoryId: foodCat.id,
          accountId: bank.id,
          transactionDate: now,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
    });

    test('Protects categories in use from deletion while allowing custom CRUD', () async {
      final acct = await provider.createAccount(
        name: 'E-Wallet',
        type: MoneyAccountType.eWallet,
        initialBalanceMinor: 20000000,
      );
      final coffeeCat = await provider.createCategory(
        name: 'Coffee & Snacks',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.restaurant_rounded.codePoint,
        colorValue: 0xFFF59E0B,
      );
      final unusedCat = await provider.createCategory(
        name: 'Unused Cat',
        type: MoneyCategoryType.expense,
        iconCodePoint: Icons.more_horiz_rounded.codePoint,
        colorValue: 0xFF6B7280,
      );

      await provider.addTransaction(
        type: MoneyTransactionType.expense,
        amountMinor: 3500000,
        categoryId: coffeeCat.id,
        accountId: acct.id,
        transactionDate: DateTime.now(),
        description: 'Morning latte',
      );

      // Protected because historical transaction references it
      await expectLater(
        () => provider.deleteCategory(coffeeCat.id),
        throwsA(isA<MoneyValidationException>()),
      );

      // Rename still succeeds safely
      await provider.updateCategory(
        categoryId: coffeeCat.id,
        name: 'Cafe & Snacks',
        iconCodePoint: coffeeCat.iconCodePoint,
        colorValue: coffeeCat.colorValue,
      );
      expect(provider.findCategoryById(coffeeCat.id)?.name, equals('Cafe & Snacks'));

      // Unused category can be deleted cleanly
      await provider.deleteCategory(unusedCat.id);
      expect(provider.findCategoryById(unusedCat.id), isNull);
    });
  });

  group('Transactions & Balance Consistency', () {
    late StorageService storage;
    late MoneyProvider provider;
    late MoneyAccount wallet;
    late MoneyAccount bank;
    late MoneyCategory salaryCat;
    late MoneyCategory foodCat;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      provider = MoneyProvider(storage);
      wallet = await provider.createAccount(
        name: 'Cash',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 10000000, // Rp100,000
      );
      bank = await provider.createAccount(
        name: 'Bank',
        type: MoneyAccountType.bankAccount,
        initialBalanceMinor: 50000000, // Rp500,000
      );
      salaryCat = provider
          .categoriesByType(MoneyCategoryType.income)
          .firstWhere((c) => c.name == 'Salary');
      foodCat = provider
          .categoriesByType(MoneyCategoryType.expense)
          .firstWhere((c) => c.name == 'Food & Drinks');
    });

    test('Creates income & expenses, rejects invalid amounts and mismatched categories', () async {
      final now = DateTime.now();

      await expectLater(
        () => provider.addTransaction(
          type: MoneyTransactionType.expense,
          amountMinor: 0,
          categoryId: foodCat.id,
          accountId: wallet.id,
          transactionDate: now,
        ),
        throwsA(isA<MoneyValidationException>()),
      );

      await expectLater(
        () => provider.addTransaction(
          type: MoneyTransactionType.income,
          amountMinor: 10000,
          categoryId: foodCat.id, // mismatch: expense cat for income tx
          accountId: wallet.id,
          transactionDate: now,
        ),
        throwsA(isA<MoneyValidationException>()),
      );

      await provider.addTransaction(
        type: MoneyTransactionType.income,
        amountMinor: 300000000, // +Rp3,000,000
        categoryId: salaryCat.id,
        accountId: bank.id,
        transactionDate: now,
        description: 'Monthly salary',
      );
      await provider.addTransaction(
        type: MoneyTransactionType.expense,
        amountMinor: 4000000, // -Rp40,000
        categoryId: foodCat.id,
        accountId: wallet.id,
        transactionDate: now,
        description: 'Lunch bowl',
      );

      expect(
        provider.findAccountById(bank.id)?.currentBalanceMinor,
        equals(350000000),
      );
      expect(
        provider.findAccountById(wallet.id)?.currentBalanceMinor,
        equals(6000000),
      );

      final summary = provider.summaryForMonth(now.year, now.month);
      expect(summary.totalIncomeMinor, equals(300000000));
      expect(summary.totalExpenseMinor, equals(4000000));
      expect(summary.netCashFlowMinor, equals(296000000));
    });

    test('Editing, moving between accounts, deleting, and backdating update balances & periods', () async {
      final backdated = DateTime(2025, 8, 15);
      final tx = await provider.addTransaction(
        type: MoneyTransactionType.expense,
        amountMinor: 5000000, // Rp50,000
        categoryId: foodCat.id,
        accountId: wallet.id,
        transactionDate: backdated,
        description: 'Backdated dinner',
      );

      expect(provider.findAccountById(wallet.id)?.currentBalanceMinor, equals(5000000));
      expect(provider.summaryForMonth(2025, 8).totalExpenseMinor, equals(5000000));

      // Edit transaction amount & move from Cash to Bank
      await provider.editTransaction(
        transactionId: tx.id,
        amountMinor: 12000000, // Rp120,000
        categoryId: foodCat.id,
        accountId: bank.id,
        transactionDate: backdated,
        description: 'Edited dinner',
      );

      expect(provider.findAccountById(wallet.id)?.currentBalanceMinor, equals(10000000)); // restored
      expect(provider.findAccountById(bank.id)?.currentBalanceMinor, equals(38000000)); // 500k - 120k
      expect(provider.summaryForMonth(2025, 8).totalExpenseMinor, equals(12000000));

      // Archive original account -> historical record still preserved & visible
      await provider.setAccountArchived(bank.id, true);
      expect(provider.transactionsForAccount(bank.id).length, equals(1));

      // Remove transaction -> reverses financial effect even cleanly on account
      await provider.deleteTransaction(tx.id);
      expect(provider.findAccountById(bank.id)?.currentBalanceMinor, equals(50000000));
      expect(provider.summaryForMonth(2025, 8).totalExpenseMinor, equals(0));
    });
  });

  group('Internal Transfers & Atomic Rollback', () {
    late StorageService storage;
    late MoneyProvider provider;
    late MoneyAccount bank;
    late MoneyAccount ewallet;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      provider = MoneyProvider(storage);
      bank = await provider.createAccount(
        name: 'Bank A',
        type: MoneyAccountType.bankAccount,
        initialBalanceMinor: 100000000, // Rp1,000,000
      );
      ewallet = await provider.createAccount(
        name: 'E-Wallet B',
        type: MoneyAccountType.eWallet,
        initialBalanceMinor: 25000000, // Rp250,000
      );
    });

    test('Transfers shift money cleanly without counting as income or expense', () async {
      final now = DateTime.now();
      final transferTx = await provider.executeTransfer(
        fromAccountId: bank.id,
        toAccountId: ewallet.id,
        amountMinor: 30000000, // Rp300,000
        transactionDate: now,
        description: 'Top up e-wallet',
      );

      expect(transferTx.transferGroupId, isNotNull);
      expect(
        provider.findAccountById(bank.id)?.currentBalanceMinor,
        equals(70000000),
      );
      expect(
        provider.findAccountById(ewallet.id)?.currentBalanceMinor,
        equals(55000000),
      );
      expect(provider.combinedActiveBalanceMinor, equals(125000000));

      final summary = provider.summaryForMonth(now.year, now.month);
      expect(summary.totalIncomeMinor, equals(0));
      expect(summary.totalExpenseMinor, equals(0));
      expect(summary.internalTransferMinor, equals(30000000));
    });

    test('Rejects same-account or invalid transfers and rolls back atomically on midpoint failure', () async {
      final now = DateTime.now();

      await expectLater(
        () => provider.executeTransfer(
          fromAccountId: bank.id,
          toAccountId: bank.id,
          amountMinor: 1000000,
          transactionDate: now,
        ),
        throwsA(isA<MoneyValidationException>()),
      );

      await expectLater(
        () => provider.executeTransfer(
          fromAccountId: bank.id,
          toAccountId: ewallet.id,
          amountMinor: 0,
          transactionDate: now,
        ),
        throwsA(isA<MoneyValidationException>()),
      );

      // Simulate crash right after debiting source before crediting destination
      await expectLater(
        () => provider.executeTransfer(
          fromAccountId: bank.id,
          toAccountId: ewallet.id,
          amountMinor: 40000000,
          transactionDate: now,
          failureInjector: (stage) {
            if (stage == 'after_debit') {
              throw StateError('Simulated power loss after debit');
            }
          },
        ),
        throwsA(isA<StateError>()),
      );

      // Verify full atomic rollback: neither balance modified, zero transfer written!
      expect(
        provider.findAccountById(bank.id)?.currentBalanceMinor,
        equals(100000000),
      );
      expect(
        provider.findAccountById(ewallet.id)?.currentBalanceMinor,
        equals(25000000),
      );
      expect(provider.transactions, isEmpty);

      // Also verify persisted storage matches rolled-back state cleanly
      await provider.reloadFromStorage();
      expect(
        provider.findAccountById(bank.id)?.currentBalanceMinor,
        equals(100000000),
      );
      expect(provider.transactions, isEmpty);
    });
  });

  group('Monthly Budgets & Utilization', () {
    late StorageService storage;
    late MoneyProvider provider;
    late MoneyAccount cash;
    late MoneyAccount bank;
    late MoneyCategory foodCat;
    late MoneyCategory salaryCat;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      provider = MoneyProvider(storage);
      cash = await provider.createAccount(
        name: 'Cash',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 500000000,
      );
      bank = await provider.createAccount(
        name: 'Bank',
        type: MoneyAccountType.bankAccount,
        initialBalanceMinor: 500000000,
      );
      foodCat = provider
          .categoriesByType(MoneyCategoryType.expense)
          .firstWhere((c) => c.name == 'Food & Drinks');
      salaryCat = provider
          .categoriesByType(MoneyCategoryType.income)
          .firstWhere((c) => c.name == 'Salary');
    });

    test('Computes utilization strictly from expenses, flags near-limit & exceeded', () async {
      await provider.setMonthlyBudget(
        year: 2026,
        month: 11,
        categoryId: foodCat.id,
        limitMinor: 200000000, // Rp2,000,000
      );
      await provider.setMonthlyBudget(
        year: 2026,
        month: 11,
        limitMinor: 300000000, // Overall Rp3,000,000
      );

      // Income and transfers must NEVER count toward budget spent
      await provider.addTransaction(
        type: MoneyTransactionType.income,
        amountMinor: 500000000,
        categoryId: salaryCat.id,
        accountId: bank.id,
        transactionDate: DateTime(2026, 11, 2),
      );
      await provider.executeTransfer(
        fromAccountId: bank.id,
        toAccountId: cash.id,
        amountMinor: 100000000,
        transactionDate: DateTime(2026, 11, 3),
      );

      // Spend Rp1,250,000 on Food (62% -> healthy, Rp750,000 remaining)
      await provider.addTransaction(
        type: MoneyTransactionType.expense,
        amountMinor: 125000000,
        categoryId: foodCat.id,
        accountId: cash.id,
        transactionDate: DateTime(2026, 11, 5),
      );

      var ov = provider.budgetOverviewForMonth(2026, 11);
      final foodSummary = ov.categoryBudgets.first;
      expect(foodSummary.spentMinor, equals(125000000));
      expect(foodSummary.remainingMinor, equals(75000000));
      expect(foodSummary.utilizationPercent, equals(62));
      expect(foodSummary.status, equals(BudgetHealthStatus.healthy));

      // Add Rp400,000 -> 1,650,000 (82% >= 80% warning)
      await provider.addTransaction(
        type: MoneyTransactionType.expense,
        amountMinor: 40000000,
        categoryId: foodCat.id,
        accountId: cash.id,
        transactionDate: DateTime(2026, 11, 10),
      );
      ov = provider.budgetOverviewForMonth(2026, 11);
      expect(ov.categoryBudgets.first.status, equals(BudgetHealthStatus.nearLimit));

      // Add Rp500,000 -> 2,150,000 (107% -> exceeded, remaining -Rp150,000)
      await provider.addTransaction(
        type: MoneyTransactionType.expense,
        amountMinor: 50000000,
        categoryId: foodCat.id,
        accountId: cash.id,
        transactionDate: DateTime(2026, 11, 14),
      );
      ov = provider.budgetOverviewForMonth(2026, 11);
      expect(ov.categoryBudgets.first.status, equals(BudgetHealthStatus.exceeded));
      expect(ov.categoryBudgets.first.remainingMinor, equals(-15000000));
      expect(ov.overallBudget?.spentMinor, equals(215000000));
    });
  });

  group('Recurring Transactions & Duplicate Prevention', () {
    late StorageService storage;
    late MoneyProvider provider;
    late MoneyAccount bank;
    late MoneyCategory utilCat;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      provider = MoneyProvider(storage);
      bank = await provider.createAccount(
        name: 'Main Bank',
        type: MoneyAccountType.bankAccount,
        initialBalanceMinor: 100000000,
      );
      utilCat = provider
          .categoriesByType(MoneyCategoryType.expense)
          .firstWhere((c) => c.name == 'Utilities');
    });

    test('Schedules monthly anchor safely without silently changing balance & blocks duplicates', () async {
      final start = DateTime(2026, 1, 31);
      final rec = await provider.createRecurring(
        title: 'Internet Bill',
        type: MoneyTransactionType.expense,
        amountMinor: 35000000, // Rp350,000
        categoryId: utilCat.id,
        accountId: bank.id,
        frequency: RecurrenceFrequency.monthly,
        startDate: start,
        endDate: DateTime(2026, 3, 15),
      );

      // Creating template MUST NOT change balance
      expect(
        provider.findAccountById(bank.id)?.currentBalanceMinor,
        equals(100000000),
      );
      expect(provider.transactions, isEmpty);

      // Execute confirmed occurrence #1 -> Jan 31 -> clamps Feb to 28!
      await provider.executeRecurringOccurrence(rec.id);
      expect(
        provider.findAccountById(bank.id)?.currentBalanceMinor,
        equals(65000000),
      );
      final afterFirst =
          provider.recurringTransactions.firstWhere((r) => r.id == rec.id);
      expect(afterFirst.nextOccurrenceDate, equals(DateTime(2026, 2, 28)));

      // Trying to insert a transaction manually with same occurrenceKey fails
      await expectLater(
        () => provider.addTransaction(
          type: MoneyTransactionType.expense,
          amountMinor: 35000000,
          categoryId: utilCat.id,
          accountId: bank.id,
          transactionDate: DateTime(2026, 1, 31),
          occurrenceKey:
              RecurringTransaction.occurrenceKeyFor(rec.id, DateTime(2026, 1, 31)),
        ),
        throwsA(isA<MoneyValidationException>()),
      );

      // Execute occurrence #2 (Feb 28 -> next becomes Mar 28 > endDate Mar 15, so auto-deactivates)
      await provider.executeRecurringOccurrence(rec.id);
      final afterSecond =
          provider.recurringTransactions.firstWhere((r) => r.id == rec.id);
      expect(afterSecond.isActive, isFalse);

      // Executing inactive template fails cleanly
      await expectLater(
        () => provider.executeRecurringOccurrence(rec.id),
        throwsA(isA<MoneyValidationException>()),
      );
    });
  });

  group('Security Isolation, Authorization, Backup & Migrations', () {
    test('Isolates user ledgers and enforces authorization on foreign records', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final provider = MoneyProvider(storage, currentUserId: 'user_alice');

      final aliceAcct = await provider.createAccount(
        name: 'Alice Vault',
        type: MoneyAccountType.bankAccount,
        initialBalanceMinor: 100000000,
      );
      final aliceCat = provider
          .categoriesByType(MoneyCategoryType.expense)
          .first;
      final aliceTx = await provider.addTransaction(
        type: MoneyTransactionType.expense,
        amountMinor: 5000000,
        categoryId: aliceCat.id,
        accountId: aliceAcct.id,
        transactionDate: DateTime.now(),
        description: 'Alice private item',
      );

      // Switch to User Bob
      await provider.setSessionUser(userId: 'user_bob', authenticated: true);
      expect(provider.accounts, isEmpty);
      expect(provider.transactions, isEmpty);

      final bobAcct = await provider.createAccount(
        name: 'Bob Wallet',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 20000000,
      );

      // Bob CANNOT read or mutate Alice's account, transaction, or category
      expect(
        () => provider.requireAccount(aliceAcct.id),
        throwsA(isA<MoneyAuthorizationException>()),
      );
      await expectLater(
        () => provider.editTransaction(
          transactionId: aliceTx.id,
          amountMinor: 100,
          accountId: bobAcct.id,
          transactionDate: DateTime.now(),
        ),
        throwsA(isA<MoneyAuthorizationException>()),
      );
      await expectLater(
        () => provider.executeTransfer(
          fromAccountId: bobAcct.id,
          toAccountId: aliceAcct.id,
          amountMinor: 1000000,
          transactionDate: DateTime.now(),
        ),
        throwsA(isA<MoneyAuthorizationException>()),
      );

      // Unauthenticated session rejects writes and hides reads
      await provider.setSessionUser(userId: 'user_bob', authenticated: false);
      expect(provider.accounts, isEmpty);
      await expectLater(
        () => provider.createAccount(
          name: 'Rogue',
          type: MoneyAccountType.cash,
        ),
        throwsA(isA<MoneyAuthorizationException>()),
      );

      // Switching back to Alice shows her records remained untouched
      await provider.setSessionUser(userId: 'user_alice', authenticated: true);
      expect(provider.accounts.length, equals(1));
      expect(
        provider.findAccountById(aliceAcct.id)?.currentBalanceMinor,
        equals(95000000),
      );
    });

    test('Backup export/restore, schema migration & DashboardConfig section integration work', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.migrateMoneySchemaIfNeeded();
      expect(storage.moneySchemaVersion, equals(1));

      final dash = DashboardProvider(storage);
      expect(dash.config.sectionOrder, contains(DashboardConfig.sectionMoney));
      await dash.toggleMoney(false);
      expect(storage.loadDashboardConfig().showMoney, isFalse);

      final provider = MoneyProvider(storage);
      final acct = await provider.createAccount(
        name: 'Travel Cash',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 40000000,
      );
      final food = provider
          .categoriesByType(MoneyCategoryType.expense)
          .firstWhere((c) => c.name == 'Food & Drinks');
      await provider.addTransaction(
        type: MoneyTransactionType.expense,
        amountMinor: 5000000,
        categoryId: food.id,
        accountId: acct.id,
        transactionDate: DateTime(2026, 11, 10),
        description: 'Airport snack',
      );
      await provider.setMonthlyBudget(
        year: 2026,
        month: 11,
        categoryId: food.id,
        limitMinor: 50000000,
      );

      final backupJson = storage.exportFullBackupJson();

      // Fresh wipe & restore
      SharedPreferences.setMockInitialValues({});
      final wipedStorage = await StorageService.init();
      expect(await wipedStorage.restoreFullBackupJson(backupJson), isTrue);

      final revived = MoneyProvider(wipedStorage);
      expect(revived.accounts.length, equals(1));
      expect(revived.accounts.first.currentBalanceMinor, equals(35000000));
      expect(revived.transactions.length, equals(1));
      expect(revived.budgets.length, equals(1));
    });
  });

  group('Twill Money UI Widget Tests', () {
    testWidgets('MoneySummaryCard and MoneyHubScreen render empty state & navigate 6 views cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final moneyProvider = MoneyProvider(storage);
      final settingsProvider = SettingsProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MoneyProvider>.value(value: moneyProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  MoneySummaryCard(isCompact: true),
                  Expanded(child: MoneyHubScreen()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state visible for new user
      expect(find.text('Twill Money Manager'), findsOneWidget);
      expect(find.text('Welcome to Twill Money'), findsOneWidget);
      expect(find.text('Create First Account'), findsOneWidget);

      // Switch across all 6 Money sections cleanly with zero overflow errors
      for (final label in [
        'Transactions',
        'Accounts',
        'Budgets',
        'Recurring',
        'Reports',
        'Overview',
      ]) {
        final tabFinder = find.text(label).first;
        await tester.ensureVisible(tabFinder);
        await tester.tap(tabFinder);
        await tester.pumpAndSettle();
      }

      // Create an account and confirm balance updates visually
      await moneyProvider.createAccount(
        name: 'Pocket Cash',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 15000000, // Rp150,000
      );
      await tester.pumpAndSettle();

      expect(find.text('Rp150,000'), findsWidgets);
      expect(find.text('Welcome to Twill Money'), findsNothing);
    });
  });
}
