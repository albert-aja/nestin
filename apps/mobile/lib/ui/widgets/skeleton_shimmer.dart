import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';

/// Provides a shared shimmer animation controller to descendant [SkeletonBox]
/// widgets so entire loading lists animate smoothly with a single ticker.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool enabled;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1300),
    this.enabled = true,
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant SkeletonShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _syncTicker();
  }

  void _syncTicker() {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shouldAnimate = widget.enabled && !disableAnimations;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animation = (widget.enabled && !disableAnimations)
        ? _controller
        : null;
    return _SkeletonShimmerScope(
      animation: animation,
      child: widget.child,
    );
  }
}

class _SkeletonShimmerScope extends InheritedNotifier<Animation<double>> {
  const _SkeletonShimmerScope({
    required Animation<double>? animation,
    required super.child,
  }) : super(notifier: animation);

  static Animation<double>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonShimmerScope>()
        ?.notifier;
  }
}

/// A lightweight themed rectangular placeholder that sweeps a subtle shimmer
/// gradient when wrapped in [SkeletonShimmer].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final animation = _SkeletonShimmerScope.of(context);
    final base = AppColors.trackSurface(context);
    final highlight = AppColors.isDark(context)
        ? Color.lerp(base, AppColors.cardSurface(context), 0.65)!
        : Color.lerp(base, Colors.white, 0.72)!;

    final t = animation?.value ?? 0.5;
    final decoration = animation == null
        ? BoxDecoration(
            color: base,
            borderRadius: borderRadius,
          )
        : BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3.0 * t, -0.15),
              end: Alignment(-0.5 + 3.0 * t, 0.15),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          );

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: decoration,
    );
  }
}

/// A themed placeholder card matching Nestin's card surface and border tokens,
/// suitable for OS capability checks, permission lists, and app usage queries.
class SkeletonPlaceholderCard extends StatelessWidget {
  final bool showLeading;
  final double leadingSize;
  final double leadingBorderRadius;
  final int lineCount;
  final bool showTrailingPill;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const SkeletonPlaceholderCard({
    super.key,
    this.showLeading = true,
    this.leadingSize = 40,
    this.leadingBorderRadius = 12,
    this.lineCount = 2,
    this.showTrailingPill = false,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showLeading) ...[
            SkeletonBox(
              width: leadingSize,
              height: leadingSize,
              borderRadius: BorderRadius.circular(leadingBorderRadius),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkeletonBox(width: 164, height: 14),
                if (lineCount >= 2) ...[
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 220, height: 11),
                ],
                if (lineCount >= 3) ...[
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 128, height: 11),
                ],
              ],
            ),
          ),
          if (showTrailingPill) ...[
            const SizedBox(width: 12),
            SkeletonBox(
              width: 58,
              height: 26,
              borderRadius: BorderRadius.circular(13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders a list of [SkeletonPlaceholderCard] items inside a single
/// [SkeletonShimmer] scope.
class SkeletonCardList extends StatelessWidget {
  final int itemCount;
  final bool showLeading;
  final double leadingSize;
  final double leadingBorderRadius;
  final int lineCount;
  final bool showTrailingPill;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const SkeletonCardList({
    super.key,
    this.itemCount = 4,
    this.showLeading = true,
    this.leadingSize = 40,
    this.leadingBorderRadius = 12,
    this.lineCount = 2,
    this.showTrailingPill = true,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: itemCount,
        itemBuilder: (context, index) => SkeletonPlaceholderCard(
          showLeading: showLeading,
          leadingSize: leadingSize,
          leadingBorderRadius: leadingBorderRadius,
          lineCount: lineCount,
          showTrailingPill: showTrailingPill,
        ),
      ),
    );
  }
}
