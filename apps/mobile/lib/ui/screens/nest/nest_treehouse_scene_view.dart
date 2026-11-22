import 'dart:async';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/weather_service.dart';
import '../../widgets/animated_mascot_sprite.dart';
import '../../widgets/before_you_go_weather_banner.dart';
import 'roo_house_screen.dart';
import 'treehouse_painters.dart';

export 'treehouse_painters.dart'
    show
        TreehouseAtmospherePainter,
        TreehouseDayPhase,
        TreehouseDayPhaseX,
        TreehouseMascotFrameSheets,
        TreehouseRoomEffectsPainter,
        TreehouseSceneAnchors;

/// Data model for a single bird perch hotspot inside [NestTreehouseSceneView].
class TreehouseSceneBirdHotspot {
  final Key key;
  final String name;
  final String compactMetric;
  final Color accentColor;
  final String spriteAsset;
  final IconData fallbackIcon;

  /// Fractional horizontal anchor (`0.0` = left, `1.0` = right) on the
  /// `1536×2752` treehouse artwork (bird feet bottom-center).
  final double fx;

  /// Fractional vertical anchor (`0.0` = top, `1.0` = bottom) on the
  /// `1536×2752` treehouse artwork (bird feet bottom-center).
  final double fy;

  /// Optional per-bird stagger phase offset in radians for organic idle motion.
  final double phaseOffset;

  /// Optional future multi-frame blink/flutter drop-in assets.
  final List<String>? blinkFrames;
  final List<String>? flutterFrames;

  final VoidCallback onTap;

  const TreehouseSceneBirdHotspot({
    required this.key,
    required this.name,
    required this.compactMetric,
    required this.accentColor,
    required this.spriteAsset,
    required this.fallbackIcon,
    required this.fx,
    required this.fy,
    required this.onTap,
    this.phaseOffset = 0.0,
    this.blinkFrames,
    this.flutterFrames,
  });
}

/// Full-bleed **Living Animated Treehouse** scene layered over the 4-phase
/// illustrated backgrounds (`treehouse_dawn.jpg`, `treehouse_day.jpg`,
/// `treehouse_sunset.jpg`, `treehouse_night.jpg`).
///
/// Performance & Accessibility Guardrails:
/// - All overlays align via fractional `(0.0–1.0)` coordinates mapped onto the
///   exact rendered image rectangle inside `LayoutBuilder`.
/// - One single shared `AnimationController` (12s seamless harmonic loop) drives
///   all room effects, outdoor atmosphere, and 6 bird idle loops.
/// - Wrapped in `RepaintBoundary` layers and `TickerMode(enabled: effectiveActive)`
///   so animations pause completely when switching tabs, pushing a Bird House,
///   or backgrounding the app.
/// - Respects `MediaQuery.maybeDisableAnimationsOf(context)` (disables motion
///   loops while keeping Roo's live grandfather clock hands accurate).
class NestTreehouseSceneView extends StatefulWidget {
  /// Optional explicit time-of-day phase override. When `null`, automatically
  /// resolves from the live clock (`05:00–07:59` Dawn, `08:00–16:59` Day,
  /// `17:00–19:29` Sunset, `19:30–04:59` Night).
  final TreehouseDayPhase? phase;

  /// Optional callback invoked when the user taps a phase chip on the live
  /// in-scene Time-of-Day Preview Scrubber (`null` = Auto Live Clock).
  final ValueChanged<TreehouseDayPhase?>? onSelectPhaseOverride;

  /// Optional deterministic clock override for widget/unit tests.
  final DateTime? clockOverride;

  /// Whether the Nest tab is currently active and visible to the user.
  /// When `false`, all ambient tickers pause cleanly via [TickerMode].
  final bool isActive;

  final String? nextAlarmTime;
  final WeatherInfo? weather;
  final bool isSerenPlaying;
  final bool hasLoggedTodayReflection;
  final List<TreehouseSceneBirdHotspot> birds;
  final VoidCallback onOpenRooHouse;
  final VoidCallback onOpenScoutHouse;

  /// Optional explicit asset override; defaults to the active phase's artwork.
  final String? backdropAssetPath;

  const NestTreehouseSceneView({
    super.key,
    this.phase,
    this.onSelectPhaseOverride,
    this.clockOverride,
    this.isActive = true,
    required this.nextAlarmTime,
    required this.weather,
    this.isSerenPlaying = false,
    this.hasLoggedTodayReflection = true,
    required this.birds,
    required this.onOpenRooHouse,
    required this.onOpenScoutHouse,
    this.backdropAssetPath,
  });

