import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import 'notes_list_screen.dart';
import 'collections_list_screen.dart';
import 'wishlist_screen.dart';
import 'money/money_hub_screen.dart';

class OrganizeHubScreen extends StatelessWidget {
  final int initialTabIndex;

  const OrganizeHubScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final safeInitialIndex = initialTabIndex.clamp(0, 3);
    return DefaultTabController(
      length: 4,
      initialIndex: safeInitialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tr('organize_hub_title')),
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.adaptive(
              context,
              dark: AppColors.accent,
              light: const Color(0xFFB45309),
            ),
            unselectedLabelColor: AppColors.textSecondary(context),
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: [
              Tab(icon: const Icon(Icons.notes_rounded, size: 18), text: l10n.tr('tab_notes')),
              Tab(icon: const Icon(Icons.list_alt_rounded, size: 18), text: l10n.tr('tab_lists')),
              Tab(
                  icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                  text: l10n.tr('tab_wishlist')),
              Tab(
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                  text: l10n.tr('tab_money')),
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

