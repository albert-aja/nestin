import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/money_budget.dart';
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
import '../../../providers/routine_provider.dart';
import '../../../providers/seren_relaxation_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/task_provider.dart';
import '../../widgets/animated_mascot_sprite.dart';
import '../../widgets/before_you_go_sheet.dart';
import '../../widgets/before_you_go_weather_banner.dart';
import '../../widgets/gratitude_jar_sheet.dart';
import '../../widgets/nestin_wordmark.dart';
import '../../widgets/quick_capture_sheet.dart';
import '../../widgets/reading_tracker_sheet.dart';
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
/// 1. **Rooms Grid View (Default):** Borderless soft time-of-day gradient
///    header with inline Next Alarm & Weather status, and a 2×3 bird rooms
///    grid with ~25% scaled sprites anchored on soft radial domain halos,
///    borderless full-pill status chips with 6dp accent dots, and crisp Light
///    Mode `#FFFFFF` card depth.
/// 2. **Illustrated 6-Room Cutaway Treehouse View:** Transparent floating top
///    bar over the illustrated sky, full cutaway room tap/long-press zones,
///    reactive provider-driven bird sprites, and 24dp extra FAB bottom
///    clearance above the raised `+` Quick Capture button.
class NestTreehouseScreen extends StatefulWidget {
  /// Whether the Nest tab is currently the active tab in [MainNavigationScreen].
  /// Passed to [NestTreehouseSceneView] so animations pause cleanly off-tab.
  final bool isActive;

  /// Optional deterministic time override for testing 4-phase visuals & clock.
  final DateTime? clockOverride;

  /// Bottom overlay clearance above the dock (default `40dp`: `16dp` raised
  /// FAB overhang + `24dp` extra breathing room).
  final double bottomOverlayClearance;

  const NestTreehouseScreen({
    super.key,
    this.isActive = true,
    this.clockOverride,
    this.bottomOverlayClearance = 40.0,
  });

  @override
  State<NestTreehouseScreen> createState() => _NestTreehouseScreenState();
}

