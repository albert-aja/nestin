import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../organize/collections_list_screen.dart';
import '../organize/money/money_hub_screen.dart';
import '../organize/notes_list_screen.dart';
import '../organize/wishlist_screen.dart';
import 'bird_house_shared.dart';

/// Twill's House — Preserves Twill's clean 4-way structure
/// (Notes, Lists & Packing, Wishlist, Money) (`#F59E0B`).
class TwillHouseScreen extends StatelessWidget {
  static const Color twillColor = Color(0xFFF59E0B);

  final int initialTabIndex;

  const TwillHouseScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final safeInitialIndex = initialTabIndex.clamp(0, 3);
    final labelColor = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );

    return DefaultTabController(
      length: 4,
      initialIndex: safeInitialIndex,
      child: Scaffold(
        key: const Key('twill_house_screen'),
        appBar: buildBirdHouseAppBar(
          context,
          title: l10n.tr('house_twill_title'),
          subtitle: l10n.tr('nest_twill_subtitle'),
          spriteAsset: 'assets/mascots/sprites/twill/organized.png',
          accentColor: twillColor,
          fallbackIcon: Icons.edit_note_rounded,
          bottom: TabBar(
            indicatorColor: twillColor,
            labelColor: labelColor,
            unselectedLabelColor: AppColors.textSecondary(context),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            tabs: [
              Tab(
                icon: const Icon(Icons.notes_rounded, size: 18),
                text: l10n.tr('tab_notes'),
              ),
              Tab(
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                text: l10n.tr('tab_lists'),
              ),
              Tab(
                icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                text: l10n.tr('tab_wishlist'),
              ),
              Tab(
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                text: l10n.tr('tab_money'),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NotesListScreen(),
            CollectionsListScreen(),
            WishlistScreen(),
            MoneyHubScreen(),
          ],
        ),
      ),
    );
  }
}
