import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../providers/health_wellness_provider.dart';
import '../../providers/hydration_provider.dart';
import 'health_wellness_sheet.dart';

class SerenWellnessSummaryCard extends StatelessWidget {
  final bool isCompact;

  const SerenWellnessSummaryCard({
    super.key,
    this.isCompact = false,
  });

  static const Color _serenPurple = Color(0xFF8B5CF6);
  static const Color _serenLight = Color(0xFFA78BFA);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _skyBlue = Color(0xFF38BDF8);

  double _readHydrationFraction(BuildContext context) {
    try {
      return Provider.of<HydrationProvider>(context).progressFraction;
    } catch (_) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<HealthWellnessProvider>(
      builder: (context, health, _) {
        final today = health.todayActivity;
        final latestSleep = health.latestSleepLog;
        final goals = health.goals;
        final hydrationFrac = _readHydrationFraction(context);
        final score = health.computeDailyWellnessScore(
          hydrationFraction: hydrationFrac,
        );
        final insight = health.wellnessInsight(
          hydrationFraction: hydrationFrac,
        );

        final hrDisplay = today.restingHeartRate != null
            ? '${today.restingHeartRate} bpm'
            : '-- bpm';

        return Container(
          padding: EdgeInsets.all(isCompact ? 14 : 16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _serenPurple.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              InkWell(
                onTap: () => HealthWellnessSheet.show(context),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _serenPurple.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.spa_rounded,
                        color: AppColors.adaptive(
                          context,
                          dark: _serenLight,
                          light: _serenPurple,
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
                              'Seren Health & Activity',
                              'Kesehatan & Aktivitas Seren',
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            l10n.pick(
                              'Steps • Sleep Cycles • Vitals • Breathing',
                              'Langkah • Siklus Tidur • Vital • Pernapasan',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (score >= 70 ? _emerald : _serenPurple)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Wellness $score',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: score >= 70
                              ? AppColors.adaptive(
                                  context,
                                  dark: _emerald,
                                  light: const Color(0xFF047857),
                                )
                              : AppColors.adaptive(
                                  context,
                                  dark: _serenLight,
                                  light: _serenPurple,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary(context),
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3 Domain Snapshot Tiles
              Row(
                children: [
                  Expanded(
                    child: _metricTile(
                      context: context,
                      onTap: () =>
                          HealthWellnessSheet.show(context, initialTabIndex: 0),
                      icon: Icons.directions_walk_rounded,
                      accent: today.isStepGoalMet ? _emerald : _serenPurple,
                      label: 'Daily Steps',
                      value: NumberFormat('#,###').format(today.steps),
                      sub:
                          '${today.distanceKmWithStride(goals.strideLengthMeters).toStringAsFixed(1)}km / ${NumberFormat('#,###').format(today.stepGoal)}',
                      progress: today.stepProgress,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile(
                      context: context,
                      onTap: () =>
                          HealthWellnessSheet.show(context, initialTabIndex: 1),
                      icon: Icons.bedtime_rounded,
                      accent: AppColors.adaptive(
                        context,
                        dark: const Color(0xFF818CF8),
                        light: const Color(0xFF4F46E5),
                      ),
                      label: 'Last Sleep',
                      value: latestSleep?.formattedDuration ?? 'Log Sleep',
                      sub: latestSleep != null
                          ? '${latestSleep.qualityRating.emoji} Score ${latestSleep.qualityScore}'
                          : 'Target ${goals.formattedSleepTarget}',
                      progress: latestSleep != null
                          ? (latestSleep.durationMinutes /
                                  goals.sleepTargetMinutes)
                              .clamp(0.0, 1.0)
                          : 0.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile(
                      context: context,
                      onTap: () =>
                          HealthWellnessSheet.show(context, initialTabIndex: 2),
                      icon: Icons.favorite_rounded,
                      accent: AppColors.adaptive(
                        context,
                        dark: _skyBlue,
                        light: const Color(0xFF0284C7),
                      ),
                      label: 'Vitals & Calm',
                      value: hrDisplay,
                      sub: '${today.mindfulMinutes}m calm today',
                      progress: today.mindfulProgress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Seren Insight Line
              if (!isCompact) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    insight,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 1-Tap Quick Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => health.addSteps(1000),
                      icon: Icon(Icons.add_rounded,
                          size: 14,
                          color: AppColors.adaptive(
                            context,
                            dark: _serenLight,
                            light: _serenPurple,
                          )),
                      label: const Text(
                        '+1,000 Steps',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary(context),
                        side: BorderSide(color: AppColors.border(context)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          HealthWellnessSheet.show(context, initialTabIndex: 1),
                      icon: Icon(Icons.nightlight_round,
                          size: 14,
                          color: AppColors.adaptive(
                            context,
                            dark: const Color(0xFF818CF8),
                            light: const Color(0xFF4F46E5),
                          )),
                      label: const Text(
                        'Log Sleep',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary(context),
                        side: BorderSide(color: AppColors.border(context)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          HealthWellnessSheet.show(context, initialTabIndex: 3),
                      icon: const Icon(Icons.air_rounded,
                          size: 14, color: _emerald),
                      label: const Text(
                        'Breathe',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary(context),
                        side: BorderSide(color: AppColors.border(context)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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

  Widget _metricTile({
    required BuildContext context,
    required VoidCallback onTap,
    required IconData icon,
    required Color accent,
    required String label,
    required String value,
    required String sub,
    required double progress,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary(context)),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.trackSurface(context),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

