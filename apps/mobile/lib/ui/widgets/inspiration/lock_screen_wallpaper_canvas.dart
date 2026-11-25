import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/daily_wallpaper_config.dart';
import '../../screens/splash/seasonal_loading_theme.dart';
import '../../screens/splash/seasonal_wallpaper_painter.dart';
import 'mascot_helper.dart';

/// Resolved image source for a custom Lock-Screen Daily Affirmation backdrop.
class DailyWallpaperBackdrop {
  final String? assetPath;
  final String? filePath;

  const DailyWallpaperBackdrop({
    this.assetPath,
    this.filePath,
  });

  bool get hasBackdrop =>
      (filePath != null && filePath!.trim().isNotEmpty) ||
      (assetPath != null && assetPath!.trim().isNotEmpty);

  /// Resolves a [DailyWallpaperConfig.customWallpaperId] (`theme:<name>`,
  /// `pack:<slug>`, or `personal_photo`) to a concrete local file or asset.
  static DailyWallpaperBackdrop resolve({
    required String? customWallpaperId,
    String? customPhotoPath,
    Map<String, String>? installedPackPaths,
  }) {
    final id = customWallpaperId?.trim();
    if (id == null || id.isEmpty) {
      return const DailyWallpaperBackdrop();
    }
    if (id == DailyWallpaperConfig.personalPhotoWallpaperId) {
      final path = customPhotoPath?.trim();
      if (path != null && path.isNotEmpty) {
        return DailyWallpaperBackdrop(filePath: path);
      }
      return const DailyWallpaperBackdrop();
    }
    if (id.startsWith('theme:')) {
      final themeName = id.substring('theme:'.length);
      final theme = SeasonalSplashThemeExt.fromNameOrNull(themeName);
      if (theme != null) {
        final spec = SeasonalSplashResolver.specFor(theme);
        return DailyWallpaperBackdrop(assetPath: spec.wallpaperAsset);
      }
      return const DailyWallpaperBackdrop();
    }
    if (id.startsWith('pack:')) {
      final slug = id.substring('pack:'.length);
      final pack = RemoteHolidayWallpaperCatalog.bySlug(slug);
      final cachedPath = installedPackPaths?[slug]?.trim();
      if (pack != null) {
        return DailyWallpaperBackdrop(
          assetPath: pack.bundledPreviewAsset,
          filePath: (cachedPath != null && cachedPath.isNotEmpty)
              ? cachedPath
              : null,
        );
      }
      if (cachedPath != null && cachedPath.isNotEmpty) {
        return DailyWallpaperBackdrop(filePath: cachedPath);
      }
    }
    return const DailyWallpaperBackdrop();
  }
}

/// Strict 9:16 lock-screen wallpaper canvas used for both live preview inside
/// `DailyWallpaperSheet` and off-screen 7-day rolling PNG pre-rendering.
///
/// Enforces vertical safe zones:
/// - Top 30%: Clear breathing room + subtle top scrim for OS clock/date legibility.
/// - Middle 38% (Sanctuary Band): Centered affirmation with dynamic font
///   auto-scaling (~26sp down to ~19sp), hairline divider, optional bird sprite,
///   and tracked uppercase companion label.
/// - Bottom 32%: Quiet negative space for lock-screen notifications & shortcuts.
class LockScreenWallpaperCanvas extends StatelessWidget {
  static const double topSafeZoneFraction = 0.30;
  static const double middleSafeZoneFraction = 0.38;
  static const double bottomSafeZoneFraction = 0.32;

  static const String treehouseDayAsset = 'assets/images/treehouse_day.jpg';
  static const String treehouseNightAsset = 'assets/images/treehouse_night.jpg';

  final String quoteText;
  final String authorName;
  final String? mascotDomain;
  final DailyWallpaperTemplate template;
  final bool isDark;
  final bool showMascotSprite;
  final DateTime? referenceDate;
  final String? badgeLabelOverride;
  final AppLocalizations? l10nOverride;
  final String? customWallpaperAsset;
  final String? customWallpaperFilePath;

  const LockScreenWallpaperCanvas({
    super.key,
    required this.quoteText,
    required this.authorName,
    required this.template,
    required this.isDark,
    this.mascotDomain,
    this.showMascotSprite = true,
    this.referenceDate,
    this.badgeLabelOverride,
    this.l10nOverride,
    this.customWallpaperAsset,
    this.customWallpaperFilePath,
  });

