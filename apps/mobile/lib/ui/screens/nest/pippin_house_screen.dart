import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/bucket_list_provider.dart';
import '../../../providers/hobby_provider.dart';
import '../../../providers/reading_provider.dart';
import '../../widgets/hobby_practice_sheet.dart';
import '../../widgets/reading_tracker_sheet.dart';
import '../explore/bucket_list_screen.dart';
import '../explore/nestin_discover_screen.dart';
import '../inspiration/inspiration_screen.dart';
import 'bird_house_shared.dart';

/// Pippin's House — Reading, Hobbies, Bucket List, Inspiration & Discover (`#10B981`).
class PippinHouseScreen extends StatelessWidget {
  static const Color pippinColor = Color(0xFF10B981);

  const PippinHouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reading = tryWatchProvider<ReadingProvider>(context);
    final hobby = tryWatchProvider<HobbyProvider>(context);
    final bucket = tryWatchProvider<BucketListProvider>(context);

    final activeBook = reading?.primaryActiveBook;
    final topHobby = (hobby != null && hobby.activeHobbies.isNotEmpty)
        ? hobby.activeHobbies.first
        : null;

    return Scaffold(
      key: const Key('pippin_house_screen'),
      appBar: buildBirdHouseAppBar(
        context,
        title: l10n.tr('house_pippin_title'),
        subtitle: l10n.tr('nest_pippin_subtitle'),
        spriteAsset: 'assets/mascots/sprites/pippin/discover.png',
        accentColor: pippinColor,
        fallbackIcon: Icons.explore_outlined,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildHeroProgressCard(
            context,
            l10n: l10n,
            reading: reading,
            hobby: hobby,
            activeBook: activeBook,
            topHobby: topHobby,
          ),
          const SizedBox(height: 18),
          BirdSectionLabel(
            text: l10n.tr('house_tools_section'),
            accentColor: pippinColor,
          ),
          BirdToolGrid(
            tiles: [
              BirdToolTile(
                tileKey: const Key('pippin_tool_reading'),
                title: l10n.tr('house_pippin_reading_title'),
                subtitle: l10n.tr('house_pippin_reading_sub', {
                  'today': reading?.todayPagesRead ?? 0,
                  'goal': reading?.dailyPageGoal ?? 20,
                }),
                icon: Icons.menu_book_rounded,
                accentColor: pippinColor,
                onTap: () => ReadingTrackerSheet.show(context),
              ),
              BirdToolTile(
                tileKey: const Key('pippin_tool_hobby'),
                title: l10n.tr('house_pippin_hobby_title'),
                subtitle: l10n.tr('house_pippin_hobby_sub', {
                  'hours': (hobby?.totalCumulativeHours ?? 0).toStringAsFixed(1),
                  'badges': hobby?.totalBadgesUnlocked ?? 0,
                }),
                icon: Icons.palette_rounded,
                accentColor: const Color(0xFF0EA5E9),
                onTap: () => HobbyPracticeSheet.show(context),
              ),
              BirdToolTile(
                tileKey: const Key('pippin_tool_bucket'),
                title: l10n.tr('house_pippin_bucket_title'),
                subtitle: l10n.tr('house_pippin_bucket_sub', {
                  'done': bucket?.completedCount ?? 0,
                  'total': bucket?.totalCount ?? 0,
                }),
                icon: Icons.flag_rounded,
                accentColor: const Color(0xFFF59E0B),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BucketListScreen(),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('pippin_tool_inspiration'),
                title: l10n.tr('house_pippin_inspiration_title'),
                subtitle: l10n.tr('house_pippin_inspiration_sub'),
                icon: Icons.format_quote_rounded,
                accentColor: const Color(0xFF8B5CF6),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const InspirationScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDiscoverBanner(context, l10n),
        ],
      ),
    );
  }

  Widget _buildHeroProgressCard(
    BuildContext context, {
    required AppLocalizations l10n,
    required ReadingProvider? reading,
    required HobbyProvider? hobby,
    required dynamic activeBook,
    required dynamic topHobby,
  }) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.adaptive(
      context,
      dark: const Color(0xFF34D399),
      light: const Color(0xFF047857),
    );

    final hasBook = activeBook != null;
    final hasHobby = topHobby != null;

    return InkWell(
      onTap: () {
        if (hasBook) {
          ReadingTrackerSheet.show(context);
        } else {
          HobbyPracticeSheet.show(context);
        }
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF142923), Color(0xFF1A1B20)]
                : const [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: pippinColor.withValues(alpha: isDark ? 0.38 : 0.28),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: pippinColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasBook
                          ? l10n.tr('house_pippin_hero_reading')
                          : l10n.tr('house_pippin_hero_hobby'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasBook) ...[
                    Text(
                      activeBook.title as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('house_pippin_page_progress', {
                        'current': activeBook.safeCurrentPage,
                        'total': activeBook.totalPages,
                        'streak': reading?.currentStreak ?? 0,
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (activeBook.progressFraction as double)
                            .clamp(0.0, 1.0),
                        backgroundColor: AppColors.trackSurface(context),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          pippinColor,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ] else if (hasHobby) ...[
                    Text(
                      '${topHobby.iconEmoji} ${topHobby.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('house_pippin_hobby_progress', {
                        'hours': (topHobby.totalHoursPracticed as double)
                            .toStringAsFixed(1),
                        'target': topHobby.targetHours,
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (topHobby.progressToTarget as double)
                            .clamp(0.0, 1.0),
                        backgroundColor: AppColors.trackSurface(context),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          pippinColor,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ] else ...[
                    Text(
                      l10n.tr('house_pippin_hero_empty'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 74,
              height: 74,
              child: Image.asset(
                'assets/mascots/sprites/pippin/reading.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.menu_book_rounded,
                  size: 46,
                  color: pippinColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverBanner(BuildContext context, AppLocalizations l10n) {
    final isDark = AppColors.isDark(context);
    return InkWell(
      key: const Key('pippin_tool_discover'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const NestinDiscoverScreen(),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.16 : 0.10),
              pippinColor.withValues(alpha: isDark ? 0.16 : 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: pippinColor.withValues(alpha: 0.36),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pippinColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: pippinColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('house_pippin_discover_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.tr('house_pippin_discover_sub'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}
