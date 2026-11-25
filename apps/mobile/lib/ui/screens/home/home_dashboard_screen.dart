import 'dart:async';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alarm.dart';
import '../../../data/models/calendar_event.dart';
import '../../../data/models/dashboard_config.dart';
import '../../../data/models/journal_entry.dart';
import '../../../data/models/reminder.dart';
import '../../../data/models/task_item.dart';
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
import '../../widgets/gratitude_jar_sheet.dart';
import '../../widgets/hydration_settings_sheet.dart';
import '../../widgets/mascot_milestone_stamp_overlay.dart';
import '../../widgets/nestin_wordmark.dart';
import '../../widgets/oem_warning_banner.dart';
import '../alarms/alarm_edit_screen.dart';
import '../alarms/alarms_list_screen.dart';
import '../nest/roo_house_screen.dart';
import '../automation/automation_hub_screen.dart';
import '../nest/bird_house_shared.dart';
import '../nest/treehouse_painters.dart';
import '../scout/phone_modes_screen.dart';
import '../search/universal_search_screen.dart';
import '../settings/settings_screen.dart';

/// Decluttered Daily Dashboard strictly focused on "Right Now" via 4 calm,
/// glanceable blocks matching Phase 1 surface & contrast tokens:
/// 1. Compact Greeting + inline Weather / BeforeYouGo strip (borderless)
/// 2. Hero Next Alarm card (Roo `#E04A3A`, tabular clock, toggle & quick test)
/// 3. Unified Today's Agenda & Tasks Due card (max 5 items, 48dp checkboxes,
///    subtle priority dots, "View all" -> Roo's House)
/// 4. 2-Column Quick Check-In Bar (Seren Hydration `+1 Glass` + Echo Mood)
class HomeDashboardScreen extends StatefulWidget {
  final void Function(int tab, [int? subTab]) onNavigateTab;

  /// Optional deterministic clock override for widget tests.
  final DateTime? clockOverride;

  /// Bottom clearance reserving breathing room above the floating pill dock.
  final double bottomOverlayClearance;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateTab,
    this.clockOverride,
    this.bottomOverlayClearance = 56.0,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  static const Color _serenLavender = AppColors.seren;
  static const Color _echoTawny = AppColors.echo;
  static const Color _scoutBlue = AppColors.scout;

  static const List<String> _focusedSectionKeys = [
    DashboardConfig.sectionNextAlarm,
    DashboardConfig.sectionAgenda,
    DashboardConfig.sectionTasks,
    DashboardConfig.sectionWeather,
    DashboardConfig.sectionHydration,
    DashboardConfig.sectionMood,
  ];

  late Timer _ticker;
  late DateTime _now;
  WeatherInfo? _weatherInfo;
  WeatherProviderInterface? _weatherService;

