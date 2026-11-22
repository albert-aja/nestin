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
class SerenHouseScreen extends StatelessWidget {
  static const Color serenColor = Color(0xFF8B5CF6);

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
        spriteAsset: 'assets/mascots/sprites/seren/hello.png',
        accentColor: serenColor,
        fallbackIcon: Icons.spa_rounded,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildMentalWellnessHero(context, l10n),
          const SizedBox(height: 12),
          _buildRelaxAudioBar(context, l10n, relax, sleep),
          const SizedBox(height: 18),
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
                accentColor: const Color(0xFF38BDF8),
                trailingBadge: hydration != null
                    ? InkWell(
                        onTap: () async {
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
                        borderRadius: BorderRadius.circular(20),
                        child: const Icon(
                          Icons.add_circle_rounded,
                          color: serenColor,
                          size: 22,
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
                accentColor: const Color(0xFFA855F7),
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
    final lavenderInk = AppColors.adaptive(
      context,
      dark: const Color(0xFFC4B5FD),
      light: const Color(0xFF6D28D9),
    );

    return Container(
      key: const Key('seren_house_mental_hero'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF231D35), Color(0xFF1A1B22)]
              : const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: serenColor.withValues(alpha: isDark ? 0.42 : 0.3),
        ),
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
              SizedBox(
                width: 74,
                height: 74,
                child: Image.asset(
                  'assets/mascots/sprites/seren/gentle_breath_lotus.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.spa_rounded,
                    size: 46,
                    color: serenColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MentalWellnessScreen(),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: serenColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.spa_rounded, size: 16),
                label: Text(
                  l10n.tr('house_seren_hero_cta'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MentalWellnessScreen(initialLayer: 1),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: lavenderInk,
                  side: BorderSide(color: serenColor.withValues(alpha: 0.45)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.favorite_outline_rounded, size: 16),
                label: Text(
                  l10n.tr('house_seren_hero_quick_aid'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
    final isPlaying =
        (relax?.isMixerPlaying ?? false) || (sleep?.isWindDownAudioPlaying ?? false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPlaying
              ? serenColor.withValues(alpha: 0.5)
              : AppColors.border(context),
        ),
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
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: serenColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/mascots/sprites/seren/headphones_bliss.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.surround_sound_rounded,
                      color: serenColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
          if (sleep != null && !sleep.isWindDownAudioPlaying) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      sleep.startWindDownAudio(
                        soundType: AmbientSoundType.rain,
                        durationMinutes: 30,
                      );
                    },
                    icon: Icon(
                      Icons.water_drop_rounded,
                      size: 14,
                      color: AppColors.adaptive(
                        context,
                        dark: const Color(0xFF38BDF8),
                        light: const Color(0xFF0284C7),
                      ),
                    ),
                    label: Text(
                      l10n.tr('k_1_tap_30m_rain'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary(context),
                      side: BorderSide(color: AppColors.border(context)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      sleep.startWindDownAudio(
                        soundType: AmbientSoundType.forest,
                        durationMinutes: 30,
                      );
                    },
                    icon: Icon(
                      Icons.park_rounded,
                      size: 14,
                      color: AppColors.adaptive(
                        context,
                        dark: const Color(0xFF34D399),
                        light: const Color(0xFF059669),
                      ),
                    ),
                    label: Text(
                      l10n.tr('k_1_tap_30m_forest'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary(context),
                      side: BorderSide(color: AppColors.border(context)),
                      visualDensity: VisualDensity.compact,
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
    return InkWell(
      key: const Key('seren_tool_health_wearables'),
      onTap: () => HealthWellnessSheet.show(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.14),
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
            OutlinedButton.icon(
              key: const Key('seren_tool_wearables_btn'),
              onPressed: () => WearableSyncSheet.show(context),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: AppColors.border(context)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              icon: const Icon(Icons.watch_rounded, size: 15),
              label: Text(
                l10n.tr('house_seren_wearable_btn'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
