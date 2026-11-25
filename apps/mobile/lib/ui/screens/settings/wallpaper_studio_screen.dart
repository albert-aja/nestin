import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/daily_wallpaper_config.dart';
import '../../../data/services/backend_gateway_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../providers/inspiration_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/inspiration/daily_wallpaper_sheet.dart';
import '../../widgets/inspiration/lock_screen_wallpaper_canvas.dart';
import '../nest/bird_house_shared.dart';
import '../splash/seasonal_loading_theme.dart';
import '../splash/seasonal_wallpaper_painter.dart';

enum _WallpaperStudioFilter {
  all,
  everyday,
  seasonal,
  downloaded,
}

/// Dedicated page for managing Nestin's Loading Screen Wallpapers, Everyday
/// (non-seasonal) & Seasonal downloadable packs, Personal Photo wallpaper,
/// live previews, and Daily Lock-Screen Affirmation wallpaper selection.
class WallpaperStudioScreen extends StatefulWidget {
  const WallpaperStudioScreen({super.key});

  @override
  State<WallpaperStudioScreen> createState() => _WallpaperStudioScreenState();
}

class _WallpaperStudioScreenState extends State<WallpaperStudioScreen> {
  _WallpaperStudioFilter _filter = _WallpaperStudioFilter.all;
  bool _isSyncing = false;

