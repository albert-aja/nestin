import 'dart:async';
import 'package:material_ui/material_ui.dart';
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
import '../../../providers/automation_provider.dart';
import '../../../providers/before_you_go_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/device_control_provider.dart';
import '../../../providers/hydration_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/wearable_provider.dart';
import '../../widgets/before_you_go_sheet.dart';
import '../../widgets/before_you_go_weather_banner.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/gratitude_jar_sheet.dart';
import '../../widgets/hydration_settings_sheet.dart';
import '../../widgets/mascot_milestone_stamp_overlay.dart';
import '../../widgets/oem_warning_banner.dart';
import '../alarms/alarm_edit_screen.dart';
import '../automation/automation_hub_screen.dart';
import '../nest/bird_house_shared.dart';
import '../scout/phone_modes_screen.dart';
import '../search/universal_search_screen.dart';
import '../settings/settings_screen.dart';

/// Decluttered Daily Dashboard strictly focused on "what needs me right now":
/// - Greeting & Morning Briefing banner
/// - Hero Next Alarm card
/// - Today's Agenda & Tasks Due Today
/// - Compact Weather / BeforeYouGo strip + Quick Hydration & Mood check-in
class HomeDashboardScreen extends StatefulWidget {
  final void Function(int tab, [int? subTab]) onNavigateTab;

  const HomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  static const List<String> _focusedSectionKeys = [
    DashboardConfig.sectionNextAlarm,
    DashboardConfig.sectionAgenda,
    DashboardConfig.sectionTasks,
    DashboardConfig.sectionWeather,
    DashboardConfig.sectionHydration,
    DashboardConfig.sectionMood,
  ];

