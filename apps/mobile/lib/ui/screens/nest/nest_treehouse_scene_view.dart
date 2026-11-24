import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
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

/// Data model for a single cutaway room + bird perch hotspot inside
/// [NestTreehouseSceneView].
class TreehouseSceneBirdHotspot {
  final Key key;
  final Key? roomKey;
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

  /// Fractional (`0.0–1.0`) room interior bounds on the `1536×2752` artwork
  /// making the entire cutaway room tappable and long-pressable.
  final Rect? roomBounds;

  /// Optional per-bird stagger phase offset in radians for organic idle motion.
  final double phaseOffset;

  /// Calm per-bird pose-switching interval (`7–11s` recommended).
  final Duration poseSwitchInterval;

  /// Optional safe fractional horizontal walking floor bounds `(minFx, maxFx)`
  /// inside this bird's cutaway room on the `1536×2752` artwork.
  final ({double minFx, double maxFx})? walkSpan;

  /// Optional future multi-frame blink/flutter drop-in assets.
  final List<String>? blinkFrames;
  final List<String>? flutterFrames;

  final VoidCallback onTap;

  /// Optional long-press micro-action (e.g., Seren `+1 Glass`, Roo toggle alarm).
  final VoidCallback? onLongPress;

  const TreehouseSceneBirdHotspot({
    required this.key,
    this.roomKey,
    required this.name,
    required this.compactMetric,
    required this.accentColor,
    required this.spriteAsset,
    required this.fallbackIcon,
    required this.fx,
    required this.fy,
    this.roomBounds,
    required this.onTap,
    this.onLongPress,
    this.phaseOffset = 0.0,
    this.poseSwitchInterval = const Duration(milliseconds: 9000),
    this.walkSpan,
    this.blinkFrames,
    this.flutterFrames,
  });
}