  BoxDecoration _surfaceCard(BuildContext context, {bool highlighted = false, Color? accent}) {
    final isDark = AppColors.isDark(context);
    final ringColor = accent ?? AppColors.primary;
    if (isDark) {
      return BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: highlighted
            ? Border.all(color: ringColor.withValues(alpha: 0.75), width: 1.5)
            : null,
      );
    }
    return BoxDecoration(
      color: AppColors.lightCard,
      borderRadius: BorderRadius.circular(18),
      border: highlighted
          ? Border.all(color: ringColor.withValues(alpha: 0.75), width: 1.5)
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _dotPill(
    BuildContext context, {
    required Color dotColor,
    required String label,
  }) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: isDark ? 0.18 : 0.11),
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
              color: dotColor,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncCatalog(SettingsProvider provider) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      BackendGatewayService? gateway;
      final storage = tryReadProvider<StorageService>(context);
      if (storage != null) {
        gateway = BackendGatewayService(storage.prefs);
      }
      await provider.refreshRemoteSplashCatalog(gateway: gateway);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.tr('splash_remote_packs_synced_toast')),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _applyLockScreenWallpaper(String? customWallpaperId) async {
    final inspiration = tryReadProvider<InspirationProvider>(context);
    if (inspiration == null) return;
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final updated = customWallpaperId == null
        ? inspiration.dailyWallpaperConfig.copyWith(clearCustomWallpaperId: true)
        : inspiration.dailyWallpaperConfig.copyWith(
            customWallpaperId: customWallpaperId,
          );
    await inspiration.updateDailyWallpaperConfig(
      updated,
      isDark: isDark,
      l10n: l10n,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.tr('wp_studio_lockscreen_applied_toast')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openPreview({
    required SeasonalLoadingSpec spec,
    required String title,
    String? customWallpaperId,
    RemoteHolidayWallpaperPack? downloadablePack,
    VoidCallback? onApplyLoading,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => WallpaperLivePreviewScreen(
          spec: spec,
          title: title,
          customWallpaperId: customWallpaperId,
          downloadablePack: downloadablePack,
          onApplyLoading: onApplyLoading,
        ),
      ),
    );
  }

  String _activeSummaryLabel(SettingsProvider provider, AppLocalizations l10n) {
    if (provider.hasCustomSplashPhoto) {
      return l10n.tr('splash_custom_photo_card_title');
    }
    final activePack = RemoteHolidayWallpaperCatalog.bySlug(
      provider.activeRemoteSplashPackSlug,
    );
    if (activePack != null) {
      return l10n.tr(activePack.titleKey);
    }
    final override = provider.seasonalSplashOverride;
    if (override != null) {
      return l10n.tr(override.labelKey);
    }
    return l10n.tr('splash_season_opt_auto');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<SettingsProvider>();
    final inspiration = tryWatchProvider<InspirationProvider>(context);

    final activeSpec = SeasonalSplashResolver.resolve(
      override: provider.seasonalSplashOverride,
      customPhotoPath: provider.customSplashPhotoPath,
      remotePackSlug: provider.activeRemoteSplashPackSlug,
      installedRemotePackPaths: provider.installedRemoteSplashPackPaths,
    );
    final activeTitle = _activeSummaryLabel(provider, l10n);
    final hasCustom = provider.hasCustomSplashPhoto;
    final customPath = provider.customSplashPhotoPath;

    final allPacks = provider.remoteSplashPacks;
    final filteredPacks = allPacks.where((pack) {
      return switch (_filter) {
        _WallpaperStudioFilter.all => true,
        _WallpaperStudioFilter.everyday => pack.isEveryday,
        _WallpaperStudioFilter.seasonal => pack.isSeasonal,
        _WallpaperStudioFilter.downloaded =>
          provider.isRemoteSplashPackInstalled(pack.slug),
      };
    }).toList(growable: false);

    final everydayThemes = SeasonalSplashTheme.values
        .where((t) => t.isEveryday)
        .toList(growable: false);
    final seasonalThemes = SeasonalSplashTheme.values
        .where((t) => !t.isEveryday)
        .toList(growable: false);

    final showEverydayBuiltIn = _filter == _WallpaperStudioFilter.all ||
        _filter == _WallpaperStudioFilter.everyday;
    final showSeasonalBuiltIn = _filter == _WallpaperStudioFilter.all ||
        _filter == _WallpaperStudioFilter.seasonal;

    return Scaffold(
      key: const Key('wallpaper_studio_screen'),
      appBar: AppBar(
        title: Text(l10n.tr('wp_studio_title')),
        actions: [
          IconButton(
            key: const Key('settings_splash_refresh_catalog_btn'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: l10n.tr('splash_remote_packs_refresh_btn'),
            onPressed: _isSyncing ? null : () => _syncCatalog(provider),
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined, size: 22),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 1. Active Loading Wallpaper Hero Card
          Container(
            key: const Key('wp_studio_active_card'),
            padding: const EdgeInsets.all(14),
            decoration: _surfaceCard(
              context,
              highlighted: true,
              accent: activeSpec.accentColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildSpecThumbnail(
                      activeSpec,
                      width: 56,
                      height: 88,
                      radius: 12,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dotPill(
                            context,
                            dotColor: activeSpec.accentColor,
                            label: l10n.tr('wp_studio_active_label'),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activeTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.tr(activeSpec.subtitleKey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('wp_studio_active_preview_btn'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          final activeWpId = hasCustom
                              ? DailyWallpaperConfig.personalPhotoWallpaperId
                              : (provider.activeRemoteSplashPackSlug != null
                                  ? 'pack:${provider.activeRemoteSplashPackSlug}'
                                  : 'theme:${activeSpec.theme.name}');
                          _openPreview(
                            spec: activeSpec,
                            title: activeTitle,
                            customWallpaperId: activeWpId,
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: Text(l10n.tr('wp_studio_preview_btn')),
                      ),
                    ),
                    if (inspiration != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('wp_studio_open_daily_wp_btn'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => DailyWallpaperSheet.show(context),
                          icon: const Icon(Icons.lock_clock_outlined, size: 18),
                          label: Text(
                            l10n.tr('wp_studio_preview_lockscreen_tab'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (hasCustom) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.tr('wp_studio_personal_photo_override_note'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Personal Photo Wallpaper Card
          Container(
            key: const Key('settings_splash_personal_photo_card'),
            padding: const EdgeInsets.all(14),
            decoration: _surfaceCard(
              context,
              highlighted: hasCustom,
              accent: AppColors.accent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hasCustom &&
                        customPath != null &&
                        File(customPath).existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(customPath),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _photoPlaceholderIcon(),
                        ),
                      )
                    else
                      _photoPlaceholderIcon(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tr('splash_custom_photo_card_title'),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasCustom
                                ? l10n.tr('splash_custom_photo_active_desc')
                                : l10n.tr('splash_custom_photo_card_desc'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('settings_splash_pick_photo_btn'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        await provider.pickAndSetCustomSplashPhoto();
                      },
                      icon: const Icon(Icons.photo_library_outlined, size: 17),
                      label: Text(l10n.tr('splash_custom_photo_pick_btn')),
                    ),
                    if (hasCustom)
                      OutlinedButton.icon(
                        key: const Key('wp_studio_preview_personal_photo_btn'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          final spec = SeasonalSplashResolver.resolve(
                            customPhotoPath: customPath,
                          );
                          _openPreview(
                            spec: spec,
                            title: l10n.tr('splash_custom_photo_card_title'),
                            customWallpaperId:
                                DailyWallpaperConfig.personalPhotoWallpaperId,
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: Text(l10n.tr('wp_studio_preview_btn')),
                      ),
                    if (hasCustom)
                      TextButton.icon(
                        key: const Key('settings_splash_clear_photo_btn'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () async {
                          await provider.clearCustomSplashPhoto();
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 17),
                        label: Text(l10n.tr('splash_custom_photo_clear_btn')),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Category Filter Pills (All | Everyday | Seasonal | Downloaded)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _WallpaperStudioFilter.values.map((f) {
                final selected = _filter == f;
                final label = switch (f) {
                  _WallpaperStudioFilter.all => l10n.tr('wp_studio_filter_all'),
                  _WallpaperStudioFilter.everyday =>
                    l10n.tr('wp_studio_filter_everyday'),
                  _WallpaperStudioFilter.seasonal =>
                    l10n.tr('wp_studio_filter_seasonal'),
                  _WallpaperStudioFilter.downloaded =>
                    '${l10n.tr('wp_studio_filter_downloaded')} (${provider.installedRemoteSplashPackSlugs.length})',
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('wp_studio_filter_${f.name}'),
                    label: Text(label),
                    selected: selected,
                    showCheckmark: false,
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                    backgroundColor: AppColors.elevatedSurface(context),
                    selectedColor: AppColors.primary.withValues(
                      alpha: AppColors.isDark(context) ? 0.24 : 0.14,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _filter = f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // 4. Downloadable Wallpaper Packs (Everyday Non-Seasonal + Seasonal)
          _sectionHeader(
            context,
            title: l10n.tr('wp_studio_downloadable_section'),
            subtitle: l10n.tr('wp_studio_downloadable_desc'),
          ),
          const SizedBox(height: 10),
          if (filteredPacks.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _surfaceCard(context),
              child: Text(
                l10n.tr('wp_studio_empty_downloaded'),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(context),
                ),
              ),
            )
          else
            ...filteredPacks.map(
              (pack) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildDownloadablePackCard(
                  context,
                  provider: provider,
                  inspiration: inspiration,
                  l10n: l10n,
                  pack: pack,
                ),
              ),
            ),

          // 5. Built-In Everyday (Non-Seasonal) Wallpapers
          if (showEverydayBuiltIn) ...[
            const SizedBox(height: 14),
            _sectionHeader(
              context,
              title: l10n.tr('wp_studio_everyday_section'),
            ),
            const SizedBox(height: 10),
            _buildAutoSmartCard(context, provider, l10n),
            const SizedBox(height: 10),
            _buildThemeGrid(
              context,
              provider: provider,
              l10n: l10n,
              themes: everydayThemes,
            ),
          ],

          // 6. Built-In Seasonal & Holiday Themes
          if (showSeasonalBuiltIn) ...[
            const SizedBox(height: 18),
            _sectionHeader(
              context,
              title: l10n.tr('wp_studio_seasonal_section'),
            ),
            const SizedBox(height: 10),
            _buildThemeGrid(
              context,
              provider: provider,
              l10n: l10n,
              themes: seasonalThemes,
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoPlaceholderIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.add_photo_alternate_rounded,
        color: AppColors.accent,
        size: 22,
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAutoSmartCard(
    BuildContext context,
    SettingsProvider provider,
    AppLocalizations l10n,
  ) {
    final isAutoActive = !provider.hasCustomSplashPhoto &&
        provider.activeRemoteSplashPackSlug == null &&
        provider.seasonalSplashOverride == null;
    final autoSpec = SeasonalSplashResolver.resolve();

    return InkWell(
      key: const Key('wp_studio_theme_card_auto'),
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        HapticFeedback.selectionClick();
        await provider.setSeasonalSplashOverride(null);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _surfaceCard(
          context,
          highlighted: isAutoActive,
          accent: AppColors.primary,
        ),
        child: Row(
          children: [
            _buildSpecThumbnail(autoSpec, width: 46, height: 64, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('splash_season_opt_auto'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.tr('splash_season_setting_auto_desc'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              key: const Key('wp_studio_theme_preview_auto'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: l10n.tr('wp_studio_preview_btn'),
              icon: const Icon(Icons.visibility_outlined, size: 20),
              onPressed: () => _openPreview(
                spec: autoSpec,
                title: l10n.tr('splash_season_opt_auto'),
                customWallpaperId: 'theme:${autoSpec.theme.name}',
                onApplyLoading: () async {
                  await provider.setSeasonalSplashOverride(null);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadablePackCard(
    BuildContext context, {
    required SettingsProvider provider,
    required InspirationProvider? inspiration,
    required AppLocalizations l10n,
    required RemoteHolidayWallpaperPack pack,
  }) {
    final isInstalled = provider.isRemoteSplashPackInstalled(pack.slug);
    final isDownloading = provider.isRemoteSplashPackDownloading(pack.slug);
    final progress = provider.remoteSplashPackDownloadProgress(pack.slug);
    final isActive = !provider.hasCustomSplashPhoto &&
        provider.activeRemoteSplashPackSlug == pack.slug;
    final cachedPath = provider.installedRemoteSplashPackPaths[pack.slug];
    final previewSpec = pack.toLoadingSpec(localCachedFilePath: cachedPath);
    final isLockSelected =
        inspiration?.dailyWallpaperConfig.customWallpaperId ==
            'pack:${pack.slug}';

    return Container(
      key: Key('settings_splash_pack_card_${pack.slug}'),
      padding: const EdgeInsets.all(12),
      decoration: _surfaceCard(
        context,
        highlighted: isActive,
        accent: pack.accentColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _openPreview(
                  spec: previewSpec,
                  title: l10n.tr(pack.titleKey),
                  customWallpaperId: 'pack:${pack.slug}',
                  downloadablePack: pack,
                  onApplyLoading: () async {
                    if (!provider.isRemoteSplashPackInstalled(pack.slug)) {
                      await provider.installRemoteSplashPack(
                        pack.slug,
                        activateOnInstall: true,
                      );
                    } else {
                      await provider.setActiveRemoteSplashPackSlug(pack.slug);
                    }
                  },
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    pack.bundledPreviewAsset,
                    width: 52,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 52,
                      height: 72,
                      color: pack.accentColor.withValues(alpha: 0.2),
                      child: Icon(Icons.wallpaper_rounded, color: pack.accentColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _dotPill(
                          context,
                          dotColor: pack.isEveryday
                              ? const Color(0xFF10B981)
                              : pack.accentColor,
                          label: pack.isEveryday
                              ? l10n.tr('wp_studio_badge_everyday')
                              : l10n.tr('wp_studio_badge_seasonal'),
                        ),
                        _dotPill(
                          context,
                          dotColor: AppColors.textSecondary(context),
                          label: pack.formattedSizeKb,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.tr(pack.titleKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.tr(pack.subtitleKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 5,
                color: pack.accentColor,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Preview button (available BEFORE and AFTER download)
              OutlinedButton.icon(
                key: Key('wp_studio_pack_preview_${pack.slug}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => _openPreview(
                  spec: previewSpec,
                  title: l10n.tr(pack.titleKey),
                  customWallpaperId: 'pack:${pack.slug}',
                  downloadablePack: pack,
                  onApplyLoading: () async {
                    if (!provider.isRemoteSplashPackInstalled(pack.slug)) {
                      await provider.installRemoteSplashPack(
                        pack.slug,
                        activateOnInstall: true,
                      );
                    } else {
                      await provider.setActiveRemoteSplashPackSlug(pack.slug);
                    }
                  },
                ),
                icon: const Icon(Icons.visibility_outlined, size: 17),
                label: Text(l10n.tr('wp_studio_preview_btn')),
              ),
              if (!isInstalled)
                FilledButton.icon(
                  key: Key('settings_splash_pack_download_${pack.slug}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: pack.accentColor,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: isDownloading
                      ? null
                      : () async {
                          await provider.installRemoteSplashPack(
                            pack.slug,
                            activateOnInstall: true,
                          );
                        },
                  icon: const Icon(Icons.download_rounded, size: 17),
                  label: Text(l10n.tr('splash_remote_pack_download_btn')),
                )
              else ...[
                FilledButton.icon(
                  key: Key('settings_splash_pack_use_${pack.slug}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: isActive
                        ? pack.accentColor.withValues(alpha: 0.18)
                        : pack.accentColor,
                    foregroundColor: isActive
                        ? AppColors.textPrimary(context)
                        : Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: isActive
                      ? null
                      : () async {
                          await provider
                              .setActiveRemoteSplashPackSlug(pack.slug);
                        },
                  icon: Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.wallpaper_rounded,
                    size: 17,
                  ),
                  label: Text(
                    isActive
                        ? l10n.tr('splash_remote_pack_active_badge')
                        : l10n.tr('splash_remote_pack_use_btn'),
                  ),
                ),
                if (inspiration != null)
                  IconButton(
                    key: Key('wp_studio_pack_lockscreen_${pack.slug}'),
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: l10n.tr('wp_studio_set_lockscreen_btn'),
                    icon: Icon(
                      isLockSelected
                          ? Icons.lock_rounded
                          : Icons.lock_outline_rounded,
                      color: isLockSelected ? AppColors.primary : null,
                      size: 20,
                    ),
                    onPressed: () =>
                        _applyLockScreenWallpaper('pack:${pack.slug}'),
                  ),
                IconButton(
                  key: Key('settings_splash_pack_remove_${pack.slug}'),
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: l10n.tr('splash_remote_pack_remove_btn'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () async {
                    await provider.removeRemoteSplashPack(pack.slug);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeGrid(
    BuildContext context, {
    required SettingsProvider provider,
    required AppLocalizations l10n,
    required List<SeasonalSplashTheme> themes,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: themes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.84,
      ),
      itemBuilder: (context, index) {
        final theme = themes[index];
        final spec = SeasonalSplashResolver.specFor(theme);
        final isActive = !provider.hasCustomSplashPhoto &&
            provider.activeRemoteSplashPackSlug == null &&
            provider.seasonalSplashOverride == theme;

        return InkWell(
          key: Key('wp_studio_theme_card_${theme.name}'),
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            HapticFeedback.selectionClick();
            await provider.setSeasonalSplashOverride(theme);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.tr('wp_studio_loading_applied_toast')),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: _surfaceCard(
              context,
              highlighted: isActive,
              accent: spec.accentColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildSpecThumbnail(
                        spec,
                        width: double.infinity,
                        height: double.infinity,
                        radius: 12,
                      ),
                      if (isActive)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: spec.accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tr(theme.labelKey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('wp_studio_theme_preview_${theme.name}'),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      tooltip: l10n.tr('wp_studio_preview_btn'),
                      icon: const Icon(Icons.visibility_outlined, size: 19),
                      onPressed: () => _openPreview(
                        spec: spec,
                        title: l10n.tr(theme.labelKey),
                        customWallpaperId: 'theme:${theme.name}',
                        onApplyLoading: () async {
                          await provider.setSeasonalSplashOverride(theme);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpecThumbnail(
    SeasonalLoadingSpec spec, {
    required double width,
    required double height,
    required double radius,
  }) {
    final filePath = spec.customWallpaperFilePath;
    Widget img;
    if (filePath != null && filePath.isNotEmpty && File(filePath).existsSync()) {
      img = Image.file(
        File(filePath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackThumb(spec, width, height),
      );
    } else if (spec.wallpaperAsset != null) {
      img = Image.asset(
        spec.wallpaperAsset!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackThumb(spec, width, height),
      );
    } else {
      img = _fallbackThumb(spec, width, height);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: img,
    );
  }

  Widget _fallbackThumb(SeasonalLoadingSpec spec, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: spec.darkGradient,
        ),
      ),
    );
  }
}

/// Full-screen interactive live preview allowing users to inspect any wallpaper
/// (built-in Everyday/Seasonal, downloadable pack before/after download, or
/// Personal Photo) in both **Loading Screen** and **Lock Screen Affirmation**
/// modes before downloading or applying.
class WallpaperLivePreviewScreen extends StatefulWidget {
  final SeasonalLoadingSpec spec;
  final String title;
  final String? customWallpaperId;
  final RemoteHolidayWallpaperPack? downloadablePack;
  final VoidCallback? onApplyLoading;

  const WallpaperLivePreviewScreen({
    super.key,
    required this.spec,
    required this.title,
    this.customWallpaperId,
    this.downloadablePack,
    this.onApplyLoading,
  });

  @override
  State<WallpaperLivePreviewScreen> createState() =>
      _WallpaperLivePreviewScreenState();
}

class _WallpaperLivePreviewScreenState extends State<WallpaperLivePreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _particleController;
  bool _lockScreenMode = false;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final settings = tryWatchProvider<SettingsProvider>(context);
    final inspiration = tryWatchProvider<InspirationProvider>(context);

    final pack = widget.downloadablePack;
    final isPackInstalled = pack == null
        ? true
        : (settings?.isRemoteSplashPackInstalled(pack.slug) ?? false);
    final isPackDownloading = pack != null &&
        (settings?.isRemoteSplashPackDownloading(pack.slug) ?? false);
    final packProgress = pack != null
        ? (settings?.remoteSplashPackDownloadProgress(pack.slug) ?? 0.0)
        : 0.0;

    final previewQuote = inspiration?.selectQuoteForDailyWallpaper(
      date: DateTime.now(),
      dayOffset: 0,
      source: inspiration.dailyWallpaperConfig.quoteSource,
      locale: l10n.isIndonesian ? 'id' : 'en',
    );

    return Scaffold(
      key: const Key('wallpaper_live_preview_screen'),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_lockScreenMode)
            Center(
              child: LockScreenWallpaperCanvas(
                quoteText: previewQuote?.quoteText ??
                    l10n.tr(widget.spec.subtitleKey),
                authorName: previewQuote?.author ?? 'Nestin',
                mascotDomain: previewQuote?.mascotDomain ?? 'pippin',
                template: inspiration?.dailyWallpaperConfig.template ??
                    DailyWallpaperTemplate.sanctuaryMinimal,
                isDark: isDark,
                showMascotSprite:
                    inspiration?.dailyWallpaperConfig.showMascotSprite ?? true,
                customWallpaperAsset: widget.spec.wallpaperAsset,
                customWallpaperFilePath: widget.spec.customWallpaperFilePath,
              ),
            )
          else
            _buildLoadingPreviewCanvas(context, l10n, isDark),

          if (_lockScreenMode)
            Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: LockScreenMockOsOverlay(isDark: isDark),
              ),
            ),

          // Top bar: Close + Loading/Lock-Screen mode toggle
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.black.withValues(alpha: 0.52),
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: const Key('wp_preview_close_btn'),
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        color: Colors.white,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _modeToggleChip(
                                key: const Key('wp_preview_tab_loading'),
                                label: l10n.tr('wp_studio_preview_loading_tab'),
                                selected: !_lockScreenMode,
                                onTap: () =>
                                    setState(() => _lockScreenMode = false),
                              ),
                              _modeToggleChip(
                                key: const Key('wp_preview_tab_lockscreen'),
                                label:
                                    l10n.tr('wp_studio_preview_lockscreen_tab'),
                                selected: _lockScreenMode,
                                onTap: () =>
                                    setState(() => _lockScreenMode = true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (isPackDownloading) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: packProgress > 0 ? packProgress : null,
                          minHeight: 5,
                          color: widget.spec.accentColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (pack != null && !isPackInstalled)
                          Expanded(
                            child: FilledButton.icon(
                              key: const Key('wp_preview_download_use_btn'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                backgroundColor: widget.spec.accentColor,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: isPackDownloading
                                  ? null
                                  : () async {
                                      if (settings == null) return;
                                      final ok = await settings
                                          .installRemoteSplashPack(
                                        pack.slug,
                                        activateOnInstall: true,
                                      );
                                      if (ok && context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10n.tr(
                                                'wp_studio_loading_applied_toast',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: Text(
                                l10n.tr('wp_studio_download_and_use_btn'),
                              ),
                            ),
                          )
                        else if (widget.onApplyLoading != null)
                          Expanded(
                            child: FilledButton.icon(
                              key: const Key('wp_preview_set_loading_btn'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                backgroundColor: widget.spec.accentColor,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                widget.onApplyLoading?.call();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.tr(
                                        'wp_studio_loading_applied_toast',
                                      ),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.wallpaper_rounded, size: 18),
                              label: Text(
                                l10n.tr('wp_studio_set_loading_btn'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        if (inspiration != null &&
                            widget.customWallpaperId != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('wp_preview_set_lockscreen_btn'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () async {
                                if (pack != null &&
                                    !isPackInstalled &&
                                    settings != null) {
                                  await settings.installRemoteSplashPack(
                                    pack.slug,
                                  );
                                }
                                final updated = inspiration.dailyWallpaperConfig
                                    .copyWith(
                                  customWallpaperId: widget.customWallpaperId,
                                );
                                await inspiration.updateDailyWallpaperConfig(
                                  updated,
                                  isDark: isDark,
                                  l10n: l10n,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.tr(
                                        'wp_studio_lockscreen_applied_toast',
                                      ),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                l10n.tr('wp_studio_set_lockscreen_btn'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeToggleChip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPreviewCanvas(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final spec = widget.spec;
    final filePath = spec.customWallpaperFilePath;
    Widget bgImage;
    if (filePath != null && filePath.isNotEmpty && File(filePath).existsSync()) {
      bgImage = Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _assetOrGradientBg(spec, isDark),
      );
    } else {
      bgImage = _assetOrGradientBg(spec, isDark);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        bgImage,
        AnimatedBuilder(
          animation: _particleController,
          builder: (_, _) => CustomPaint(
            painter: SeasonalWallpaperPainter(
              theme: spec.theme,
              progress: _particleController.value,
              isDark: isDark,
              accentColor: spec.accentColor,
              secondaryAccentColor: spec.secondaryAccentColor,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: spec.accentColor.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.tr(spec.badgeKey),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.tr(spec.titleKey),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.tr(spec.subtitleKey),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _assetOrGradientBg(SeasonalLoadingSpec spec, bool isDark) {
    if (spec.wallpaperAsset != null) {
      return Image.asset(
        spec.wallpaperAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark ? spec.darkGradient : spec.lightGradient,
            ),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? spec.darkGradient : spec.lightGradient,
        ),
      ),
    );
  }
}
