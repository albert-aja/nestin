import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/daily_wallpaper_config.dart';
import '../../../providers/inspiration_provider.dart';
import 'lock_screen_wallpaper_canvas.dart';

/// Opt-in 24dp bottom sheet for Nestin's Daily Affirmation Lock-Screen Wallpaper.
///
/// Supports:
/// - Android: Auto-update toggle, 3 templates, live Mock OS Clock preview,
///   Lock Screen Only vs Lock & Home target, quote source filter, refresh time
///   picker (default 05:00), and 1-tap "Apply Today's Wallpaper Now".
/// - iOS: Honest Daily Lock Screen Studio hiding unsupported Android auto-apply
///   flags while keeping full 3-template safe-zone preview + "Save to Photos".
class DailyWallpaperSheet extends StatefulWidget {
  final String? initialQuoteText;
  final String? initialAuthorName;
  final String? initialMascotDomain;

  const DailyWallpaperSheet({
    super.key,
    this.initialQuoteText,
    this.initialAuthorName,
    this.initialMascotDomain,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialQuoteText,
    String? initialAuthorName,
    String? initialMascotDomain,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DailyWallpaperSheet(
        initialQuoteText: initialQuoteText,
        initialAuthorName: initialAuthorName,
        initialMascotDomain: initialMascotDomain,
      ),
    );
  }

  @override
  State<DailyWallpaperSheet> createState() => _DailyWallpaperSheetState();
}

class _DailyWallpaperSheetState extends State<DailyWallpaperSheet> {
  final GlobalKey _previewBoundaryKey = GlobalKey();
  bool _showMockOsClock = true;
  bool _isApplying = false;

  Future<void> _updateConfig(
    InspirationProvider provider,
    DailyWallpaperConfig updated,
  ) async {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    await provider.updateDailyWallpaperConfig(
      updated,
      isDark: isDark,
      l10n: l10n,
    );
  }

