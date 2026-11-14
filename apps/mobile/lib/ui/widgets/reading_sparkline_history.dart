import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/reading_goal_data.dart';
import '../../providers/reading_provider.dart';

const Color _pippinEmerald = Color(0xFF10B981);
const Color _pippinGold = Color(0xFFF59E0B);
const Color _pippinSky = Color(0xFF38BDF8);

/// Reusable streak pill badge displayed across Pippin reading surfaces.
class ReadingStreakBadge extends StatelessWidget {
  final int streak;
  final VoidCallback? onTap;

  const ReadingStreakBadge({
    super.key,
    required this.streak,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasStreak = streak > 0;
    final color = hasStreak
        ? AppColors.adaptive(
            context,
            dark: _pippinGold,
            light: const Color(0xFFB45309),
          )
        : AppColors.textSecondary(context);
    final bgColor = hasStreak
        ? _pippinGold.withValues(alpha: 0.16)
        : AppColors.elevatedSurface(context);

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasStreak
              ? _pippinGold.withValues(alpha: 0.35)
              : AppColors.border(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasStreak ? '🔥' : '📖',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            l10n.pick('${streak}d streak', '${streak}h beruntun'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return badge;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: badge,
    );
  }
}

/// Interactive 7-day pages-read sparkline bar history + daily goal reference line.
class ReadingSparklineHistory extends StatefulWidget {
  final bool compact;
  final VoidCallback? onConfigureGoal;

  const ReadingSparklineHistory({
    super.key,
    this.compact = false,
    this.onConfigureGoal,
  });

  @override
  State<ReadingSparklineHistory> createState() =>
      _ReadingSparklineHistoryState();
}

class _ReadingSparklineHistoryState extends State<ReadingSparklineHistory> {
  int? _selectedBarIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<ReadingProvider>(
      builder: (context, provider, _) {
        final dates = provider.weeklyDates;
        final pagesList = provider.weeklyPagesRead;
        final dailyGoal = provider.dailyPageGoal;
        final todayRead = provider.todayPagesRead;
        final isGoalMet = provider.isDailyGoalMet;
        final progress = provider.dailyGoalProgressFraction;
        final maxPagesInWeek = max(dailyGoal, pagesList.fold<int>(0, max));
        final chartScaleMax = max(maxPagesInWeek, 1);

        final emeraldInk = AppColors.adaptive(
          context,
          dark: _pippinEmerald,
          light: const Color(0xFF047857),
        );
        final skyInk = AppColors.adaptive(
          context,
          dark: _pippinSky,
          light: const Color(0xFF0284C7),
        );

        final todayKey = ReadingGoalData.dateKey(
          dates.isNotEmpty ? dates.last : DateTime.now(),
        );
        final double chartHeight = widget.compact ? 26.0 : 46.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Daily Page Goal progress + Streak + Optional Evening Nudge trigger
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isGoalMet
                                ? l10n.pick(
                                    'Today: $todayRead/$dailyGoal p ✓',
                                    'Hari ini: $todayRead/$dailyGoal hal ✓',
                                  )
                                : l10n.pick(
                                    'Today: $todayRead/$dailyGoal pages',
                                    'Hari ini: $todayRead/$dailyGoal hal',
                                  ),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isGoalMet
                                  ? emeraldInk
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ReadingStreakBadge(
                            streak: provider.currentStreak,
                            onTap: widget.onConfigureGoal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: AppColors.trackSurface(context),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isGoalMet ? _pippinEmerald : _pippinGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onConfigureGoal != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onConfigureGoal,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: provider.eveningReminderEnabled
                            ? _pippinEmerald.withValues(alpha: 0.14)
                            : AppColors.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: provider.eveningReminderEnabled
                              ? _pippinEmerald.withValues(alpha: 0.4)
                              : AppColors.border(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            provider.eveningReminderEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded,
                            size: 14,
                            color: provider.eveningReminderEnabled
                                ? emeraldInk
                                : AppColors.textSecondary(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            provider.eveningReminderEnabled
                                ? provider.formattedReminderTime
                                : l10n.pick('Nudge', 'Pengingat'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: provider.eveningReminderEnabled
                                  ? emeraldInk
                                  : AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: widget.compact ? 8 : 10),

            if (!widget.compact) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.pick('7-DAY PAGES READ', 'BACAAN 7 HARI'),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  Text(
                    l10n.pick(
                      'Goal: $dailyGoal p • ${provider.weeklyDaysMetCount}/7d',
                      'Target: $dailyGoal hal • ${provider.weeklyDaysMetCount}/7h',
                    ),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: emeraldInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // 7-day bars with goal reference marker
            SizedBox(
              height: widget.compact ? chartHeight + 16 : chartHeight + 34,
              child: Stack(
                children: [
                  // Horizontal Goal Reference Line
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: (widget.compact ? 16 : 18) +
                        (chartHeight *
                            (dailyGoal / chartScaleMax).clamp(0.05, 1.0)),
                    child: IgnorePointer(
                      child: Container(
                        height: 1,
                        color: _pippinEmerald.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      final date = dates[index];
                      final key = ReadingGoalData.dateKey(date);
                      final isToday = key == todayKey;
                      final pages = pagesList[index];
                      final metGoal = pages >= dailyGoal;
                      final isSelected = _selectedBarIndex == index;

                      final fraction =
                          (pages / chartScaleMax).clamp(0.08, 1.0);
                      final barHeight = chartHeight * fraction;

                      final Color barColor;
                      if (metGoal) {
                        barColor = _pippinEmerald;
                      } else if (pages > 0) {
                        barColor = _pippinSky;
                      } else {
                        barColor = AppColors.trackSurface(context);
                      }

                      final dayLetter =
                          DateFormat('E').format(date).substring(0, 3);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (widget.compact) return;
                            setState(() {
                              _selectedBarIndex =
                                  _selectedBarIndex == index ? null : index;
                            });
                          },
                          child: Container(
                            color: Colors.transparent,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!widget.compact) ...[
                                  Text(
                                    '$pages',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: isToday
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: pages > 0
                                          ? AppColors.textPrimary(context)
                                          : AppColors.textMuted(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Container(
                                  width: widget.compact ? 14 : 18,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5),
                                    ),
                                    border: isToday
                                        ? Border.all(
                                            color:
                                                AppColors.textPrimary(context),
                                            width: 1.3,
                                          )
                                        : (isSelected
                                            ? Border.all(
                                                color: _pippinGold,
                                                width: 1.3,
                                              )
                                            : null),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isToday
                                      ? l10n.pick('Today', 'Kini')
                                      : dayLetter,
                                  style: TextStyle(
                                    fontSize: widget.compact ? 8.5 : 9.5,
                                    fontWeight: isToday
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isToday
                                        ? skyInk
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            if (!widget.compact && _selectedBarIndex != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(dates[_selectedBarIndex!]),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      pagesList[_selectedBarIndex!] >= dailyGoal
                          ? l10n.pick(
                              '${pagesList[_selectedBarIndex!]} pages • Goal Met 🎉',
                              '${pagesList[_selectedBarIndex!]} hal • Target Tercapai 🎉',
                            )
                          : l10n.pick(
                              '${pagesList[_selectedBarIndex!]} / $dailyGoal pages',
                              '${pagesList[_selectedBarIndex!]} / $dailyGoal hal',
                            ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pagesList[_selectedBarIndex!] >= dailyGoal
                            ? emeraldInk
                            : skyInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