  bool get _hasCustomWallpaper =>
      (customWallpaperFilePath != null &&
          customWallpaperFilePath!.trim().isNotEmpty) ||
      (customWallpaperAsset != null &&
          customWallpaperAsset!.trim().isNotEmpty);

  /// Computes a calm, balanced base font size from ~26sp down to ~19sp so longer
  /// English or Bahasa Indonesia affirmations fit comfortably inside the 38%
  /// Sanctuary Band without clipping.
  static double computeAutoScaledFontSize(String text) {
    final len = text.trim().length;
    if (len <= 48) return 26.0;
    if (len <= 78) return 23.5;
    if (len <= 115) return 21.5;
    if (len <= 155) return 20.0;
    return 19.0;
  }

  String _resolveTrackedLabel(
    AppLocalizations l10n,
    InspirationMascotMeta? mascot,
  ) {
    if (badgeLabelOverride != null && badgeLabelOverride!.trim().isNotEmpty) {
      return badgeLabelOverride!.trim().toUpperCase();
    }
    final domain = mascot?.domain ?? 'pippin';
    final name = (mascot?.displayName ?? 'Pippin').toUpperCase();
    final suffixKey = switch (domain) {
      'seren' => 'daily_wp_label_gentle_reminder',
      'echo' => 'daily_wp_label_quiet_reflection',
      'roo' => 'daily_wp_label_steady_rhythm',
      'twill' => 'daily_wp_label_mindful_note',
      'scout' => 'daily_wp_label_clear_horizon',
      _ => 'daily_wp_label_daily_spark',
    };
    return '$name • ${l10n.tr(suffixKey).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOverride ?? AppLocalizations.of(context);
    final mascot = inspirationMascotFor(mascotDomain ?? 'pippin') ??
        inspirationMascotFor('pippin')!;
    final accentColor = mascot.accentColor;
    final date = referenceDate ?? DateTime.now();
    final seasonalSpec = SeasonalSplashResolver.resolve(now: date);

    final bool useCustomPhotoBackdrop = _hasCustomWallpaper;
    final Color textColor = useCustomPhotoBackdrop &&
            template != DailyWallpaperTemplate.treehouseGlassCard
        ? Colors.white
        : switch (template) {
            DailyWallpaperTemplate.sanctuaryMinimal =>
              isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            DailyWallpaperTemplate.seasonalAtmosphere =>
              isDark ? AppColors.slate50 : AppColors.lightTextPrimary,
            DailyWallpaperTemplate.treehouseGlassCard =>
              isDark ? AppColors.slate50 : AppColors.lightTextPrimary,
          };

    final Color secondaryTextColor = textColor.withValues(alpha: 0.72);
    final trackedLabel = _resolveTrackedLabel(l10n, mascot);
    final baseFontSize = computeAutoScaledFontSize(quoteText);

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          // Scale typography proportionally if previewed smaller than 360dp wide.
          final scale = (width / 360.0).clamp(0.45, 1.5);
          final topHeight = height * topSafeZoneFraction;
          final middleHeight = height * middleSafeZoneFraction;
          final bottomHeight = height * bottomSafeZoneFraction;
          final horizontalMargin = width * 0.095;

          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1: Template background
                _buildBackground(
                  width: width,
                  height: height,
                  accentColor: accentColor,
                  seasonalSpec: seasonalSpec,
                ),

                // Layer 2: Subtle top 30% scrim for OS clock & date legibility
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topHeight * 1.15,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (isDark ? Colors.black : AppColors.slate900)
                              .withValues(
                            alpha: template ==
                                    DailyWallpaperTemplate.sanctuaryMinimal
                                ? (isDark ? 0.28 : 0.06)
                                : (isDark ? 0.42 : 0.16),
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Layer 3: Strict 30% / 38% / 32% Vertical Safe-Zone Layout
                Column(
                  children: [
                    // Top 30% — Clear breathing room for OS clock & date
                    SizedBox(
                      key: const ValueKey('lock_screen_top_safe_zone'),
                      height: topHeight,
                      width: width,
                    ),

                    // Middle 38% — Sanctuary Band
                    SizedBox(
                      key: const ValueKey('lock_screen_sanctuary_band'),
                      height: middleHeight,
                      width: width,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalMargin,
                          vertical: 8 * scale,
                        ),
                        child: Center(
                          child: _buildSanctuaryBandContent(
                            width: width - (horizontalMargin * 2),
                            maxHeight: middleHeight - (16 * scale),
                            scale: scale,
                            baseFontSize: baseFontSize,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            accentColor: accentColor,
                            mascot: mascot,
                            trackedLabel: trackedLabel,
                          ),
                        ),
                      ),
                    ),

                    // Bottom 32% — Quiet negative space for notifications/actions
                    SizedBox(
                      key: const ValueKey('lock_screen_bottom_safe_zone'),
                      height: bottomHeight,
                      width: width,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomPhotoLayer({required double blurSigma}) {
    final filePath = customWallpaperFilePath?.trim();
    final assetPath = customWallpaperAsset?.trim();

    Widget buildFallbackGradient() => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF141824), Color(0xFF22283A)]
                  : const [Color(0xFFE7EEF6), Color(0xFFF6EFE6)],
            ),
          ),
        );

    Widget buildAssetImage() {
      if (assetPath != null && assetPath.isNotEmpty) {
        return Image.asset(
          assetPath,
          key: const ValueKey('lock_screen_custom_asset_image'),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => buildFallbackGradient(),
        );
      }
      return buildFallbackGradient();
    }

    Widget imageWidget;
    if (filePath != null && filePath.isNotEmpty && File(filePath).existsSync()) {
      imageWidget = Image.file(
        File(filePath),
        key: const ValueKey('lock_screen_custom_file_image'),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => buildAssetImage(),
      );
    } else {
      imageWidget = buildAssetImage();
    }

    if (blurSigma > 0) {
      return ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Transform.scale(scale: 1.06, child: imageWidget),
      );
    }
    return imageWidget;
  }

  Widget _buildBackground({
    required double width,
    required double height,
    required Color accentColor,
    required SeasonalLoadingSpec seasonalSpec,
  }) {
    if (_hasCustomWallpaper) {
      final isGlass = template == DailyWallpaperTemplate.treehouseGlassCard;
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: isDark ? AppColors.darkBg : AppColors.lightBg),
          _buildCustomPhotoLayer(blurSigma: isGlass ? 8.0 : 0.0),
          if (isGlass)
            ColoredBox(
              color: (isDark ? Colors.black : Colors.white)
                  .withValues(alpha: isDark ? 0.24 : 0.14),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.28, 0.50, 0.72, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.54),
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.38),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    switch (template) {
      case DailyWallpaperTemplate.sanctuaryMinimal:
        final baseBg = isDark ? AppColors.darkBg : AppColors.lightBg;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: baseBg),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.04),
                  radius: 0.78,
                  colors: [
                    accentColor.withValues(alpha: isDark ? 0.13 : 0.11),
                    accentColor.withValues(alpha: isDark ? 0.04 : 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ],
        );

      case DailyWallpaperTemplate.seasonalAtmosphere:
        final gradientColors =
            isDark ? seasonalSpec.darkGradient : seasonalSpec.lightGradient;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
              ),
            ),
            CustomPaint(
              painter: SeasonalWallpaperPainter(
                theme: seasonalSpec.theme,
                progress: 0.35,
                isDark: isDark,
                accentColor: seasonalSpec.accentColor,
                secondaryAccentColor: seasonalSpec.secondaryAccentColor,
              ),
            ),
            // Subtle translucent center scrim for crisp affirmation contrast
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.22, 0.48, 0.74],
                  colors: [
                    Colors.transparent,
                    (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: isDark ? 0.34 : 0.42),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );

      case DailyWallpaperTemplate.treehouseGlassCard:
        final assetPath = isDark ? treehouseNightAsset : treehouseDayAsset;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: isDark ? AppColors.darkBg : AppColors.lightBg),
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Transform.scale(
                scale: 1.08,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? const [Color(0xFF141824), Color(0xFF22283A)]
                            : const [Color(0xFFE7EEF6), Color(0xFFF6EFE6)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ColoredBox(
              color: (isDark ? Colors.black : Colors.white)
                  .withValues(alpha: isDark ? 0.24 : 0.14),
            ),
          ],
        );
    }
  }

  Widget _buildSanctuaryBandContent({
    required double width,
    required double maxHeight,
    required double scale,
    required double baseFontSize,
    required Color textColor,
    required Color secondaryTextColor,
    required Color accentColor,
    required InspirationMascotMeta mascot,
    required String trackedLabel,
  }) {
    final bool isGlass = template == DailyWallpaperTemplate.treehouseGlassCard;
    final double innerPaddingH = isGlass ? 20 * scale : 6 * scale;
    final double innerPaddingV = isGlass ? 18 * scale : 6 * scale;

    final innerColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showMascotSprite) ...[
          Image.asset(
            mascot.assetPath,
            width: 34 * scale,
            height: 34 * scale,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.eco_rounded,
              size: 24 * scale,
              color: accentColor,
            ),
          ),
          SizedBox(height: 12 * scale),
        ],
        Text(
          '“${quoteText.trim()}”',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: baseFontSize * scale,
            fontWeight: FontWeight.w600,
            height: 1.38,
            letterSpacing: -0.15 * scale,
            color: textColor,
          ),
        ),
        if (authorName.trim().isNotEmpty) ...[
          SizedBox(height: 10 * scale),
          Text(
            '— ${authorName.trim()}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5 * scale,
              fontWeight: FontWeight.w500,
              color: secondaryTextColor,
            ),
          ),
        ],
        SizedBox(height: 12 * scale),
        Container(
          width: 36 * scale,
          height: (1.0 * scale).clamp(0.75, 1.5),
          color: textColor.withValues(alpha: 0.24),
        ),
        SizedBox(height: 10 * scale),
        Text(
          trackedLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9.5 * scale,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8 * scale,
            color: textColor.withValues(alpha: 0.68),
          ),
        ),
      ],
    );

    final boundedContent = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: maxHeight,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: width - (isGlass ? innerPaddingH * 2 : 0),
          child: innerColumn,
        ),
      ),
    );

    if (!isGlass) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: innerPaddingH,
          vertical: innerPaddingV,
        ),
        child: boundedContent,
      );
    }

    return Container(
      width: width,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.symmetric(
        horizontal: innerPaddingH,
        vertical: innerPaddingV,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF14161D) : Colors.white)
            .withValues(alpha: isDark ? 0.68 : 0.78),
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: isDark ? 0.16 : 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
            blurRadius: 18 * scale,
            offset: Offset(0, 6 * scale),
          ),
        ],
      ),
      child: Center(
        heightFactor: 1.0,
        child: boundedContent,
      ),
    );
  }
}

