import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/ambient_sound_service.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/caffeine_provider.dart';
import '../../../providers/hydration_provider.dart';
import '../../../providers/medication_provider.dart';
import '../../../providers/seren_relaxation_provider.dart';
import '../../../providers/sleep_wellness_provider.dart';
import '../../../providers/wearable_provider.dart';
import '../../widgets/caffeine_tracker_sheet.dart';
import '../../widgets/health_wellness_sheet.dart';
import '../../widgets/hydration_settings_sheet.dart';
import '../../widgets/mascot_milestone_stamp_overlay.dart';
import '../../widgets/medication_tracker_sheet.dart';
import '../../widgets/sleep_cycle_sheet.dart';
import '../../widgets/wearable_sync_sheet.dart';
import '../seren/mental_wellness_screen.dart';
import '../seren/seren_relaxation_screen.dart';
import 'bird_house_shared.dart';

/// Seren's House — Personal Wellness, Calm Support & Body Care (`#8B5CF6`).
///
/// Strictly unlocked even when Diary PIN/Biometric lock is active, with zero
/// guilt or streak metrics anywhere in Seren's sanctuary.
class SerenHouseScreen extends StatelessWidget {
  static const Color serenColor = AppColors.seren;

  const SerenHouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hydration = tryWatchProvider<HydrationProvider>(context);
    final sleep = tryWatchProvider<SleepWellnessProvider>(context);
    final alarmProvider = tryWatchProvider<AlarmProvider>(context);
    final med = tryWatchProvider<MedicationProvider>(context);
    final caffeine = tryWatchProvider<CaffeineProvider>(context);
    final relax = tryWatchProvider<SerenRelaxationProvider>(context);

    final now = DateTime.now();
    String sleepSub = l10n.tr('house_seren_sleep_sub_off');
    if (sleep != null && sleep.isEnabled) {
      final bed = sleep.getTargetBedtime(
        currentTime: now,
        nextAlarmTime: alarmProvider?.nextUpcomingAlarm?.nextOccurrence(now),
      );
      final formatted =
          '${bed.hour.toString().padLeft(2, '0')}:${bed.minute.toString().padLeft(2, '0')}';
      sleepSub = l10n.tr('house_seren_sleep_sub_on', {'time': formatted});
    }

    final hydrationSub = hydration != null
        ? l10n.tr('house_seren_hydration_sub', {
            'glasses': hydration.glassesConsumed,
            'goal': hydration.dailyGoalGlasses,
            'ml': hydration.currentMilliliters,
          })
        : l10n.tr('water_goal');

    final medSub = med != null && med.todayDosesTotalCount > 0
        ? l10n.tr('house_seren_med_sub', {
            'taken': med.todayDosesTakenCount,
            'total': med.todayDosesTotalCount,
          })
        : l10n.tr('house_seren_med_empty');

    final caffeineSub = l10n.tr(
      'house_seren_caffeine_sub',
      {'mg': caffeine?.todayTotalMg ?? 0},
    );

