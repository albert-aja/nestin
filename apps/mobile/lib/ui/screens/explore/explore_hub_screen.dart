import 'package:flutter/material.dart';
import '../../widgets/inspiration/inspiration_explore_card.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/services/weather_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/models/wearable_source.dart';
import '../../../data/services/ambient_sound_service.dart';
import '../../../providers/wearable_provider.dart';
import '../../../providers/hydration_provider.dart';
import '../../../providers/sleep_wellness_provider.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/medication_provider.dart';
import '../../../providers/hobby_provider.dart';
import '../../../providers/health_wellness_provider.dart';
import '../../widgets/wearable_sync_sheet.dart';
import '../../widgets/hydration_settings_sheet.dart';
import '../../widgets/hydration_sparkline_card.dart';
import '../../widgets/caffeine_summary_card.dart';
import '../../widgets/sleep_cycle_sheet.dart';
import '../../widgets/medication_tracker_sheet.dart';
import '../../widgets/hobby_practice_sheet.dart';
import '../../widgets/seren_wellness_summary_card.dart';
import '../../widgets/reading_progress_card.dart';
import '../../widgets/bucket_list_summary_card.dart';
import '../../widgets/location_reminders_card.dart';
import '../../widgets/before_you_go_card.dart';
import '../../widgets/before_you_go_weather_banner.dart';
import '../../widgets/money_summary_card.dart';
import '../../widgets/mascot_milestone_stamp_overlay.dart';
import '../settings/settings_screen.dart';
import '../settings/permission_center_screen.dart';
import '../search/universal_search_screen.dart';
import '../automation/automation_hub_screen.dart';
import '../scout/phone_modes_screen.dart';
import '../seren/seren_relaxation_screen.dart';
import '../seren/mental_wellness_screen.dart';
import '../../../providers/device_control_provider.dart';
import '../../../providers/automation_provider.dart';

class ExploreHubScreen extends StatefulWidget {
  const ExploreHubScreen({super.key});

  @override
  State<ExploreHubScreen> createState() => _ExploreHubScreenState();
}

class _ExploreHubScreenState extends State<ExploreHubScreen> {
  WeatherProviderInterface? _weatherService;
  WeatherInfo? _weatherInfo;

  @override
  void initState() {
    super.initState();
    try {
      _weatherService =
          Provider.of<WeatherProviderInterface>(context, listen: false);
    } on ProviderNotFoundException {
      _weatherService = LocalWeatherService();
    }
    final service = _weatherService;
    if (service is LocalWeatherService) {
      service.addWeatherListener(_onWeatherUpdated);
    }
    _loadWeather();
  }

  void _onWeatherUpdated() {
    if (mounted) _loadWeather();
  }

  @override
  void dispose() {
    final service = _weatherService;
    if (service is LocalWeatherService) {
      service.removeWeatherListener(_onWeatherUpdated);
    }
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final service = _weatherService ?? LocalWeatherService();
    final info = await service.getCurrentWeather();
    if (mounted) setState(() => _weatherInfo = info);
  }

  void _showSleepCycleSheet() {
    SleepCycleSheet.show(context);
  }


