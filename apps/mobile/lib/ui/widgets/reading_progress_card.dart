import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/reading_item.dart';
import '../../providers/reading_provider.dart';
import 'reading_goal_sheet.dart';
import 'reading_progress_slider.dart';
import 'reading_sparkline_history.dart';
import 'reading_tracker_sheet.dart';

class ReadingProgressCard extends StatelessWidget {
  final bool isCompact;

  const ReadingProgressCard({
    super.key,
    this.isCompact = false,
  });

  static const Color _pippinEmerald = Color(0xFF10B981);
  static const Color _pippinGold = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<ReadingProvider>(
      builder: (context, provider, _) {
        final activeBook = provider.primaryActiveBook;
        final readingCount = provider.currentlyReadingCount;
        final finishedCount = provider.finishedBooksCount;

        return Container(
          padding: EdgeInsets.all(isCompact ? 14 : 16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pippinEmerald.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row (taps to open full Reading Sanctuary sheet)
              InkWell(
                onTap: () => ReadingTrackerSheet.show(context),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _pippinEmerald.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('📚', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.pick(
                                    'Reading Progress Tracker',
                                    'Pelacak Kemajuan Baca',
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _pippinEmerald.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l10n.pick(
                                    '$readingCount Reading • $finishedCount Done',
                                    '$readingCount Dibaca • $finishedCount Selesai',
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.adaptive(
                                      context,
                                      dark: _pippinEmerald,
                                      light: const Color(0xFF047857),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.pick(
                              '${provider.totalPagesRead} total pages read • ${provider.totalBooksCount} in library',
                              '${provider.totalPagesRead} total halaman dibaca • ${provider.totalBooksCount} di pustaka',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary(context),
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: AppColors.border(context)),
              const SizedBox(height: 10),

              // Daily Reading Page Goal, Streak Badge & 7-Day Sparkline History
              ReadingSparklineHistory(
                compact: isCompact,
                onConfigureGoal: () => ReadingGoalSettingsSheet.show(context),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: AppColors.border(context)),
              const SizedBox(height: 10),

              if (activeBook == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.pick(
                          'No books added yet. Track your current page & completion!',
                          'Belum ada buku. Lacak halaman & progres bacamu!',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => ReadingTrackerSheet.show(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pippinEmerald,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        l10n.pick('+ Add Book', '+ Tambah Buku'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Text(
                      activeBook.format.emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeBook.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (activeBook.author.isNotEmpty)
                            Text(
                              activeBook.author,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (!isCompact)
                      TextButton(
                        onPressed: () => ReadingTrackerSheet.show(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.pick(
                            'All (${provider.totalBooksCount})',
                            'Semua (${provider.totalBooksCount})',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: activeBook.isCompleted
                                ? _pippinGold
                                : _pippinEmerald,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ReadingProgressSlider(
                  book: activeBook,
                  compact: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
