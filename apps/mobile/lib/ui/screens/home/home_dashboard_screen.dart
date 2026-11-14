import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alarm.dart';
import '../../../data/models/dashboard_config.dart';
import '../../../data/models/journal_entry.dart';
import '../../../data/services/weather_service.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/note_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/quick_capture_sheet.dart';
import '../../widgets/hydration_sparkline_card.dart';
import '../../widgets/seren_wellness_summary_card.dart';
import '../../widgets/reading_progress_card.dart';
import '../../widgets/gratitude_jar_sheet.dart';
import '../../widgets/location_reminders_card.dart';
import '../../widgets/before_you_go_card.dart';
import '../../widgets/money_summary_card.dart';
import '../../widgets/oem_warning_banner.dart';
import '../alarms/alarm_edit_screen.dart';
import '../search/universal_search_screen.dart';
import '../settings/settings_screen.dart';
import '../scout/digital_wellbeing_screen.dart';
import '../automation/automation_hub_screen.dart';
import '../../../providers/device_control_provider.dart';
import '../../../providers/automation_provider.dart';

class HomeDashboardScreen extends StatefulWidget {
  final void Function(int tab, [int? subTab]) onNavigateTab;

  const HomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late Timer _ticker;
  DateTime _now = DateTime.now();
  WeatherInfo? _weatherInfo;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final weatherService = LocalWeatherService();
    final info = await weatherService.getCurrentWeather();
    if (mounted) {
      setState(() {
        _weatherInfo = info;
      });
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String _greeting(AppLocalizations l10n) => l10n.greetingForHour(_now.hour);

  bool get _isMorning => _now.hour < 12;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final alarmProvider = Provider.of<AlarmProvider>(context);
    final reminderProvider = Provider.of<ReminderProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final calendarProvider = Provider.of<CalendarProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final routineProvider = Provider.of<RoutineProvider>(context);
    final noteProvider = Provider.of<NoteProvider>(context);
    final journalProvider = Provider.of<JournalProvider>(context);
    final dashboardProvider = Provider.of<DashboardProvider>(context);

    final config = dashboardProvider.config;
    final nextAlarm = alarmProvider.nextUpcomingAlarm;
    final activeAlarmsCount =
        alarmProvider.alarms.where((a) => a.isEnabled).length;
    final pendingReminders = reminderProvider.pendingReminders;
    final todayTasks = taskProvider.tasksDueToday(_now);
    final todayEvents = calendarProvider.eventsForDate(_now);
    final routines = routineProvider.routines;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.cardSurface(context),
          onRefresh: () async {
            await HapticFeedback.mediumImpact();
            await _loadWeather();
            setState(() {
              _now = DateTime.now();
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.tr('today_refreshed')),
                    ],
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Header with Search, Reorder & Settings
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: AppColors.primary,
                              child: const Icon(
                                Icons.wb_twilight_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting(l10n)},',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            Text(
                              l10n.tr('nestin_everyday'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.dashboard_customize_rounded,
                            size: 20),
                        tooltip: l10n.tr('customize_cards'),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _showReorderDashboardSheet(context);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.search_rounded, size: 22),
                        tooltip: l10n.tr('universal_search'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UniversalSearchScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 22),
                        tooltip: l10n.tr('settings'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Morning Briefing Banner
                if (_isMorning || config.showWeather)
                  _buildMorningBriefingBanner(
                    context,
                    nextAlarm,
                    todayTasks,
                    todayEvents,
                    _weatherInfo,
                  ),

                // OEM Battery Hardening Warning Banner
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: OemWarningBanner(),
                ),

                // Active Phone Mode & Pending Automation Banner
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
                    final activeMode = dc?.activePhoneMode;
                    final pendingCount =
                        auto?.pendingConfirmations.length ?? 0;
                    if (activeMode == null && pendingCount == 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Card(
                        child: ListTile(
                          leading: Icon(
                            activeMode != null
                                ? Icons.shield_moon_rounded
                                : Icons.auto_awesome_rounded,
                            color: activeMode != null
                                ? Color(activeMode.colorValue)
                                : AppColors.warning,
                          ),
                          title: Text(
                            activeMode != null
                                ? '${activeMode.name} Active'
                                : '$pendingCount Automation(s) Need Confirmation',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            activeMode != null
                                ? 'Safe state snapshot ready for restore on exit.'
                                : 'Review pending trigger before device changes run.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(ctx),
                            ),
                          ),
                          trailing: activeMode != null
                              ? TextButton(
                                  onPressed: () => dc!.endActivePhoneMode(),
                                  child: const Text('End'),
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(ctx).push(
                              MaterialPageRoute(
                                builder: (_) => activeMode != null
                                    ? const DigitalWellbeingScreen(initialTab: 1)
                                    : const AutomationHubScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),

                // Everyday Metrics Quick Strip
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      _buildMetricCard(
                        title: l10n.tr('metric_alarms'),
                        count: l10n.tr('count_active', {'count': activeAlarmsCount}),
                        icon: Icons.alarm_rounded,
                        color: AppColors.primary,
                        onTap: () => widget.onNavigateTab(1, 0),
                      ),
                      const SizedBox(width: 8),
                      _buildMetricCard(
                        title: l10n.tr('metric_tasks'),
                        count: l10n.tr('count_due', {'count': todayTasks.length}),
                        icon: Icons.checklist_rounded,
                        color: AppColors.catWork,
                        onTap: () => widget.onNavigateTab(1, 3),
                      ),
                      const SizedBox(width: 8),
                      _buildMetricCard(
                        title: l10n.tr('metric_reminders'),
                        count: l10n.tr('count_active', {'count': pendingReminders.length}),
                        icon: Icons.notifications_active_outlined,
                        color: AppColors.accent,
                        onTap: () => widget.onNavigateTab(1, 1),
                      ),
                      const SizedBox(width: 8),
                      _buildMetricCard(
                        title: l10n.tr('metric_notes'),
                        count: l10n.tr('count_saved', {'count': noteProvider.activeNotes.length}),
                        icon: Icons.description_outlined,
                        color: AppColors.catPersonal,
                        onTap: () => widget.onNavigateTab(2, 0),
                      ),
                    ],
                  ),
                ),

                // Quick Capture & Action Row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => QuickCaptureSheet.show(context),
                            icon: Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: AppColors.adaptive(
                                context,
                                dark: AppColors.accent,
                                light: const Color(0xFFB45309),
                              ),
                            ),
                            label: Text(l10n.tr('quick_capture'),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.adaptive(
                                context,
                                dark: AppColors.accent,
                                light: const Color(0xFFB45309),
                              ),
                              side: BorderSide(
                                color: AppColors.adaptive(
                                  context,
                                  dark: AppColors.accent,
                                  light: const Color(0xFFB45309),
                                ).withValues(alpha: 0.45),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const AlarmEditScreen()),
                              );
                            },
                            icon: const Icon(Icons.alarm_add_rounded,
                                size: 16, color: AppColors.primary),
                            label: const Text('+ Alarm',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                  color: AppColors.primary.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Dynamic Reorderable Sections based on config.sectionOrder
                ...config.sectionOrder.map((sectionKey) {
                  return _buildSectionByKey(
                    sectionKey,
                    config,
                    nextAlarm,
                    alarmProvider,
                    settingsProvider,
                    todayEvents,
                    pendingReminders,
                    todayTasks,
                    taskProvider,
                    routines,
                    routineProvider,
                    journalProvider,
                  );
                }),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionByKey(
    String key,
    DashboardConfig config,
    Alarm? nextAlarm,
    AlarmProvider alarmProvider,
    SettingsProvider settingsProvider,
    List<dynamic> todayEvents,
    List<dynamic> pendingReminders,
    List<dynamic> todayTasks,
    TaskProvider taskProvider,
    List<dynamic> routines,
    RoutineProvider routineProvider,
    JournalProvider journalProvider,
  ) {
    final l10n = context.l10n;
    switch (key) {
      case DashboardConfig.sectionWeather:
        if (!config.showWeather || _weatherInfo == null) {
          return const SizedBox.shrink();
        }
        final dateFormatted = l10n.formatDate(_now, 'EEEE, MMM d');
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _buildWeatherBanner(_weatherInfo!, dateFormatted),
        );

      case DashboardConfig.sectionNextAlarm:
        if (!config.showNextAlarm) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _buildNextAlarmHero(
            context,
            nextAlarm,
            alarmProvider,
            settingsProvider,
          ),
        );

      case DashboardConfig.sectionAgenda:
        if (!config.showTodayAgenda) return const SizedBox.shrink();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.pick('Today\'s Agenda', 'Agenda Hari Ini'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(1, 2),
                    child: Text(l10n.pick('Full Calendar', 'Kalender Lengkap'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            _buildAgendaSection(
                todayEvents, pendingReminders, settingsProvider),
            const SizedBox(height: 16),
          ],
        );

      case DashboardConfig.sectionLocationReminders:
        if (!config.showLocationReminders) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: LocationRemindersCard(),
        );

      case DashboardConfig.sectionBeforeYouGo:
        if (!config.showBeforeYouGo) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: BeforeYouGoCard(),
        );

