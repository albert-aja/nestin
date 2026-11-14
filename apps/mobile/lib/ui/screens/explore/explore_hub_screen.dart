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
import '../../widgets/location_reminders_card.dart';
import '../../widgets/before_you_go_card.dart';
import '../../widgets/money_summary_card.dart';
import '../settings/settings_screen.dart';
import '../settings/permission_center_screen.dart';
import '../search/universal_search_screen.dart';
import '../scout/digital_wellbeing_screen.dart';
import '../automation/automation_hub_screen.dart';
import '../../../providers/device_control_provider.dart';
import '../../../providers/automation_provider.dart';

class ExploreHubScreen extends StatefulWidget {
  const ExploreHubScreen({super.key});

  @override
  State<ExploreHubScreen> createState() => _ExploreHubScreenState();
}

class _ExploreHubScreenState extends State<ExploreHubScreen> {
  final WeatherProviderInterface _weatherService = LocalWeatherService();
  WeatherInfo? _weatherInfo;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final info = await _weatherService.getCurrentWeather();
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
        title: Text(l10n.pick('Local Backup Export', 'Ekspor Cadangan Lokal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pick(
                'Full application state exported as local-first JSON format. All modules, alarms, and settings included:',
                'Seluruh status aplikasi diekspor ke format JSON lokal. Semua modul, alarm, dan pengaturan disertakan:',
              ),
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
        title: Text(l10n.pick('Everyday Life & Wellness', 'Keseharian & Kebugaran')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n.pick('Universal Search', 'Pencarian Universal'),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.wb_sunny_rounded, color: AppColors.accent, size: 32),
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
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _weatherInfo!.condition,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
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
                                label: l10n.pick('Steps', 'Langkah'),
                                value: '${record.stepCount ?? 0}',
                              ),
                              _miniMetric(
                                icon: Icons.water_drop_rounded,
                                color: const Color(0xFF3A86FF),
                                label: l10n.pick('Hydration', 'Hidrasi'),
                                value: '${record.waterIntakeMl ?? 0}ml',
                              ),
                              _miniMetric(
                                icon: Icons.favorite_rounded,
                                color: const Color(0xFFEF4444),
                                label: l10n.pick('Resting HR', 'Detak Istirahat'),
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
            l10n.pick('Personal Wellness & Sleep', 'Kebugaran Pribadi & Tidur'),
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
                                        ? l10n.pick('Alert On', 'Aktif')
                                        : l10n.pick('Alert Off', 'Nonaktif'),
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
                                  ? l10n.pick('Bedtime $bedH:$bedM', 'Tidur $bedH:$bedM')
                                  : l10n.pick('Sleep Cycles', 'Siklus Tidur'),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sleepWellness.isEnabled
                                  ? l10n.pick(
                                      '${sleepWellness.windDownLeadMinutes}m wind-down',
                                      '${sleepWellness.windDownLeadMinutes}m relaksasi',
                                    )
                                  : l10n.pick('Optimal Bedtime', 'Jam Tidur Optimal'),
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
                                l10n.pick('Water Goal', 'Target Minum'),
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
                                    onTap: () {
                                      hydration.addGlass();
                                      Provider.of<WearableProvider>(context,
                                              listen: false)
                                          .syncHydrationToWearable(
                                              hydration.currentMilliliters);
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
                                l10n.pick(
                                  '${hydration.glassesConsumed} / ${hydration.dailyGoalGlasses} glasses',
                                  '${hydration.glassesConsumed} / ${hydration.dailyGoalGlasses} gelas',
                                ),
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary(context)),
                              ),
                              if (hydration.isGoalMet)
                                Text(
                                  l10n.pick('Met! 🌿', 'Tercapai! 🌿'),
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
                                  l10n.pick(
                                    'Medication & Pill Tracker',
                                    'Pelacak Obat & Vitamin',
                                  ),
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
                                  ? l10n.pick(
                                      '⚠️ Refill needed for low stock',
                                      '⚠️ Stok menipis, perlu isi ulang',
                                    )
                                  : (totalCount == 0
                                      ? l10n.pick(
                                          'No doses scheduled today • Tap to manage',
                                          'Belum ada jadwal hari ini • Ketuk untuk kelola',
                                        )
                                      : l10n.pick(
                                          '$takenCount of $totalCount doses taken today${snoozedCount > 0 ? ' • $snoozedCount snoozed' : ''}',
                                          '$takenCount dari $totalCount dosis diminum hari ini${snoozedCount > 0 ? ' • $snoozedCount ditunda' : ''}',
                                        )),
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
                                    l10n.pick(
                                      'Wind-Down: ${sleepWellness.activeAmbientSound.label}',
                                      'Relaksasi: ${sleepWellness.activeAmbientSound.label}',
                                    ),
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
                                l10n.pick(
                                  '${sleepWellness.formattedRemainingTime} remaining • Tap for sheet',
                                  'Tersisa ${sleepWellness.formattedRemainingTime} • Ketuk untuk buka',
                                ),
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
                        tooltip: l10n.pick('Stop Audio', 'Hentikan Audio'),
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
                                l10n.pick(
                                  '🌧️ Playing 30m soothing rainfall for bedtime wind-down...',
                                  '🌧️ Memutar 30m suara hujan untuk pengantar tidur...',
                                ),
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
                            l10n.pick('1-Tap: 30m Rain', '1-Ketuk: 30m Hujan'),
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
                                l10n.pick(
                                  '🌲 Playing 30m forest breeze for bedtime wind-down...',
                                  '🌲 Memutar 30m angin hutan untuk pengantar tidur...',
                                ),
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
                            l10n.pick('1-Tap: 30m Forest', '1-Ketuk: 30m Hutan'),
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
            l10n.pick(
              'Personal Interests & Skill Milestones',
              'Minat Pribadi & Pencapaian Keahlian',
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
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
                                      l10n.pick(
                                        'Hobby Practice Tracker',
                                        'Pelacak Latihan Hobi',
                                      ),
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
                                        l10n.pick(
                                          '🎖️ $badgesCount Badges',
                                          '🎖️ $badgesCount Lencana',
                                        ),
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
                                  l10n.pick(
                                    '${totalHours.toStringAsFixed(1)} cumulative practice hrs • $sessionsCount sessions',
                                    '${totalHours.toStringAsFixed(1)} jam latihan kumulatif • $sessionsCount sesi',
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
          const SizedBox(height: 20),

          // Everyday Assistance & Location Geofences (Scout's Domain)
          Text(
            l10n.pick(
              'Scout — Location Reminders & Departures',
              'Scout — Pengingat Lokasi & Keberangkatan',
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const LocationRemindersCard(),
          const SizedBox(height: 20),

          // Scout Digital Wellbeing, Phone Modes & Automations
          Text(
            l10n.pick(
              'Scout — Digital Wellbeing & Automations',
              'Scout — Kesejahteraan Digital & Otomasi',
            ),
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
                        Icons.phonelink_lock_rounded,
                        color: Color(0xFF3B82F6),
                      ),
                      title: Text(
                        l10n.pick(
                          'Digital Wellbeing & Phone Modes',
                          'Kesejahteraan Digital & Mode Ponsel',
                        ),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        dc?.activePhoneMode != null
                            ? '${dc!.activePhoneMode!.name} active · ${dc.appRules.where((r) => r.isEnabled).length} app limits'
                            : l10n.pick(
                                'App usage limits, Sleep/Work/Study modes & state restore',
                                'Batas aplikasi, mode Tidur/Kerja/Belajar & pemulihan status',
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(ctx),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => const DigitalWellbeingScreen(),
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
                        l10n.pick(
                          'Nestin Automation Engine',
                          'Mesin Otomasi Nestin',
                        ),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        auto != null
                            ? '${auto.rules.where((r) => r.isEnabled).length} active rules • ${auto.pendingConfirmations.length} awaiting confirm'
                            : l10n.pick(
                                'Cross-family local triggers, locks & safe rollback',
                                'Pemicu lintas modul, kunci konflik & pembatalan aman',
                              ),
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
                        l10n.pick(
                          'Permission & Capability Center',
                          'Pusat Izin & Kapabilitas',
                        ),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        dc != null && dc.registry.revokedPermissions.isNotEmpty
                            ? '${dc.registry.revokedPermissions.length} revoked permission(s) detected'
                            : l10n.pick(
                                'Inspect device support, rationales & OS settings',
                                'Periksa dukungan perangkat, alasan izin & pengaturan OS',
                              ),
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
            l10n.pick(
              'Twill — Personal Money & Resources',
              'Twill — Keuangan Pribadi & Sumber Daya',
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const MoneySummaryCard(),
          const SizedBox(height: 14),

          // BeforeYouGo Departure Assistant
          Text(
            l10n.pick(
              'BeforeYouGo — Departure Assistant',
              'BeforeYouGo — Asisten Keberangkatan',
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const BeforeYouGoCard(),
          const SizedBox(height: 20),

          // Local-First Data Export
          Text(
            l10n.pick(
              'Local-First Data Portability',
              'Portabilitas Data Lokal',
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined, color: AppColors.success),
              title: Text(
                l10n.pick(
                  'Export Local Backup (JSON)',
                  'Ekspor Cadangan Lokal (JSON)',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                l10n.pick(
                  'Download all alarms, tasks, notes, journal & settings',
                  'Unduh semua alarm, tugas, catatan, jurnal & pengaturan',
                ),
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