  @override
  State<NestTreehouseSceneView> createState() => _NestTreehouseSceneViewState();
}

class _NestTreehouseSceneViewState extends State<NestTreehouseSceneView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ambientController;
  Timer? _clockTimer;
  late DateTime _now;
  bool _appResumed = true;
  bool _disableAnimations = false;
  TreehouseDayPhase? _localPhaseOverride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = widget.clockOverride ?? DateTime.now();
    _localPhaseOverride = widget.phase;
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _syncClockTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncAnimationController();
  }

  @override
  void didUpdateWidget(covariant NestTreehouseSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase != oldWidget.phase) {
      _localPhaseOverride = widget.phase;
    }
    if (widget.clockOverride != oldWidget.clockOverride) {
      _now = widget.clockOverride ?? DateTime.now();
    }
    if (widget.isActive != oldWidget.isActive ||
        widget.clockOverride != oldWidget.clockOverride) {
      _syncClockTimer();
      _syncAnimationController();
    }
  }

  void _selectPhaseOverride(TreehouseDayPhase? nextPhase) {
    setState(() => _localPhaseOverride = nextPhase);
    widget.onSelectPhaseOverride?.call(nextPhase);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    setState(() {
      _appResumed = resumed;
      if (resumed && widget.clockOverride == null) {
        _now = DateTime.now();
      }
    });
    _syncClockTimer();
    _syncAnimationController();
  }

  bool get _effectiveActive => widget.isActive && _appResumed;

  void _syncClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = null;
    if (!_effectiveActive || widget.clockOverride != null) return;
    // Keeps Roo's grandfather clock hands and 4-phase cross-fade accurate even
    // when motion loops are disabled via reduced-motion settings.
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final latest = DateTime.now();
      if (latest.minute != _now.minute || latest.hour != _now.hour) {
        setState(() => _now = latest);
      }
    });
  }

  void _syncAnimationController() {
    final shouldRun = _effectiveActive && !_disableAnimations;
    if (shouldRun) {
      if (!_ambientController.isAnimating) {
        _ambientController.repeat();
      }
    } else {
      if (_ambientController.isAnimating) {
        _ambientController.stop(canceled: false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final currentTime = widget.clockOverride ?? _now;
    final effectiveOverride = widget.onSelectPhaseOverride != null
        ? widget.phase
        : _localPhaseOverride;
    final activePhase =
        effectiveOverride ?? TreehouseDayPhaseX.resolve(currentTime);
    final backdropAsset =
        widget.backdropAssetPath ?? activePhase.backdropAsset;
    final isRainy = widget.weather?.isRainy ?? false;

    final tickerEnabled = _effectiveActive && !disableAnimations;

    return TickerMode(
      key: const Key('nest_scene_ticker_mode'),
      enabled: tickerEnabled,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.72;
          final viewport = Size(width, height);
          final imageLayout =
              TreehouseSceneAnchors.resolveImageLayout(viewport);
          final imageRect = imageLayout.rect;

          final maxPillWidth =
              (imageRect.width * 0.42).clamp(104.0, 166.0);
          final spriteSize =
              (imageRect.width * 0.155).clamp(44.0, 68.0);

          return SizedBox(
            key: const Key('nest_treehouse_scene_view'),
            width: width,
            height: height,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 0. Seamless ambient sky/forest backdrop behind ultra-wide letterbox
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: ProceduralTreehouseBackdropPainter(
                        phase: activePhase,
                        isDark: isDark,
                      ),
                    ),
                  ),

                  // 1. 4-Phase Illustrated Treehouse Artwork with smooth AnimatedSwitcher cross-fade
                  RepaintBoundary(
                    child: AnimatedSwitcher(
                      key: const Key('nest_scene_backdrop_switcher'),
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 900),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      child: SizedBox.expand(
                        key: ValueKey<String>(backdropAsset),
                        child: Image.asset(
                          backdropAsset,
                          key: Key('nest_scene_art_${activePhase.name}'),
                          fit: imageLayout.fit,
                          alignment: Alignment.center,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => CustomPaint(
                            key: const Key('nest_scene_procedural_backdrop'),
                            painter: ProceduralTreehouseBackdropPainter(
                              phase: activePhase,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Room Prop Animations (Roo clock/pendulum/cogs, Seren steam/lamp,
                  //    Echo skylight stars/warm glow, Scout balcony lantern/rain)
                  RepaintBoundary(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const Key('nest_scene_room_effects'),
                        painter: TreehouseRoomEffectsPainter(
                          animation: _ambientController,
                          imageRect: imageRect,
                          phase: activePhase,
                          currentTime: currentTime,
                          disableAnimations: disableAnimations,
                          isSerenPlaying: widget.isSerenPlaying,
                          hasLoggedTodayReflection:
                              widget.hasLoggedTodayReflection,
                          isRainy: isRainy,
                        ),
                      ),
                    ),
                  ),

                  // 3. 6 Living Animated Bird Hotspots planted in their rooms
                  for (var i = 0; i < widget.birds.length; i++)
                    _buildPositionedBirdHotspot(
                      bird: widget.birds[i],
                      index: i,
                      imageRect: imageRect,
                      viewportWidth: width,
                      viewportHeight: height,
                      maxPillWidth: maxPillWidth,
                      spriteSize: spriteSize,
                    ),

                  // 4. Phase-Aware Outdoor Atmosphere Layer (Dawn mist & lanterns,
                  //    Day butterflies/motes/clouds, Sunset lanterns & early fireflies,
                  //    Night sky stars, pulsing 4 lanterns & 10 fireflies)
                  RepaintBoundary(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const Key('nest_scene_atmosphere'),
                        painter: TreehouseAtmospherePainter(
                          animation: _ambientController,
                          imageRect: imageRect,
                          phase: activePhase,
                          disableAnimations: disableAnimations,
                        ),
                      ),
                    ),
                  ),

                  // 5. Subtle top/bottom vignette for top pill & bottom whisper legibility
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.12, 0.88, 1.0],
                          colors: [
                            Colors.black
                                .withValues(alpha: isDark ? 0.28 : 0.16),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black
                                .withValues(alpha: isDark ? 0.34 : 0.22),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 6. Top floating status pill (Next Alarm + Weather)
                  Positioned(
                    top: 6,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: _SceneTopStatusPill(
                        nextAlarmTime: widget.nextAlarmTime,
                        weather: widget.weather,
                        onTapAlarm: widget.onOpenRooHouse,
                        onTapWeather: widget.onOpenScoutHouse,
                      ),
                    ),
                  ),

                  // 7. Live Time-of-Day Phase Preview Scrubber & bottom whisper hint
                  Positioned(
                    bottom: 8,
                    left: 12,
                    right: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ScenePhasePreviewScrubber(
                          selectedOverride: effectiveOverride,
                          activePhase: activePhase,
                          onSelectPhase: _selectPhaseOverride,
                        ),
                        const SizedBox(height: 5),
                        IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xA610131A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Text(
                              l10n.tr('nest_scene_tap_hint'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
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
    );
  }

  Widget _buildPositionedBirdHotspot({
    required TreehouseSceneBirdHotspot bird,
    required int index,
    required Rect imageRect,
    required double viewportWidth,
    required double viewportHeight,
    required double maxPillWidth,
    required double spriteSize,
  }) {
    final anchor = TreehouseSceneAnchors.mapPoint(imageRect, bird.fx, bird.fy);
    final slotWidth = maxPillWidth;
    final pillHeight = 25.0;
    final totalHeight = spriteSize + 2 + pillHeight;

    // Plant bird feet (bottom of sprite) right at anchor.dy, with dark-glass
    // status pill resting cleanly on the timber beam beneath the feet.
    final rawLeft = anchor.dx - slotWidth / 2;
    final rawTop = anchor.dy - spriteSize;

    final double safeLeft = rawLeft
        .clamp(6.0, math.max(6.0, viewportWidth - slotWidth - 6.0))
        .toDouble();
    final double safeTop = rawTop
        .clamp(46.0, math.max(46.0, viewportHeight - totalHeight - 58.0))
        .toDouble();

    final staggerOffset =
        bird.phaseOffset != 0.0 ? bird.phaseOffset : index * 1.05;

    return Positioned(
      left: safeLeft,
      top: safeTop,
      width: slotWidth,
      child: _SceneBirdHotspotButton(
        bird: bird,
        spriteSize: spriteSize,
        ambientAnimation: _ambientController,
        phaseOffset: staggerOffset,
      ),
    );
  }
}

class _ScenePhasePreviewScrubber extends StatelessWidget {
  final TreehouseDayPhase? selectedOverride;
  final TreehouseDayPhase activePhase;
  final ValueChanged<TreehouseDayPhase?> onSelectPhase;

  const _ScenePhasePreviewScrubber({
    required this.selectedOverride,
    required this.activePhase,
    required this.onSelectPhase,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(String, TreehouseDayPhase?, IconData, String)>[
      (
        'nest_scene_phase_chip_auto',
        null,
        Icons.schedule_rounded,
        l10n.tr('treehouse_phase_short_auto'),
      ),
      for (final phase in TreehouseDayPhase.values)
        (
          'nest_scene_phase_chip_${phase.name}',
          phase,
          phase.icon,
          l10n.tr(phase.shortLabelKey),
        ),
    ];

    return Container(
      key: const Key('nest_scene_phase_scrubber'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC10131C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildChip(
                  key: Key(opt.$1),
                  phase: opt.$2,
                  icon: opt.$3,
                  label: opt.$4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required Key key,
    required TreehouseDayPhase? phase,
    required IconData icon,
    required String label,
  }) {
    final isSelected = selectedOverride == phase;
    final isLiveActive = selectedOverride == null && phase == activePhase;

    return InkWell(
      key: key,
      onTap: () => onSelectPhase(phase),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF59E0B).withValues(alpha: 0.28)
              : (isLiveActive
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFBBF24)
                : (isLiveActive
                    ? Colors.white.withValues(alpha: 0.24)
                    : Colors.transparent),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFD1D5DB),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneTopStatusPill extends StatelessWidget {
  final String? nextAlarmTime;
  final WeatherInfo? weather;
  final VoidCallback onTapAlarm;
  final VoidCallback onTapWeather;

  const _SceneTopStatusPill({
    required this.nextAlarmTime,
    required this.weather,
    required this.onTapAlarm,
    required this.onTapWeather,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weatherVisual = weather != null
        ? BeforeYouGoWeatherBanner.resolveWeatherVisual(context, weather!)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xBF12151E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          InkWell(
            onTap: onTapAlarm,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.alarm_rounded,
                  size: 14,
                  color: RooHouseScreen.rooColor,
                ),
                const SizedBox(width: 5),
                Text(
                  nextAlarmTime ?? l10n.tr('nest_status_no_alarm'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (weather != null)
            InkWell(
              onTap: onTapWeather,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    weatherVisual?.icon ?? Icons.wb_cloudy_outlined,
                    size: 14,
                    color: const Color(0xFF93C5FD),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${weather!.temperatureCelsius.round()}°C • ${weather!.condition}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SceneBirdHotspotButton extends StatefulWidget {
  final TreehouseSceneBirdHotspot bird;
  final double spriteSize;
  final Animation<double> ambientAnimation;
  final double phaseOffset;

  const _SceneBirdHotspotButton({
    required this.bird,
    required this.spriteSize,
    required this.ambientAnimation,
    required this.phaseOffset,
  });

  @override
  State<_SceneBirdHotspotButton> createState() =>
      _SceneBirdHotspotButtonState();
}

class _SceneBirdHotspotButtonState extends State<_SceneBirdHotspotButton> {
  final GlobalKey<AnimatedMascotSpriteState> _spriteKey =
      GlobalKey<AnimatedMascotSpriteState>();

  @override
  Widget build(BuildContext context) {
    final bird = widget.bird;

    return GestureDetector(
      key: bird.key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final spriteState = _spriteKey.currentState;
        if (spriteState != null) {
          spriteState.triggerHopAndTap(bird.onTap);
        } else {
          bird.onTap();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedMascotSprite(
            key: _spriteKey,
            spriteAsset: bird.spriteAsset,
            size: widget.spriteSize,
            accentColor: bird.accentColor,
            fallbackIcon: bird.fallbackIcon,
            ambientAnimation: widget.ambientAnimation,
            phaseOffset: widget.phaseOffset,
            blinkFrames: bird.blinkFrames,
            flutterFrames: bird.flutterFrames,
            showSubtleHalo: false,
          ),
          const SizedBox(height: 2),
          // Compact floating dark-glass status pill ("Roo • 06:30", "Scout • 28°C")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xD911141C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bird.accentColor.withValues(alpha: 0.68),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bird.accentColor,
                  ),
                ),
                const SizedBox(width: 4.5),
                Flexible(
                  child: Text(
                    '${bird.name} • ${bird.compactMetric}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