/// Non-exported translucent Mock OS Clock & bottom quick-action overlay layered
/// on top of [LockScreenWallpaperCanvas] inside the interactive preview sheet.
class LockScreenMockOsOverlay extends StatelessWidget {
  final bool isDark;
  final DateTime? referenceDate;

  const LockScreenMockOsOverlay({
    super.key,
    required this.isDark,
    this.referenceDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = referenceDate ?? DateTime.now();
    final dateText = l10n.formatDate(date, 'EEEE, d MMMM');
    final foreground = isDark ? Colors.white : const Color(0xFF14161D);

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / 360.0).clamp(0.45, 1.4);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Top 30% mock OS clock & date
              Positioned(
                top: constraints.maxHeight * 0.085,
                left: 12 * scale,
                right: 12 * scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16 * scale,
                      color: foreground.withValues(alpha: 0.72),
                    ),
                    SizedBox(height: 6 * scale),
                    Text(
                      '07:30',
                      style: TextStyle(
                        fontSize: 54 * scale,
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                        letterSpacing: -1.2 * scale,
                        color: foreground.withValues(alpha: 0.88),
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Text(
                      dateText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w500,
                        color: foreground.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom corner flashlight & camera quick-action icons
              Positioned(
                bottom: constraints.maxHeight * 0.055,
                left: constraints.maxWidth * 0.09,
                child: _quickActionCircle(
                  Icons.flashlight_on_rounded,
                  foreground,
                  scale,
                ),
              ),
              Positioned(
                bottom: constraints.maxHeight * 0.055,
                right: constraints.maxWidth * 0.09,
                child: _quickActionCircle(
                  Icons.camera_alt_rounded,
                  foreground,
                  scale,
                ),
              ),

              // Subtle bottom home indicator pill
              Positioned(
                bottom: constraints.maxHeight * 0.02,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 96 * scale,
                    height: 3.5 * scale,
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickActionCircle(IconData icon, Color foreground, double scale) {
    return Container(
      width: 36 * scale,
      height: 36 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: foreground.withValues(alpha: 0.14),
        border: Border.all(
          color: foreground.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Icon(
        icon,
        size: 17 * scale,
        color: foreground.withValues(alpha: 0.82),
      ),
    );
  }
}
