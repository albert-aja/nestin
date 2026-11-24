import 'dart:async';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// Instantaneous horizontal pacing transform computed for a bird in Treehouse
/// Scene mode.
typedef BirdPacingState = ({
  double dx,
  double stepBobDy,
  bool flipX,
  bool isWalking,
});

/// Reusable living mascot sprite widget for both the Illustrated Treehouse
/// Scene and the 2×3 Bird Rooms Grid.
///
/// Features:
/// - **Organic Idle Motion:** Driven by a shared parent [ambientAnimation]
///   (`0.0 -> 1.0`, seamless 12s integer harmonics) so all birds share one ticker:
///   - Gentle breathing (`Transform.scale` anchored at `Alignment.bottomCenter`,
///     `1.00 -> 1.032`).
///   - Subtle micro-sway (`±0.018 rad` anchored at `Alignment.bottomCenter`).
///   - Per-bird [phaseOffset] staggering so companions never breathe in lockstep.
/// - **Calm Staggered Pose Switching:** Slowly cycles across [spriteAsset] and
///   optional [blinkFrames] / [flutterFrames] on a calm, staggered **`7–11s`**
///   [poseSwitchInterval] using a smooth **`450ms`** `AnimatedSwitcher` fade
///   instead of rapid hard cuts. Pauses cleanly whenever `TickerMode` is off or
///   reduced motion is enabled.
/// - **Gentle Horizontal Room Pacing (Treehouse View):** When
///   [enableRoomPacing] is enabled, gently strolls left and right within
///   `[-pacingRangeLeft, +pacingRangeRight]` with natural idle pauses (~52%
///   resting, ~48% strolling), tiny organic step bobs, and horizontal direction
///   flips (`Transform.flip(flipX: ...)`).
/// - **Springy Hop Bounce on Tap:** Plays a crisp squash-and-hop arc before
///   invoking [onTap] to open the bird's House screen.
/// - **Reduced Motion:** Respects `MediaQuery.maybeDisableAnimationsOf(context)`
///   by rendering statically and invoking [onTap] immediately.
class AnimatedMascotSprite extends StatefulWidget {
  final String spriteAsset;
  final double size;
  final Color accentColor;
  final IconData fallbackIcon;

  /// Shared looping `0.0 -> 1.0` animation controller owned by the parent view.
  final Animation<double> ambientAnimation;

  /// Stagger offset in radians (`0.0 .. 2π`) to desynchronize birds organically.
  final double phaseOffset;

  /// Optional callback fired after the springy tap hop completes.
  final VoidCallback? onTap;

  /// Optional secondary calm pose assets cycled gently with [spriteAsset].
  final List<String>? blinkFrames;

  /// Optional expressive alternate pose assets cycled gently with [spriteAsset].
  final List<String>? flutterFrames;

  /// Calm per-bird pose-switching interval (recommended staggered `7–11s`).
  final Duration poseSwitchInterval;

  /// Smooth cross-fade duration for `AnimatedSwitcher` pose swaps (`450ms`).
  final Duration poseTransitionDuration;

  /// Enables gentle horizontal left-right room pacing (Treehouse Scene mode).
  final bool enableRoomPacing;

  /// Maximum safe horizontal pacing distance (in logical pixels) left of anchor.
  final double pacingRangeLeft;

  /// Maximum safe horizontal pacing distance (in logical pixels) right of anchor.
  final double pacingRangeRight;

  /// Whether to render a soft subtle accent halo behind the transparent sprite.
  final bool showSubtleHalo;

  const AnimatedMascotSprite({
    super.key,
    required this.spriteAsset,
    required this.size,
    required this.accentColor,
    required this.fallbackIcon,
    required this.ambientAnimation,
    this.phaseOffset = 0.0,
    this.onTap,
    this.blinkFrames,
    this.flutterFrames,
    this.poseSwitchInterval = const Duration(milliseconds: 9000),
    this.poseTransitionDuration = const Duration(milliseconds: 450),
    this.enableRoomPacing = false,
    this.pacingRangeLeft = 0.0,
    this.pacingRangeRight = 0.0,
    this.showSubtleHalo = false,
  });