  late Timer _ticker;
  DateTime _now = DateTime.now();
  WeatherInfo? _weatherInfo;
  WeatherProviderInterface? _weatherService;

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
    _attachWeatherService();
    _loadWeather();
  }

  void _attachWeatherService() {
    final resolved = tryReadProvider<WeatherProviderInterface>(context) ??
        LocalWeatherService();
    if (identical(_weatherService, resolved)) return;
    final prev = _weatherService;
    if (prev is LocalWeatherService) {
      prev.removeWeatherListener(_onWeatherServiceUpdated);
    }
    _weatherService = resolved;
    if (resolved is LocalWeatherService) {
      resolved.addWeatherListener(_onWeatherServiceUpdated);
    }
  }

  void _onWeatherServiceUpdated() {
    if (mounted) _loadWeather();
  }

  Future<void> _loadWeather() async {
    final service = _weatherService ?? LocalWeatherService();
    final info = await service.getCurrentWeather();
    if (mounted) {
      setState(() {
        _weatherInfo = info;
      });
    }
  }

  @override
  void dispose() {
    final service = _weatherService;
    if (service is LocalWeatherService) {
      service.removeWeatherListener(_onWeatherServiceUpdated);
    }
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
    final journalProvider = Provider.of<JournalProvider>(context);
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final hydrationProvider = tryWatchProvider<HydrationProvider>(context);
    final bygProvider = tryWatchProvider<BeforeYouGoProvider>(context);

    final config = dashboardProvider.config;
    final nextAlarm = alarmProvider.nextUpcomingAlarm;
    final pendingReminders = reminderProvider.pendingReminders;
    final todayTasks = taskProvider.tasksDueToday(_now);
    final todayEvents = calendarProvider.eventsForDate(_now);
    final activeWeather = bygProvider?.currentWeather ?? _weatherInfo;

    // Preserve user custom section order while keeping strictly focused daily cards
    final orderedFocusedSections = <String>[
      for (final key in config.sectionOrder)
        if (_focusedSectionKeys.contains(key)) key,
      for (final key in _focusedSectionKeys)
        if (!config.sectionOrder.contains(key)) key,
    ];

    return Scaffold(
      key: const Key('home_dashboard_screen'),
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
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
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
                // Top Brand Header with clean Search & Settings (plus Customize)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
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
                            errorBuilder: (_, _, _) => Container(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            Text(
                              l10n.tr('nestin_everyday'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                        icon: const Icon(
                          Icons.dashboard_customize_rounded,
                          size: 20,
                        ),
                        tooltip: l10n.tr('customize_cards'),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _showReorderDashboardSheet(context);
                        },
                      ),
                      IconButton(
                        key: const Key('dashboard_search_btn'),
                        icon: const Icon(Icons.search_rounded, size: 22),
                        tooltip: l10n.tr('universal_search'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const UniversalSearchScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        key: const Key('dashboard_settings_btn'),
                        icon: const Icon(Icons.tune_rounded, size: 22),
                        tooltip: l10n.tr('settings'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Greeting & Morning Briefing Banner
                if (_isMorning || config.showWeather)
                  _buildMorningBriefingBanner(
                    context,
                    nextAlarm,
                    todayTasks,
                    todayEvents,
                    activeWeather,
                  ),

                // OEM Battery Hardening Warning Banner (only shown if needed)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: OemWarningBanner(),
                ),

                // Active Phone Mode or Pending Automation Alert (immediate needs only)
                _buildImmediateSystemAlertBanner(context, l10n),

                const SizedBox(height: 4),

                // Decluttered Focused Daily Sections
                ...orderedFocusedSections.map((sectionKey) {
                  return _buildFocusedSection(
                    context,
                    key: sectionKey,
                    config: config,
                    nextAlarm: nextAlarm,
                    alarmProvider: alarmProvider,
                    settingsProvider: settingsProvider,
                    todayEvents: todayEvents,
                    pendingReminders: pendingReminders,
                    todayTasks: todayTasks,
                    taskProvider: taskProvider,
                    activeWeather: activeWeather,
                    bygProvider: bygProvider,
                    hydrationProvider: hydrationProvider,
                    journalProvider: journalProvider,
                  );
                }),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImmediateSystemAlertBanner(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final dc = tryWatchProvider<DeviceControlProvider>(context);
    final auto = tryWatchProvider<AutomationProvider>(context);
    final activeMode = dc?.activePhoneMode;
    final pendingCount = auto?.pendingConfirmations.length ?? 0;

    if (activeMode == null && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
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
                ? l10n.tr('dash_mode_active_title', {'name': activeMode.name})
                : l10n.tr('dash_auto_confirm_title', {'count': pendingCount}),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          subtitle: Text(
            activeMode != null
                ? l10n.tr('dash_mode_active_sub')
                : l10n.tr('dash_auto_confirm_sub'),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
          trailing: activeMode != null
              ? TextButton(
                  onPressed: () => dc!.endActivePhoneMode(),
                  child: Text(l10n.tr('dash_end_action')),
                )
              : const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => activeMode != null
                    ? const PhoneModesScreen()
                    : const AutomationHubScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFocusedSection(
    BuildContext context, {
    required String key,
    required DashboardConfig config,
    required Alarm? nextAlarm,
    required AlarmProvider alarmProvider,
    required SettingsProvider settingsProvider,
    required List<dynamic> todayEvents,
    required List<dynamic> pendingReminders,
    required List<dynamic> todayTasks,
    required TaskProvider taskProvider,
    required WeatherInfo? activeWeather,
    required BeforeYouGoProvider? bygProvider,
    required HydrationProvider? hydrationProvider,
    required JournalProvider journalProvider,
  }) {
    final l10n = context.l10n;
    switch (key) {
      case DashboardConfig.sectionNextAlarm:
        if (!config.showNextAlarm) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      l10n.tr('today_s_agenda'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(1, 2),
                    child: Text(
                      l10n.tr('full_calendar'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            _buildAgendaSection(
              todayEvents,
              pendingReminders,
              settingsProvider,
            ),
            const SizedBox(height: 12),
          ],
        );

      case DashboardConfig.sectionTasks:
        if (!config.showTodayTasks) return const SizedBox.shrink();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.tr('tasks_due_today'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.catWork.withValues(alpha: 0.18),
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
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(1, 3),
                    child: Text(
                      l10n.tr('all_tasks'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            _buildTasksSection(todayTasks, taskProvider),
            const SizedBox(height: 14),
          ],
        );

      case DashboardConfig.sectionWeather:
        if (!config.showWeather && !config.showBeforeYouGo) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _buildCompactWeatherBeforeYouGoStrip(
            context,
            l10n,
            activeWeather,
            bygProvider,
          ),
        );

      case DashboardConfig.sectionHydration:
        if (!config.showHydration || hydrationProvider == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _buildCompactHydrationStrip(context, l10n, hydrationProvider),
        );

      case DashboardConfig.sectionMood:
        if (!config.showQuickJournal) return const SizedBox.shrink();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      l10n.tr('everyday_reflection'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(3, 0),
                    child: Text(
                      l10n.tr('tab_diary'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildQuickMoodCheckIn(context, journalProvider),
            ),
            const SizedBox(height: 12),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCompactWeatherBeforeYouGoStrip(
    BuildContext context,
    AppLocalizations l10n,
    WeatherInfo? weather,
    BeforeYouGoProvider? bygProvider,
  ) {
    final preset = bygProvider?.activePreset;
    final visual = weather != null
        ? BeforeYouGoWeatherBanner.resolveWeatherVisual(context, weather)
        : null;
    final dateFormatted = l10n.formatDate(_now, 'EEE, MMM d');

    return InkWell(
      key: const Key('dashboard_weather_byg_strip'),
      onTap: () => BeforeYouGoSheet.show(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (visual?.color ?? AppColors.info)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    visual?.icon ?? Icons.wb_sunny_rounded,
                    color: visual?.color ?? AppColors.info,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (weather != null) ...[
                            Text(
                              '${weather.temperatureCelsius.round()}°C',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              weather?.condition ??
                                  l10n.tr('dash_weather_before_you_go'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            flex: 0,
                            child: Text(
                              dateFormatted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (preset != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: preset.allChecked
                                    ? AppColors.success.withValues(alpha: 0.16)
                                    : AppColors.info.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${preset.name} • ${l10n.tr('nest_pill_scout_ready', {'checked': preset.checkedCount, 'total': preset.totalCount})}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: preset.allChecked
                                      ? AppColors.adaptive(
                                          context,
                                          dark: AppColors.success,
                                          light: const Color(0xFF047857),
                                        )
                                      : AppColors.adaptive(
                                          context,
                                          dark: const Color(0xFF93C5FD),
                                          light: const Color(0xFF1D4ED8),
                                        ),
                                ),
                              ),
                            ),
                          if (weather != null)
                            Text(
                              weather.advice,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
            if (bygProvider != null) ...[
              const SizedBox(height: 8),
              BeforeYouGoWeatherBanner(provider: bygProvider, compact: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHydrationStrip(
    BuildContext context,
    AppLocalizations l10n,
    HydrationProvider hydration,
  ) {
    const serenViolet = Color(0xFF8B5CF6);
    final goalMet = hydration.isGoalMet;

    return InkWell(
      key: const Key('dashboard_quick_hydration_strip'),
      onTap: () => HydrationSettingsSheet.show(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: goalMet
                ? AppColors.success.withValues(alpha: 0.45)
                : AppColors.border(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: serenViolet.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                color: serenViolet,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('dash_quick_hydration'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.tr('glasses', {
                      'hydration_glassesConsumed': hydration.glassesConsumed,
                      'hydration_dailyGoalGlasses': hydration.dailyGoalGlasses,
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: hydration.progressFraction,
                      backgroundColor: AppColors.trackSurface(context),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        goalMet ? AppColors.success : serenViolet,
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              key: const Key('dashboard_add_glass_btn'),
              onPressed: () async {
                HapticFeedback.lightImpact();
                final goalJustMet = await hydration.addGlass();
                if (!context.mounted) return;
                tryReadProvider<WearableProvider>(context)
                    ?.syncHydrationToWearable(hydration.currentMilliliters);
                if (goalJustMet) {
                  MascotMilestoneStampOverlay.showSerenRefreshed(
                    context,
                    currentMl: hydration.currentMilliliters,
                    targetMl: hydration.targetMilliliters,
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: serenViolet.withValues(alpha: 0.16),
                foregroundColor: AppColors.adaptive(
                  context,
                  dark: const Color(0xFFC4B5FD),
                  light: const Color(0xFF6D28D9),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              child: Text(
                l10n.tr('dash_add_glass_btn'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMorningBriefingBanner(
    BuildContext context,
    Alarm? nextAlarm,
    List<dynamic> tasks,
    List<dynamic> events,
    WeatherInfo? weather,
  ) {
    final l10n = context.l10n;
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
              ? const [Color(0xFF2B1B17), Color(0xFF1F1A24)]
              : const [Color(0xFFFFF7ED), Color(0xFFFFF3E0)],
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
            child: Icon(Icons.wb_sunny_rounded, color: accentInk, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('morning_briefing'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accentInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.tr('tasks_due_events_today', {
                    'weather_C': weather != null
                        ? '${weather.temperatureCelsius.toInt()}°C • '
                        : '',
                    'tasks_length': tasks.length,
                    'events_length': events.length,
                  }),
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
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              SystemSound.play(SystemSoundType.click);
              _showBriefingDialog(context, nextAlarm, tasks, events, weather);
            },
            icon: const Icon(Icons.volume_up_rounded, size: 14),
            label: Text(l10n.tr('read'), style: const TextStyle(fontSize: 11)),
            style: FilledButton.styleFrom(
              backgroundColor:
                  AppColors.accent.withValues(alpha: isDark ? 0.25 : 0.16),
              foregroundColor: accentInk,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
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
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final accentInk = AppColors.adaptive(
          ctx,
          dark: AppColors.accent,
          light: const Color(0xFFB45309),
        );
        return AlertDialog(
          backgroundColor: AppColors.cardSurface(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.wb_twilight_rounded, color: accentInk, size: 24),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l10n.tr('daily_briefing'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tr('good_day_here_is_your_snapshot', {
                  'l10n_d': l10n.formatDate(_now, 'EEEE, MMM d'),
                  'l10n_MMM': l10n.formatDate(_now, 'EEEE, d MMM'),
                }),
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
                        l10n.tr('weather_c', {
                          'weather_toInt': weather.temperatureCelsius.toInt(),
                          'weather_condition': weather.condition,
                          'weather_advice': weather.advice,
                        }),
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
                  const Icon(
                    Icons.alarm_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nextAlarm != null
                          ? l10n.tr('next_alarm_at', {
                              'nextAlarm_title': nextAlarm.title,
                              'nextAlarm_formattedTime':
                                  nextAlarm.formattedTime(),
                            })
                          : l10n.tr('no_alarms_currently_scheduled_for_today'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.checklist_rounded,
                    size: 18,
                    color: AppColors.catWork,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tr('tasks_pending_items_due_today', {
                        'tasks_length': tasks.length,
                      }),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 18,
                    color: AppColors.catPersonal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tr('agenda_events_scheduled_in_calendar', {
                        'events_length': events.length,
                      }),
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                l10n.tr('ready_for_the_day'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showReorderDashboardSheet(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
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
            final sectionOrder = [
              for (final k in config.sectionOrder)
                if (_focusedSectionKeys.contains(k)) k,
              for (final k in _focusedSectionKeys)
                if (!config.sectionOrder.contains(k)) k,
            ];

            final Map<String, Map<String, dynamic>> sectionMeta = {
              DashboardConfig.sectionNextAlarm: {
                'title': l10n.tr('hero_next_alarm'),
                'icon': Icons.alarm_rounded,
                'color': AppColors.primary,
                'isEnabled': config.showNextAlarm,
                'toggle': (bool v) => provider.toggleNextAlarm(v),
              },
              DashboardConfig.sectionAgenda: {
                'title': l10n.tr('today_s_agenda_events_reminders'),
                'icon': Icons.event_note_rounded,
                'color': AppColors.catWork,
                'isEnabled': config.showTodayAgenda,
                'toggle': (bool v) => provider.toggleTodayAgenda(v),
              },
              DashboardConfig.sectionTasks: {
                'title': l10n.tr('tasks_due_today'),
                'icon': Icons.checklist_rounded,
                'color': AppColors.catWork,
                'isEnabled': config.showTodayTasks,
                'toggle': (bool v) => provider.toggleTodayTasks(v),
              },
              DashboardConfig.sectionWeather: {
                'title': l10n.tr('dash_weather_before_you_go'),
                'icon': Icons.wb_sunny_rounded,
                'color': AppColors.accent,
                'isEnabled': config.showWeather || config.showBeforeYouGo,
                'toggle': (bool v) {
                  provider.toggleWeather(v);
                  provider.toggleBeforeYouGo(v);
                },
              },
              DashboardConfig.sectionHydration: {
                'title': l10n.tr('dash_quick_hydration'),
                'icon': Icons.water_drop_rounded,
                'color': const Color(0xFF8B5CF6),
                'isEnabled': config.showHydration,
                'toggle': (bool v) => provider.toggleHydration(v),
              },
              DashboardConfig.sectionMood: {
                'title': l10n.tr('everyday_reflection'),
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
                        Flexible(
                          child: Text(
                            l10n.tr('customize_dashboard_cards'),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            provider.resetSectionOrder();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(
                            l10n.tr('reset'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('drag_handles_to_reorder_sections_toggle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sectionOrder.length,
                        itemBuilder: (context, index) {
                          final key = sectionOrder[index];
                          final meta = sectionMeta[key]!;
                          return Container(
                            key: ValueKey(key),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
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
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) {
                                    HapticFeedback.lightImpact();
                                    (meta['toggle'] as Function(bool))(val);
                                  },
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
                      child: Text(
                        l10n.tr('done'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
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

  Widget _buildNextAlarmHero(
    BuildContext context,
    Alarm? alarm,
    AlarmProvider provider,
    SettingsProvider settingsProvider,
  ) {
    if (alarm == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.alarm_off_rounded,
              size: 32,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tr('no_upcoming_alarms_set'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.tr('set_an_alarm_to_keep_your'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AlarmEditScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.l10n.tr('add_alarm'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
              ? const [Color(0xFF261D22), Color(0xFF1B181E)]
              : const [Color(0xFFFFF4F6), Color(0xFFFDF2F8)],
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
              Flexible(child: CategoryBadge(category: alarm.category)),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      alarm.timeUntilNext(_now),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentInk,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alarm.formattedTime(use24Hour: settingsProvider.use24Hour),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
              color: AppColors.textPrimary(context),
            ),
          ),
          Text(
            alarm.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: challenge.isEnabled
                    ? Row(
                        children: [
                          Icon(
                            Icons.psychology_rounded,
                            size: 14,
                            color: accentInk,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              context.l10n.tr('challenge', {
                                'challenge_typeLabel': challenge.typeLabel,
                              }),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accentInk,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        context.l10n.tr('standard_dismissal'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => provider.triggerAlarm(alarm),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(context.l10n.tr('test_ring')),
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              alignment: Alignment.center,
              child: Text(
                context.l10n.tr('no_events_or_reminders_scheduled_for'),
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
                    child: const Icon(
                      Icons.event_note_rounded,
                      size: 16,
                      color: AppColors.catWork,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (e.location != null && e.location!.isNotEmpty)
                          Text(
                            e.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: w,
                  ),
                )
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              alignment: Alignment.center,
              child: Text(
                context.l10n.tr('all_caught_up_no_tasks_due'),
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
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final t = tasks[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        borderRadius: BorderRadius.circular(5),
                      ),
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
                              context.l10n.tr('subtasks', {
                                't_completedSubtasksCount':
                                    t.completedSubtasksCount,
                                't_length': t.subtasks.length,
                              }),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (t.priorityColor as Color)
                            .withValues(alpha: 0.15),
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

  Widget _buildQuickMoodCheckIn(
    BuildContext context,
    JournalProvider provider,
  ) {
    final l10n = context.l10n;
    final moods = [
      {'emoji': '😊', 'label': l10n.tr('great_2'), 'mood': JournalMood.great},
      {'emoji': '🙂', 'label': l10n.tr('good'), 'mood': JournalMood.good},
      {'emoji': '😐', 'label': l10n.tr('neutral'), 'mood': JournalMood.neutral},
      {'emoji': '😔', 'label': l10n.tr('low_2'), 'mood': JournalMood.low},
      {'emoji': '😫', 'label': l10n.tr('tough'), 'mood': JournalMood.tough},
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
            l10n.tr('how_are_you_feeling_right_now'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: moods.map((m) {
              final moodEnum = m['mood'] as JournalMood;
              final emoji = m['emoji'] as String;
              final label = m['label'] as String;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final now = DateTime.now();
                      final entry = JournalEntry(
                        id: const Uuid().v4(),
                        title: l10n.tr('mood_check', {'label': label}),
                        content: l10n.tr(
                          'logged_mood_during_everyday_reflection',
                          {'emoji': emoji, 'label': label},
                        ),
                        date: now,
                        mood: moodEnum,
                        tags: [l10n.tr('reflection'), label],
                        createdAt: now,
                        updatedAt: now,
                      );
                      await provider.addJournalEntry(entry);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.tr('logged_feeling_to_diary', {
                                'emoji': emoji,
                                'label': label,
                              }),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 19)),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
