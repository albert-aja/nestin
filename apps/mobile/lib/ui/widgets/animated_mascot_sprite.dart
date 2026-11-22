import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// Reusable living mascot sprite widget for the Illustrated Treehouse and
/// interactive sanctuary views.
///
/// Features:
/// - **Organic Idle Motion:** Driven by a shared parent [ambientAnimation]
///   (`0.0 -> 1.0`, seamless integer harmonics) so all birds share one ticker:
///   - Gentle breathing (`Transform.scale` anchored at `Alignment.bottomCenter`,
///     `1.00 -> 1.035`).
///   - Subtle micro-sway (`±0.02 rad` anchored at `Alignment.bottomCenter`).
///   - Per-bird [phaseOffset] staggering so companions never breathe in lockstep.
/// - **Springy Hop Bounce on Tap:** Plays a crisp squash-and-hop arc before
///   invoking [onTap] to open the bird's House screen.
/// - **Future Multi-Frame Hook:** Accepts optional [blinkFrames] and
///   [flutterFrames] asset lists that swap cleanly inside brief harmonic windows
///   without altering layout dimensions.
/// - **Reduced Motion:** Respects `MediaQuery.maybeDisableAnimationsOf(context)`
///   by rendering statically and invoking [onTap] immediately.
class AnimatedMascotSprite extends StatefulWidget {
  final String spriteAsset;
  final double size;
  final Color accentColor;
  final IconData fallbackIcon;

  /// Shared looping `0.0 -> 1.0` animation controller owned by the parent scene.
  final Animation<double> ambientAnimation;

  /// Stagger offset in radians (`0.0 .. 2π`) to desynchronize birds organically.
  final double phaseOffset;

  /// Optional callback fired after the springy tap hop completes.
  final VoidCallback? onTap;

  /// Optional future multi-frame blink sprite assets (same dimensions as [spriteAsset]).
  final List<String>? blinkFrames;

  /// Optional future multi-frame wing-flutter sprite assets.
  final List<String>? flutterFrames;

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
    this.showSubtleHalo = false,
  });

  /// Resolves the active sprite asset for the given [ambientT] (`0.0..1.0`),
  /// supporting 2-frame blink and 2-frame wing-flutter sequences without
  /// altering layout dimensions.
  String resolveActiveFrameAsset(
    double ambientT, {
    bool disableAnimations = false,
  }) {
    if (disableAnimations) return spriteAsset;

    final blink = blinkFrames;
    if (blink != null && blink.isNotEmpty) {
      // Crisp 2-frame blink window near the end of each 4s breath cycle
      final cycle = (ambientT * 3.0 + phaseOffset / (2 * math.pi)) % 1.0;
      if (cycle >= 0.90 && cycle < 0.96) {
        final idx = ((cycle - 0.90) / 0.06 * blink.length)
            .floor()
            .clamp(0, blink.length - 1);
        return blink[idx];
      }
    }

    final flutter = flutterFrames;
    if (flutter != null && flutter.isNotEmpty) {
      // Gentle 2-frame wing-flutter window once per 12s cycle
      final shifted = (ambientT + phaseOffset / (2 * math.pi)) % 1.0;
      if (shifted >= 0.44 && shifted < 0.52) {
        final idx = ((shifted - 0.44) / 0.08 * flutter.length)
            .floor()
            .clamp(0, flutter.length - 1);
        return flutter[idx];
      }
    }

    return spriteAsset;
  }

  @override
  State<AnimatedMascotSprite> createState() => AnimatedMascotSpriteState();
}

class AnimatedMascotSpriteState extends State<AnimatedMascotSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hopController;
  bool _isHopping = false;

  @override
  void initState() {
    super.initState();
    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
  }

  @override
  void dispose() {
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

  /// Resolves the active sprite asset for the current frame, supporting future
  /// multi-frame blink/flutter drop-in assets without any layout shifts.
  String _resolveFrameAsset(double ambientT, bool disableAnimations) {
    return widget.resolveActiveFrameAsset(
      ambientT,
      disableAnimations: disableAnimations,
    );
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
    final hasExtraFrames =
        (widget.blinkFrames?.isNotEmpty ?? false) ||
            (widget.flutterFrames?.isNotEmpty ?? false);

    // Cache static child when no frame swapping is active so Image.asset is not
    // rebuilt on animation frames.
    final staticChild =
        hasExtraFrames ? null : _buildSpriteImage(widget.spriteAsset);

    final animatedVisual = RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.ambientAnimation, _hopController]),
        child: staticChild,
        builder: (context, child) {
          final spriteWidget = child ??
              _buildSpriteImage(
                _resolveFrameAsset(
                  widget.ambientAnimation.value,
                  disableAnimations,
                ),
              );

          if (disableAnimations) {
            return spriteWidget;
          }

          final t = widget.ambientAnimation.value;
          // Seamless integer harmonics across the shared 12-second cycle:
          // - Breathing: 3 cycles / 12s (4s calm breath), scale 1.00 -> 1.035
          final breathWave =
              0.5 - 0.5 * math.cos(t * 2 * math.pi * 3 + widget.phaseOffset);
          final breathScale = 1.0 + 0.035 * breathWave;

          // - Micro-sway: 2 cycles / 12s (6s organic drift), ±0.02 rad
          final swayAngle =
              math.sin(t * 2 * math.pi * 2 + widget.phaseOffset * 1.37) * 0.02;

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

          return Transform.translate(
            offset: Offset(0, hopDy),
            child: Transform.rotate(
              alignment: Alignment.bottomCenter,
              angle: swayAngle,
              child: Transform.scale(
                alignment: Alignment.bottomCenter,
                scaleX: breathScale * hopScaleX,
                scaleY: breathScale * hopScaleY,
                child: spriteWidget,
              ),
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