  /// Builds the deduplicated calm pose sequence anchored on [spriteAsset] so
  /// each bird returns gracefully to its primary reactive pose between visits
  /// to alternate poses.
  List<String> buildPoseSequence() {
    final alternates = <String>[];
    void addUnique(List<String>? list) {
      if (list == null) return;
      for (final asset in list) {
        if (asset.isNotEmpty &&
            asset != spriteAsset &&
            !alternates.contains(asset)) {
          alternates.add(asset);
        }
      }
    }

    addUnique(blinkFrames);
    addUnique(flutterFrames);
    if (alternates.isEmpty) return <String>[spriteAsset];

    // Interleave primary reactive pose so the companion naturally dwells on
    // its live domain state between calm alternate poses.
    final seq = <String>[];
    for (final alt in alternates) {
      seq.add(spriteAsset);
      seq.add(alt);
    }
    return seq;
  }

  /// Resolves the active sprite asset for a given pose index or normalized
  /// progress [ambientT] (`0.0..1.0`) for deterministic tests.
  String resolveActiveFrameAsset(
    double ambientT, {
    bool disableAnimations = false,
  }) {
    if (disableAnimations) return spriteAsset;
    final sequence = buildPoseSequence();
    if (sequence.length <= 1) return spriteAsset;
    final shifted = (ambientT + phaseOffset / (2 * math.pi)) % 1.0;
    final idx = (shifted * sequence.length).floor().clamp(0, sequence.length - 1);
    return sequence[idx];
  }

  /// Computes gentle, organic left-right room pacing with natural idle pauses
  /// (~52% paused, ~48% strolling), smooth ease-in-out movement, subtle walk
  /// step bob, and horizontal direction flip (`flipX`).
  ///
  /// Seamless at `ambientT = 0.0 == 1.0` across the shared 12-second loop.
  static BirdPacingState computePacingState(
    double ambientT, {
    required double phaseOffset,
    required double rangeLeft,
    required double rangeRight,
    bool disableAnimations = false,
  }) {
    final safeLeft = math.max(0.0, rangeLeft);
    final safeRight = math.max(0.0, rangeRight);
    if (disableAnimations || (safeLeft + safeRight) < 2.0) {
      return (dx: 0.0, stepBobDy: 0.0, flipX: false, isWalking: false);
    }

    final u = (ambientT + phaseOffset / (2 * math.pi)) % 1.0;

    // 4-phase seamless stroll loop:
    // [0.00, 0.24): Calm idle pause on left side (facing right)
    // [0.24, 0.48): Gentle stroll left -> right (facing right)
    // [0.48, 0.74): Calm idle pause on right side (facing left/resting)
    // [0.74, 0.98): Gentle stroll right -> left (facing left, flipX = true)
    // [0.98, 1.00): Settle smoothly into left idle pause
    if (u < 0.24) {
      return (dx: -safeLeft, stepBobDy: 0.0, flipX: false, isWalking: false);
    }
    if (u < 0.48) {
      final p = (u - 0.24) / 0.24;
      final eased = 0.5 - 0.5 * math.cos(p * math.pi);
      final dx = -safeLeft + (safeLeft + safeRight) * eased;
      // Subtle cute footstep bounce fading in/out at walk start & stop
      final envelope = math.sin(p * math.pi);
      final stepBobDy = -math.sin(p * math.pi * 6).abs() * 2.2 * envelope;
      return (dx: dx, stepBobDy: stepBobDy, flipX: false, isWalking: true);
    }
    if (u < 0.74) {
      return (dx: safeRight, stepBobDy: 0.0, flipX: true, isWalking: false);
    }
    if (u < 0.98) {
      final p = (u - 0.74) / 0.24;
      final eased = 0.5 - 0.5 * math.cos(p * math.pi);
      final dx = safeRight - (safeLeft + safeRight) * eased;
      final envelope = math.sin(p * math.pi);
      final stepBobDy = -math.sin(p * math.pi * 6).abs() * 2.2 * envelope;
      return (dx: dx, stepBobDy: stepBobDy, flipX: true, isWalking: true);
    }
    return (dx: -safeLeft, stepBobDy: 0.0, flipX: false, isWalking: false);
  }

