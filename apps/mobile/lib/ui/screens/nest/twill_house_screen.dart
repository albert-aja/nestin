import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/money_transaction.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/money_provider.dart';
import '../../../providers/note_provider.dart';
import '../../widgets/money/money_editor_dialogs.dart';
import '../organize/collections_list_screen.dart';
import '../organize/money/money_hub_screen.dart';
import '../organize/notes_list_screen.dart';
import '../organize/wishlist_screen.dart';
import 'bird_house_shared.dart';

/// Twill's House — Notes, Lists & Packing, Wishlist & Offline Personal Money (`#F59E0B`).
///
/// Unified into the standard 1 Hero + 2×2 Tool Grid architecture shared across
/// all 6 Bird Houses. All money copy is strictly personal and offline/non-banking.
class TwillHouseScreen extends StatelessWidget {
  static const Color twillColor = AppColors.twill;

  /// Retained for backward compatibility with legacy callers.
  final int initialTabIndex;

  const TwillHouseScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = tryWatchProvider<MoneyProvider>(context);
    final notes = tryWatchProvider<NoteProvider>(context);
    final collections = tryWatchProvider<CollectionProvider>(context);

    final activeNotesCount = notes?.activeNotes.length ?? 0;
    final pinnedNotesCount = notes?.pinnedNotes.length ?? 0;
    final activeListsCount = collections?.collections.length ?? 0;
    final pendingWishlistCount = collections != null
        ? collections.wishlist.where((item) => !item.isPurchased).length
        : 0;
    final activeAccountsCount = money?.activeAccounts.length ?? 0;
    final activeBudgetsCount = money?.budgets.length ?? 0;

    return Scaffold(
      key: const Key('twill_house_screen'),
      appBar: buildBirdHouseAppBar(
        context,
        title: l10n.tr('house_twill_title'),
        subtitle: l10n.tr('nest_twill_subtitle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildMoneyHeroCard(context, l10n: l10n, money: money),
          const SizedBox(height: 20),
          BirdSectionLabel(
            text: l10n.tr('house_tools_section'),
            accentColor: twillColor,
          ),
          BirdToolGrid(
            tiles: [
              BirdToolTile(
                tileKey: const Key('twill_tool_notes'),
                title: l10n.tr('tab_notes'),
                subtitle: l10n.tr('house_twill_notes_sub', {
                  'active': activeNotesCount,
                  'pinned': pinnedNotesCount,
                }),
                icon: Icons.notes_rounded,
                accentColor: twillColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BirdToolPageScaffold(
                      title: l10n.tr('tab_notes'),
                      child: const NotesListScreen(),
                    ),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('twill_tool_lists'),
                title: l10n.tr('house_twill_lists_title'),
                subtitle: l10n.tr('house_twill_lists_sub', {
                  'count': activeListsCount,
                }),
                icon: Icons.list_alt_rounded,
                accentColor: AppColors.skyMid,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BirdToolPageScaffold(
                      title: l10n.tr('house_twill_lists_title'),
                      child: const CollectionsListScreen(),
                    ),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('twill_tool_wishlist'),
                title: l10n.tr('tab_wishlist'),
                subtitle: l10n.tr('house_twill_wishlist_sub', {
                  'count': pendingWishlistCount,
                }),
                icon: Icons.card_giftcard_rounded,
                accentColor: AppColors.pink,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BirdToolPageScaffold(
                      title: l10n.tr('tab_wishlist'),
                      child: const WishlistScreen(),
                    ),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('twill_tool_money'),
                title: l10n.tr('house_twill_money_title'),
                subtitle: l10n.tr('house_twill_money_sub', {
                  'accounts': activeAccountsCount,
                  'budgets': activeBudgetsCount,
                }),
                icon: Icons.account_balance_wallet_rounded,
                accentColor: AppColors.success,
                onTap: () => MoneyHubScreen.push(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyHeroCard(
    BuildContext context, {
    required AppLocalizations l10n,
    required MoneyProvider? money,
  }) {
    final isDark = AppColors.isDark(context);
    final now = DateTime.now();
    final isPinLocked = money != null &&
        money.settings.requirePinForMoney &&
        !money.isPinUnlocked;
    final summary = money?.summaryForMonth(now.year, now.month);

    final balanceDisplay = isPinLocked
        ? '••••••'
        : (money != null
            ? money.formatAmount(money.combinedActiveBalanceMinor)
            : '0');

    final incomeDisplay = isPinLocked
        ? '••••'
        : (money != null && summary != null
            ? money.formatAmount(summary.totalIncomeMinor, compact: true)
            : '0');

    final expenseDisplay = isPinLocked
        ? '••••'
        : (money != null && summary != null
            ? money.formatAmount(summary.totalExpenseMinor, compact: true)
            : '0');

    return Container(
      key: const Key('twill_house_hero_card'),
      padding: const EdgeInsets.all(18),
      decoration: birdHouseCardDecoration(
        context,
        heroTintColor: twillColor,
        radius: 22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BirdStatusPill(
                      pillKey: const Key('twill_hero_status_pill'),
                      label: isPinLocked
                          ? l10n.tr('house_twill_money_locked')
                          : l10n.tr('house_twill_hero_label'),
                      dotColor: twillColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      balanceDisplay,
                      key: const Key('twill_hero_balance_text'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: AppColors.textPrimary(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        BirdStatusPill(
                          pillKey: const Key('twill_hero_income_pill'),
                          label: '${l10n.tr('month_in')} $incomeDisplay',
                          dotColor: AppColors.success,
                          tabular: true,
                        ),
                        BirdStatusPill(
                          pillKey: const Key('twill_hero_expense_pill'),
                          label: '${l10n.tr('month_out')} $expenseDisplay',
                          dotColor: AppColors.error,
                          tabular: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const BirdHeroSpriteHalo(
                assetPath: 'assets/mascots/sprites/twill/budgeted.png',
                accentColor: twillColor,
                fallbackIcon: Icons.account_balance_wallet_rounded,
                size: 80,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('twill_hero_add_expense_btn'),
                onPressed: () {
                  if (isPinLocked) {
                    MoneyHubScreen.push(context);
                  } else {
                    showMoneyTransactionSheet(
                      context,
                      initialType: MoneyTransactionType.expense,
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: twillColor,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.north_east_rounded, size: 16),
                label: Text(
                  l10n.tr('house_twill_add_expense'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('twill_hero_open_money_btn'),
                onPressed: () => MoneyHubScreen.push(context),
                style: TextButton.styleFrom(
                  backgroundColor: twillColor.withValues(
                    alpha: isDark ? 0.16 : 0.12,
                  ),
                  foregroundColor: AppColors.textPrimary(context),
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                  color: twillColor,
                ),
                label: Text(
                  l10n.tr('house_twill_open_money'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