  Future<void> _pickRefreshTime(
    InspirationProvider provider,
    DailyWallpaperConfig config,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: config.refreshHour,
        minute: config.refreshMinute,
      ),
    );
    if (picked == null || !mounted) return;
    await _updateConfig(
      provider,
      config.copyWith(
        refreshHour: picked.hour,
        refreshMinute: picked.minute,
      ),
    );
  }

  Future<void> _handlePrimaryAction(InspirationProvider provider) async {
    if (_isApplying) return;
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final isAndroid = provider.isDailyWallpaperAndroid;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isApplying = true);
    try {
      if (isAndroid) {
        final applied = await provider.applyTodayWallpaperNow(
          boundaryKey: _previewBoundaryKey,
          isDark: isDark,
          l10n: l10n,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              applied
                  ? l10n.tr('daily_wp_applied_success')
                  : l10n.tr('daily_wp_apply_failed'),
            ),
          ),
        );
      } else {
        final outcome = await provider.saveTodayWallpaperForIos(
          boundaryKey: _previewBoundaryKey,
          quoteText: widget.initialQuoteText,
          authorName: widget.initialAuthorName,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              outcome.sharedViaNativeSheet
                  ? l10n.tr('daily_wp_ios_ready_to_save')
                  : l10n.tr('daily_wp_ios_saved_locally'),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.tr('daily_wp_apply_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final provider = context.watch<InspirationProvider>();
    final config = provider.dailyWallpaperConfig;
    final isAndroid = provider.isDailyWallpaperAndroid;

    final previewQuote = provider.selectQuoteForDailyWallpaper(
      date: DateTime.now(),
      dayOffset: 0,
      source: config.quoteSource,
      locale: l10n.isIndonesian ? 'id' : 'en',
    );
    final displayQuoteText =
        widget.initialQuoteText ?? previewQuote.quoteText;
    final displayAuthor = widget.initialAuthorName ?? previewQuote.author;
    final displayMascot =
        widget.initialMascotDomain ?? previewQuote.mascotDomain ?? 'pippin';

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.90,
        minChildSize: 0.65,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.scrimHandle(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.wallpaper_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAndroid
                                ? l10n.tr('daily_wp_title_android')
                                : l10n.tr('daily_wp_title_ios'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAndroid
                                ? l10n.tr('daily_wp_subtitle_android')
                                : l10n.tr('daily_wp_subtitle_ios'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.tr('close'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Scrollable Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    // Interactive 9:16 Live Preview + Mock OS Clock Toggle
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.recessedSurface(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 310,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 9 / 16,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      RepaintBoundary(
                                        key: _previewBoundaryKey,
                                        child: LockScreenWallpaperCanvas(
                                          quoteText: displayQuoteText,
                                          authorName: displayAuthor,
                                          mascotDomain: displayMascot,
                                          template: config.template,
                                          isDark: isDark,
                                          showMascotSprite:
                                              config.showMascotSprite,
                                        ),
                                      ),
                                      AnimatedOpacity(
                                        opacity: _showMockOsClock ? 1.0 : 0.0,
                                        duration: reduceMotion
                                            ? Duration.zero
                                            : const Duration(milliseconds: 180),
                                        child: LockScreenMockOsOverlay(
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              FilterChip(
                                avatar: Icon(
                                  _showMockOsClock
                                      ? Icons.access_time_filled_rounded
                                      : Icons.access_time_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  l10n.tr('daily_wp_mock_clock_toggle'),
                                ),
                                selected: _showMockOsClock,
                                onSelected: (v) =>
                                    setState(() => _showMockOsClock = v),
                              ),
                              FilterChip(
                                avatar: const Icon(
                                  Icons.pets_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  l10n.tr('daily_wp_show_bird_toggle'),
                                ),
                                selected: config.showMascotSprite,
                                onSelected: (v) => _updateConfig(
                                  provider,
                                  config.copyWith(showMascotSprite: v),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Master Opt-In Toggle (Android) or iOS Honest Note
                    if (isAndroid) ...[
                      Material(
                        color: AppColors.cardSurface(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.border(context)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          title: Text(
                            l10n.tr('daily_wp_auto_update_toggle'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          subtitle: Text(
                            l10n.tr('daily_wp_auto_update_desc'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          value: config.enabled,
                          onChanged: (v) => _updateConfig(
                            provider,
                            config.copyWith(enabled: v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.tr('daily_wp_ios_honest_note'),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Template Style Picker (3 Templates)
                    _sectionLabel(context, l10n.tr('daily_wp_template_section')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DailyWallpaperTemplate.values.map((tpl) {
                        final selected = config.template == tpl;
                        return ChoiceChip(
                          label: Text(l10n.tr(tpl.titleKey)),
                          selected: selected,
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.18),
                          onSelected: (_) => _updateConfig(
                            provider,
                            config.copyWith(template: tpl),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.tr(config.template.subtitleKey),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quote Source Filter
                    _sectionLabel(context, l10n.tr('daily_wp_source_section')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DailyWallpaperSource.values.map((src) {
                        return ChoiceChip(
                          label: Text(l10n.tr(src.labelKey)),
                          selected: config.quoteSource == src,
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.18),
                          onSelected: (_) => _updateConfig(
                            provider,
                            config.copyWith(quoteSource: src),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Android-only Target Selector & Refresh Time Picker
                    if (isAndroid) ...[
                      _sectionLabel(
                        context,
                        l10n.tr('daily_wp_target_section'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DailyWallpaperTarget.values.map((target) {
                          return ChoiceChip(
                            label: Text(l10n.tr(target.labelKey)),
                            selected: config.target == target,
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.18),
                            onSelected: (_) => _updateConfig(
                              provider,
                              config.copyWith(target: target),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      Material(
                        color: AppColors.cardSurface(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppColors.border(context)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          minVerticalPadding: 12,
                          leading: const Icon(Icons.schedule_rounded),
                          title: Text(
                            l10n.tr('daily_wp_refresh_time_label'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          subtitle: Text(
                            l10n.tr('daily_wp_refresh_time_desc'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.subtleFill(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              config.formattedRefreshTime,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                          onTap: () => _pickRefreshTime(provider, config),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Primary 1-Tap CTA
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: (_isApplying ||
                                provider.isPreparingDailyWallpapers)
                            ? null
                            : () => _handlePrimaryAction(provider),
                        icon: (_isApplying ||
                                provider.isPreparingDailyWallpapers)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isAndroid
                                    ? Icons.wallpaper_rounded
                                    : Icons.download_rounded,
                                size: 20,
                              ),
                        label: Text(
                          isAndroid
                              ? l10n.tr('daily_wp_apply_now_cta')
                              : l10n.tr('daily_wp_save_to_photos_cta'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.textSecondary(context),
      ),
    );
  }
}