/// Full-bleed **Living Animated Treehouse** scene layered over the 4-phase
/// illustrated cutaway backgrounds (`treehouse_dawn.jpg`, `treehouse_day.jpg`,
/// `treehouse_sunset.jpg`, `treehouse_night.jpg`).
///
/// Performance & Accessibility Guardrails:
/// - All overlays and full cutaway room hit zones align via fractional
///   (`0.0–1.0`) coordinates mapped onto the exact rendered image rectangle
///   inside `LayoutBuilder`.
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

  /// Bottom overlay clearance reserving breathing room above the raised `+`
  /// Quick Capture FAB (`16dp` overhang + `24dp` extra clearance = `40dp`).
  final double bottomOverlayClearance;

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
    this.bottomOverlayClearance = 40.0,
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
    final topInset = MediaQuery.paddingOf(context).top;
    final currentTime = widget.clockOverride ?? _now;
    final effectiveOverride = widget.onSelectPhaseOverride != null
        ? widget.phase
        : _localPhaseOverride;
    final activePhase =
        effectiveOverride ?? TreehouseDayPhaseX.resolve(currentTime);
    final backdropAsset =
        widget.backdropAssetPath ?? activePhase.backdropAsset;
    final isRainy = widget.weather?.isRainy ?? false;
    final isHeavyRain = widget.weather?.isHeavyRain ?? false;
    final weatherCond = widget.weather?.condition.toLowerCase() ?? '';
    final isCoolBreeze = !isRainy &&
        ((widget.weather?.isCool ?? false) ||
            weatherCond.contains('breeze') ||
            weatherCond.contains('wind') ||
            weatherCond.contains('angin'));

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
              (imageRect.width * 0.165).clamp(48.0, 72.0);

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

                  // 1. 4-Phase Illustrated Cutaway Treehouse Artwork with smooth cross-fade
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

                  // 2. Room Prop Animations for ALL 6 Rooms (Roo clock/pendulum/brass gears,
                  //    Echo skylight stars/telescope/lantern, Scout balcony lantern/map/weather,
                  //    Seren teacup steam/lavender/lamp, Pippin lamp beam/dust motes/compass,
                  //    Twill hanging keys/tools sway & workshop lamp)
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
                          isHeavyRain: isHeavyRain,
                          isCoolBreeze: isCoolBreeze,
                        ),
                      ),
                    ),
                  ),

                  // 3. 6 Interactive Full-Room Cutaway Regions + Living Bird Hotspots
                  for (var i = 0; i < widget.birds.length; i++)
                    _buildInteractiveRoomHotspot(
                      bird: widget.birds[i],
                      index: i,
                      imageRect: imageRect,
                      viewportWidth: width,
                      viewportHeight: height,
                      topInset: topInset,
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

                  // 5. Subtle top/bottom vignette for floating header & bottom hint legibility
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.16, 0.84, 1.0],
                          colors: [
                            Colors.black
                                .withValues(alpha: isDark ? 0.32 : 0.20),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black
                                .withValues(alpha: isDark ? 0.42 : 0.28),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 6. Top floating status pill (Next Alarm + Weather) below transparent AppBar
                  Positioned(
                    top: topInset + 2,
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
                  //    Elevated by bottomOverlayClearance (40dp = 16dp FAB + 24dp extra breathing room)
                  Positioned(
                    key: const Key('nest_scene_bottom_overlay'),
                    bottom: widget.bottomOverlayClearance,
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
                        const SizedBox(height: 2),
                        IgnorePointer(
                          child: Container(
                            key: const Key('nest_scene_tap_hint_pill'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xB810131A),
                              borderRadius: BorderRadius.circular(999),
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

  Widget _buildInteractiveRoomHotspot({
    required TreehouseSceneBirdHotspot bird,
    required int index,
    required Rect imageRect,
    required double viewportWidth,
    required double viewportHeight,
    required double topInset,
    required double maxPillWidth,
    required double spriteSize,
  }) {
    final anchor = TreehouseSceneAnchors.mapPoint(imageRect, bird.fx, bird.fy);
    final slotWidth = maxPillWidth;
    const pillHeight = 25.0;
    final totalHeight = spriteSize + 2 + pillHeight;

    // Plant bird feet (bottom of sprite) right at anchor.dy, with dark-glass
    // status pill resting cleanly on the timber beam beneath the feet.
    final rawLeft = anchor.dx - slotWidth / 2;
    final rawTop = anchor.dy - spriteSize;

    final double minSafeTop = math.max(46.0, topInset + 44.0);
    final double maxSafeTop = math.max(
      minSafeTop,
      viewportHeight - totalHeight - (widget.bottomOverlayClearance + 76.0),
    );

    final double safeLeft = rawLeft
        .clamp(6.0, math.max(6.0, viewportWidth - slotWidth - 6.0))
        .toDouble();
    final double safeTop = rawTop.clamp(minSafeTop, maxSafeTop).toDouble();
    final birdRect = Rect.fromLTWH(safeLeft, safeTop, slotWidth, totalHeight);

    final Rect mappedRoomRect;
    if (bird.roomBounds != null) {
      final rawRoom = TreehouseSceneAnchors.mapRect(
        imageRect,
        bird.roomBounds!,
      );
      final clampedLeft = rawRoom.left.clamp(0.0, viewportWidth - 48.0);
      final clampedTop = rawRoom.top.clamp(0.0, viewportHeight - 48.0);
      final clampedRight =
          rawRoom.right.clamp(clampedLeft + 48.0, viewportWidth);
      final clampedBottom =
          rawRoom.bottom.clamp(clampedTop + 48.0, viewportHeight);
      mappedRoomRect = Rect.fromLTRB(
        clampedLeft.toDouble(),
        clampedTop.toDouble(),
        clampedRight.toDouble(),
        clampedBottom.toDouble(),
      );
    } else {
      mappedRoomRect = birdRect.inflate(8);
    }

    // Calibrate safe horizontal pacing bounds in logical pixels inside this
    // room's floor so the bird strolls naturally without clipping walls/edges.
    final birdCenterX = birdRect.center.dx;
    final halfSprite = spriteSize * 0.46;
    final minAllowedCenterX = math.max(
      mappedRoomRect.left + halfSprite,
      halfSprite + 4.0,
    );
    final maxAllowedCenterX = math.min(
      mappedRoomRect.right - halfSprite,
      viewportWidth - halfSprite - 4.0,
    );
    double pacingRangeLeft = 0.0;
    double pacingRangeRight = 0.0;
    if (bird.walkSpan != null) {
      final targetMinX = imageRect.left + imageRect.width * bird.walkSpan!.minFx;
      final targetMaxX = imageRect.left + imageRect.width * bird.walkSpan!.maxFx;
      final clampedMinX = math.max(targetMinX, minAllowedCenterX);
      final clampedMaxX = math.min(targetMaxX, maxAllowedCenterX);
      pacingRangeLeft = math.max(0.0, birdCenterX - clampedMinX).clamp(0.0, 34.0);
      pacingRangeRight =
          math.max(0.0, clampedMaxX - birdCenterX).clamp(0.0, 34.0);
    }

    // Unified bounding box containing both the full cutaway room interior and
    // the bird sprite + floating pill so tapping or long-pressing anywhere in
    // the room gives unified scale/glow feedback without sibling occlusion.
    final unionRect = mappedRoomRect.expandToInclude(birdRect);
    final localRoomRect = mappedRoomRect.shift(-unionRect.topLeft);
    final localBirdRect = birdRect.shift(-unionRect.topLeft);

    final staggerOffset =
        bird.phaseOffset != 0.0 ? bird.phaseOffset : index * 1.05;

    return Positioned.fromRect(
      rect: unionRect,
      child: _InteractiveCutawayRoom(
        bird: bird,
        localRoomRect: localRoomRect,
        localBirdRect: localBirdRect,
        spriteSize: spriteSize,
        pacingRangeLeft: pacingRangeLeft,
        pacingRangeRight: pacingRangeRight,
        ambientAnimation: _ambientController,
        phaseOffset: staggerOffset,
      ),
    );
  }
}

class _InteractiveCutawayRoom extends StatefulWidget {
  final TreehouseSceneBirdHotspot bird;
  final Rect localRoomRect;
  final Rect localBirdRect;
  final double spriteSize;
  final double pacingRangeLeft;
  final double pacingRangeRight;
  final Animation<double> ambientAnimation;
  final double phaseOffset;

  const _InteractiveCutawayRoom({
    required this.bird,
    required this.localRoomRect,
    required this.localBirdRect,
    required this.spriteSize,
    required this.pacingRangeLeft,
    required this.pacingRangeRight,
    required this.ambientAnimation,
    required this.phaseOffset,
  });

  @override
  State<_InteractiveCutawayRoom> createState() =>
      _InteractiveCutawayRoomState();
}

class _InteractiveCutawayRoomState extends State<_InteractiveCutawayRoom> {
  final GlobalKey<AnimatedMascotSpriteState> _spriteKey =
      GlobalKey<AnimatedMascotSpriteState>();
  bool _isPressed = false;
  bool _isLongPressGlow = false;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) return;
    setState(() => _isPressed = value);
  }

  void _handleTap() {
    _setPressed(false);
    final spriteState = _spriteKey.currentState;
    if (spriteState != null) {
      spriteState.triggerHopAndTap(widget.bird.onTap);
    } else {
      widget.bird.onTap();
    }
  }

  void _handleLongPress() {
    final onLongPress = widget.bird.onLongPress;
    if (onLongPress == null) return;
    HapticFeedback.mediumImpact();
    _flashTimer?.cancel();
    setState(() {
      _isPressed = false;
      _isLongPressGlow = true;
    });
    onLongPress();
    _flashTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) {
        setState(() => _isLongPressGlow = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bird = widget.bird;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final activeHighlight = _isPressed || _isLongPressGlow;
    final animDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 120);

    return Semantics(
      button: true,
      label: '${bird.name} • ${bird.compactMetric}',
      child: GestureDetector(
        key: bird.roomKey,
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _handleTap,
        onLongPress: bird.onLongPress != null ? _handleLongPress : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: animDuration,
          curve: Curves.easeOutCubic,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Subtle press / long-press interior glow covering the cutaway room
              Positioned.fromRect(
                rect: widget.localRoomRect,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: animDuration,
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: activeHighlight
                          ? RadialGradient(
                              colors: [
                                bird.accentColor.withValues(
                                  alpha: _isLongPressGlow ? 0.34 : 0.22,
                                ),
                                bird.accentColor.withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.62, 1.0],
                            )
                          : null,
                      border: Border.all(
                        color: bird.accentColor.withValues(
                          alpha: activeHighlight
                              ? (_isLongPressGlow ? 0.72 : 0.50)
                              : 0.0,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: activeHighlight
                          ? [
                              BoxShadow(
                                color: bird.accentColor.withValues(alpha: 0.28),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),

              // Living animated bird sprite + floating dark-glass status pill
              Positioned.fromRect(
                rect: widget.localBirdRect,
                child: KeyedSubtree(
                  key: bird.key,
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
                        poseSwitchInterval: bird.poseSwitchInterval,
                        blinkFrames: bird.blinkFrames,
                        flutterFrames: bird.flutterFrames,
                        enableRoomPacing:
                            (widget.pacingRangeLeft + widget.pacingRangeRight) >=
                                2.0,
                        pacingRangeLeft: widget.pacingRangeLeft,
                        pacingRangeRight: widget.pacingRangeRight,
                        showSubtleHalo: false,
                      ),
                      const SizedBox(height: 2),
                      // Compact floating dark-glass full-pill status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xD911141C),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: bird.accentColor.withValues(alpha: 0.55),
                            width: 0.9,
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
                              width: 6,
                              height: 6,
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
                ),
              ),
            ],
          ),
        ),
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

    return SizedBox(
      key: const Key('nest_scene_phase_scrubber'),
      height: 48,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sleek dark-glass pill rail visually centered behind 48dp hit targets
            Positioned.fill(
              top: 8,
              bottom: 8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xCC10131C),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final opt in options)
                    _buildChip(
                      key: Key(opt.$1),
                      phase: opt.$2,
                      icon: opt.$3,
                      label: opt.$4,
                    ),
                ],
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

    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelectPhase(phase),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.28)
                    : (isLiveActive
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(999),
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
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFFD1D5DB),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

    return SizedBox(
      height: 48,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sleek dark-glass capsule visually centered inside 48dp hit zone
            Positioned.fill(
              top: 7,
              bottom: 7,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xBF12151E),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: const Key('nest_scene_top_alarm_tap'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapAlarm,
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
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
                              nextAlarmTime ??
                                  l10n.tr('nest_status_no_alarm'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (weather != null) ...[
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    GestureDetector(
                      key: const Key('nest_scene_top_weather_tap'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onTapWeather,
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
