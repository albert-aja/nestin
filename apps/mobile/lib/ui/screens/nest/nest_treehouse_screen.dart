import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_preferences.dart';
import '../../../data/services/weather_service.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/before_you_go_provider.dart';
import '../../../providers/hobby_provider.dart';
import '../../../providers/hydration_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/money_provider.dart';
import '../../../providers/note_provider.dart';
import '../../../providers/reading_provider.dart';
import '../../../providers/seren_relaxation_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/task_provider.dart';
import '../../widgets/before_you_go_weather_banner.dart';
import '../search/universal_search_screen.dart';
import '../settings/settings_screen.dart';
import 'bird_house_shared.dart';
import 'echo_house_screen.dart';
import 'nest_treehouse_scene_view.dart';
import 'pippin_house_screen.dart';
import 'roo_house_screen.dart';
import 'scout_house_screen.dart';
import 'seren_house_screen.dart';
import 'twill_house_screen.dart';

/// Hybrid "Nest" Treehouse Screen — supports switching cleanly between:
/// 1. **Rooms Grid View (Default):** Streamlined brand app bar, bold greeting,
///    slim quick-status pill (Next Alarm • Weather), and a vibrant 2×3 bird
///    rooms grid with asymmetric text-left / sprite-right layout, high-contrast
///    status pills, and glowing domain-accent borders.
/// 2. **Treehouse Scene View:** Full-bleed interactive treehouse layout with
///    all 6 birds positioned at proportional coordinates and floating dark-glass
///    status pills.
class NestTreehouseScreen extends StatefulWidget {
  /// Whether the Nest tab is currently the active tab in [MainNavigationScreen].
  /// Passed to [NestTreehouseSceneView] so animations pause cleanly off-tab.
  final bool isActive;

  /// Optional deterministic time override for testing 4-phase visuals & clock.
  final DateTime? clockOverride;

  const NestTreehouseScreen({
    super.key,
    this.isActive = true,
    this.clockOverride,
  });

  @override
  State<NestTreehouseScreen> createState() => _NestTreehouseScreenState();
}

class _NestTreehouseScreenState extends State<NestTreehouseScreen> {
  WeatherProviderInterface? _weatherService;
  WeatherInfo? _weatherInfo;

  /// Fallback in-memory toggle if [SettingsProvider] is absent in isolated tests.
  NestViewMode _fallbackViewMode = NestViewMode.roomsGrid;

  @override
  void initState() {
    super.initState();
    _weatherService =
        tryReadProvider<WeatherProviderInterface>(context) ??
            LocalWeatherService();
    final service = _weatherService;
    if (service is LocalWeatherService) {
      service.addWeatherListener(_onWeatherChanged);
    }
    _loadWeather();
  }

  void _onWeatherChanged() {
    if (mounted) _loadWeather();
  }

  Future<void> _loadWeather() async {
    final info =
        await (_weatherService ?? LocalWeatherService()).getCurrentWeather();
    if (mounted) setState(() => _weatherInfo = info);
  }

  @override
  void dispose() {
    final service = _weatherService;
    if (service is LocalWeatherService) {
      service.removeWeatherListener(_onWeatherChanged);
    }
    super.dispose();
  }

