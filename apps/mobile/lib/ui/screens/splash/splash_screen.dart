import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import 'seasonal_loading_theme.dart';
import 'seasonal_wallpaper_painter.dart';

enum _SplashPhase {
  logoBanner,
  seasonalWallpaper,
}

/// Animated two-phase branded splash & seasonal wallpaper loading screen.
///
/// Phase 1 displays the Nestin app logo & banner (`assets/logo.jpg` over
/// `assets/banner.jpg`).
/// Phase 2 smoothly cross-fades into a seasonal wallpaper loading screen
/// (e.g. Christmas in December, New Year in January, Spring Bloom, etc.).
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final Duration minDuration;
  final Duration? animationDuration;
  final DateTime? currentDate;
  final SeasonalSplashTheme? seasonalThemeOverride;

  const SplashScreen({
    super.key,
    required this.onFinish,
    this.minDuration = const Duration(milliseconds: 1400),
    this.animationDuration,
    this.currentDate,
    this.seasonalThemeOverride,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _wallpaperController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _subtleSlideAnimation;
  late final SeasonalLoadingSpec _seasonalSpec;

  _SplashPhase _phase = _SplashPhase.logoBanner;
  Timer? _phaseTimer;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();
    _seasonalSpec = SeasonalSplashResolver.resolve(
      now: widget.currentDate,
      override: widget.seasonalThemeOverride,
    );

    final effectiveAnimDuration = widget.animationDuration ??
        (widget.minDuration <= Duration.zero
            ? Duration.zero
            : (widget.minDuration.inMilliseconds < 1100
                ? Duration(
                    milliseconds:
                        (widget.minDuration.inMilliseconds * 0.55).round(),
                  )
                : const Duration(milliseconds: 650)));

    _introController = AnimationController(
      vsync: this,
      duration: effectiveAnimDuration,
    );

    _wallpaperController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.80, curve: Curves.easeOutBack),
      ),
    );

    _subtleSlideAnimation = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    if (widget.minDuration <= Duration.zero) {
      _introController.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onFinish();
        }
      });
    } else {
      _introController.forward();
      final totalMs = widget.minDuration.inMilliseconds;
      final phase1Ms = (totalMs * 0.42).round().clamp(180, totalMs - 180);

      _phaseTimer = Timer(Duration(milliseconds: phase1Ms), () {
        if (!mounted) return;
        setState(() {
          _phase = _SplashPhase.seasonalWallpaper;
        });
        _wallpaperController.repeat();
      });

      _finishTimer = Timer(widget.minDuration, () {
        if (mounted) {
          widget.onFinish();
        }
      });
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _finishTimer?.cancel();
    _introController.dispose();
    _wallpaperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: primaryBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _phase == _SplashPhase.logoBanner
            ? _buildLogoBannerPhase(context, isDark, primaryBg)
            : _buildSeasonalWallpaperPhase(context, isDark),
      ),
    );
  }

  Widget _buildLogoBannerPhase(
    BuildContext context,
    bool isDark,
    Color primaryBg,
  ) {
    final l10n = context.l10n;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted;

    return Stack(
      key: const ValueKey('splash_phase_logo_banner'),
      fit: StackFit.expand,
      children: [
        // Background banner image with atmospheric gradient scrims
        Positioned.fill(
          child: Opacity(
            opacity: isDark ? 0.40 : 0.32,
            child: Image.asset(
              'assets/banner.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),

        // Adaptive gradient overlay to softly blend banner into theme background
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryBg.withValues(alpha: isDark ? 0.65 : 0.60),
                  primaryBg.withValues(alpha: isDark ? 0.86 : 0.82),
                  primaryBg,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Centered branded content
        SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _introController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Transform.translate(
                    offset: Offset(0, _subtleSlideAnimation.value),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.38),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          blurRadius: 40,
                          spreadRadius: 4,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.asset(
                        'assets/logo.jpg',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.primary,
                          child: const Icon(
                            Icons.alarm_on_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Nestin',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.brandTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                        color: textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom subtle sanctuary imprint
        Positioned(
          left: 0,
          right: 0,
          bottom: 36,
          child: SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.tr('splash_personal_space'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        color: textMuted.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonalWallpaperPhase(BuildContext context, bool isDark) {
    final l10n = context.l10n;
    final spec = _seasonalSpec;
    final gradientColors = isDark ? spec.darkGradient : spec.lightGradient;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextMuted;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Stack(
      key: ValueKey('splash_phase_seasonal_${spec.theme.name}'),
      fit: StackFit.expand,
      children: [
        // Full-bleed seasonal wallpaper gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
          ),
        ),

        // Subtle sanctuary banner texture underneath
        Positioned.fill(
          child: Opacity(
            opacity: isDark ? 0.14 : 0.10,
            child: Image.asset(
              'assets/banner.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),

        // Seasonal atmospheric artwork painter
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _wallpaperController,
            builder: (context, _) {
              return CustomPaint(
                painter: SeasonalWallpaperPainter(
                  theme: spec.theme,
                  progress:
                      disableAnimations ? 0.25 : _wallpaperController.value,
                  isDark: isDark,
                  accentColor: spec.accentColor,
                  secondaryAccentColor: spec.secondaryAccentColor,
                ),
              );
            },
          ),
        ),

        // Centerpiece seasonal card / mascot medallion
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: spec.accentColor.withValues(
                        alpha: isDark ? 0.22 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: spec.accentColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      l10n.tr(spec.badgeKey),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: isDark
                            ? spec.secondaryAccentColor
                            : spec.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Seasonal Mascot Medallion
                  Container(
                    width: 152,
                    height: 152,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark ? Colors.white : spec.accentColor)
                          .withValues(alpha: isDark ? 0.08 : 0.09),
                      border: Border.all(
                        color: spec.secondaryAccentColor.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: spec.accentColor.withValues(alpha: 0.24),
                          blurRadius: 34,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        spec.mascotAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    l10n.tr(spec.titleKey),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tr(spec.subtitleKey),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom loading bar & watermark
        Positioned(
          left: 36,
          right: 36,
          bottom: 36,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 5,
                    child: LinearProgressIndicator(
                      backgroundColor: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        spec.accentColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.tr('splash_loading_sanctuary'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: textMuted.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
