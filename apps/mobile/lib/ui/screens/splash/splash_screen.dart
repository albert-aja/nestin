import 'dart:async';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
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
  final String? customPhotoPath;
  final String? remotePackSlug;
  final Map<String, String>? installedRemotePackPaths;

  const SplashScreen({
    super.key,
    required this.onFinish,
    this.minDuration = const Duration(milliseconds: 1400),
    this.animationDuration,
    this.currentDate,
    this.seasonalThemeOverride,
    this.customPhotoPath,
    this.remotePackSlug,
    this.installedRemotePackPaths,
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
  late SeasonalLoadingSpec _seasonalSpec;

  _SplashPhase _phase = _SplashPhase.logoBanner;
  Timer? _phaseTimer;
  Timer? _finishTimer;
  bool _precachedWallpaper = false;

  int _computePhase1Ms(Duration minDuration) {
    final totalMs = minDuration.inMilliseconds;
    if (totalMs <= 0) return 0;
    return (totalMs * 0.48).round().clamp(180, totalMs - 180);
  }

  Duration _computeIntroAnimDuration(Duration minDuration) {
    final phase1Ms = _computePhase1Ms(minDuration);
    if (phase1Ms <= 0) return Duration.zero;
    final maxIntroMs = (phase1Ms * 0.55).round().clamp(160, 480);
    final requestedMs = widget.animationDuration?.inMilliseconds ?? maxIntroMs;
    return Duration(milliseconds: requestedMs.clamp(160, maxIntroMs));
  }

  @override
  void initState() {
    super.initState();
    _resolveSeasonalSpec();

    _introController = AnimationController(
      vsync: this,
      duration: _computeIntroAnimDuration(widget.minDuration),
    );

    _wallpaperController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _subtleSlideAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.10, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _schedulePhaseTimers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precachedWallpaper && _seasonalSpec.wallpaperAsset != null) {
      _precachedWallpaper = true;
      unawaited(
        precacheImage(AssetImage(_seasonalSpec.wallpaperAsset!), context)
            .catchError((_) {}),
      );
    }
  }

  void _resolveSeasonalSpec() {
    _seasonalSpec = SeasonalSplashResolver.resolve(
      now: widget.currentDate,
      override: widget.seasonalThemeOverride,
      customPhotoPath: widget.customPhotoPath,
      remotePackSlug: widget.remotePackSlug,
      installedRemotePackPaths: widget.installedRemotePackPaths,
    );
  }

  void _schedulePhaseTimers() {
    _phaseTimer?.cancel();
    _finishTimer?.cancel();

    if (widget.minDuration <= Duration.zero) {
      _introController.duration = Duration.zero;
      _introController.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onFinish();
        }
      });
    } else {
      _phase = _SplashPhase.logoBanner;
      _introController.duration = _computeIntroAnimDuration(widget.minDuration);
      final phase1Ms = _computePhase1Ms(widget.minDuration);

      // Wait until the first frame paints so cold-start decoding does not
      // consume the user's configured splash dwell duration (e.g. 2.2s).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _introController.forward(from: 0.0);

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
      });
    }
  }

  @override
  void didUpdateWidget(covariant SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDate != widget.currentDate ||
        oldWidget.seasonalThemeOverride != widget.seasonalThemeOverride ||
        oldWidget.customPhotoPath != widget.customPhotoPath ||
        oldWidget.remotePackSlug != widget.remotePackSlug ||
        oldWidget.installedRemotePackPaths != widget.installedRemotePackPaths) {
      setState(_resolveSeasonalSpec);
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
    final scaffoldBg = _phase == _SplashPhase.logoBanner
        ? Colors.white
        : (isDark ? AppColors.darkBg : AppColors.lightBg);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _phase == _SplashPhase.logoBanner
            ? _buildLogoBannerPhase(context)
            : _buildSeasonalWallpaperPhase(context, isDark),
      ),
    );
  }

  Widget _buildLogoBannerPhase(BuildContext context) {
    final l10n = context.l10n;

    return ColoredBox(
      key: const ValueKey('splash_phase_logo_banner'),
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Clean centered Nestin logo banner on pure white background
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 260,
                          maxHeight: 220,
                        ),
                        child: Image.asset(
                          'assets/banner.jpg',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/logo.jpg',
                            width: 112,
                            height: 112,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.brandTagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Subtle bottom sanctuary imprint on clean white
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
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
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
                          color: AppColors.lightTextMuted.withValues(alpha: 0.80),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
    final customFilePath = spec.customWallpaperFilePath;
    final hasCustomFile = customFilePath != null &&
        customFilePath.trim().isNotEmpty &&
        File(customFilePath).existsSync();
    final hasWallpaper = hasCustomFile || spec.wallpaperAsset != null;
    final phaseKeySuffix = (widget.customPhotoPath != null &&
            widget.customPhotoPath!.trim().isNotEmpty &&
            hasCustomFile)
        ? 'custom_photo'
        : (spec.hasRemotePack ? 'pack_${spec.remotePackSlug}' : spec.theme.name);

    return Stack(
      key: ValueKey('splash_phase_seasonal_$phaseKeySuffix'),
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

        // Illustrated seasonal wallpaper, downloaded pack, or personal photo
        if (hasWallpaper) ...[
          Positioned.fill(
            child: hasCustomFile
                ? (Platform.environment.containsKey('FLUTTER_TEST')
                    ? DecoratedBox(
                        key: const ValueKey('splash_custom_file_image'),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                          ),
                        ),
                      )
                    : Image.file(
                        File(customFilePath),
                        key: const ValueKey('splash_custom_file_image'),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => spec.wallpaperAsset != null
                            ? Image.asset(
                                spec.wallpaperAsset!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              )
                            : const SizedBox.shrink(),
                      ))
                : Image.asset(
                    spec.wallpaperAsset!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
          ),
          // Subtle top & bottom vignettes so text/loader stay legible while
          // keeping the middle scene & mascot flock crisp and unobstructed.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.58),
                  ],
                  stops: const [0.0, 0.30, 0.72, 1.0],
                ),
              ),
            ),
          ),
        ] else
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
                  isDark: hasWallpaper ? true : isDark,
                  accentColor: spec.accentColor,
                  secondaryAccentColor: spec.secondaryAccentColor,
                ),
              );
            },
          ),
        ),

        // Header / Centerpiece content
        SafeArea(
          child: Align(
            alignment: hasWallpaper ? Alignment.topCenter : Alignment.center,
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, hasWallpaper ? 28 : 0, 28, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: hasWallpaper
                          ? Colors.black.withValues(alpha: 0.36)
                          : spec.accentColor.withValues(
                              alpha: isDark ? 0.22 : 0.14,
                            ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (hasWallpaper
                                ? spec.secondaryAccentColor
                                : spec.accentColor)
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      l10n.tr(spec.badgeKey),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: hasWallpaper || isDark
                            ? spec.secondaryAccentColor
                            : spec.accentColor,
                      ),
                    ),
                  ),
                  SizedBox(height: hasWallpaper ? 14 : 22),

                  if (!hasWallpaper) ...[
                    // Seasonal Mascot Medallion (procedural fallback seasons)
                    Container(
                      width: 152,
                      height: 152,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isDark ? Colors.white : spec.accentColor)
                            .withValues(alpha: isDark ? 0.08 : 0.09),
                        border: Border.all(
                          color:
                              spec.secondaryAccentColor.withValues(alpha: 0.45),
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
                  ],

                  Text(
                    l10n.tr(spec.titleKey),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: hasWallpaper ? 26 : 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: hasWallpaper ? Colors.white : textPrimary,
                      shadows: hasWallpaper
                          ? const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 12,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
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
                      color: hasWallpaper
                          ? Colors.white.withValues(alpha: 0.90)
                          : textMuted,
                      shadows: hasWallpaper
                          ? const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
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
          bottom: 32,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 5,
                    child: LinearProgressIndicator(
                      backgroundColor: (hasWallpaper || isDark
                              ? Colors.white
                              : Colors.black)
                          .withValues(alpha: hasWallpaper ? 0.24 : 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hasWallpaper ? spec.secondaryAccentColor : spec.accentColor,
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
                    color: hasWallpaper
                        ? Colors.white.withValues(alpha: 0.92)
                        : textMuted.withValues(alpha: 0.85),
                    shadows: hasWallpaper
                        ? const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
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