      case DashboardConfig.sectionTasks:
        if (!config.showTodayTasks) return const SizedBox.shrink();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.pick('Tasks Due Today', 'Tugas Hari Ini'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.catWork.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${todayTasks.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.catWork,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(1, 3),
                    child: Text(l10n.pick('All Tasks', 'Semua Tugas'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            _buildTasksSection(todayTasks, taskProvider),
            const SizedBox(height: 16),
          ],
        );

      case DashboardConfig.sectionRoutines:
        if (!config.showRoutines || routines.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.pick('Daily Routines & Habits', 'Rutinitas & Kebiasaan'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(1, 4),
                    child: Text(l10n.pick('Manage', 'Kelola'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            _buildRoutinesSection(routines, routineProvider),
            const SizedBox(height: 16),
          ],
        );

      case DashboardConfig.sectionHydration:
        if (!config.showHydration) return const SizedBox.shrink();
        return const Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: HydrationSparklineCard(),
            ),
            SizedBox(height: 16),
          ],
        );

      case DashboardConfig.sectionWellness:
        if (!config.showWellness) return const SizedBox.shrink();
        return const Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SerenWellnessSummaryCard(isCompact: true),
            ),
            SizedBox(height: 16),
          ],
        );

      case DashboardConfig.sectionReading:
        if (!config.showReading) return const SizedBox.shrink();
        return const Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ReadingProgressCard(isCompact: true),
            ),
            SizedBox(height: 16),
          ],
        );

      case DashboardConfig.sectionMoney:
        if (!config.showMoney) return const SizedBox.shrink();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MoneySummaryCard(
                isCompact: true,
                onOpenMoneyHub: () => widget.onNavigateTab(2, 3),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );

      case DashboardConfig.sectionMood:
        if (!config.showQuickJournal) return const SizedBox.shrink();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.pick('Everyday Reflection', 'Refleksi Harian'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(3, 0),
                    child: Text(l10n.tr('tab_diary'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildQuickMoodCheckIn(context, journalProvider),
            ),
            const SizedBox(height: 24),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMorningBriefingBanner(
    BuildContext context,
    Alarm? nextAlarm,
    List<dynamic> tasks,
    List<dynamic> events,
    WeatherInfo? weather,
  ) {
    final l10n = context.l10n;
    return Builder(
      builder: (context) {
        final isDark = AppColors.isDark(context);
        final accentInk = AppColors.adaptive(
          context,
          dark: AppColors.accent,
          light: const Color(0xFFB45309),
        );
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [
                      Color(0xFF2B1B17),
                      Color(0xFF1F1A24),
                    ]
                  : const [
                      Color(0xFFFFF7ED),
                      Color(0xFFFFF3E0),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: isDark ? 0.08 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.wb_sunny_rounded,
                    color: accentInk, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pick('☀️ Morning Briefing', '☀️ Ringkasan Pagi'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accentInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.pick(
                        '${weather != null ? "${weather.temperatureCelsius.toInt()}°C • " : ""}${tasks.length} tasks due, ${events.length} events today.',
                        '${weather != null ? "${weather.temperatureCelsius.toInt()}°C • " : ""}${tasks.length} tugas, ${events.length} acara hari ini.',
                      ),
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
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  SystemSound.play(SystemSoundType.click);
                  _showBriefingDialog(context, nextAlarm, tasks, events, weather);
                },
                icon: const Icon(Icons.volume_up_rounded, size: 14),
                label: Text(l10n.pick('Read', 'Baca'),
                    style: const TextStyle(fontSize: 11)),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppColors.accent.withValues(alpha: isDark ? 0.25 : 0.16),
                  foregroundColor: accentInk,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBriefingDialog(
    BuildContext context,
    Alarm? nextAlarm,
    List<dynamic> tasks,
    List<dynamic> events,
    WeatherInfo? weather,
  ) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) {
        final accentInk = AppColors.adaptive(
          ctx,
          dark: AppColors.accent,
          light: const Color(0xFFB45309),
        );
        return AlertDialog(
          backgroundColor: AppColors.cardSurface(ctx),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.wb_twilight_rounded, color: accentInk, size: 24),
              const SizedBox(width: 10),
              Text(l10n.pick('Daily Briefing', 'Ringkasan Harian'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pick(
                  'Good day! Here is your snapshot for ${l10n.formatDate(_now, "EEEE, MMM d")}:',
                  'Selamat beraktivitas! Ini ringkasan untuk ${l10n.formatDate(_now, "EEEE, d MMM")}:',
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 14),
              if (weather != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_outlined, size: 18, color: accentInk),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.pick(
                          'Weather: ${weather.temperatureCelsius.toInt()}°C (${weather.condition}). ${weather.advice}',
                          'Cuaca: ${weather.temperatureCelsius.toInt()}°C (${weather.condition}). ${weather.advice}',
                        ),
                        style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.alarm_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextAlarm != null
                        ? l10n.pick(
                            'Next Alarm: "${nextAlarm.title}" at ${nextAlarm.formattedTime()}',
                            'Alarm Berikutnya: "${nextAlarm.title}" pukul ${nextAlarm.formattedTime()}',
                          )
                        : l10n.pick(
                            'No alarms currently scheduled for today.',
                            'Belum ada alarm terjadwal hari ini.',
                          ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.checklist_rounded,
                    size: 18, color: AppColors.catWork),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.pick(
                      'Tasks: ${tasks.length} pending items due today.',
                      'Tugas: ${tasks.length} tugas perlu diselesaikan hari ini.',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.event_available_rounded,
                    size: 18, color: AppColors.catPersonal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.pick(
                      'Agenda: ${events.length} events scheduled in calendar.',
                      'Agenda: ${events.length} acara terjadwal di kalender.',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.pick('Ready for the day!', 'Siap jalani hari!'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
        );
      },
    );
  }

  void _showReorderDashboardSheet(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<DashboardProvider>(
          builder: (context, provider, _) {
            final config = provider.config;
            final sectionOrder = config.sectionOrder;

            final Map<String, Map<String, dynamic>> sectionMeta = {
              DashboardConfig.sectionWeather: {
                'title': l10n.pick('Weather & Daily Advice', 'Cuaca & Saran Harian'),
                'icon': Icons.wb_sunny_rounded,
                'color': AppColors.accent,
                'isEnabled': config.showWeather,
                'toggle': (bool v) => provider.toggleWeather(v),
              },
              DashboardConfig.sectionNextAlarm: {
                'title': l10n.pick('Hero Next Alarm', 'Alarm Berikutnya'),
                'icon': Icons.alarm_rounded,
                'color': AppColors.primary,
                'isEnabled': config.showNextAlarm,
                'toggle': (bool v) => provider.toggleNextAlarm(v),
              },
              DashboardConfig.sectionAgenda: {
                'title': l10n.pick('Today\'s Agenda (Events & Reminders)', 'Agenda Hari Ini (Acara & Pengingat)'),
                'icon': Icons.event_note_rounded,
                'color': AppColors.catWork,
                'isEnabled': config.showTodayAgenda,
                'toggle': (bool v) => provider.toggleTodayAgenda(v),
              },
              DashboardConfig.sectionLocationReminders: {
                'title': l10n.pick('Scout Location Reminders (Geofences)', 'Pengingat Lokasi Scout (Geofence)'),
                'icon': Icons.location_on_rounded,
                'color': const Color(0xFF3B82F6),
                'isEnabled': config.showLocationReminders,
                'toggle': (bool v) => provider.toggleLocationReminders(v),
              },
              DashboardConfig.sectionBeforeYouGo: {
                'title': l10n.pick('Scout BeforeYouGo & Departure Alerts', 'BeforeYouGo & Pengingat Berangkat Scout'),
                'icon': Icons.door_front_door_outlined,
                'color': const Color(0xFF3B82F6),
                'isEnabled': config.showBeforeYouGo,
                'toggle': (bool v) => provider.toggleBeforeYouGo(v),
              },
              DashboardConfig.sectionTasks: {
                'title': l10n.pick('Tasks Due Today', 'Tugas Hari Ini'),
                'icon': Icons.checklist_rounded,
                'color': AppColors.catWork,
                'isEnabled': config.showTodayTasks,
                'toggle': (bool v) => provider.toggleTodayTasks(v),
              },
              DashboardConfig.sectionRoutines: {
                'title': l10n.pick('Daily Routines & Habits', 'Rutinitas & Kebiasaan Harian'),
                'icon': Icons.repeat_rounded,
                'color': AppColors.accent,
                'isEnabled': config.showRoutines,
                'toggle': (bool v) => provider.toggleRoutines(v),
              },
              DashboardConfig.sectionHydration: {
                'title': l10n.pick('Hydration 7-Day Sparkline', 'Grafik Hidrasi 7 Hari'),
                'icon': Icons.water_drop_rounded,
                'color': const Color(0xFF38BDF8),
                'isEnabled': config.showHydration,
                'toggle': (bool v) => provider.toggleHydration(v),
              },
              DashboardConfig.sectionWellness: {
                'title': l10n.pick('Seren Health (Steps, Sleep & Vitals)', 'Kesehatan Seren (Langkah, Tidur & Vital)'),
                'icon': Icons.spa_rounded,
                'color': const Color(0xFF8B5CF6),
                'isEnabled': config.showWellness,
                'toggle': (bool v) => provider.toggleWellness(v),
              },
              DashboardConfig.sectionReading: {
                'title': l10n.pick('Reading Progress Tracker', 'Pelacak Progres Membaca'),
                'icon': Icons.menu_book_rounded,
                'color': const Color(0xFF10B981),
                'isEnabled': config.showReading,
                'toggle': (bool v) => provider.toggleReading(v),
              },
              DashboardConfig.sectionMoney: {
                'title': l10n.pick('Twill Money Management', 'Pengelola Keuangan Twill'),
                'icon': Icons.account_balance_wallet_rounded,
                'color': const Color(0xFFF59E0B),
                'isEnabled': config.showMoney,
                'toggle': (bool v) => provider.toggleMoney(v),
              },
              DashboardConfig.sectionMood: {
                'title': l10n.pick('Reflection & Weekly Mood Trend', 'Refleksi & Tren Suasana Hati'),
                'icon': Icons.mood_rounded,
                'color': AppColors.catPersonal,
                'isEnabled': config.showQuickJournal,
                'toggle': (bool v) => provider.toggleQuickJournal(v),
              },
            };

            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.pick('Customize Dashboard Cards', 'Atur Kartu Beranda'),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            provider.resetSectionOrder();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(l10n.tr('reset'),
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.pick(
                        'Drag handles to reorder sections. Toggle switches to show or hide cards.',
                        'Seret pegangan untuk mengurutkan. Gunakan sakelar untuk menampilkan atau menyembunyikan kartu.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        itemCount: sectionOrder.length,
                        onReorder: (oldIndex, newIndex) {
                          HapticFeedback.selectionClick();
                          provider.reorderSections(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final key = sectionOrder[index];
                          final meta = sectionMeta[key] ??
                              {
                                'title': key,
                                'icon': Icons.dashboard_rounded,
                                'color': AppColors.textPrimary(context),
                                'isEnabled': true,
                                'toggle': (bool _) {},
                              };

                          return Container(
                            key: ValueKey(key),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface(context),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: AppColors.border(context)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  meta['icon'] as IconData,
                                  color: meta['color'] as Color,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    meta['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: meta['isEnabled'] as bool,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    HapticFeedback.lightImpact();
                                    (meta['toggle'] as Function(bool))(val);
                                  },
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.drag_handle_rounded,
                                  color: AppColors.textSecondary(context),
                                  size: 22,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeatherBanner(WeatherInfo info, String dateText) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.wb_sunny_rounded,
                color: AppColors.adaptive(
                  context,
                  dark: AppColors.accent,
                  light: const Color(0xFFB45309),
                ),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${info.temperatureCelsius.toInt()}°C',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        info.condition,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.advice,
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
          ],
        ),
      ),
    );
  }

  Widget _buildNextAlarmHero(
    BuildContext context,
    Alarm? alarm,
    AlarmProvider provider,
    SettingsProvider settingsProvider,
  ) {
    if (alarm == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          children: [
            Icon(Icons.alarm_off_rounded,
                size: 34, color: AppColors.textSecondary(context)),
            const SizedBox(height: 10),
            Text(
              context.l10n.pick(
                'No upcoming alarms set',
                'Belum ada alarm mendatang',
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.pick(
                'Set an alarm to keep your schedule punctual',
                'Atur alarm agar jadwalmu tetap tepat waktu',
              ),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AlarmEditScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                  context.l10n.pick('Add Alarm', 'Tambah Alarm'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final challenge =
        alarm.effectiveChallenge(settingsProvider.globalChallengeProfile);
    final isDark = AppColors.isDark(context);
    final accentInk = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF261D22),
                  Color(0xFF1B181E),
                ]
              : const [
                  Color(0xFFFFF4F6),
                  Color(0xFFFDF2F8),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBadge(category: alarm.category),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alarm.timeUntilNext(_now),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alarm.formattedTime(use24Hour: settingsProvider.use24Hour),
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              color: AppColors.textPrimary(context),
            ),
          ),
          Text(
            alarm.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (challenge.isEnabled)
                Row(
                  children: [
                    Icon(Icons.psychology_rounded, size: 14, color: accentInk),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.pick(
                        '${challenge.typeLabel} Challenge',
                        'Tantangan ${challenge.typeLabel}',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentInk,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  context.l10n.pick('Standard dismissal', 'Matikan standar'),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => provider.triggerAlarm(alarm),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(context.l10n.pick('Test Ring', 'Uji Dering')),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.14),
                  foregroundColor: AppColors.adaptive(
                    context,
                    dark: AppColors.primaryLight,
                    light: AppColors.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Builder(
        builder: (context) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgendaSection(
    List<dynamic> events,
    List<dynamic> reminders,
    SettingsProvider settings,
  ) {
    return Builder(
      builder: (context) {
        if (events.isEmpty && reminders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              alignment: Alignment.center,
              child: Text(
                context.l10n.pick(
                  'No events or reminders scheduled for today.',
                  'Belum ada acara atau pengingat hari ini.',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          );
        }

        final combinedItems = <Widget>[];

        for (final e in events.take(2)) {
          combinedItems.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.catWork.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_note_rounded,
                        size: 16, color: AppColors.catWork),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (e.location != null && e.location!.isNotEmpty)
                          Text(
                            e.location!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    e.formattedTime(),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        for (final r in reminders.take(2)) {
          combinedItems.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                children: [
                  CategoryBadge(category: r.category, compact: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    r.formattedDueTime(use24Hour: settings.use24Hour),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: combinedItems
                .map((w) =>
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: w))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildTasksSection(List<dynamic> tasks, TaskProvider taskProvider) {
    return Builder(
      builder: (context) {
        if (tasks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              alignment: Alignment.center,
              child: Text(
                context.l10n.pick(
                  'All caught up! No tasks due today.',
                  'Semua beres! Tidak ada tugas jatuh tempo hari ini.',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length > 3 ? 3 : tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final t = tasks[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: t.isCompleted,
                      activeColor: AppColors.catWork,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                      onChanged: (_) {
                        HapticFeedback.lightImpact();
                        taskProvider.toggleTaskCompletion(t.id);
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: t.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: t.isCompleted
                                  ? AppColors.textSecondary(context)
                                  : AppColors.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (t.subtasks.isNotEmpty)
                            Text(
                              context.l10n.pick(
                                '${t.completedSubtasksCount}/${t.subtasks.length} subtasks',
                                '${t.completedSubtasksCount}/${t.subtasks.length} subtugas',
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
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t.priorityLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: t.priorityColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
      },
    );
  }

  Widget _buildRoutinesSection(
      List<dynamic> routines, RoutineProvider provider) {
    final activeRoutine = routines.first; // primary morning/evening routine
    return Builder(
      builder: (context) {
        final accentInk = AppColors.adaptive(
          context,
          dark: AppColors.accent,
          light: const Color(0xFFB45309),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        activeRoutine.typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.adaptive(
                            context,
                            dark: AppColors.primaryLight,
                            light: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      context.l10n.pick(
                        '🔥 ${activeRoutine.streakCount} day streak',
                        '🔥 ${activeRoutine.streakCount} hari beruntun',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activeRoutine.title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: activeRoutine.progress,
                    minHeight: 6,
                    backgroundColor: AppColors.trackSurface(context),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 12),
                // First 2-3 steps preview with toggle
                ...List.generate(
                  activeRoutine.steps.length > 3
                      ? 3
                      : activeRoutine.steps.length,
                  (idx) {
                    final isDone =
                        activeRoutine.completedStepIndices.contains(idx);
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        provider.toggleStep(activeRoutine.id, idx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isDone
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isDone
                                  ? accentInk
                                  : AppColors.textSecondary(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activeRoutine.steps[idx],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDone
                                      ? AppColors.textSecondary(context)
                                      : AppColors.textPrimary(context),
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickMoodCheckIn(
      BuildContext context, JournalProvider provider) {
    final l10n = context.l10n;
    final moods = [
      {
        'emoji': '😊',
        'label': l10n.pick('Great', 'Sangat Baik'),
        'mood': JournalMood.great,
      },
      {
        'emoji': '🙂',
        'label': l10n.pick('Good', 'Baik'),
        'mood': JournalMood.good,
      },
      {
        'emoji': '😐',
        'label': l10n.pick('Neutral', 'Netral'),
        'mood': JournalMood.neutral,
      },
      {
        'emoji': '😔',
        'label': l10n.pick('Low', 'Kurang'),
        'mood': JournalMood.low,
      },
      {
        'emoji': '😫',
        'label': l10n.pick('Tough', 'Berat'),
        'mood': JournalMood.tough,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pick(
              'How are you feeling right now?',
              'Bagaimana perasaanmu saat ini?',
            ),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: moods.map((m) {
              final moodEnum = m['mood'] as JournalMood;
              final emoji = m['emoji'] as String;
              final label = m['label'] as String;
              return InkWell(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final now = DateTime.now();
                  final entry = JournalEntry(
                    id: const Uuid().v4(),
                    title: l10n.pick('Mood Check: $label', 'Cek Suasana Hati: $label'),
                    content: l10n.pick(
                      'Logged mood $emoji $label during everyday reflection.',
                      'Mencatat suasana hati $emoji $label saat refleksi harian.',
                    ),
                    date: now,
                    mood: moodEnum,
                    tags: [l10n.pick('Reflection', 'Refleksi'), label],
                    createdAt: now,
                    updatedAt: now,
                  );
                  await provider.addJournalEntry(entry);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.pick(
                            'Logged feeling $emoji $label to diary!',
                            'Perasaan $emoji $label dicatat ke diari!',
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    if (JournalProvider.isLowOrToughMood(moodEnum)) {
                      await GratitudeJarSheet.show(
                        context,
                        triggeredByMood: moodEnum,
                        autoShake: true,
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          // 7-Day Mood Trend Visualization
          _buildWeeklyMoodTrend(provider),
        ],
      ),
    );
  }

  Widget _buildWeeklyMoodTrend(JournalProvider provider) {
    return Builder(
      builder: (context) {
        final entries = provider.journalEntries;
        final days = <DateTime>[];
        for (int i = 6; i >= 0; i--) {
          days.add(DateTime(_now.year, _now.month, _now.day)
              .subtract(Duration(days: i)));
        }

        final moodScores = <int>[];
        final moodEmojis = <String>[];
        final moodColors = <Color>[];

        int loggedCount = 0;
        JournalMood? dominantMood;
        final moodCountMap = <JournalMood, int>{};

        for (final d in days) {
          final matches = entries
              .where((e) =>
                  e.date.year == d.year &&
                  e.date.month == d.month &&
                  e.date.day == d.day)
              .toList();

          if (matches.isNotEmpty) {
            loggedCount++;
            final m = matches.first.mood;
            moodCountMap[m] = (moodCountMap[m] ?? 0) + 1;
            moodEmojis.add(m.emoji);

            switch (m) {
              case JournalMood.great:
                moodScores.add(5);
                moodColors.add(const Color(0xFF10B981));
                break;
              case JournalMood.good:
                moodScores.add(4);
                moodColors.add(const Color(0xFF3B82F6));
                break;
              case JournalMood.neutral:
                moodScores.add(3);
                moodColors.add(const Color(0xFFF59E0B));
                break;
              case JournalMood.low:
                moodScores.add(2);
                moodColors.add(const Color(0xFFF97316));
                break;
              case JournalMood.tough:
                moodScores.add(1);
                moodColors.add(const Color(0xFFEF4444));
                break;
            }
          } else {
            moodScores.add(0);
            moodEmojis.add('·');
            moodColors.add(AppColors.trackSurface(context));
          }
        }

        if (moodCountMap.isNotEmpty) {
          dominantMood = moodCountMap.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;
        }

        final accentInk = AppColors.adaptive(
          context,
          dark: AppColors.accent,
          light: const Color(0xFFB45309),
        );

        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.pick(
                      '7-Day Reflection Trend',
                      'Tren Refleksi 7 Hari',
                    ),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    dominantMood != null
                        ? context.l10n.pick(
                            '$loggedCount/7 days • Mostly ${dominantMood.label} ${dominantMood.emoji}',
                            '$loggedCount/7 hari • Dominan ${dominantMood.label} ${dominantMood.emoji}',
                          )
                        : context.l10n.pick(
                            '$loggedCount/7 days logged',
                            '$loggedCount/7 hari tercatat',
                          ),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (idx) {
                  final d = days[idx];
                  final score = moodScores[idx];
                  final emoji = moodEmojis[idx];
                  final color = moodColors[idx];
                  final dayInitial =
                      context.l10n.formatDate(d, 'E').substring(0, 1);
                  final isToday = idx == 6;

                  return Column(
                    children: [
                      Text(
                        emoji,
                        style: TextStyle(
                          fontSize: score > 0 ? 14 : 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 14,
                        height: score > 0 ? (score * 6.0) : 6.0,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: score >= 4
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayInitial,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.w500,
                          color: isToday
                              ? accentInk
                              : AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