    return Scaffold(
      key: const Key('seren_house_screen'),
      appBar: buildBirdHouseAppBar(
        context,
        title: l10n.tr('house_seren_title'),
        subtitle: l10n.tr('nest_seren_subtitle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildMentalWellnessHero(context, l10n),
          const SizedBox(height: 12),
          _buildRelaxAudioBar(context, l10n, relax, sleep),
          const SizedBox(height: 20),
          BirdSectionLabel(
            text: l10n.tr('house_seren_body_care'),
            accentColor: serenColor,
          ),
          BirdToolGrid(
            tiles: [
              BirdToolTile(
                tileKey: const Key('seren_tool_sleep'),
                title: l10n.tr('house_seren_sleep_title'),
                subtitle: sleepSub,
                icon: Icons.nightlight_round,
                accentColor: serenColor,
                onTap: () => SleepCycleSheet.show(context),
              ),
              BirdToolTile(
                tileKey: const Key('seren_tool_hydration'),
                title: l10n.tr('house_seren_hydration_title'),
                subtitle: hydrationSub,
                icon: Icons.water_drop_rounded,
                accentColor: AppColors.sky,
                trailingBadge: hydration != null
                    ? SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          key: const Key('seren_tool_hydration_add_btn'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final met = await hydration.addGlass();
                            if (!context.mounted) return;
                            tryReadProvider<WearableProvider>(context)
                                ?.syncHydrationToWearable(
                              hydration.currentMilliliters,
                            );
                            if (met) {
                              MascotMilestoneStampOverlay.showSerenRefreshed(
                                context,
                                currentMl: hydration.currentMilliliters,
                                targetMl: hydration.targetMilliliters,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.add_circle_rounded,
                            color: serenColor,
                            size: 24,
                          ),
                        ),
                      )
                    : null,
                onTap: () => HydrationSettingsSheet.show(context),
              ),
              BirdToolTile(
                tileKey: const Key('seren_tool_medication'),
                title: l10n.tr('house_seren_med_title'),
                subtitle: medSub,
                icon: Icons.medication_rounded,
                accentColor: AppColors.purple,
                onTap: () => MedicationTrackerSheet.show(context),
              ),
              BirdToolTile(
                tileKey: const Key('seren_tool_caffeine'),
                title: l10n.tr('house_seren_caffeine_title'),
                subtitle: caffeineSub,
                icon: Icons.coffee_rounded,
                accentColor: AppColors.warning,
                onTap: () => CaffeineTrackerSheet.show(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildHealthAndWearablesTile(context, l10n),
        ],
      ),
    );
  }

  Widget _buildMentalWellnessHero(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final isDark = AppColors.isDark(context);

    return Container(
      key: const Key('seren_house_mental_hero'),
      padding: const EdgeInsets.all(18),
      decoration: birdHouseCardDecoration(
        context,
        heroTintColor: serenColor,
        radius: 22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('house_seren_hero_title'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l10n.tr('house_seren_hero_subtitle'),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const BirdHeroSpriteHalo(
                assetPath:
                    'assets/mascots/sprites/seren/gentle_breath_lotus.png',
                accentColor: serenColor,
                fallbackIcon: Icons.spa_rounded,
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
                key: const Key('seren_hero_open_support_btn'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MentalWellnessScreen(),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: serenColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.spa_rounded, size: 16),
                label: Text(
                  l10n.tr('house_seren_hero_cta'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('seren_hero_quick_aid_btn'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const MentalWellnessScreen(initialLayer: 1),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: serenColor.withValues(
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
                  Icons.favorite_outline_rounded,
                  size: 16,
                  color: serenColor,
                ),
                label: Text(
                  l10n.tr('house_seren_hero_quick_aid'),
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

  Widget _buildRelaxAudioBar(
    BuildContext context,
    AppLocalizations l10n,
    SerenRelaxationProvider? relax,
    SleepWellnessProvider? sleep,
  ) {
    final isDark = AppColors.isDark(context);
    final isPlaying = (relax?.isMixerPlaying ?? false) ||
        (sleep?.isWindDownAudioPlaying ?? false);

    return Container(
      key: const Key('seren_relax_audio_card'),
      padding: const EdgeInsets.all(16),
      decoration: birdHouseCardDecoration(
        context,
        heroTintColor: isPlaying ? serenColor : null,
        radius: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('seren_relax_bar'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SerenRelaxationScreen(),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'assets/mascots/sprites/seren/headphones_bliss.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.surround_sound_rounded,
                        color: serenColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.tr('house_seren_relax_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPlaying
                              ? l10n.tr('house_seren_relax_playing')
                              : l10n.tr('house_seren_relax_idle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sleep != null && sleep.isWindDownAudioPlaying)
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(
                        Icons.stop_circle_rounded,
                        color: AppColors.error,
                      ),
                      tooltip: l10n.tr('stop_audio'),
                      onPressed: () => sleep.stopWindDownAudio(),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary(context),
                    ),
                ],
              ),
            ),
          ),
          if (sleep != null && !sleep.isWindDownAudioPlaying) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('seren_quick_rain_btn'),
                    onTap: () {
                      sleep.startWindDownAudio(
                        soundType: AmbientSoundType.rain,
                        durationMinutes: 30,
                      );
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sky.withValues(
                          alpha: isDark ? 0.14 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.water_drop_rounded,
                            size: 15,
                            color: AppColors.skyAdaptive(context),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.tr('k_1_tap_30m_rain'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    key: const Key('seren_quick_forest_btn'),
                    onTap: () {
                      sleep.startWindDownAudio(
                        soundType: AmbientSoundType.forest,
                        durationMinutes: 30,
                      );
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pippin.withValues(
                          alpha: isDark ? 0.14 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.park_rounded,
                            size: 15,
                            color: AppColors.pippinAdaptive(context),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.tr('k_1_tap_30m_forest'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthAndWearablesTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final isDark = AppColors.isDark(context);

    return InkWell(
      key: const Key('seren_tool_health_wearables'),
      onTap: () => HealthWellnessSheet.show(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.all(16),
        decoration: birdHouseCardDecoration(context, radius: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(
                  alpha: isDark ? 0.16 : 0.11,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('house_seren_health_wearables'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.tr('house_seren_health_sub'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              key: const Key('seren_tool_wearables_btn'),
              onTap: () => WearableSyncSheet.show(context),
              borderRadius: BorderRadius.circular(999),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Center(
                  child: BirdStatusPill(
                    label: l10n.tr('house_seren_wearable_btn'),
                    dotColor: AppColors.success,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