  void _toggleViewMode(SettingsProvider? settings) {
    HapticFeedback.selectionClick();
    if (settings != null) {
      settings.toggleNestViewMode();
    } else {
      setState(() {
        _fallbackViewMode = _fallbackViewMode == NestViewMode.roomsGrid
            ? NestViewMode.treehouseScene
            : NestViewMode.roomsGrid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = widget.clockOverride ?? DateTime.now();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final settings = tryWatchProvider<SettingsProvider>(context);
    final viewMode = settings?.nestViewMode ?? _fallbackViewMode;
    final isSceneMode = viewMode == NestViewMode.treehouseScene;

    final alarmProvider = tryWatchProvider<AlarmProvider>(context);
    final taskProvider = tryWatchProvider<TaskProvider>(context);
    final bygProvider = tryWatchProvider<BeforeYouGoProvider>(context);
    final hydrationProvider = tryWatchProvider<HydrationProvider>(context);
    final readingProvider = tryWatchProvider<ReadingProvider>(context);
    final hobbyProvider = tryWatchProvider<HobbyProvider>(context);
    final noteProvider = tryWatchProvider<NoteProvider>(context);
    final moneyProvider = tryWatchProvider<MoneyProvider>(context);
    final journalProvider = tryWatchProvider<JournalProvider>(context);
    final serenProvider = tryWatchProvider<SerenRelaxationProvider>(context);

    final use24Hour = settings?.use24Hour ?? true;
    final nextAlarm = alarmProvider?.nextUpcomingAlarm;
    final nextAlarmTime = nextAlarm?.formattedTime(use24Hour: use24Hour);
    final todayTasksCount = taskProvider?.tasksDueToday(now).length ?? 0;
    final weather = bygProvider?.currentWeather ?? _weatherInfo;
    final glasses = hydrationProvider?.glassesConsumed ?? 0;
    final goalGlasses = hydrationProvider?.dailyGoalGlasses ?? 8;
    final notesCount = noteProvider?.activeNotes.length ?? 0;
    final pebblesCount = journalProvider?.getGratitudePebbles().length ?? 0;
    final isSerenPlaying = (serenProvider?.isMixerPlaying ?? false) ||
        (serenProvider?.isTtsPlaying ?? false) ||
        (serenProvider?.isGuidedSessionRunning ?? false);
    final hasLoggedTodayReflection =
        journalProvider?.hasEntryForDate(now) ?? false;

    void openRoo() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RooHouseScreen()),
        );
    void openScout() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ScoutHouseScreen()),
        );
    void openSeren() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SerenHouseScreen()),
        );
    void openPippin() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PippinHouseScreen()),
        );
    void openTwill() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TwillHouseScreen()),
        );
    void openEcho() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EchoHouseScreen()),
        );

    final Widget bodyContent;
    if (isSceneMode) {
      final sceneBirds = [
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_roo'),
          name: 'Roo',
          compactMetric: _rooCompactMetric(l10n, nextAlarmTime, todayTasksCount),
          accentColor: RooHouseScreen.rooColor,
          spriteAsset: 'assets/mascots/sprites/roo/welcome.png',
          blinkFrames: TreehouseMascotFrameSheets.rooBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.rooFlutterFrames,
          fallbackIcon: Icons.alarm_on_rounded,
          fx: TreehouseSceneAnchors.rooPerch.dx,
          fy: TreehouseSceneAnchors.rooPerch.dy,
          phaseOffset: 0.0,
          onTap: openRoo,
        ),
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_echo'),
          name: 'Echo',
          compactMetric: pebblesCount > 0
              ? l10n.tr('nest_scene_pill_echo_pebbles', {'count': pebblesCount})
              : l10n.tr('nest_scene_pill_echo_diary'),
          accentColor: EchoHouseScreen.echoColor,
          spriteAsset: 'assets/mascots/sprites/echo/reflect.png',
          blinkFrames: TreehouseMascotFrameSheets.echoBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.echoFlutterFrames,
          fallbackIcon: Icons.auto_stories_rounded,
          fx: TreehouseSceneAnchors.echoPerch.dx,
          fy: TreehouseSceneAnchors.echoPerch.dy,
          phaseOffset: 1.05,
          onTap: openEcho,
        ),
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_scout'),
          name: 'Scout',
          compactMetric: _scoutCompactMetric(l10n, weather, bygProvider),
          accentColor: ScoutHouseScreen.scoutColor,
          spriteAsset: 'assets/mascots/sprites/scout/briefing.png',
          blinkFrames: TreehouseMascotFrameSheets.scoutBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.scoutFlutterFrames,
          fallbackIcon: Icons.explore_rounded,
          fx: TreehouseSceneAnchors.scoutPerch.dx,
          fy: TreehouseSceneAnchors.scoutPerch.dy,
          phaseOffset: 2.1,
          onTap: openScout,
        ),
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_seren'),
          name: 'Seren',
          compactMetric: l10n.tr('nest_scene_pill_seren_glasses', {
            'glasses': glasses,
            'goal': goalGlasses,
          }),
          accentColor: SerenHouseScreen.serenColor,
          spriteAsset: 'assets/mascots/sprites/seren/hello.png',
          blinkFrames: TreehouseMascotFrameSheets.serenBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.serenFlutterFrames,
          fallbackIcon: Icons.spa_rounded,
          fx: TreehouseSceneAnchors.serenPerch.dx,
          fy: TreehouseSceneAnchors.serenPerch.dy,
          phaseOffset: 3.15,
          onTap: openSeren,
        ),
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_pippin'),
          name: 'Pippin',
          compactMetric: _pippinCompactMetric(
            l10n,
            readingProvider,
            hobbyProvider,
          ),
          accentColor: PippinHouseScreen.pippinColor,
          spriteAsset: 'assets/mascots/sprites/pippin/discover.png',
          blinkFrames: TreehouseMascotFrameSheets.pippinBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.pippinFlutterFrames,
          fallbackIcon: Icons.menu_book_rounded,
          fx: TreehouseSceneAnchors.pippinPerch.dx,
          fy: TreehouseSceneAnchors.pippinPerch.dy,
          phaseOffset: 4.2,
          onTap: openPippin,
        ),
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_twill'),
          name: 'Twill',
          compactMetric: l10n.tr('nest_scene_pill_twill_notes', {
            'count': notesCount,
          }),
          accentColor: TwillHouseScreen.twillColor,
          spriteAsset: 'assets/mascots/sprites/twill/organized.png',
          blinkFrames: TreehouseMascotFrameSheets.twillBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.twillFlutterFrames,
          fallbackIcon: Icons.edit_note_rounded,
          fx: TreehouseSceneAnchors.twillPerch.dx,
          fy: TreehouseSceneAnchors.twillPerch.dy,
          phaseOffset: 5.25,
          onTap: openTwill,
        ),
      ];

      bodyContent = NestTreehouseSceneView(
        key: const ValueKey('nest_mode_scene'),
        phase: settings?.treehousePhaseOverride,
        onSelectPhaseOverride: settings != null
            ? (nextPhase) => settings.setTreehousePhaseOverride(nextPhase)
            : null,
        clockOverride: widget.clockOverride,
        isActive: widget.isActive,
        nextAlarmTime: nextAlarmTime,
        weather: weather,
        isSerenPlaying: isSerenPlaying,
        hasLoggedTodayReflection: hasLoggedTodayReflection,
        birds: sceneBirds,
        onOpenRooHouse: openRoo,
        onOpenScoutHouse: openScout,
      );
    } else {
      // Rooms Grid View (Default)
      final rooStatus = _rooStatusText(l10n, nextAlarmTime, todayTasksCount);
      final scoutStatus = _scoutStatusText(l10n, weather, bygProvider);
      final serenStatus = l10n.tr('nest_pill_seren_short', {
        'glasses': glasses,
        'goal': goalGlasses,
      });
      final pippinStatus = _pippinStatusText(
        l10n,
        readingProvider,
        hobbyProvider,
      );
      final twillStatus = _twillStatusText(l10n, notesCount, moneyProvider);
      final echoStatus = pebblesCount > 0
          ? l10n.tr('nest_pill_echo_pebbles', {'count': pebblesCount})
          : l10n.tr('nest_pill_echo_short');

      final roomCards = [
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_roo'),
          name: 'Roo',
          subtitle: l10n.tr('nest_roo_subtitle'),
          statusPill: rooStatus,
          accentColor: RooHouseScreen.rooColor,
          spriteAsset: 'assets/mascots/sprites/roo/welcome.png',
          fallbackIcon: Icons.alarm_on_rounded,
          onTap: openRoo,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_scout'),
          name: 'Scout',
          subtitle: l10n.tr('nest_scout_subtitle'),
          statusPill: scoutStatus,
          accentColor: ScoutHouseScreen.scoutColor,
          spriteAsset: 'assets/mascots/sprites/scout/briefing.png',
          fallbackIcon: Icons.explore_rounded,
          onTap: openScout,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_seren'),
          name: 'Seren',
          subtitle: l10n.tr('nest_seren_subtitle'),
          statusPill: serenStatus,
          accentColor: SerenHouseScreen.serenColor,
          spriteAsset: 'assets/mascots/sprites/seren/hello.png',
          fallbackIcon: Icons.spa_rounded,
          onTap: openSeren,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_pippin'),
          name: 'Pippin',
          subtitle: l10n.tr('nest_pippin_subtitle'),
          statusPill: pippinStatus,
          accentColor: PippinHouseScreen.pippinColor,
          spriteAsset: 'assets/mascots/sprites/pippin/discover.png',
          fallbackIcon: Icons.menu_book_rounded,
          onTap: openPippin,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_twill'),
          name: 'Twill',
          subtitle: l10n.tr('nest_twill_subtitle'),
          statusPill: twillStatus,
          accentColor: TwillHouseScreen.twillColor,
          spriteAsset: 'assets/mascots/sprites/twill/organized.png',
          fallbackIcon: Icons.edit_note_rounded,
          onTap: openTwill,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_echo'),
          name: 'Echo',
          subtitle: l10n.tr('nest_echo_subtitle'),
          statusPill: echoStatus,
          accentColor: EchoHouseScreen.echoColor,
          spriteAsset: 'assets/mascots/sprites/echo/reflect.png',
          fallbackIcon: Icons.auto_stories_rounded,
          onTap: openEcho,
        ),
      ];

      bodyContent = ListView(
        key: const ValueKey('nest_mode_grid'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          // Bold Time-of-Day Greeting directly beneath AppBar
          Text(
            '${l10n.greetingForHour(now.hour)},',
            key: const Key('nest_greeting_text'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 10),

          // Slim Quick-Status Pill (Next Alarm • Weather)
          _buildSlimStatusPill(
            context,
            l10n: l10n,
            nextAlarmTime: nextAlarmTime,
            weather: weather,
            onTapAlarm: openRoo,
            onTapWeather: openScout,
          ),
          const SizedBox(height: 14),

          // Compact 2×3 Bird Rooms Grid
          BirdToolGrid(
            spacing: 12,
            tiles: roomCards,
          ),
        ],
      );
    }

    final brandWarmInk = AppColors.adaptive(
      context,
      dark: const Color(0xFFFFB86C),
      light: AppColors.primaryDark,
    );

    return Scaffold(
      key: const Key('nest_treehouse_screen'),
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          'Nestin',
          key: const Key('nest_brand_title'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: brandWarmInk,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('nest_view_mode_toggle_btn'),
            icon: Icon(
              isSceneMode ? Icons.grid_view_rounded : Icons.park_rounded,
            ),
            tooltip: isSceneMode
                ? l10n.tr('nest_switch_to_grid')
                : l10n.tr('nest_switch_to_scene'),
            onPressed: () => _toggleViewMode(settings),
          ),
          IconButton(
            key: const Key('nest_search_btn'),
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n.tr('universal_search'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const UniversalSearchScreen(),
              ),
            ),
          ),
          IconButton(
            key: const Key('nest_settings_btn'),
            icon: const Icon(Icons.tune_rounded),
            tooltip: l10n.tr('settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration:
            disableAnimations ? Duration.zero : const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: bodyContent,
      ),
    );
  }

  Widget _buildSlimStatusPill(
    BuildContext context, {
    required AppLocalizations l10n,
    required String? nextAlarmTime,
    required WeatherInfo? weather,
    required VoidCallback onTapAlarm,
    required VoidCallback onTapWeather,
  }) {
    final weatherVisual = weather != null
        ? BeforeYouGoWeatherBanner.resolveWeatherVisual(context, weather)
        : null;

    final alarmLabel = nextAlarmTime != null
        ? l10n.tr('nest_pill_next_alarm', {'time': nextAlarmTime})
        : l10n.tr('nest_status_no_alarm');

    return Container(
      key: const Key('nest_slim_status_pill'),
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Flexible(
            flex: weather != null ? 5 : 1,
            child: InkWell(
              key: const Key('nest_slim_pill_alarm_tap'),
              onTap: onTapAlarm,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.alarm_rounded,
                    size: 15,
                    color: RooHouseScreen.rooColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      alarmLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (weather != null) ...[
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
            Flexible(
              flex: 5,
              child: InkWell(
                key: const Key('nest_slim_pill_weather_tap'),
                onTap: onTapWeather,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      weatherVisual?.icon ?? Icons.wb_sunny_rounded,
                      size: 15,
                      color:
                          weatherVisual?.color ?? ScoutHouseScreen.scoutColor,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${weather.temperatureCelsius.round()}°C ${weather.condition}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _rooCompactMetric(
    AppLocalizations l10n,
    String? nextAlarmTime,
    int todayTasksCount,
  ) {
    if (nextAlarmTime != null) return nextAlarmTime;
    if (todayTasksCount > 0) {
      return l10n.tr('nest_scene_pill_roo_tasks', {'count': todayTasksCount});
    }
    return l10n.tr('nest_scene_pill_roo_quiet');
  }

  String _scoutCompactMetric(
    AppLocalizations l10n,
    WeatherInfo? weather,
    BeforeYouGoProvider? bygProvider,
  ) {
    if (weather != null) return '${weather.temperatureCelsius.round()}°C';
    final preset = bygProvider?.activePreset;
    if (preset != null) {
      return '${preset.checkedCount}/${preset.totalCount}';
    }
    return l10n.tr('qc_action_before_you_go');
  }

  String _pippinCompactMetric(
    AppLocalizations l10n,
    ReadingProvider? reading,
    HobbyProvider? hobby,
  ) {
    final activeBook = reading?.primaryActiveBook;
    if (activeBook != null && activeBook.safeCurrentPage > 0) {
      return l10n.tr('nest_scene_pill_pippin_page', {
        'page': activeBook.safeCurrentPage,
      });
    }
    final hours = hobby?.totalCumulativeHours ?? 0;
    if (hours > 0) {
      return l10n.tr('nest_scene_pill_pippin_hobby', {
        'hours': hours.toStringAsFixed(0),
      });
    }
    return l10n.tr('nest_scene_pill_pippin_discover');
  }

  String _rooStatusText(
    AppLocalizations l10n,
    String? nextAlarmTime,
    int todayTasksCount,
  ) {
    if (nextAlarmTime != null && todayTasksCount > 0) {
      return l10n.tr('nest_pill_roo_alarm_tasks', {
        'time': nextAlarmTime,
        'count': todayTasksCount,
      });
    }
    if (nextAlarmTime != null) {
      return l10n.tr('nest_pill_roo_alarm_only', {'time': nextAlarmTime});
    }
    if (todayTasksCount > 0) {
      return l10n.tr('nest_pill_roo_tasks_only', {'count': todayTasksCount});
    }
    return l10n.tr('nest_pill_roo_quiet');
  }

  String _scoutStatusText(
    AppLocalizations l10n,
    WeatherInfo? weather,
    BeforeYouGoProvider? bygProvider,
  ) {
    final preset = bygProvider?.activePreset;
    if (preset != null && preset.allChecked && preset.totalCount > 0) {
      return l10n.tr('nest_pill_scout_byg_ready');
    }
    if (weather != null) {
      return l10n.tr('nest_pill_scout_weather', {
        'temp': weather.temperatureCelsius.round(),
      });
    }
    if (preset != null) {
      return l10n.tr('nest_pill_scout_ready', {
        'checked': preset.checkedCount,
        'total': preset.totalCount,
      });
    }
    return l10n.tr('nest_pill_scout_byg_ready');
  }

  String _pippinStatusText(
    AppLocalizations l10n,
    ReadingProvider? reading,
    HobbyProvider? hobby,
  ) {
    final activeBook = reading?.primaryActiveBook;
    if (activeBook != null && activeBook.safeCurrentPage > 0) {
      return l10n.tr('nest_pill_pippin_reading_short', {
        'page': activeBook.safeCurrentPage,
      });
    }
    final hours = hobby?.totalCumulativeHours ?? 0;
    if (hours > 0) {
      return l10n.tr('nest_pill_pippin_hobby_short', {
        'hours': hours.toStringAsFixed(0),
      });
    }
    return l10n.tr('nest_pill_pippin_default');
  }

  String _twillStatusText(
    AppLocalizations l10n,
    int notesCount,
    MoneyProvider? money,
  ) {
    return l10n.tr('nest_pill_twill_notes', {'notes': notesCount});
  }
}

class _TreehouseRoomCard extends StatelessWidget {
  final Key cardKey;
  final String name;
  final String subtitle;
  final String statusPill;
  final Color accentColor;
  final String spriteAsset;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  const _TreehouseRoomCard({
    required this.cardKey,
    required this.name,
    required this.subtitle,
    required this.statusPill,
    required this.accentColor,
    required this.spriteAsset,
    required this.fallbackIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final surface = AppColors.cardSurface(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 390;
    final cardWidth = ((screenWidth - 32 - 12) / 2).clamp(136.0, 220.0);
    final targetAspect = isNarrow ? 1.06 : 1.10;
    final minCardHeight = (cardWidth / targetAspect).clamp(138.0, 166.0);
    final spriteSize = isNarrow ? 62.0 : 70.0;

    return InkWell(
      key: cardKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: BoxConstraints(minHeight: minCardHeight),
        padding: const EdgeInsets.fromLTRB(13, 13, 10, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Color.lerp(surface, accentColor, 0.06)!,
                    surface,
                  ]
                : [
                    surface,
                    Color.lerp(surface, accentColor, 0.03)!,
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.75 : 0.55),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.22 : 0.10),
              blurRadius: isDark ? 14 : 10,
              spreadRadius: 0,
              offset: isDark ? Offset.zero : const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Left-aligned Name + 2-line Subtitle, Right-side Sprite
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isNarrow ? 18 : 19.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: spriteSize,
                  height: spriteSize,
                  child: Image.asset(
                    spriteAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      fallbackIcon,
                      size: 36,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bottom Row: Left-aligned high-contrast status pill
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.28 : 0.22),
                  width: 0.8,
                ),
              ),
              child: Text(
                statusPill,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
