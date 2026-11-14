import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import 'diary_entries_screen.dart';
import 'timeline_screen.dart';
import 'memories_screen.dart';

class JournalHubScreen extends StatelessWidget {
  final int initialTabIndex;

  const JournalHubScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tr('journal_hub_title')),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.adaptive(
              context,
              dark: AppColors.primaryLight,
              light: AppColors.primary,
            ),
            unselectedLabelColor: AppColors.textSecondary(context),
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(icon: const Icon(Icons.book_outlined, size: 18), text: l10n.tr('tab_diary')),
              Tab(icon: const Icon(Icons.timeline_rounded, size: 18), text: l10n.tr('tab_timeline')),
              Tab(icon: const Icon(Icons.star_outline_rounded, size: 18), text: l10n.tr('tab_memories')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DiaryEntriesScreen(),
            TimelineScreen(),
            MemoriesScreen(),
          ],
        ),
      ),
    );
  }
}

