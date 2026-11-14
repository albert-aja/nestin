import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../providers/hydration_provider.dart';
import '../../providers/wearable_provider.dart';
import 'hydration_settings_sheet.dart';

class HydrationSparklineCard extends StatefulWidget {
  final bool isCompact;

  const HydrationSparklineCard({
    super.key,
    this.isCompact = false,
  });

  @override
  State<HydrationSparklineCard> createState() => _HydrationSparklineCardState();
}

class _HydrationSparklineCardState extends State<HydrationSparklineCard> {
  int? _selectedBarIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<HydrationProvider>(
      builder: (context, hydration, _) {
        final dates = hydration.weeklyDates;
        final glassesList = hydration.weeklyGlasses;
        final dailyGoal = hydration.dailyGoalGlasses;
        final maxGlassesInWeek = max(dailyGoal, glassesList.fold<int>(0, max));
        final chartScaleMax = max(maxGlassesInWeek, 1);

        final daysMet = hydration.weeklyDaysMetCount;
        final consistencyPct = hydration.weeklyConsistencyPercentage.round();
        final avgMl = hydration.weeklyAverageMilliliters;

        Color badgeColor;
        if (daysMet >= 5) {
          badgeColor = const Color(0xFF10B981); // Emerald
        } else if (daysMet >= 3) {
          badgeColor = const Color(0xFF38BDF8); // Cyan
        } else {
          badgeColor = const Color(0xFFF59E0B); // Amber
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hydration.isGoalMet
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : AppColors.border(context),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header: Icon, Title, Consistency Pill & Settings
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.water_drop_rounded,
                      color: AppColors.adaptive(
                        context,
                        dark: const Color(0xFF38BDF8),
                        light: const Color(0xFF0284C7),
                      ),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pick(
                            'Hydration & Weekly Intake',
                            'Hidrasi & Asupan Mingguan',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.pick(
                            '${hydration.currentMilliliters}ml / ${hydration.targetMilliliters}ml target today',
                            '${hydration.currentMilliliters}ml / ${hydration.targetMilliliters}ml target hari ini',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '$daysMet/7d • $consistencyPct%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.adaptive(
                          context,
                          dark: badgeColor,
                          light: badgeColor == const Color(0xFF10B981)
                              ? const Color(0xFF047857)
                              : (badgeColor == const Color(0xFFF59E0B)
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF0369A1)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      hydration.remindersEnabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      size: 18,
                      color: hydration.remindersEnabled
                          ? AppColors.adaptive(
                              context,
                              dark: const Color(0xFF38BDF8),
                              light: const Color(0xFF0284C7),
                            )
                          : AppColors.textSecondary(context),
                    ),
                    tooltip: 'Hydration Settings',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => HydrationSettingsSheet.show(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Metrics Strip
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: "Today's Intake",
                      value: '${hydration.currentMilliliters}ml',
                      subtitle:
                          '${hydration.glassesConsumed}/$dailyGoal glasses',
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Weekly Average',
                      value: '${avgMl}ml',
                      subtitle: 'daily intake',
                      color: const Color(0xFF818CF8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Consistency',
                      value: '$daysMet of 7',
                      subtitle: 'goals completed',
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. 7-Day Sparkline Bar Chart
              _buildSparklineChart(
                context,
                dates: dates,
                glassesList: glassesList,
                dailyGoal: dailyGoal,
                chartScaleMax: chartScaleMax,
                hydration: hydration,
              ),
              const SizedBox(height: 12),

              // 4. Consistency Insight
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      daysMet >= 5
                          ? Icons.verified_rounded
                          : Icons.insights_rounded,
                      size: 15,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hydration.weeklyInsight,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimary(context),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Quick Water Logging Controls
              Row(
                children: [
                  // Minus Button
                  IconButton.filledTonal(
                    onPressed: hydration.glassesConsumed > 0
                        ? () {
                            hydration.removeGlass();
                            Provider.of<WearableProvider>(context,
                                    listen: false)
                                .syncHydrationToWearable(
                                    hydration.currentMilliliters);
                          }
                        : null,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.elevatedSurface(context),
                      foregroundColor: AppColors.textPrimary(context),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Progress Tag
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hydration.isGoalMet
                                ? Icons.check_circle_rounded
                                : Icons.local_drink_rounded,
                            size: 16,
                            color: hydration.isGoalMet
                                ? const Color(0xFF10B981)
                                : AppColors.adaptive(
                                    context,
                                    dark: const Color(0xFF38BDF8),
                                    light: const Color(0xFF0284C7),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hydration.isGoalMet
                                ? 'Daily Target Met! 🌿'
                                : '${(hydration.progressFraction * 100).toInt()}% of 2,000ml goal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: hydration.isGoalMet
                                  ? AppColors.adaptive(
                                      context,
                                      dark: const Color(0xFF10B981),
                                      light: const Color(0xFF047857),
                                    )
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Add Glass Button
                  ElevatedButton.icon(
                    onPressed: () {
                      hydration.addGlass();
                      Provider.of<WearableProvider>(context, listen: false)
                          .syncHydrationToWearable(
                              hydration.currentMilliliters);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      '+250ml',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textMuted(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSparklineChart(
    BuildContext context, {
    required List<DateTime> dates,
    required List<int> glassesList,
    required int dailyGoal,
    required int chartScaleMax,
    required HydrationProvider hydration,
  }) {
    const double chartHeight = 90.0;
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);

    return Column(
      children: [
        // Target Goal Reference Line indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '7-DAY INTAKE TREND',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.textSecondary(context),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 2,
                  color: const Color(0xFF0284C7).withValues(alpha: 0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  'Goal: ${dailyGoal * 250}ml',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.adaptive(
                      context,
                      dark: const Color(0xFF38BDF8),
                      light: const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 7 Bars
        SizedBox(
          height: chartHeight + 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final date = dates[index];
              final dateStr = date.toIso8601String().substring(0, 10);
              final isToday = dateStr == todayStr;
              final glasses = glassesList[index];
              final ml = glasses * 250;
              final isMet = glasses >= dailyGoal;
              final isSelected = _selectedBarIndex == index;

              // Compute fraction of chart height
              final fraction = (glasses / chartScaleMax).clamp(0.05, 1.0);
              final barHeight = chartHeight * fraction;

              Color barColor;
              if (isMet) {
                barColor = const Color(0xFF10B981); // Emerald target reached
              } else if (glasses > 0) {
                barColor = const Color(0xFF38BDF8); // Active blue/cyan intake
              } else {
                barColor = AppColors.trackSurface(context); // Zero intake
              }

              final dayLetter = DateFormat('E').format(date).substring(0, 3);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedBarIndex == index) {
                        _selectedBarIndex = null;
                      } else {
                        _selectedBarIndex = index;
                      }
                    });
                  },
                  child: Container(
                    color: Colors.transparent, // expand hit area
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Quantity label on top
                        Text(
                          glasses > 0 ? '${(ml / 1000).toStringAsFixed(1)}L' : '0',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? AppColors.textPrimary(context)
                                : (glasses > 0
                                    ? AppColors.textPrimary(context)
                                    : AppColors.textMuted(context)),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // The Bar
                        Container(
                          width: 22,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            border: isToday
                                ? Border.all(
                                    color: AppColors.textPrimary(context),
                                    width: 1.5,
                                  )
                                : (isSelected
                                    ? Border.all(
                                        color: const Color(0xFF38BDF8),
                                        width: 1.2,
                                      )
                                    : null),
                            boxShadow: isMet
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Day label below
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF38BDF8)
                                    .withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isToday ? 'Today' : dayLetter,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w600,
                              color: isToday
                                  ? AppColors.adaptive(
                                      context,
                                      dark: const Color(0xFF38BDF8),
                                      light: const Color(0xFF0284C7),
                                    )
                                  : AppColors.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Popover snippet if a bar is selected
        if (_selectedBarIndex != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM d')
                      .format(dates[_selectedBarIndex!]),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  '${glassesList[_selectedBarIndex!] * 250}ml (${glassesList[_selectedBarIndex!]} glasses) • ${glassesList[_selectedBarIndex!] >= dailyGoal ? "Target Met 🎉" : "Below Goal"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: glassesList[_selectedBarIndex!] >= dailyGoal
                        ? AppColors.adaptive(
                            context,
                            dark: const Color(0xFF10B981),
                            light: const Color(0xFF047857),
                          )
                        : AppColors.adaptive(
                            context,
                            dark: const Color(0xFF38BDF8),
                            light: const Color(0xFF0284C7),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