  @override
  State<AnimatedMascotSprite> createState() => AnimatedMascotSpriteState();
}

class AnimatedMascotSpriteState extends State<AnimatedMascotSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hopController;
  Timer? _poseTimer;
  List<String> _poseSequence = const <String>[];
  int _poseIndex = 0;
  bool _isHopping = false;
  bool _tickersEnabled = true;
  bool _disableAnimations = false;

  /// Exposes the currently displayed pose asset path (for tests & debugging).
  String get currentPoseAsset {
    if (_disableAnimations || _poseSequence.isEmpty) {
      return widget.spriteAsset;
    }
    return _poseSequence[_poseIndex % _poseSequence.length];
  }

  @override
  void initState() {
    super.initState();
    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
    _poseSequence = widget.buildPoseSequence();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final tickersEnabled = TickerMode.valuesOf(context).enabled;
    final changed = disableAnimations != _disableAnimations ||
        tickersEnabled != _tickersEnabled;
    _disableAnimations = disableAnimations;
    _tickersEnabled = tickersEnabled;
    if (changed || _poseTimer == null) {
      _syncPoseTimer();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedMascotSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSequence = widget.buildPoseSequence();
    final spriteChanged = widget.spriteAsset != oldWidget.spriteAsset;
    final framesChanged =
        nextSequence.length != _poseSequence.length ||
        !_listEquals(nextSequence, _poseSequence);

    if (spriteChanged || framesChanged) {
      _poseSequence = nextSequence;
      if (spriteChanged) {
        _poseIndex = 0;
      } else if (_poseSequence.isNotEmpty) {
        _poseIndex = _poseIndex % _poseSequence.length;
      }
    }

    if (spriteChanged ||
        framesChanged ||
        widget.poseSwitchInterval != oldWidget.poseSwitchInterval ||
        widget.phaseOffset != oldWidget.phaseOffset) {
      _syncPoseTimer(restart: true);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _syncPoseTimer({bool restart = false}) {
    final shouldCycle =
        _tickersEnabled && !_disableAnimations && _poseSequence.length > 1;
    if (!shouldCycle) {
      _poseTimer?.cancel();
      _poseTimer = null;
      return;
    }

    if (_poseTimer != null && !restart) return;
    _poseTimer?.cancel();

    // Stagger initial pose swap across birds using phaseOffset so the flock
    // transitions organically and never flickers in unison.
    final intervalMs = widget.poseSwitchInterval.inMilliseconds.clamp(
      7000,
      11500,
    );
    final staggerFraction =
        ((widget.phaseOffset % (2 * math.pi)) / (2 * math.pi)).clamp(0.0, 0.95);
    final initialDelayMs = (intervalMs * (0.45 + 0.55 * staggerFraction)).round();

    _poseTimer = Timer(Duration(milliseconds: initialDelayMs), () {
      if (!mounted || !_tickersEnabled || _disableAnimations) return;
      _advancePose();
      _poseTimer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => _advancePose(),
      );
    });
  }

  void _advancePose() {
    if (!mounted || !_tickersEnabled || _disableAnimations) return;
    if (_poseSequence.length <= 1) return;
    setState(() {
      _poseIndex = (_poseIndex + 1) % _poseSequence.length;
    });
  }

  @override
  void dispose() {
    _poseTimer?.cancel();
    _hopController.dispose();
    super.dispose();
  }

  /// Plays the springy hop bounce (unless reduced motion is enabled) and then
  /// fires [overrideCallback] or `widget.onTap`.
  Future<void> triggerHopAndTap([VoidCallback? overrideCallback]) async {
    final callback = overrideCallback ?? widget.onTap;
    if (callback == null || _isHopping) return;

    HapticFeedback.lightImpact();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations || !TickerMode.valuesOf(context).enabled) {
      callback();
      return;
    }

    _isHopping = true;
    try {
      await _hopController.forward(from: 0.0);
    } catch (_) {
      // Safe if widget unmounts mid-hop
    } finally {
      _isHopping = false;
    }
    if (mounted) {
      _hopController.value = 0.0;
      callback();
    }
  }

  Widget _buildSpriteImage(String assetPath) {
    final image = Image.asset(
      assetPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.accentColor.withValues(alpha: 0.25),
        ),
        child: Icon(
          widget.fallbackIcon,
          color: Colors.white,
          size: widget.size * 0.52,
        ),
      ),
    );

    if (!widget.showSubtleHalo) return image;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            widget.accentColor.withValues(alpha: 0.24),
            widget.accentColor.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.62, 1.0],
        ),
      ),
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final activeAsset = currentPoseAsset;

    // Smooth 450ms AnimatedSwitcher fade lives outside the 60fps AnimatedBuilder
    // so pose images only rebuild when a calm 7–11s pose transition triggers.
    final spriteSwitcher = AnimatedSwitcher(
      duration: disableAnimations
          ? Duration.zero
          : widget.poseTransitionDuration,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [
          ...previousChildren,
          ?currentChild,
        ],
      ),
      child: KeyedSubtree(
        key: ValueKey<String>(activeAsset),
        child: _buildSpriteImage(activeAsset),
      ),
    );

    final animatedVisual = RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.ambientAnimation, _hopController]),
        child: spriteSwitcher,
        builder: (context, child) {
          final spriteWidget = child!;

          if (disableAnimations) {
            return spriteWidget;
          }

          final t = widget.ambientAnimation.value;
          // Seamless integer harmonics across the shared 12-second cycle:
          // - Breathing: 3 cycles / 12s (4s calm breath), scale 1.00 -> 1.032
          final breathWave =
              0.5 - 0.5 * math.cos(t * 2 * math.pi * 3 + widget.phaseOffset);
          final breathScale = 1.0 + 0.032 * breathWave;

          // - Micro-sway: 2 cycles / 12s (6s organic drift), ±0.018 rad
          final swayAngle =
              math.sin(t * 2 * math.pi * 2 + widget.phaseOffset * 1.37) * 0.018;

          // - Gentle horizontal room pacing (Treehouse View only)
          final pacing = widget.enableRoomPacing
              ? AnimatedMascotSprite.computePacingState(
                  t,
                  phaseOffset: widget.phaseOffset,
                  rangeLeft: widget.pacingRangeLeft,
                  rangeRight: widget.pacingRangeRight,
                  disableAnimations: disableAnimations,
                )
              : (dx: 0.0, stepBobDy: 0.0, flipX: false, isWalking: false);

          // - Springy tap hop arc: quick squash -> upward hop -> crisp settle
          final hopT = _hopController.value;
          double hopDy = 0.0;
          double hopScaleX = 1.0;
          double hopScaleY = 1.0;
          if (hopT > 0.0) {
            if (hopT < 0.22) {
              final u = hopT / 0.22;
              hopScaleY = 1.0 - 0.10 * u;
              hopScaleX = 1.0 + 0.07 * u;
            } else {
              final u = (hopT - 0.22) / 0.78;
              final arc = math.sin(u * math.pi);
              hopDy = -arc * (widget.size * 0.20);
              hopScaleY = 1.0 + 0.09 * arc;
              hopScaleX = 1.0 - 0.04 * arc;
            }
          }

          Widget transformed = Transform.scale(
            alignment: Alignment.bottomCenter,
            scaleX: breathScale * hopScaleX,
            scaleY: breathScale * hopScaleY,
            child: spriteWidget,
          );

          if (pacing.flipX) {
            transformed = Transform.flip(
              flipX: true,
              child: transformed,
            );
          }

          return Transform.translate(
            offset: Offset(pacing.dx, hopDy + pacing.stepBobDy),
            child: Transform.rotate(
              alignment: Alignment.bottomCenter,
              angle: swayAngle,
              child: transformed,
            ),
          );
        },
      ),
    );

    if (widget.onTap == null) {
      return animatedVisual;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => triggerHopAndTap(),
      child: animatedVisual,
    );
  }
}