  @override
  void initState() {
    super.initState();
    _now = widget.clockOverride ?? DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.clockOverride == null) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
    _attachWeatherService();
    _loadWeather();
  }

  @override
  void didUpdateWidget(covariant HomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clockOverride != oldWidget.clockOverride) {
      _now = widget.clockOverride ?? DateTime.now();
    }
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

  DateTime get _currentNow => widget.clockOverride ?? _now;

  String _greeting(AppLocalizations l10n) =>
      l10n.greetingForHour(_currentNow.hour);

  bool get _isMorning => _currentNow.hour < 12;

  /// Shared Phase 1/2 clean surface decoration: pure `#FFFFFF` with subtle soft
  /// shadow on `#F4F6F9` in Light Mode; clean `#1A1B20` in Dark Mode (no box-in-a-box).
  BoxDecoration _surfaceCardDecoration(
    BuildContext context, {
    double radius = 20,
    Color? darkTint,
    Color? darkBorderAccent,
  }) {
    final isDark = AppColors.isDark(context);
    if (isDark) {
      return BoxDecoration(
        gradient: darkTint != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(AppColors.darkCard, darkTint, 0.06)!,
                  AppColors.darkCard,
                ],
              )
            : null,
        color: darkTint == null ? AppColors.darkCard : null,
        borderRadius: BorderRadius.circular(radius),
        border: darkBorderAccent != null
            ? Border.all(
                color: darkBorderAccent.withValues(alpha: 0.28),
                width: 1.0,
              )
            : null,
      );
    }

    return BoxDecoration(
      color: AppColors.lightCard,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Borderless full-pill status chip with a leading `6dp` accent dot and crisp
  /// `AppColors.textPrimary(context)` copy (never dark saturated text on dark fills).
  Widget _buildStatusPill(
    BuildContext context, {
    Key? key,
    required Color dotColor,
    required String label,
    bool tabular = false,
  }) {
    final isDark = AppColors.isDark(context);
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                fontFeatures:
                    tabular ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  JournalEntry? _todayMoodEntry(JournalProvider journalProvider) {
    final now = _currentNow;
    for (final entry in journalProvider.journalEntries) {
      if (entry.date.year == now.year &&
          entry.date.month == now.month &&
          entry.date.day == now.day) {
        return entry;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = _currentNow;
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
    final todayTasks = taskProvider.tasksDueToday(now);
    final todayEvents = calendarProvider.eventsForDate(now);
    final activeWeather = bygProvider?.currentWeather ?? _weatherInfo;
    final todayMood = _todayMoodEntry(journalProvider);

    final showAgendaOrTasks = config.showTodayAgenda || config.showTodayTasks;
    final showHydrationCard = config.showHydration && hydrationProvider != null;
    final showMoodCard = config.showQuickJournal;
    final showCheckInBar = showHydrationCard || showMoodCard;

    return Scaffold(
      key: const Key('home_dashboard_screen'),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primaryAdaptive(context),
          backgroundColor: AppColors.cardSurface(context),
          onRefresh: () async {
            await HapticFeedback.mediumImpact();
            await _loadWeather();
            if (mounted && widget.clockOverride == null) {
              setState(() {
                _now = DateTime.now();
              });
            }
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
                // Top Brand Header matching Phase 1 icon language (gear + search + customize)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.24),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.primary,
                              child: const Icon(
                                Icons.wb_twilight_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: NestinWordmark(
                          textKey: Key('dashboard_brand_title'),
                          fontSize: 24,
                        ),
                      ),
                      IconButton(
                        key: const Key('dashboard_customize_btn'),
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(
                          Icons.dashboard_customize_outlined,
                          size: 21,
                        ),
                        tooltip: l10n.tr('customize_cards'),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _showReorderDashboardSheet(context);
                        },
                      ),
                      IconButton(
                        key: const Key('dashboard_search_btn'),
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
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
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.settings_outlined, size: 22),
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

                // Conditional Safety Banners (shown ONLY when actively triggered)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: OemWarningBanner(),
                ),
                _buildImmediateSystemAlertBanner(context, l10n),

                // =============================================================
                // BLOCK 1: Compact Greeting + Inline Weather / BeforeYouGo Strip
                // =============================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _buildGreetingAndWeatherStrip(
                    context,
                    l10n: l10n,
                    config: config,
                    nextAlarm: nextAlarm,
                    todayTasks: todayTasks,
                    todayEvents: todayEvents,
                    weather: activeWeather,
                    bygProvider: bygProvider,
                  ),
                ),

                // =============================================================
                // BLOCK 2: Hero Next Alarm Card (Roo's Domain — #E04A3A)
                // =============================================================
                if (config.showNextAlarm)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _buildNextAlarmHero(
                      context,
                      nextAlarm,
                      alarmProvider,
                      settingsProvider,
                    ),
                  ),

                // =============================================================
                // BLOCK 3: Combined Today's Agenda & Tasks Due (max 5 items)
                // =============================================================
                if (showAgendaOrTasks)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _buildCombinedAgendaAndTasksBlock(
                      context,
                      l10n: l10n,
                      config: config,
                      events: todayEvents,
                      reminders: pendingReminders,
                      tasks: todayTasks,
                      taskProvider: taskProvider,
                      settingsProvider: settingsProvider,
                    ),
                  ),

                // =============================================================
                // BLOCK 4: Quick Check-In Bar (2-Column Hydration & Mood)
                // =============================================================
                if (showCheckInBar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _buildQuickCheckInBar(
                      context,
                      l10n: l10n,
                      hydrationProvider:
                          showHydrationCard ? hydrationProvider : null,
                      journalProvider: showMoodCard ? journalProvider : null,
                      todayMood: todayMood,
                    ),
                  ),

                // Bottom breathing room cleanly clearing the floating pill dock
                SizedBox(height: widget.bottomOverlayClearance),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CONDITIONAL SAFETY ALERT (Phone Mode / Pending Automation Confirmation)
  // ===========================================================================
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

    final accent = activeMode != null
        ? Color(activeMode.colorValue)
        : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: InkWell(
        key: const Key('dashboard_system_alert_banner'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => activeMode != null
                  ? const PhoneModesScreen()
                  : const AutomationHubScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: _surfaceCardDecoration(
            context,
            radius: 18,
            darkTint: accent,
            darkBorderAccent: accent,
          ),
          child: Row(
            children: [
              Icon(
                activeMode != null
                    ? Icons.shield_moon_rounded
                    : Icons.auto_awesome_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeMode != null
                          ? l10n.tr(
                              'dash_mode_active_title',
                              {'name': activeMode.name},
                            )
                          : l10n.tr(
                              'dash_auto_confirm_title',
                              {'count': pendingCount},
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeMode != null
                          ? l10n.tr('dash_mode_active_sub')
                          : l10n.tr('dash_auto_confirm_sub'),
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
              if (activeMode != null)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => dc!.endActivePhoneMode(),
                  child: Text(l10n.tr('dash_end_action')),
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
    );
  }

  // ===========================================================================
  // BLOCK 1: Compact Borderless Greeting + Inline Weather / BeforeYouGo Strip
  // ===========================================================================
  Widget _buildGreetingAndWeatherStrip(
    BuildContext context, {
    required AppLocalizations l10n,
    required DashboardConfig config,
    required Alarm? nextAlarm,
    required List<TaskItem> todayTasks,
    required List<CalendarEvent> todayEvents,
    required WeatherInfo? weather,
    required BeforeYouGoProvider? bygProvider,
  }) {
    final isDark = AppColors.isDark(context);
    final phase = TreehouseDayPhaseX.resolve(_currentNow);
    final showInlineStatus = config.showWeather || config.showBeforeYouGo;
    final preset = bygProvider?.activePreset;
    final weatherVisual = weather != null
        ? BeforeYouGoWeatherBanner.resolveWeatherVisual(context, weather)
        : null;
    final dateFormatted = l10n.formatDate(_currentNow, 'EEEE, MMM d');

    final gradientColors = switch (phase) {
      TreehouseDayPhase.dawn => isDark
          ? const [Color(0xFF28202B), Color(0xFF1A1B24)]
          : const [AppColors.peachSoft, Color(0xFFF3ECF8)],
      TreehouseDayPhase.day => isDark
          ? const [Color(0xFF1A2431), Color(0xFF171A23)]
          : const [Color(0xFFE7F4FD), Color(0xFFF4F8FC)],
      TreehouseDayPhase.sunset => isDark
          ? const [Color(0xFF2B201E), Color(0xFF1D1A26)]
          : const [Color(0xFFFFF0E2), Color(0xFFFCE8EC)],
      TreehouseDayPhase.night => isDark
          ? const [Color(0xFF1A1E2E), Color(0xFF141620)]
          : const [Color(0xFFEAEEF8), Color(0xFFF2EFFA)],
    };

    final bygLabel = preset != null
        ? '${preset.name} ${preset.checkedCount}/${preset.totalCount}'
        : l10n.tr('nest_pill_scout_byg_ready');
    final bygDotColor = (preset != null && preset.allChecked)
        ? AppColors.success
        : _scoutBlue;

    return Container(
      key: const Key('dashboard_greeting_strip'),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        showInlineStatus ? 4 : 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting(l10n)},',
                      key: const Key('dashboard_greeting_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormatted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isMorning || config.showWeather) ...[
                const SizedBox(width: 8),
                InkWell(
                  key: const Key('dashboard_morning_briefing_btn'),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    SystemSound.play(SystemSoundType.click);
                    _showBriefingDialog(
                      context,
                      nextAlarm,
                      todayTasks,
                      todayEvents,
                      weather,
                    );
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(
                            alpha: isDark ? 0.18 : 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wb_sunny_rounded,
                              size: 14,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l10n.tr('read'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (showInlineStatus)
            Row(
              key: const Key('dashboard_weather_byg_strip'),
              children: [
                if (weather != null && config.showWeather)
                  Flexible(
                    flex: 5,
                    child: InkWell(
                      key: const Key('dashboard_inline_weather_tap'),
                      onTap: () => BeforeYouGoSheet.show(context),
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              weatherVisual?.icon ?? Icons.wb_sunny_rounded,
                              size: 15,
                              color: weatherVisual?.color ?? _scoutBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${weather.temperatureCelsius.round()}°C',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                weather.condition,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (weather != null &&
                    config.showWeather &&
                    config.showBeforeYouGo)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '•',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                if (config.showBeforeYouGo)
                  Flexible(
                    flex: 5,
                    child: InkWell(
                      key: const Key('dashboard_inline_byg_tap'),
                      onTap: () => BeforeYouGoSheet.show(context),
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bygDotColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                bygLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
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
      ),
    );
  }

  // ===========================================================================
  // BLOCK 2: Hero Next Alarm Card (Roo's Domain — #E04A3A)
  // ===========================================================================
  Widget _buildNextAlarmHero(
    BuildContext context,
    Alarm? alarm,
    AlarmProvider provider,
    SettingsProvider settingsProvider,
  ) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);

    if (alarm == null) {
      return Container(
        key: const Key('dashboard_next_alarm_hero'),
        padding: const EdgeInsets.all(16),
        decoration: _surfaceCardDecoration(context),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.rooCrimson.withValues(alpha: isDark ? 0.16 : 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.alarm_add_rounded,
                size: 22,
                color: AppColors.rooCrimson,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('no_upcoming_alarms_set'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.tr('set_an_alarm_to_keep_your'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              key: const Key('dashboard_set_alarm_btn'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AlarmEditScreen(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rooCrimson,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              child: Text(
                l10n.tr('dash_set_alarm_cta'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final challenge =
        alarm.effectiveChallenge(settingsProvider.globalChallengeProfile);

    return InkWell(
      key: const Key('dashboard_next_alarm_hero'),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AlarmEditScreen(initialAlarm: alarm),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: _surfaceCardDecoration(
          context,
          darkTint: AppColors.rooCrimson,
          darkBorderAccent: AppColors.rooCrimson,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Borderless category pill + tabular countdown pill
            Row(
              children: [
                Flexible(
                  child: _buildStatusPill(
                    context,
                    key: const Key('dashboard_alarm_category_pill'),
                    dotColor: alarm.category.color,
                    label: l10n.categoryName(alarm.category.type),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildStatusPill(
                      context,
                      key: const Key('dashboard_alarm_countdown_pill'),
                      dotColor: AppColors.accent,
                      label: alarm.timeUntilNext(_currentNow),
                      tabular: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle Row: Large tabular clock (32sp) + label on left, active Switch on right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.formattedTime(
                          use24Hour: settingsProvider.use24Hour,
                        ),
                        key: const Key('dashboard_next_alarm_clock'),
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          color: AppColors.textPrimary(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        alarm.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        challenge.isEnabled
                            ? l10n.tr('challenge', {
                                'challenge_typeLabel': challenge.typeLabel,
                              })
                            : l10n.tr('standard_dismissal'),
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
                SizedBox(
                  height: 48,
                  child: Center(
                    child: Switch.adaptive(
                      key: const Key('dashboard_next_alarm_toggle'),
                      value: alarm.isEnabled,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.rooCrimson,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        provider.toggleAlarm(alarm.id, val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Bottom Compact Action Bar: Test Ring pill + Open Alarms link (48dp height)
            Row(
              children: [
                InkWell(
                  key: const Key('dashboard_alarm_test_btn'),
                  onTap: () => provider.triggerAlarm(alarm),
                  borderRadius: BorderRadius.circular(999),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.rooCrimson.withValues(
                            alpha: isDark ? 0.18 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 15,
                              color: AppColors.rooCrimson,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.tr('test_ring'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  key: const Key('dashboard_alarm_open_btn'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AlarmsListScreen(),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.tr('dash_open_alarms'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textSecondary(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BLOCK 3: Unified Today's Agenda & Tasks Due (max 5 items, 48dp checkboxes)
  // ===========================================================================
  Widget _buildCombinedAgendaAndTasksBlock(
    BuildContext context, {
    required AppLocalizations l10n,
    required DashboardConfig config,
    required List<CalendarEvent> events,
    required List<Reminder> reminders,
    required List<TaskItem> tasks,
    required TaskProvider taskProvider,
    required SettingsProvider settingsProvider,
  }) {
    final visibleEvents = config.showTodayAgenda ? events : const <CalendarEvent>[];
    final visibleReminders = config.showTodayAgenda ? reminders : const <Reminder>[];
    final visibleTasks = config.showTodayTasks ? tasks : const <TaskItem>[];

    final totalCount =
        visibleEvents.length + visibleReminders.length + visibleTasks.length;

    // Balance combined list up to max 5 visible items
    final rows = <Widget>[];
    const maxItems = 5;

    final reservedForTasks = visibleTasks.isEmpty
        ? 0
        : (visibleTasks.length >= 2 ? 2 : visibleTasks.length);
    final agendaBudget = maxItems - reservedForTasks;
    final takenEvents = visibleEvents.take(agendaBudget).toList();
    final remBudget = agendaBudget - takenEvents.length;
    final takenReminders = visibleReminders.take(remBudget).toList();
    final taskBudget = maxItems - takenEvents.length - takenReminders.length;
    final takenTasks = visibleTasks.take(taskBudget).toList();

    for (final e in takenEvents) {
      rows.add(_buildAgendaEventRow(context, e));
    }
    for (final r in takenReminders) {
      rows.add(_buildAgendaReminderRow(context, r, settingsProvider));
    }
    for (final t in takenTasks) {
      rows.add(_buildAgendaTaskRow(context, l10n, t, taskProvider));
    }

    return Column(
      key: const Key('dashboard_agenda_tasks_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clean section header with tabular count pill & subtle "View all" -> Roo's House
        Row(
          children: [
            Flexible(
              child: Text(
                l10n.tr('today_s_agenda'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusPill(
              context,
              key: const Key('dashboard_agenda_count_pill'),
              dotColor: AppColors.catWork,
              label: '$totalCount',
              tabular: true,
            ),
            const Spacer(),
            InkWell(
              key: const Key('dashboard_agenda_view_all_btn'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RooHouseScreen(),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.tr('dash_view_all'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.adaptive(
                            context,
                            dark: AppColors.primaryLight,
                            light: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.adaptive(
                          context,
                          dark: AppColors.primaryLight,
                          light: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),

        // Single clean surface card (zero nested bordered cards)
        Container(
          key: const Key('dashboard_agenda_tasks_card'),
          padding: rows.isEmpty
              ? const EdgeInsets.all(16)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: _surfaceCardDecoration(context),
          child: rows.isEmpty
              ? Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.tr('dash_today_clear'),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      rows[i],
                      if (i < rows.length - 1)
                        Divider(
                          height: 1,
                          indent: 48,
                          endIndent: 8,
                          color: AppColors.border(context).withValues(alpha: 0.55),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAgendaEventRow(BuildContext context, CalendarEvent event) {
    return InkWell(
      onTap: () => widget.onNavigateTab(1, 2),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.catWork.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    size: 16,
                    color: AppColors.catWork,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (event.location != null && event.location!.isNotEmpty)
                      Text(
                        event.location!,
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
              Text(
                event.formattedTime(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgendaReminderRow(
    BuildContext context,
    Reminder reminder,
    SettingsProvider settings,
  ) {
    return InkWell(
      onTap: () => widget.onNavigateTab(1, 1),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: reminder.category.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 16,
                    color: reminder.category.color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reminder.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                reminder.formattedDueTime(use24Hour: settings.use24Hour),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgendaTaskRow(
    BuildContext context,
    AppLocalizations l10n,
    TaskItem task,
    TaskProvider taskProvider,
  ) {
    return Row(
      key: Key('dashboard_task_row_${task.id}'),
      children: [
        // Explicit 48x48dp inline checkbox tap target
        SizedBox(
          width: 48,
          height: 48,
          child: Checkbox(
            key: Key('dashboard_task_checkbox_${task.id}'),
            value: task.isCompleted,
            activeColor: AppColors.catWork,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: (_) {
              HapticFeedback.lightImpact();
              taskProvider.toggleTaskCompletion(task.id);
            },
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              taskProvider.toggleTaskCompletion(task.id);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted
                          ? AppColors.textSecondary(context)
                          : AppColors.textPrimary(context),
                    ),
                  ),
                  if (task.subtasks.isNotEmpty)
                    Text(
                      l10n.tr('subtasks', {
                        't_completedSubtasksCount': task.completedSubtasksCount,
                        't_length': task.subtasks.length,
                      }),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Subtle priority dot instead of heavy bordered tag
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            label: task.localizedPriorityLabel,
            child: Tooltip(
              message: task.localizedPriorityLabel,
              child: Container(
                key: Key('dashboard_task_priority_dot_${task.id}'),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.priorityColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BLOCK 4: Quick Check-In Bar (2-Column Hydration & Mood Calm Strip)
  // ===========================================================================
  Widget _buildQuickCheckInBar(
    BuildContext context, {
    required AppLocalizations l10n,
    required HydrationProvider? hydrationProvider,
    required JournalProvider? journalProvider,
    required JournalEntry? todayMood,
  }) {
    final hydrationCard = hydrationProvider != null
        ? _buildHydrationCheckInTile(context, l10n, hydrationProvider)
        : null;
    final moodCard = journalProvider != null
        ? _buildMoodCheckInTile(context, l10n, journalProvider, todayMood)
        : null;

    if (hydrationCard != null && moodCard != null) {
      return IntrinsicHeight(
        key: const Key('dashboard_quick_checkin_bar'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: hydrationCard),
            const SizedBox(width: 12),
            Expanded(child: moodCard),
          ],
        ),
      );
    }

    return KeyedSubtree(
      key: const Key('dashboard_quick_checkin_bar'),
      child: hydrationCard ?? moodCard ?? const SizedBox.shrink(),
    );
  }

  Widget _buildHydrationCheckInTile(
    BuildContext context,
    AppLocalizations l10n,
    HydrationProvider hydration,
  ) {
    final isDark = AppColors.isDark(context);
    final goalMet = hydration.isGoalMet;
    final accent = goalMet ? AppColors.success : _serenLavender;

    return InkWell(
      key: const Key('dashboard_quick_hydration_strip'),
      onTap: () => HydrationSettingsSheet.show(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _surfaceCardDecoration(
          context,
          darkTint: accent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.water_drop_rounded,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.tr('dash_quick_hydration'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${hydration.glassesConsumed}/${hydration.dailyGoalGlasses}',
                  key: const Key('dashboard_hydration_counter'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: hydration.progressFraction,
                    backgroundColor: AppColors.trackSurface(context),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
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
                  backgroundColor: _serenLavender.withValues(
                    alpha: isDark ? 0.20 : 0.12,
                  ),
                  foregroundColor: AppColors.textPrimary(context),
                  elevation: 0,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.tr('dash_add_glass_btn'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodCheckInTile(
    BuildContext context,
    AppLocalizations l10n,
    JournalProvider journalProvider,
    JournalEntry? todayMood,
  ) {
    final isDark = AppColors.isDark(context);

    return InkWell(
      key: const Key('dashboard_quick_mood_strip'),
      onTap: () => _showQuickMoodSheet(context, journalProvider),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _surfaceCardDecoration(
          context,
          darkTint: _echoTawny,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      size: 16,
                      color: _echoTawny,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.tr('dash_mood_label'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (todayMood != null)
                  _buildStatusPill(
                    context,
                    key: const Key('dashboard_today_mood_pill'),
                    dotColor: _echoTawny,
                    label: '${todayMood.mood.emoji} ${todayMood.mood.label}',
                  )
                else
                  Text(
                    l10n.tr('dash_mood_prompt'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('dashboard_mood_checkin_btn'),
                onPressed: () => _showQuickMoodSheet(context, journalProvider),
                style: FilledButton.styleFrom(
                  backgroundColor: _echoTawny.withValues(
                    alpha: isDark ? 0.20 : 0.12,
                  ),
                  foregroundColor: AppColors.textPrimary(context),
                  elevation: 0,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _echoTawny,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.tr('dash_mood_checkin_cta'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickMoodSheet(
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

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.scrimHandle(sheetCtx),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      size: 20,
                      color: _echoTawny,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.tr('how_are_you_feeling_right_now'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(sheetCtx),
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        widget.onNavigateTab(3, 0);
                      },
                      child: Text(l10n.tr('dash_open_diary')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: moods.map((m) {
                    final moodEnum = m['mood'] as JournalMood;
                    final emoji = m['emoji'] as String;
                    final label = m['label'] as String;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          key: Key('dashboard_mood_option_${moodEnum.name}'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            Navigator.of(sheetCtx).pop();
                            final now = _currentNow;
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
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 68),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.elevatedSurface(sheetCtx),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 5),
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(sheetCtx),
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
          ),
        );
      },
    );
  }

  // ===========================================================================
  // MORNING BRIEFING DIALOG (Preserved)
  // ===========================================================================
  void _showBriefingDialog(
    BuildContext context,
    Alarm? nextAlarm,
    List<TaskItem> tasks,
    List<CalendarEvent> events,
    WeatherInfo? weather,
  ) {
    final l10n = context.l10n;
    final now = _currentNow;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final accentInk = AppColors.adaptive(
          ctx,
          dark: AppColors.accent,
          light: AppColors.twillDark,
        );
        return AlertDialog(
          backgroundColor: AppColors.cardSurface(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
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
                  'l10n_d': l10n.formatDate(now, 'EEEE, MMM d'),
                  'l10n_MMM': l10n.formatDate(now, 'EEEE, d MMM'),
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
                minimumSize: const Size(48, 48),
                shape: const StadiumBorder(),
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

  // ===========================================================================
  // CUSTOMIZE DASHBOARD SHEET (Preserves DashboardConfig keys)
  // ===========================================================================
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
                'color': _serenLavender,
                'isEnabled': config.showHydration,
                'toggle': (bool v) => provider.toggleHydration(v),
              },
              DashboardConfig.sectionMood: {
                'title': l10n.tr('everyday_reflection'),
                'icon': Icons.mood_rounded,
                'color': _echoTawny,
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
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.scrimHandle(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
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
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
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
                    const SizedBox(height: 2),
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
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.elevatedSurface(context),
                              borderRadius: BorderRadius.circular(14),
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
                                SizedBox(
                                  height: 48,
                                  child: Switch.adaptive(
                                    value: meta['isEnabled'] as bool,
                                    onChanged: (val) {
                                      HapticFeedback.lightImpact();
                                      (meta['toggle'] as Function(bool))(val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
}