  void _handleDataExport(BuildContext context) {
    final storage = Provider.of<StorageService>(context, listen: false);
    final jsonStr = storage.exportFullBackupJson();

    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('local_backup_export')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tr('full_application_state_exported_as_local'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.recessedSurface(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Text(
                '${jsonStr.substring(0, jsonStr.length > 200 ? 200 : jsonStr.length)}...',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.tr('done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('explore_hub_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n.tr('universal_search_2'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UniversalSearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: l10n.tr('settings_title'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Weather & Context Card
          if (_weatherInfo != null)
            Builder(
              builder: (context) {
                final visual = BeforeYouGoWeatherBanner.resolveWeatherVisual(
                  context,
                  _weatherInfo!,
                );
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: visual.color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            visual.icon,
                            color: visual.color,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${_weatherInfo!.temperatureCelsius.round()}°C',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _weatherInfo!.condition,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _weatherInfo!.advice,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),

          // Wearable Integration Card
          Consumer<WearableProvider>(
            builder: (context, wearable, _) {
              final config = wearable.config;
              final record = wearable.latestRecord;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => WearableSyncSheet.show(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: config.isConnected
                                    ? AppColors.success.withOpacity(0.18)
                                    : AppColors.accent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                config.isConnected
                                    ? Icons.watch_rounded
                                    : Icons.add_to_home_screen_rounded,
                                color: config.isConnected
                                    ? AppColors.success
                                    : AppColors.accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Wearable Health Sync',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: config.isConnected
                                                ? AppColors.success.withValues(alpha: 0.15)
                                                : AppColors.trackSurface(context),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            config.isConnected
                                                ? config.selectedPlatform.shortName
                                                : 'Apple / Google',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: config.isConnected
                                                  ? AppColors.success
                                                  : AppColors.textSecondary(context),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      config.isConnected && record != null
                                          ? 'Last synced ${record.syncedAt.hour.toString().padLeft(2, '0')}:${record.syncedAt.minute.toString().padLeft(2, '0')} • Tap to view'
                                          : 'Connect Apple Health or Google Fit for sleep & step sync',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (config.isConnected)
                                IconButton(
                                  icon: wearable.isSyncing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.sync_rounded),
                                  tooltip: 'Sync Now',
                                  color: AppColors.accent,
                                  onPressed: () async {
                                    final rec = await wearable.syncNow();
                                    if (rec != null && context.mounted) {
                                      Provider.of<HealthWellnessProvider>(context,
                                              listen: false)
                                          .ingestWearableRecord(rec);
                                    }
                                  },
                                )
                              else
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary(context),
                                ),
                          ],
                        ),
                        if (config.isConnected && record != null) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _miniMetric(
                                icon: Icons.bedtime_rounded,
                                color: const Color(0xFF8338EC),
                                label: 'Sleep',
                                value: record.sleepDurationFormatted,
                              ),
                              _miniMetric(
                                icon: Icons.directions_walk_rounded,
                                color: const Color(0xFF10B981),
                                label: l10n.tr('steps'),
                                value: '${record.stepCount ?? 0}',
                              ),
                              _miniMetric(
                                icon: Icons.water_drop_rounded,
                                color: const Color(0xFF3A86FF),
                                label: l10n.tr('hydration'),
                                value: '${record.waterIntakeMl ?? 0}ml',
                              ),
                              _miniMetric(
                                icon: Icons.favorite_rounded,
                                color: const Color(0xFFEF4444),
                                label: l10n.tr('resting_hr'),
                                value: '${record.restingHeartRate ?? 0} bpm',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Wellness Row
          Text(
            l10n.tr('personal_wellness_sleep'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              // Sleep Cycles & Wind-Down Card (Seren's Sleep Companion)
              Expanded(
                child: Consumer2<SleepWellnessProvider, AlarmProvider>(
                  builder: (context, sleepWellness, alarmProvider, _) {
                    final now = DateTime.now();
                    final nextAlarm = alarmProvider.nextUpcomingAlarm;
                    final targetBedtime = sleepWellness.getTargetBedtime(
                      currentTime: now,
                      nextAlarmTime: nextAlarm?.nextOccurrence(now),
                    );
                    final bedH =
                        targetBedtime.hour.toString().padLeft(2, '0');
                    final bedM =
                        targetBedtime.minute.toString().padLeft(2, '0');

                    return InkWell(
                      onTap: _showSleepCycleSheet,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sleepWellness.isEnabled
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.45)
                                : AppColors.border(context),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.nightlight_round,
                                    color: Color(0xFF8B5CF6), size: 22),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: sleepWellness.isEnabled
                                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                        : AppColors.trackSurface(context),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    sleepWellness.isEnabled
                                        ? l10n.tr('alert_on')
                                        : l10n.tr('alert_off'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: sleepWellness.isEnabled
                                          ? const Color(0xFF8B5CF6)
                                          : AppColors.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              sleepWellness.isEnabled
                                  ? l10n.tr('bedtime', {'bedH': bedH, 'bedM': bedM})
                                  : l10n.tr('sleep_cycles'),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sleepWellness.isEnabled
                                  ? l10n.tr('m_wind_down', {'sleepWellness_windDownLeadMinutes': sleepWellness.windDownLeadMinutes})
                                  : l10n.tr('optimal_bedtime'),
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Water Tracker Card (Seren's Hydration Companion)
              Expanded(
                child: Consumer<HydrationProvider>(
                  builder: (context, hydration, _) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hydration.isGoalMet
                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                              : AppColors.border(context),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.water_drop_rounded,
                                      color: Color(0xFF8B5CF6), size: 22),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${hydration.currentMilliliters}ml',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => HydrationSettingsSheet.show(context),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.trackSurface(context),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    hydration.remindersEnabled
                                        ? Icons.notifications_active_rounded
                                        : Icons.notifications_off_outlined,
                                    size: 14,
                                    color: hydration.remindersEnabled
                                        ? const Color(0xFF8B5CF6)
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.tr('water_goal'),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              Row(
                                children: [
                                  if (hydration.glassesConsumed > 0)
                                    InkWell(
                                      onTap: () {
                                        hydration.removeGlass();
                                        Provider.of<WearableProvider>(context,
                                                listen: false)
                                            .syncHydrationToWearable(
                                                hydration.currentMilliliters);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Icon(Icons.remove_circle_outline,
                                            color: AppColors.textSecondary(context), size: 18),
                                      ),
                                    ),
                                  InkWell(
                                    onTap: () async {
                                      final goalJustMet =
                                          await hydration.addGlass();
                                      if (!context.mounted) return;
                                      Provider.of<WearableProvider>(context,
                                              listen: false)
                                          .syncHydrationToWearable(
                                              hydration.currentMilliliters);
                                      if (goalJustMet) {
                                        MascotMilestoneStampOverlay
                                            .showSerenRefreshed(
                                          context,
                                          currentMl:
                                              hydration.currentMilliliters,
                                          targetMl:
                                              hydration.targetMilliliters,
                                        );
                                      }
                                    },
                                    child: const Icon(Icons.add_circle_rounded,
                                        color: Color(0xFF8B5CF6), size: 20),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: hydration.progressFraction,
                              backgroundColor: AppColors.trackSurface(context),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                hydration.isGoalMet
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF8B5CF6),
                              ),
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.tr('glasses', {'hydration_glassesConsumed': hydration.glassesConsumed, 'hydration_dailyGoalGlasses': hydration.dailyGoalGlasses}),
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary(context)),
                              ),
                              if (hydration.isGoalMet)
                                Text(
                                  l10n.tr('met'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Seren Health & Activity Card (Steps, Sleep Tracking, Vitals, Breathing)
          const SerenWellnessSummaryCard(),
          const SizedBox(height: 12),

          // Seren Mental Wellness Support Hero Card
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.cardSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
              ),
            ),
            child: ListTile(
              key: const Key('explore_seren_mental_wellness_card'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MentalWellnessScreen(),
                  ),
                );
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              title: Text(
                l10n.tr('explore_mw_card_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                l10n.tr('explore_mw_card_subtitle'),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 12),

          // Seren Daily Relaxation & Ambient Soundscape Studio Card
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.cardSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              ),
            ),
            child: ListTile(
              key: const Key('explore_seren_relaxation_card'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SerenRelaxationScreen(),
                  ),
                );
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.surround_sound_rounded,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              title: Text(
                l10n.tr('seren_explore_card_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                l10n.tr('seren_explore_card_subtitle'),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 12),

          // Medication & Dosage Tracker Card (Seren's Pill Companion)
          Consumer<MedicationProvider>(
            builder: (context, medProvider, _) {
              final takenCount = medProvider.todayDosesTakenCount;
              final totalCount = medProvider.todayDosesTotalCount;
              final snoozedCount =
                  medProvider.todayDoses.where((d) => d.isSnoozed).length;
              final hasWarnings = medProvider.hasLowStockWarnings;
              final streak = medProvider.adherenceStreakDays;

              return InkWell(
                onTap: () => MedicationTrackerSheet.show(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasWarnings
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                          : (totalCount > 0 && takenCount == totalCount
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : AppColors.border(context)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.medication_rounded,
                          color: AppColors.adaptive(
                            context,
                            dark: const Color(0xFFA78BFA),
                            light: const Color(0xFF7C3AED),
                          ),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  l10n.tr('medication_pill_tracker'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                if (streak > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '🔥 ${streak}d',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.adaptive(
                                          context,
                                          dark: const Color(0xFFF59E0B),
                                          light: const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hasWarnings
                                  ? l10n.tr('refill_needed_for_low_stock')
                                  : (totalCount == 0
                                      ? l10n.tr('no_doses_scheduled_today_tap_to')
                                      : l10n.tr('of_doses_taken_today', {'takenCount': takenCount, 'totalCount': totalCount, 'snoozedCount_snoozed': snoozedCount > 0 ? ' • $snoozedCount snoozed' : '', 'snoozedCount_ditunda': snoozedCount > 0 ? ' • $snoozedCount ditunda' : ''})),
                              style: TextStyle(
                                fontSize: 12,
                                color: hasWarnings
                                    ? AppColors.adaptive(
                                        context,
                                        dark: const Color(0xFFF59E0B),
                                        light: const Color(0xFFB45309),
                                      )
                                    : (totalCount > 0 && takenCount == totalCount
                                        ? AppColors.adaptive(
                                            context,
                                            dark: const Color(0xFF10B981),
                                            light: const Color(0xFF047857),
                                          )
                                        : AppColors.textSecondary(context)),
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
              );
            },
          ),
          const SizedBox(height: 12),

          // Wind-Down Ambient Audio 1-Tap Trigger / Mini Player
          Consumer<SleepWellnessProvider>(
            builder: (context, sleepWellness, _) {
              if (sleepWellness.isWindDownAudioPlaying) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF8B5CF6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          sleepWellness.activeAmbientSound.icon,
                          color: const Color(0xFF8B5CF6),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _showSleepCycleSheet,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    l10n.tr('wind_down', {'sleepWellness_label': sleepWellness.activeAmbientSound.label}),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(l10n.tr('active'),
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.adaptive(
                                              context,
                                              dark: const Color(0xFF10B981),
                                              light: const Color(0xFF047857),
                                            ))),
                                  ),
                                ],
                              ),
                              Text(
                                l10n.tr('remaining_tap_for_sheet', {'sleepWellness_formattedRemainingTime': sleepWellness.formattedRemainingTime}),
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop_circle_rounded,
                            color: Color(0xFFEF4444)),
                        tooltip: l10n.tr('stop_audio'),
                        onPressed: () => sleepWellness.stopWindDownAudio(),
                      ),
                    ],
                  ),
                );
              }

              // 1-Tap Trigger Shortcuts when not playing
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          sleepWellness.startWindDownAudio(
                            soundType: AmbientSoundType.rain,
                            durationMinutes: 30,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.tr('playing_30m_soothing_rainfall_for_bedtime'),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(Icons.water_drop_rounded,
                            size: 15,
                            color: AppColors.adaptive(
                              context,
                              dark: const Color(0xFF38BDF8),
                              light: const Color(0xFF0284C7),
                            )),
                        label: Text(
                            l10n.tr('k_1_tap_30m_rain'),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary(context),
                          backgroundColor: AppColors.cardSurface(context),
                          side: BorderSide(color: AppColors.border(context)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          sleepWellness.startWindDownAudio(
                            soundType: AmbientSoundType.forest,
                            durationMinutes: 30,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.tr('playing_30m_forest_breeze_for_bedtime'),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(Icons.park_rounded,
                            size: 15,
                            color: AppColors.adaptive(
                              context,
                              dark: const Color(0xFF34D399),
                              light: const Color(0xFF059669),
                            )),
                        label: Text(
                            l10n.tr('k_1_tap_30m_forest'),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary(context),
                          backgroundColor: AppColors.cardSurface(context),
                          side: BorderSide(color: AppColors.border(context)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const HydrationSparklineCard(),
          const SizedBox(height: 12),
          const CaffeineSummaryCard(),
          const SizedBox(height: 16),
          const InspirationExploreCard(),
          const SizedBox(height: 20),

          // Personal Interests & Hobbies (Pippin's Domain)
          Text(
            l10n.tr('personal_interests_skill_milestones'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const NestinDiscoverBannerCard(),
          const SizedBox(height: 12),
          Consumer<HobbyProvider>(
            builder: (context, hobbyProvider, _) {
              final activeHobbies = hobbyProvider.activeHobbies;
              final totalHours = hobbyProvider.totalCumulativeHours;
              final badgesCount = hobbyProvider.totalBadgesUnlocked;
              final sessionsCount = hobbyProvider.totalSessionsCount;
              final topHobby =
                  activeHobbies.isNotEmpty ? activeHobbies.first : null;

              return InkWell(
                onTap: () => HobbyPracticeSheet.show(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('🎯',
                                style: TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      l10n.tr('hobby_practice_tracker'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.18),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        l10n.tr('badges', {'badgesCount': badgesCount}),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.adaptive(
                                            context,
                                            dark: const Color(0xFF10B981),
                                            light: const Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.tr('cumulative_practice_hrs_sessions', {'totalHours_1': totalHours.toStringAsFixed(1), 'sessionsCount': sessionsCount}),
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
                      if (topHobby != null) ...[
                        const SizedBox(height: 12),
                        Divider(height: 1, color: AppColors.border(context)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(topHobby.iconEmoji,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        topHobby.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      Text(
                                        '${topHobby.totalHoursPracticed.toStringAsFixed(1)} / ${topHobby.targetHours}h',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.adaptive(
                                            context,
                                            dark: const Color(0xFF10B981),
                                            light: const Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: topHobby.progressToTarget,
                                      backgroundColor: AppColors.trackSurface(context),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF10B981),
                                      ),
                                      minHeight: 5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const ReadingProgressCard(),
          const SizedBox(height: 12),
          const BucketListSummaryCard(),
          const SizedBox(height: 20),

          // Everyday Assistance & Location Geofences (Scout's Domain)
          Text(
            l10n.tr('scout_location_reminders_departures'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const LocationRemindersCard(),
          const SizedBox(height: 20),

          // Scout Automations & Device Utilities
          Text(
            l10n.tr('scout_digital_wellbeing_automations'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (ctx) {
              DeviceControlProvider? dc;
              AutomationProvider? auto;
              try {
                dc = Provider.of<DeviceControlProvider>(ctx);
              } catch (_) {}
              try {
                auto = Provider.of<AutomationProvider>(ctx);
              } catch (_) {}
              return Column(
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.shield_moon_rounded,
                        color: AppColors.info,
                      ),
                      title: Text(
                        l10n.tr('phone_modes_controls'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        dc?.activePhoneMode != null
                            ? l10n.tr('mode_active_label',
                                {'name': dc!.activePhoneMode!.name})
                            : l10n.tr('app_usage_limits_sleep_work_study'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(ctx),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => const PhoneModesScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.accent,
                      ),
                      title: Text(
                        l10n.tr('nestin_automation_engine'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        auto != null
                            ? '${auto.rules.where((r) => r.isEnabled).length} active rules • ${auto.pendingConfirmations.length} awaiting confirm'
                            : l10n.tr('cross_family_local_triggers_locks_safe'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(ctx),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => const AutomationHubScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.success,
                      ),
                      title: Text(
                        l10n.tr('permission_capability_center'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        dc != null && dc.registry.revokedPermissions.isNotEmpty
                            ? '${dc.registry.revokedPermissions.length} revoked permission(s) detected'
                            : l10n.tr('inspect_device_support_rationales_os_settings'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(ctx),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => const PermissionCenterScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Organization & Money Management (Twill's Domain)
          Text(
            l10n.tr('twill_personal_money_resources'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const MoneySummaryCard(),
          const SizedBox(height: 14),

          // BeforeYouGo Departure Assistant
          Text(
            l10n.tr('beforeyougo_departure_assistant'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const BeforeYouGoCard(),
          const SizedBox(height: 20),

          // Local-First Data Export
          Text(
            l10n.tr('local_first_data_portability'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined, color: AppColors.success),
              title: Text(
                l10n.tr('export_local_backup_json'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                l10n.tr('download_all_alarms_tasks_notes_journal'),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _handleDataExport(context),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _miniMetric({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Builder(
          builder: (context) => Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}