class _NestTreehouseScreenState extends State<NestTreehouseScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _gridAmbientController;
  WeatherProviderInterface? _weatherService;
  WeatherInfo? _weatherInfo;
  bool _appResumed = true;
  bool _disableAnimations = false;
  bool _lastIsSceneMode = false;

  /// Fallback in-memory toggle if [SettingsProvider] is absent in isolated tests.
  NestViewMode _fallbackViewMode = NestViewMode.roomsGrid;

  /// Remembers the last alarm toggled via Roo long-press so a second long-press
  /// restores that same alarm seamlessly.
  String? _lastToggledAlarmId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gridAmbientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _weatherService =
        tryReadProvider<WeatherProviderInterface>(context) ??
            LocalWeatherService();
    final service = _weatherService;
    if (service is LocalWeatherService) {
      service.addWeatherListener(_onWeatherChanged);
    }
    _loadWeather();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final settings = tryReadProvider<SettingsProvider>(context);
    _lastIsSceneMode =
        (settings?.nestViewMode ?? _fallbackViewMode) ==
        NestViewMode.treehouseScene;
    _syncGridController();
  }

  @override
  void didUpdateWidget(covariant NestTreehouseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _syncGridController();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    setState(() => _appResumed = resumed);
    _syncGridController();
  }

  void _syncGridController({bool? isSceneMode}) {
    if (isSceneMode != null) {
      _lastIsSceneMode = isSceneMode;
    }
    final shouldRun =
        widget.isActive && !_lastIsSceneMode && _appResumed && !_disableAnimations;
    if (shouldRun) {
      if (!_gridAmbientController.isAnimating) {
        _gridAmbientController.repeat();
      }
    } else {
      if (_gridAmbientController.isAnimating) {
        _gridAmbientController.stop(canceled: false);
      }
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _gridAmbientController.dispose();
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

  Future<void> _microActionSerenAddGlass(
    HydrationProvider? hydrationProvider,
    AppLocalizations l10n,
  ) async {
    if (hydrationProvider == null) return;
    final previouslyMet = hydrationProvider.isGoalMet;
    final goal = hydrationProvider.dailyGoalGlasses;
    final future = hydrationProvider.addGlass();
    final glasses = hydrationProvider.glassesConsumed;
    final newlyReached = !previouslyMet && hydrationProvider.isGoalMet;
    final message = newlyReached
        ? l10n.tr('nest_micro_seren_goal_reached', {'goal': goal})
        : l10n.tr('nest_micro_seren_glass_logged', {
            'glasses': glasses,
            'goal': goal,
          });
    _showMicroActionToast(message);
    await future;
  }

  Future<void> _microActionRooToggleNextAlarm(
    AlarmProvider? alarmProvider,
    bool use24Hour,
    AppLocalizations l10n,
    VoidCallback fallbackOpenRoo,
  ) async {
    if (alarmProvider == null || alarmProvider.alarms.isEmpty) {
      fallbackOpenRoo();
      return;
    }

    final nextEnabled = alarmProvider.nextUpcomingAlarm;
    if (nextEnabled != null) {
      _lastToggledAlarmId = nextEnabled.id;
      _showMicroActionToast(
        l10n.tr('nest_micro_roo_alarm_off', {
          'time': nextEnabled.formattedTime(use24Hour: use24Hour),
        }),
      );
      await alarmProvider.toggleAlarm(nextEnabled.id, false);
      return;
    }

    final target = alarmProvider.alarms.firstWhere(
      (a) => a.id == _lastToggledAlarmId,
      orElse: () => alarmProvider.alarms.first,
    );
    _lastToggledAlarmId = target.id;
    _showMicroActionToast(
      l10n.tr('nest_micro_roo_alarm_on', {
        'time': target.formattedTime(use24Hour: use24Hour),
      }),
    );
    await alarmProvider.toggleAlarm(target.id, true);
  }

  void _showMicroActionToast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    _disableAnimations = disableAnimations;
    _syncGridController(isSceneMode: isSceneMode);
    final activePhase =
        settings?.treehousePhaseOverride ?? TreehouseDayPhaseX.resolve(now);

    final alarmProvider = tryWatchProvider<AlarmProvider>(context);
    final taskProvider = tryWatchProvider<TaskProvider>(context);
    final routineProvider = tryWatchProvider<RoutineProvider>(context);
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

    // Reactive live sprites driven by existing domain providers
    final rooSprite = _resolveRooSprite(
      routineProvider,
      alarmProvider,
      todayTasksCount,
    );
    final scoutSprite = _resolveScoutSprite(weather, bygProvider);
    final serenSprite = _resolveSerenSprite(
      hydrationProvider,
      isSerenPlaying,
      now,
    );
    final pippinSprite = _resolvePippinSprite(readingProvider, hobbyProvider);
    final twillSprite = _resolveTwillSprite(moneyProvider, notesCount, now);
    final echoSprite = _resolveEchoSprite(
      pebblesCount,
      hasLoggedTodayReflection,
      now,
    );

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

    void longPressRoo() => _microActionRooToggleNextAlarm(
          alarmProvider,
          use24Hour,
          l10n,
          openRoo,
        );
    void longPressScout() => BeforeYouGoSheet.show(context);
    void longPressSeren() =>
        _microActionSerenAddGlass(hydrationProvider, l10n);
    void longPressPippin() => ReadingTrackerSheet.show(context);
    void longPressTwill() =>
        QuickCaptureSheet.show(context, initialType: CaptureType.note);
    void longPressEcho() => GratitudeJarSheet.show(context, autoShake: true);

    final Widget bodyContent;
    if (isSceneMode) {
      final sceneBirds = [
        // Top Attic (Observatory): Echo
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_echo'),
          roomKey: const Key('nest_scene_room_echo'),
          name: 'Echo',
          compactMetric: _echoCompactMetric(l10n, pebblesCount),
          accentColor: EchoHouseScreen.echoColor,
          spriteAsset: echoSprite,
          blinkFrames: TreehouseMascotFrameSheets.echoBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.echoFlutterFrames,
          fallbackIcon: Icons.auto_stories_rounded,
          fx: TreehouseSceneAnchors.echoPerch.dx,
          fy: TreehouseSceneAnchors.echoPerch.dy,
          roomBounds: TreehouseSceneAnchors.echoRoomBounds,
          walkSpan: TreehouseSceneAnchors.echoWalkSpan,
          phaseOffset: 1.05,
          poseSwitchInterval: const Duration(milliseconds: 10500),
          onTap: openEcho,
          onLongPress: longPressEcho,
        ),
        // Upper-Left (Clockwork Room): Roo
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_roo'),
          roomKey: const Key('nest_scene_room_roo'),
          name: 'Roo',
          compactMetric: _rooCompactMetric(l10n, nextAlarmTime, todayTasksCount),
          accentColor: RooHouseScreen.rooColor,
          spriteAsset: rooSprite,
          blinkFrames: TreehouseMascotFrameSheets.rooBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.rooFlutterFrames,
          fallbackIcon: Icons.alarm_on_rounded,
          fx: TreehouseSceneAnchors.rooPerch.dx,
          fy: TreehouseSceneAnchors.rooPerch.dy,
          roomBounds: TreehouseSceneAnchors.rooRoomBounds,
          walkSpan: TreehouseSceneAnchors.rooWalkSpan,
          phaseOffset: 0.0,
          poseSwitchInterval: const Duration(milliseconds: 7500),
          onTap: openRoo,
          onLongPress: longPressRoo,
        ),
        // Mid-Left (Open Balcony): Scout
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_scout'),
          roomKey: const Key('nest_scene_room_scout'),
          name: 'Scout',
          compactMetric: _scoutCompactMetric(l10n, weather, bygProvider),
          accentColor: ScoutHouseScreen.scoutColor,
          spriteAsset: scoutSprite,
          blinkFrames: TreehouseMascotFrameSheets.scoutBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.scoutFlutterFrames,
          fallbackIcon: Icons.explore_rounded,
          fx: TreehouseSceneAnchors.scoutPerch.dx,
          fy: TreehouseSceneAnchors.scoutPerch.dy,
          roomBounds: TreehouseSceneAnchors.scoutRoomBounds,
          walkSpan: TreehouseSceneAnchors.scoutWalkSpan,
          phaseOffset: 2.1,
          poseSwitchInterval: const Duration(milliseconds: 8500),
          onTap: openScout,
          onLongPress: longPressScout,
        ),
        // Mid-Right (Tea & Lavender Room): Seren
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_seren'),
          roomKey: const Key('nest_scene_room_seren'),
          name: 'Seren',
          compactMetric: l10n.tr('nest_scene_pill_seren_glasses', {
            'glasses': glasses,
            'goal': goalGlasses,
          }),
          accentColor: SerenHouseScreen.serenColor,
          spriteAsset: serenSprite,
          blinkFrames: TreehouseMascotFrameSheets.serenBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.serenFlutterFrames,
          fallbackIcon: Icons.spa_rounded,
          fx: TreehouseSceneAnchors.serenPerch.dx,
          fy: TreehouseSceneAnchors.serenPerch.dy,
          roomBounds: TreehouseSceneAnchors.serenRoomBounds,
          walkSpan: TreehouseSceneAnchors.serenWalkSpan,
          phaseOffset: 3.15,
          poseSwitchInterval: const Duration(milliseconds: 11000),
          onTap: openSeren,
          onLongPress: longPressSeren,
        ),
        // Lower-Left (Explorer Library): Pippin
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_pippin'),
          roomKey: const Key('nest_scene_room_pippin'),
          name: 'Pippin',
          compactMetric: _pippinCompactMetric(
            l10n,
            readingProvider,
            hobbyProvider,
          ),
          accentColor: PippinHouseScreen.pippinColor,
          spriteAsset: pippinSprite,
          blinkFrames: TreehouseMascotFrameSheets.pippinBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.pippinFlutterFrames,
          fallbackIcon: Icons.menu_book_rounded,
          fx: TreehouseSceneAnchors.pippinPerch.dx,
          fy: TreehouseSceneAnchors.pippinPerch.dy,
          roomBounds: TreehouseSceneAnchors.pippinRoomBounds,
          walkSpan: TreehouseSceneAnchors.pippinWalkSpan,
          phaseOffset: 4.2,
          poseSwitchInterval: const Duration(milliseconds: 9000),
          onTap: openPippin,
          onLongPress: longPressPippin,
        ),
        // Lower-Right (Organizer Workshop): Twill
        TreehouseSceneBirdHotspot(
          key: const Key('nest_scene_bird_twill'),
          roomKey: const Key('nest_scene_room_twill'),
          name: 'Twill',
          compactMetric: _twillCompactMetric(l10n, notesCount),
          accentColor: TwillHouseScreen.twillColor,
          spriteAsset: twillSprite,
          blinkFrames: TreehouseMascotFrameSheets.twillBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.twillFlutterFrames,
          fallbackIcon: Icons.edit_note_rounded,
          fx: TreehouseSceneAnchors.twillPerch.dx,
          fy: TreehouseSceneAnchors.twillPerch.dy,
          roomBounds: TreehouseSceneAnchors.twillRoomBounds,
          walkSpan: TreehouseSceneAnchors.twillWalkSpan,
          phaseOffset: 5.25,
          poseSwitchInterval: const Duration(milliseconds: 9500),
          onTap: openTwill,
          onLongPress: longPressTwill,
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
        bottomOverlayClearance: widget.bottomOverlayClearance,
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
      final echoStatus = _echoStatusText(l10n, pebblesCount);

      final gridTickerEnabled =
          widget.isActive && _appResumed && !disableAnimations;

      final roomCards = [
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_roo'),
          haloKey: const Key('nest_bird_halo_roo'),
          pillKey: const Key('nest_bird_pill_roo'),
          glowBorderKey: const Key('nest_bird_glow_border_roo'),
          name: 'Roo',
          subtitle: l10n.tr('nest_roo_subtitle'),
          statusPill: rooStatus,
          accentColor: RooHouseScreen.rooColor,
          spriteAsset: rooSprite,
          blinkFrames: TreehouseMascotFrameSheets.rooBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.rooFlutterFrames,
          ambientAnimation: _gridAmbientController,
          phaseOffset: 0.0,
          poseSwitchInterval: const Duration(milliseconds: 7500),
          fallbackIcon: Icons.alarm_on_rounded,
          onTap: openRoo,
          onLongPress: longPressRoo,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_scout'),
          haloKey: const Key('nest_bird_halo_scout'),
          pillKey: const Key('nest_bird_pill_scout'),
          glowBorderKey: const Key('nest_bird_glow_border_scout'),
          name: 'Scout',
          subtitle: l10n.tr('nest_scout_subtitle'),
          statusPill: scoutStatus,
          accentColor: ScoutHouseScreen.scoutColor,
          spriteAsset: scoutSprite,
          blinkFrames: TreehouseMascotFrameSheets.scoutBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.scoutFlutterFrames,
          ambientAnimation: _gridAmbientController,
          phaseOffset: 1.05,
          poseSwitchInterval: const Duration(milliseconds: 8500),
          fallbackIcon: Icons.explore_rounded,
          onTap: openScout,
          onLongPress: longPressScout,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_seren'),
          haloKey: const Key('nest_bird_halo_seren'),
          pillKey: const Key('nest_bird_pill_seren'),
          glowBorderKey: const Key('nest_bird_glow_border_seren'),
          name: 'Seren',
          subtitle: l10n.tr('nest_seren_subtitle'),
          statusPill: serenStatus,
          accentColor: SerenHouseScreen.serenColor,
          spriteAsset: serenSprite,
          blinkFrames: TreehouseMascotFrameSheets.serenBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.serenFlutterFrames,
          ambientAnimation: _gridAmbientController,
          phaseOffset: 2.1,
          poseSwitchInterval: const Duration(milliseconds: 11000),
          fallbackIcon: Icons.spa_rounded,
          onTap: openSeren,
          onLongPress: longPressSeren,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_pippin'),
          haloKey: const Key('nest_bird_halo_pippin'),
          pillKey: const Key('nest_bird_pill_pippin'),
          glowBorderKey: const Key('nest_bird_glow_border_pippin'),
          name: 'Pippin',
          subtitle: l10n.tr('nest_pippin_subtitle'),
          statusPill: pippinStatus,
          accentColor: PippinHouseScreen.pippinColor,
          spriteAsset: pippinSprite,
          blinkFrames: TreehouseMascotFrameSheets.pippinBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.pippinFlutterFrames,
          ambientAnimation: _gridAmbientController,
          phaseOffset: 3.15,
          poseSwitchInterval: const Duration(milliseconds: 9000),
          fallbackIcon: Icons.menu_book_rounded,
          onTap: openPippin,
          onLongPress: longPressPippin,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_twill'),
          haloKey: const Key('nest_bird_halo_twill'),
          pillKey: const Key('nest_bird_pill_twill'),
          glowBorderKey: const Key('nest_bird_glow_border_twill'),
          name: 'Twill',
          subtitle: l10n.tr('nest_twill_subtitle'),
          statusPill: twillStatus,
          accentColor: TwillHouseScreen.twillColor,
          spriteAsset: twillSprite,
          blinkFrames: TreehouseMascotFrameSheets.twillBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.twillFlutterFrames,
          ambientAnimation: _gridAmbientController,
          phaseOffset: 4.2,
          poseSwitchInterval: const Duration(milliseconds: 9500),
          fallbackIcon: Icons.edit_note_rounded,
          onTap: openTwill,
          onLongPress: longPressTwill,
        ),
        _TreehouseRoomCard(
          cardKey: const Key('nest_bird_card_echo'),
          haloKey: const Key('nest_bird_halo_echo'),
          pillKey: const Key('nest_bird_pill_echo'),
          glowBorderKey: const Key('nest_bird_glow_border_echo'),
          name: 'Echo',
          subtitle: l10n.tr('nest_echo_subtitle'),
          statusPill: echoStatus,
          accentColor: EchoHouseScreen.echoColor,
          spriteAsset: echoSprite,
          blinkFrames: TreehouseMascotFrameSheets.echoBlinkFrames,
          flutterFrames: TreehouseMascotFrameSheets.echoFlutterFrames,
          ambientAnimation: _gridAmbientController,
          phaseOffset: 5.25,
          poseSwitchInterval: const Duration(milliseconds: 10500),
          fallbackIcon: Icons.auto_stories_rounded,
          onTap: openEcho,
          onLongPress: longPressEcho,
        ),
      ];

      bodyContent = TickerMode(
        key: const Key('nest_grid_ticker_mode'),
        enabled: gridTickerEnabled,
        child: ListView(
          key: const ValueKey('nest_mode_grid'),
          padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            20 + widget.bottomOverlayClearance,
          ),
          children: [
            // Time-of-day header card (#FFFFFF 18dp card in Light Mode; atmospheric gradient in Dark Mode)
            _buildTimeOfDayBanner(
              context,
              l10n: l10n,
              phase: activePhase,
              nextAlarmTime: nextAlarmTime,
              weather: weather,
              onTapAlarm: openRoo,
              onTapWeather: openScout,
            ),
            const SizedBox(height: 14),

            // Compact 2×3 Bird Rooms Grid (animated flock + moving glow borders)
            BirdToolGrid(
              spacing: 12,
              tiles: roomCards,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: const Key('nest_treehouse_screen'),
      extendBodyBehindAppBar: isSceneMode,
      appBar: AppBar(
        key: const Key('nest_top_app_bar'),
        titleSpacing: 16,
        backgroundColor: isSceneMode ? Colors.transparent : null,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isSceneMode ? SystemUiOverlayStyle.light : null,
        flexibleSpace: isSceneMode
            ? IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.42),
                        Colors.black.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.58, 1.0],
                    ),
                  ),
                ),
              )
            : null,
        title: NestinWordmark(
          textKey: const Key('nest_brand_title'),
          fontSize: 24,
          onDarkBackdrop: isSceneMode,
        ),
        actions: [
          _buildTopBarAction(
            key: const Key('nest_view_mode_toggle_btn'),
            icon: isSceneMode ? Icons.grid_view_rounded : Icons.park_rounded,
            tooltip: isSceneMode
                ? l10n.tr('nest_switch_to_grid')
                : l10n.tr('nest_switch_to_scene'),
            isSceneMode: isSceneMode,
            onPressed: () => _toggleViewMode(settings),
          ),
          _buildTopBarAction(
            key: const Key('nest_search_btn'),
            icon: Icons.search_rounded,
            tooltip: l10n.tr('universal_search'),
            isSceneMode: isSceneMode,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const UniversalSearchScreen(),
              ),
            ),
          ),
          _buildTopBarAction(
            key: const Key('nest_settings_btn'),
            icon: Icons.settings_outlined,
            tooltip: l10n.tr('settings'),
            isSceneMode: isSceneMode,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
          const SizedBox(width: 4),
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

  Widget _buildTopBarAction({
    required Key key,
    required IconData icon,
    required String tooltip,
    required bool isSceneMode,
    required VoidCallback onPressed,
  }) {
    final iconWidget = Icon(
      icon,
      size: 22,
      color: isSceneMode ? Colors.white : null,
    );

    return IconButton(
      key: key,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onPressed,
      icon: isSceneMode
          ? Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x7310131C),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 0.8,
                ),
              ),
              child: Center(child: iconWidget),
            )
          : iconWidget,
    );
  }

  Widget _buildTimeOfDayBanner(
    BuildContext context, {
    required AppLocalizations l10n,
    required TreehouseDayPhase phase,
    required String? nextAlarmTime,
    required WeatherInfo? weather,
    required VoidCallback onTapAlarm,
    required VoidCallback onTapWeather,
  }) {
    final isDark = AppColors.isDark(context);
    final weatherVisual = weather != null
        ? BeforeYouGoWeatherBanner.resolveWeatherVisual(context, weather)
        : null;

    final alarmLabel = nextAlarmTime != null
        ? l10n.tr('nest_pill_next_alarm', {'time': nextAlarmTime})
        : l10n.tr('nest_status_no_alarm');

    final (gradientColors, phaseAccent) = switch (phase) {
      TreehouseDayPhase.dawn => (
          isDark
              ? const [Color(0xFF28202B), Color(0xFF1A1B24)]
              : const [AppColors.peachSoft, Color(0xFFF3ECF8)],
          isDark ? const Color(0xFFFDBA74) : AppColors.echo,
        ),
      TreehouseDayPhase.day => (
          isDark
              ? const [Color(0xFF1A2431), Color(0xFF171A23)]
              : const [Color(0xFFE7F4FD), Color(0xFFF4F8FC)],
          isDark ? AppColors.scoutLight : const Color(0xFF2563EB),
        ),
      TreehouseDayPhase.sunset => (
          isDark
              ? const [Color(0xFF2B201E), Color(0xFF1D1A26)]
              : const [Color(0xFFFFF0E2), Color(0xFFFCE8EC)],
          isDark ? AppColors.orangeLight : AppColors.orangeDark,
        ),
      TreehouseDayPhase.night => (
          isDark
              ? const [Color(0xFF1A1E2E), Color(0xFF141620)]
              : const [Color(0xFFEAEEF8), Color(0xFFF2EFFA)],
          isDark ? AppColors.serenLight : AppColors.serenDark,
        ),
    };

    return Container(
      key: const Key('nest_time_banner'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: isDark
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(18),
            )
          : BoxDecoration(
              // Pure #FFFFFF card matching the exact 18dp radius & soft shadow
              // of the 6 bird room cards below so it separates crisply from #F4F6F9
              color: AppColors.lightCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(phase.icon, size: 18, color: phaseAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.tr(phase.bannerTitleKey),
                  key: const Key('nest_greeting_text'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            l10n.tr('nest_treehouse_subtitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
            ),
          ),
          // Inline borderless Next Alarm & Weather status row (48dp touch targets)
          Row(
            key: const Key('nest_slim_status_pill'),
            children: [
              Flexible(
                flex: weather != null ? 5 : 1,
                child: InkWell(
                  key: const Key('nest_slim_pill_alarm_tap'),
                  onTap: onTapAlarm,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
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
                            color: weatherVisual?.color ??
                                ScoutHouseScreen.scoutColor,
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
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // --- Reactive Sprite Resolvers ---

  String _resolveRooSprite(
    RoutineProvider? routines,
    AlarmProvider? alarms,
    int todayTasksCount,
  ) {
    final hasActiveStreak = routines?.routines.any(
          (r) => r.streakCount >= 3 || (r.isCompletedToday && r.streakCount > 0),
        ) ??
        false;
    if (hasActiveStreak) return 'assets/mascots/sprites/roo/on_fire.png';
    if (alarms?.nextUpcomingAlarm != null) {
      return 'assets/mascots/sprites/roo/alarm.png';
    }
    if (todayTasksCount > 0) return 'assets/mascots/sprites/roo/planning.png';
    return 'assets/mascots/sprites/roo/welcome.png';
  }

  String _resolveScoutSprite(
    WeatherInfo? weather,
    BeforeYouGoProvider? bygProvider,
  ) {
    if (weather?.isHeavyRain == true) {
      return 'assets/mascots/sprites/scout/heavy_storm_raincoat.png';
    }
    if (weather?.isRainy == true) {
      return 'assets/mascots/sprites/scout/umbrella.png';
    }
    final preset = bygProvider?.activePreset;
    if (preset != null && preset.allChecked && preset.totalCount > 0) {
      return 'assets/mascots/sprites/scout/all_ready_salute.png';
    }
    return 'assets/mascots/sprites/scout/briefing.png';
  }

  String _resolveSerenSprite(
    HydrationProvider? hydration,
    bool isSerenPlaying,
    DateTime now,
  ) {
    if (hydration?.isGoalMet == true) {
      return 'assets/mascots/sprites/seren/refreshed.png';
    }
    if (isSerenPlaying) {
      return 'assets/mascots/sprites/seren/headphones_bliss.png';
    }
    if ((hydration?.glassesConsumed ?? 0) > 0) {
      return 'assets/mascots/sprites/seren/hydrate.png';
    }
    if (now.hour >= 21 || now.hour < 5) {
      return 'assets/mascots/sprites/seren/wind_down.png';
    }
    return 'assets/mascots/sprites/seren/hello.png';
  }

  String _resolvePippinSprite(
    ReadingProvider? reading,
    HobbyProvider? hobby,
  ) {
    if (reading?.isDailyGoalMet == true) {
      return 'assets/mascots/sprites/pippin/reading_streak_lantern.png';
    }
    if ((reading?.primaryActiveBook?.safeCurrentPage ?? 0) > 0) {
      return 'assets/mascots/sprites/pippin/reading.png';
    }
    if ((hobby?.totalCumulativeHours ?? 0) > 0) {
      return 'assets/mascots/sprites/pippin/hobby_time.png';
    }
    return 'assets/mascots/sprites/pippin/discover.png';
  }

  String _resolveTwillSprite(
    MoneyProvider? money,
    int notesCount,
    DateTime now,
  ) {
    final overview = money?.budgetOverviewForMonth(now.year, now.month);
    final budgets = <BudgetUtilizationSummary>[
      if (overview?.overallBudget != null) overview!.overallBudget!,
      ...?overview?.categoryBudgets,
    ];
    if (budgets.isNotEmpty) {
      if (budgets.any((b) => b.status == BudgetHealthStatus.exceeded)) {
        return 'assets/mascots/sprites/twill/budget_overflow_patch.png';
      }
      if (budgets.any((b) => b.status == BudgetHealthStatus.nearLimit)) {
        return 'assets/mascots/sprites/twill/budget_caution_amber.png';
      }
      return 'assets/mascots/sprites/twill/budgeted.png';
    }
    if (notesCount > 0) return 'assets/mascots/sprites/twill/organized.png';
    return 'assets/mascots/sprites/twill/noted.png';
  }

  String _resolveEchoSprite(
    int pebblesCount,
    bool hasLoggedTodayReflection,
    DateTime now,
  ) {
    if (pebblesCount >= 3) return 'assets/mascots/sprites/echo/grateful.png';
    if (hasLoggedTodayReflection) {
      return 'assets/mascots/sprites/echo/reflect.png';
    }
    if (now.hour >= 20 || now.hour < 5) {
      return 'assets/mascots/sprites/echo/stargazing.png';
    }
    return 'assets/mascots/sprites/echo/candlelight.png';
  }

  // --- Singular/Plural-Safe Status Strings ---

  String _rooCompactMetric(
    AppLocalizations l10n,
    String? nextAlarmTime,
    int todayTasksCount,
  ) {
    if (nextAlarmTime != null) return nextAlarmTime;
    if (todayTasksCount == 1) return l10n.tr('nest_scene_pill_roo_task_one');
    if (todayTasksCount > 1) {
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

  String _twillCompactMetric(AppLocalizations l10n, int notesCount) {
    if (notesCount == 1) return l10n.tr('nest_scene_pill_twill_note_one');
    return l10n.tr('nest_scene_pill_twill_notes', {'count': notesCount});
  }

  String _echoCompactMetric(AppLocalizations l10n, int pebblesCount) {
    if (pebblesCount == 1) return l10n.tr('nest_scene_pill_echo_pebble_one');
    if (pebblesCount > 1) {
      return l10n.tr('nest_scene_pill_echo_pebbles', {'count': pebblesCount});
    }
    return l10n.tr('nest_scene_pill_echo_diary');
  }

  String _rooStatusText(
    AppLocalizations l10n,
    String? nextAlarmTime,
    int todayTasksCount,
  ) {
    if (nextAlarmTime != null && todayTasksCount == 1) {
      return l10n.tr('nest_pill_roo_alarm_task_one', {'time': nextAlarmTime});
    }
    if (nextAlarmTime != null && todayTasksCount > 1) {
      return l10n.tr('nest_pill_roo_alarm_tasks', {
        'time': nextAlarmTime,
        'count': todayTasksCount,
      });
    }
    if (nextAlarmTime != null) {
      return l10n.tr('nest_pill_roo_alarm_only', {'time': nextAlarmTime});
    }
    if (todayTasksCount == 1) {
      return l10n.tr('nest_pill_roo_task_one');
    }
    if (todayTasksCount > 1) {
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
    if (notesCount == 1) return l10n.tr('nest_pill_twill_note_one');
    return l10n.tr('nest_pill_twill_notes', {'notes': notesCount});
  }

  String _echoStatusText(AppLocalizations l10n, int pebblesCount) {
    if (pebblesCount == 1) return l10n.tr('nest_pill_echo_pebble_one');
    if (pebblesCount > 1) {
      return l10n.tr('nest_pill_echo_pebbles', {'count': pebblesCount});
    }
    return l10n.tr('nest_pill_echo_short');
  }
}

class _TreehouseRoomCard extends StatelessWidget {
  final Key cardKey;
  final Key haloKey;
  final Key pillKey;
  final Key glowBorderKey;
  final String name;
  final String subtitle;
  final String statusPill;
  final Color accentColor;
  final String spriteAsset;
  final List<String> blinkFrames;
  final List<String> flutterFrames;
  final Animation<double> ambientAnimation;
  final double phaseOffset;
  final Duration poseSwitchInterval;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _TreehouseRoomCard({
    required this.cardKey,
    required this.haloKey,
    required this.pillKey,
    required this.glowBorderKey,
    required this.name,
    required this.subtitle,
    required this.statusPill,
    required this.accentColor,
    required this.spriteAsset,
    required this.blinkFrames,
    required this.flutterFrames,
    required this.ambientAnimation,
    required this.phaseOffset,
    required this.poseSwitchInterval,
    required this.fallbackIcon,
    required this.onTap,
    this.onLongPress,
  });

  static const double _cardRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final surface = AppColors.cardSurface(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 390;
    final cardWidth = ((screenWidth - 32 - 12) / 2).clamp(136.0, 220.0);
    // ~25% larger bird sprites (78dp on 360dp, 86–90dp on 390dp+)
    final spriteSize = (cardWidth * 0.495).clamp(76.0, 90.0);
    final haloSize = spriteSize + 14.0;
    final minCardHeight = isNarrow ? 118.0 : 126.0;

    return RepaintBoundary(
      child: CustomPaint(
        key: glowBorderKey,
        foregroundPainter: _AnimatedGlowBorderPainter(
          animation: ambientAnimation,
          accentColor: accentColor,
          phaseOffset: phaseOffset,
          borderRadius: _cardRadius,
          isDark: isDark,
          disableAnimations: disableAnimations,
        ),
        child: InkWell(
          key: cardKey,
          onTap: onTap,
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                }
              : null,
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Container(
            constraints: BoxConstraints(minHeight: minCardHeight),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
            decoration: isDark
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(surface, accentColor, 0.05)!,
                        surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(_cardRadius),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.42),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.14),
                        blurRadius: 14,
                        spreadRadius: 0,
                        offset: Offset.zero,
                      ),
                    ],
                  )
                : BoxDecoration(
                    color: AppColors.lightCard, // pure #FFFFFF on #F4F6F9 scaffold
                    borderRadius: BorderRadius.circular(_cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Left-aligned Name + 2-line Subtitle, Right-side Halo + Living Animated Sprite
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
                              fontSize: isNarrow ? 17 : 18.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isNarrow ? 11.5 : 12.2,
                              height: 1.22,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 2),
                    SizedBox(
                      width: spriteSize,
                      height: spriteSize,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Soft radial gradient halo (13–16% opacity) preventing dark feathers from blending
                          OverflowBox(
                            maxWidth: haloSize,
                            maxHeight: haloSize,
                            child: DecoratedBox(
                              key: haloKey,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    accentColor.withValues(
                                      alpha: isDark ? 0.16 : 0.13,
                                    ),
                                    accentColor.withValues(
                                      alpha: isDark ? 0.06 : 0.04,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.58, 1.0],
                                ),
                              ),
                              child: SizedBox(width: haloSize, height: haloSize),
                            ),
                          ),
                          AnimatedMascotSprite(
                            spriteAsset: spriteAsset,
                            size: spriteSize,
                            accentColor: accentColor,
                            fallbackIcon: fallbackIcon,
                            ambientAnimation: ambientAnimation,
                            phaseOffset: phaseOffset,
                            poseSwitchInterval: poseSwitchInterval,
                            blinkFrames: blinkFrames,
                            flutterFrames: flutterFrames,
                            enableRoomPacing: false,
                            showSubtleHalo: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bottom Row: Borderless full-pill status chip with 6dp accent dot & crisp textPrimary
                Container(
                  key: pillKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.15 : 0.10),
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
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Smooth rotating `SweepGradient` moving glow border painted around each 2×3
/// bird room card, tinted with the companion's domain accent and staggered via
/// [phaseOffset].
///
/// - **Light Mode:** Crisp, restrained sheen gliding over a whisper hairline.
/// - **Dark Mode:** Softly luminous moving edge highlight with gentle outer bloom.
/// - **Reduced Motion / Off-Tab:** Pauses automatically via parent `TickerMode`
///   and paints a calm static rim when [disableAnimations] is enabled.
class _AnimatedGlowBorderPainter extends CustomPainter {
  final Animation<double> animation;
  final Color accentColor;
  final double phaseOffset;
  final double borderRadius;
  final bool isDark;
  final bool disableAnimations;

  const _AnimatedGlowBorderPainter({
    required this.animation,
    required this.accentColor,
    required this.phaseOffset,
    required this.borderRadius,
    required this.isDark,
    required this.disableAnimations,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final strokeWidth = isDark ? 1.5 : 1.35;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(math.max(0.0, borderRadius - strokeWidth / 2)),
    );

    if (disableAnimations) {
      // Static calm border fallback for reduced motion accessibility
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = accentColor.withValues(alpha: isDark ? 0.32 : 0.14),
      );
      return;
    }

    final angle = animation.value * 2 * math.pi + phaseOffset;
    final highlightColor = Color.lerp(
      accentColor,
      Colors.white,
      isDark ? 0.35 : 0.22,
    )!;

    if (isDark) {
      // Soft luminous outer bloom pass in Dark Mode
      final bloomGradient = SweepGradient(
        center: Alignment.center,
        transform: GradientRotation(angle),
        colors: [
          Colors.transparent,
          accentColor.withValues(alpha: 0.08),
          accentColor.withValues(alpha: 0.34),
          highlightColor.withValues(alpha: 0.40),
          accentColor.withValues(alpha: 0.14),
          Colors.transparent,
        ],
        stops: const [0.0, 0.56, 0.78, 0.88, 0.96, 1.0],
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
          ..shader = bloomGradient.createShader(rect),
      );
    }

    // Crisp moving gradient rim pass
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(angle),
      colors: isDark
          ? [
              accentColor.withValues(alpha: 0.14),
              accentColor.withValues(alpha: 0.14),
              accentColor.withValues(alpha: 0.52),
              highlightColor.withValues(alpha: 0.86),
              accentColor.withValues(alpha: 0.42),
              accentColor.withValues(alpha: 0.14),
            ]
          : [
              accentColor.withValues(alpha: 0.06),
              accentColor.withValues(alpha: 0.06),
              accentColor.withValues(alpha: 0.30),
              highlightColor.withValues(alpha: 0.58),
              accentColor.withValues(alpha: 0.24),
              accentColor.withValues(alpha: 0.06),
            ],
      stops: const [0.0, 0.55, 0.76, 0.87, 0.95, 1.0],
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..shader = sweepGradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedGlowBorderPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.phaseOffset != phaseOffset ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isDark != isDark ||
        oldDelegate.disableAnimations != disableAnimations;
  }
}
