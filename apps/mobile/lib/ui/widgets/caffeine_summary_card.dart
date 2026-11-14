import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/caffeine_data.dart';
import '../../domain/sleep/caffeine_calculator.dart';
import '../../providers/alarm_provider.dart';
import '../../providers/caffeine_provider.dart';
import '../../providers/sleep_wellness_provider.dart';
import 'caffeine_tracker_sheet.dart';

/// Compact Seren Wellness card surfacing today's caffeine load, projected residual
/// at tonight's SleepCycleSheet target bedtime, curfew status, and 1-tap drink logging.
class CaffeineSummaryCard extends StatelessWidget {
  const CaffeineSummaryCard({super.key});

  T? _tryWatch<T>(BuildContext context) {
    try {
      return Provider.of<T>(context);
    } catch (_) {
      return null;
    }
  }

  DateTime _resolveTargetBedtime(
    DateTime now,
    SleepWellnessProvider? sleepWellness,
    AlarmProvider? alarmProvider,
  ) {
    if (sleepWellness != null) {
      final nextAlarmTime = alarmProvider?.nextUpcomingAlarm?.nextOccurrence(now);
      return sleepWellness.getTargetBedtime(
        currentTime: now,
        nextAlarmTime: nextAlarmTime,
      );
    }
    var fallback = DateTime(now.year, now.month, now.day, 22, 30);
    if (fallback.isBefore(now)) {
      fallback = fallback.add(const Duration(days: 1));
    }
    return fallback;
  }

  static Color impactColor(BuildContext context, CaffeineSleepImpact impact) {
    switch (impact) {
      case CaffeineSleepImpact.clear:
        return AppColors.adaptive(
          context,
          dark: const Color(0xFF34D399),
          light: const Color(0xFF059669),
        );
      case CaffeineSleepImpact.mild:
        return AppColors.adaptive(
          context,
          dark: const Color(0xFF2DD4BF),
          light: const Color(0xFF0D9488),
        );
      case CaffeineSleepImpact.moderate:
        return AppColors.adaptive(
          context,
          dark: const Color(0xFFFBBF24),
          light: const Color(0xFFD97706),
        );
      case CaffeineSleepImpact.elevated:
        return AppColors.adaptive(
          context,
          dark: const Color(0xFFF87171),
          light: const Color(0xFFDC2626),
        );
    }
  }

  static String impactLabel(AppLocalizations l10n, CaffeineSleepImpact impact) {
    switch (impact) {
      case CaffeineSleepImpact.clear:
        return l10n.pick('Sleep-Safe', 'Aman Tidur');
      case CaffeineSleepImpact.mild:
        return l10n.pick('Low Residual', 'Sisa Rendah');
      case CaffeineSleepImpact.moderate:
        return l10n.pick('Moderate Load', 'Beban Sedang');
      case CaffeineSleepImpact.elevated:
        return l10n.pick('High Load', 'Beban Tinggi');
    }
  }

  String _formatHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final caffeine = _tryWatch<CaffeineProvider>(context);
    if (caffeine == null) return const SizedBox.shrink();

    final sleepWellness = _tryWatch<SleepWellnessProvider>(context);
    final alarmProvider = _tryWatch<AlarmProvider>(context);
    final l10n = context.l10n;

    final now = DateTime.now();
    final targetBedtime = _resolveTargetBedtime(now, sleepWellness, alarmProvider);
    final todayTotalMg = caffeine.todayTotalMg;
    final activeNowMg = caffeine.residualNow(now: now).round();
    final bedtimeResidualMg = caffeine.residualAt(targetBedtime).round();
    final impact = caffeine.impactAt(targetBedtime);
    final impactColor = CaffeineSummaryCard.impactColor(context, impact);
    final curfewTime = caffeine.resolvedCurfewTime(
      referenceDate: now,
      targetBedtime: targetBedtime,
    );
    final pastCurfew = caffeine.isPastCurfew(
      now: now,
      targetBedtime: targetBedtime,
    );

    const accentAmber = Color(0xFFD97706);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => CaffeineTrackerSheet.show(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: pastCurfew && activeNowMg > 0
                  ? accentAmber.withValues(alpha: 0.45)
                  : AppColors.border(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentAmber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.coffee_rounded,
                      color: accentAmber,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pick(
                            'Caffeine & Cutoff',
                            'Kafein & Batas Sore',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          caffeine.curfewEnabled
                              ? l10n.pick(
                                  pastCurfew
                                      ? 'Past ${_formatHm(curfewTime)} curfew'
                                      : 'Curfew at ${_formatHm(curfewTime)}',
                                  pastCurfew
                                      ? 'Lewat batas ${_formatHm(curfewTime)}'
                                      : 'Batas pukul ${_formatHm(curfewTime)}',
                                )
                              : l10n.pick(
                                  'Curfew nudge paused',
                                  'Pengingat batas dijeda',
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: pastCurfew
                                ? accentAmber
                                : AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: impactColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.pick(
                        '${_formatHm(targetBedtime)}: ~${bedtimeResidualMg}mg',
                        '${_formatHm(targetBedtime)}: ~${bedtimeResidualMg}mg',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: impactColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    l10n.pick(
                      'Today: ${todayTotalMg}mg',
                      'Hari ini: ${todayTotalMg}mg',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '•',
                    style: TextStyle(color: AppColors.textSecondary(context)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.pick(
                      'Active now: ~${activeNowMg}mg',
                      'Aktif kini: ~${activeNowMg}mg',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: StimulantType.values
                      .where((t) => t != StimulantType.custom)
                      .map((type) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        avatar: Text(
                          type.emoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                        label: Text(
                          '${type.localizedName(isIndonesian: l10n.isIndonesian)} ${type.defaultMg}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        backgroundColor: AppColors.elevatedSurface(context),
                        side: BorderSide(
                          color: type.color.withValues(alpha: 0.35),
                        ),
                        onPressed: () async {
                          await caffeine.logDrink(
                            type: type,
                            isIndonesian: l10n.isIndonesian,
                          );
                          await caffeine.syncCurfewNotification(
                            targetBedtime: targetBedtime,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.pick(
                                  '${type.emoji} +${type.defaultMg}mg ${type.enName} logged',
                                  '${type.emoji} +${type.defaultMg}mg ${type.idName} dicatat',
                                ),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact bedtime-focused caffeine residual banner embedded inside SleepCycleSheet.
class CaffeineBedtimeBanner extends StatelessWidget {
  final DateTime targetBedtime;

  const CaffeineBedtimeBanner({
    super.key,
    required this.targetBedtime,
  });

  @override
  Widget build(BuildContext context) {
    CaffeineProvider? caffeine;
    try {
      caffeine = Provider.of<CaffeineProvider>(context);
    } catch (_) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final residualMg = caffeine.residualAt(targetBedtime).round();
    final todayMg = caffeine.todayTotalMg;
    final impact = caffeine.impactAt(targetBedtime);
    final color = CaffeineSummaryCard.impactColor(context, impact);
    final statusLabel = CaffeineSummaryCard.impactLabel(l10n, impact);

    final bedHm =
        '${targetBedtime.hour.toString().padLeft(2, '0')}:${targetBedtime.minute.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => CaffeineTrackerSheet.show(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.coffee_rounded, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick(
                        'Caffeine at Bedtime ($bedHm)',
                        'Kafein Saat Jam Tidur ($bedHm)',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      l10n.pick(
                        '~${residualMg}mg residual • ${todayMg}mg logged today',
                        'Sisa ~${residualMg}mg • ${todayMg}mg tercatat hari ini',
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
