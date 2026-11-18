import 'package:flutter/material.dart';

/// A drop-in replacement for [IndexedStack] that applies a subtle Material-style
/// fade-through transition (cross-fade + gentle 98.5% -> 100% scale-in) when
/// [index] changes, while keeping all child [State] objects mounted and alive.
class FadeThroughIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeThroughIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<FadeThroughIndexedStack> createState() =>
      _FadeThroughIndexedStackState();
}

class _FadeThroughIndexedStackState extends State<FadeThroughIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _inOpacity;
  late Animation<double> _inScale;
  late Animation<double> _outOpacity;

  late int _currentIndex;
  int? _previousIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _clampIndex(widget.index);
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _buildAnimations();
    _controller.addStatusListener(_handleStatusChange);
  }

  void _buildAnimations() {
    final inCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    );
    _inOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(inCurve);
    _inScale = Tween<double>(begin: 0.985, end: 1.0).animate(inCurve);
    _outOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeInCubic),
      ),
    );
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previousIndex != null) {
      setState(() {
        _previousIndex = null;
      });
    }
  }

  int _clampIndex(int index) {
    if (widget.children.isEmpty) return 0;
    return index.clamp(0, widget.children.length - 1);
  }

  @override
  void didUpdateWidget(covariant FadeThroughIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    final nextIndex = _clampIndex(widget.index);
    if (nextIndex != _currentIndex) {
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableAnimations || widget.duration == Duration.zero) {
        _previousIndex = null;
        _currentIndex = nextIndex;
        _controller.value = 1.0;
      } else {
        _previousIndex = _currentIndex;
        _currentIndex = nextIndex;
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatusChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List<Widget>.generate(widget.children.length, (i) {
        final isCurrent = i == _currentIndex;
        final isPrevious = i == _previousIndex;
        final isVisible = isCurrent || isPrevious;
        final isTransitioning = _previousIndex != null;

        final Animation<double> opacity = isCurrent
            ? (isTransitioning ? _inOpacity : kAlwaysCompleteAnimation)
            : (isPrevious ? _outOpacity : kAlwaysDismissedAnimation);

        final Animation<double> scale = (isCurrent && isTransitioning)
            ? _inScale
            : kAlwaysCompleteAnimation;

        return Offstage(
          offstage: !isVisible,
          child: TickerMode(
            enabled: isCurrent,
            child: IgnorePointer(
              ignoring: !isCurrent,
              child: FadeTransition(
                opacity: opacity,
                child: ScaleTransition(
                  scale: scale,
                  child: widget.children[i],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
