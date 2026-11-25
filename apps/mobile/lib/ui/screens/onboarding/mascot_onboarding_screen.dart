import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/mascot_companion.dart';
import '../../../providers/settings_provider.dart';

enum _OnboardingSlideKind { welcome, mascotPage1, mascotPage2, ready }

class _OnboardingSlideSpec {
  final _OnboardingSlideKind kind;
  final MascotCompanionProfile? companion;
  final String badgeTitle;
  final IconData badgeIcon;
  final Color accentColor;
  final Color lightInkColor;
  final String? spriteAsset;
  final String? altSpriteAsset;
  final String headlineLeadKey;
  final String headlineHighlightKey;
  final String subtitleKey;
  final int chapterIndex; // 0 = welcome, 1..6 = birds, 7 = ready

  const _OnboardingSlideSpec({
    required this.kind,
    this.companion,
    required this.badgeTitle,
    required this.badgeIcon,
    required this.accentColor,
    required this.lightInkColor,
    this.spriteAsset,
    this.altSpriteAsset,
    required this.headlineLeadKey,
    required this.headlineHighlightKey,
    required this.subtitleKey,
    required this.chapterIndex,
  });
}

/// Clean, minimalist multi-page mascot onboarding tour.
///
/// Splits every companion into 2 airy, focused pages (14 slides total:
/// Welcome + 6 birds × 2 pages + All-Set Ready) featuring a minimal centered
/// icon-and-name header, a soft circular hero stage, an editorial 2-line
/// accent-highlighted headline, a slim chapter progress bar, and a centered
/// minimalist pill CTA.
class MascotOnboardingScreen extends StatefulWidget {
  final bool isReplay;
  final int initialPage;
  final VoidCallback? onCompleted;

  /// Total slide count: Welcome (0) + 6 birds × 2 pages (1..12) + Ready (13).
  static const int totalPages = 14;

  /// Index of the final "Ready" summary slide.
  static const int readyPageIndex = 13;

  const MascotOnboardingScreen({
    super.key,
    this.isReplay = false,
    this.initialPage = 0,
    this.onCompleted,
  });

  @override
  State<MascotOnboardingScreen> createState() => _MascotOnboardingScreenState();
}

class _MascotOnboardingScreenState extends State<MascotOnboardingScreen> {
  static final List<_OnboardingSlideSpec> _slides = _buildSlides();

  late final PageController _pageController;
  late int _currentPage;
  final Set<int> _tappedSlides = <int>{};
  bool _isFinishing = false;

  static List<_OnboardingSlideSpec> _buildSlides() {
    final roo = NestinFlock.byId(NestinMascotId.roo);
    final scout = NestinFlock.byId(NestinMascotId.scout);
    final seren = NestinFlock.byId(NestinMascotId.seren);
    final pippin = NestinFlock.byId(NestinMascotId.pippin);
    final twill = NestinFlock.byId(NestinMascotId.twill);
    final echo = NestinFlock.byId(NestinMascotId.echo);

    return [
      const _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.welcome,
        badgeTitle: 'Nestin',
        badgeIcon: Icons.wb_twilight_rounded,
        accentColor: AppColors.primary,
        lightInkColor: AppColors.primaryDark,
        headlineLeadKey: 'onb_welcome_lead',
        headlineHighlightKey: 'onb_welcome_hl',
        subtitleKey: 'onb_welcome_sub',
        chapterIndex: 0,
      ),
      // 1-2: Roo
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage1,
        companion: roo,
        badgeTitle: roo.name,
        badgeIcon: Icons.alarm_rounded,
        accentColor: roo.accentColor,
        lightInkColor: roo.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/roo/alarm.png',
        altSpriteAsset: 'assets/mascots/sprites/roo/welcome.png',
        headlineLeadKey: 'onb_roo_p1_lead',
        headlineHighlightKey: 'onb_roo_p1_hl',
        subtitleKey: 'onb_roo_p1_sub',
        chapterIndex: 1,
      ),
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage2,
        companion: roo,
        badgeTitle: roo.name,
        badgeIcon: Icons.alarm_rounded,
        accentColor: roo.accentColor,
        lightInkColor: roo.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/roo/focus_lock_padlock.png',
        altSpriteAsset: 'assets/mascots/sprites/roo/high_five.png',
        headlineLeadKey: 'onb_roo_p2_lead',
        headlineHighlightKey: 'onb_roo_p2_hl',
        subtitleKey: 'onb_roo_p2_sub',
        chapterIndex: 1,
      ),
      // 3-4: Scout
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage1,
        companion: scout,
        badgeTitle: scout.name,
        badgeIcon: Icons.explore_rounded,
        accentColor: scout.accentColor,
        lightInkColor: scout.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/scout/before_you_go.png',
        altSpriteAsset: 'assets/mascots/sprites/scout/briefing.png',
        headlineLeadKey: 'onb_scout_p1_lead',
        headlineHighlightKey: 'onb_scout_p1_hl',
        subtitleKey: 'onb_scout_p1_sub',
        chapterIndex: 2,
      ),
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage2,
        companion: scout,
        badgeTitle: scout.name,
        badgeIcon: Icons.explore_rounded,
        accentColor: scout.accentColor,
        lightInkColor: scout.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/scout/phone_mode_sliders.png',
        altSpriteAsset: 'assets/mascots/sprites/scout/briefing.png',
        headlineLeadKey: 'onb_scout_p2_lead',
        headlineHighlightKey: 'onb_scout_p2_hl',
        subtitleKey: 'onb_scout_p2_sub',
        chapterIndex: 2,
      ),
      // 5-6: Seren
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage1,
        companion: seren,
        badgeTitle: seren.name,
        badgeIcon: Icons.spa_rounded,
        accentColor: seren.accentColor,
        lightInkColor: seren.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/seren/gentle_breath_lotus.png',
        altSpriteAsset: 'assets/mascots/sprites/seren/hello.png',
        headlineLeadKey: 'onb_seren_p1_lead',
        headlineHighlightKey: 'onb_seren_p1_hl',
        subtitleKey: 'onb_seren_p1_sub',
        chapterIndex: 3,
      ),
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage2,
        companion: seren,
        badgeTitle: seren.name,
        badgeIcon: Icons.spa_rounded,
        accentColor: seren.accentColor,
        lightInkColor: seren.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/seren/hydrate.png',
        altSpriteAsset: 'assets/mascots/sprites/seren/hello.png',
        headlineLeadKey: 'onb_seren_p2_lead',
        headlineHighlightKey: 'onb_seren_p2_hl',
        subtitleKey: 'onb_seren_p2_sub',
        chapterIndex: 3,
      ),
      // 7-8: Pippin
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage1,
        companion: pippin,
        badgeTitle: pippin.name,
        badgeIcon: Icons.menu_book_rounded,
        accentColor: pippin.accentColor,
        lightInkColor: pippin.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/pippin/reading.png',
        altSpriteAsset: 'assets/mascots/sprites/pippin/inspired.png',
        headlineLeadKey: 'onb_pippin_p1_lead',
        headlineHighlightKey: 'onb_pippin_p1_hl',
        subtitleKey: 'onb_pippin_p1_sub',
        chapterIndex: 4,
      ),
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage2,
        companion: pippin,
        badgeTitle: pippin.name,
        badgeIcon: Icons.menu_book_rounded,
        accentColor: pippin.accentColor,
        lightInkColor: pippin.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/pippin/discover.png',
        altSpriteAsset: 'assets/mascots/sprites/pippin/inspired.png',
        headlineLeadKey: 'onb_pippin_p2_lead',
        headlineHighlightKey: 'onb_pippin_p2_hl',
        subtitleKey: 'onb_pippin_p2_sub',
        chapterIndex: 4,
      ),
      // 9-10: Twill
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage1,
        companion: twill,
        badgeTitle: twill.name,
        badgeIcon: Icons.edit_note_rounded,
        accentColor: twill.accentColor,
        lightInkColor: twill.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/twill/organized.png',
        altSpriteAsset: 'assets/mascots/sprites/twill/checklist.png',
        headlineLeadKey: 'onb_twill_p1_lead',
        headlineHighlightKey: 'onb_twill_p1_hl',
        subtitleKey: 'onb_twill_p1_sub',
        chapterIndex: 5,
      ),
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage2,
        companion: twill,
        badgeTitle: twill.name,
        badgeIcon: Icons.edit_note_rounded,
        accentColor: twill.accentColor,
        lightInkColor: twill.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/twill/budgeted.png',
        altSpriteAsset: 'assets/mascots/sprites/twill/organized.png',
        headlineLeadKey: 'onb_twill_p2_lead',
        headlineHighlightKey: 'onb_twill_p2_hl',
        subtitleKey: 'onb_twill_p2_sub',
        chapterIndex: 5,
      ),
      // 11-12: Echo
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage1,
        companion: echo,
        badgeTitle: echo.name,
        badgeIcon: Icons.auto_stories_rounded,
        accentColor: echo.accentColor,
        lightInkColor: echo.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/echo/grateful.png',
        altSpriteAsset: 'assets/mascots/sprites/echo/reflect.png',
        headlineLeadKey: 'onb_echo_p1_lead',
        headlineHighlightKey: 'onb_echo_p1_hl',
        subtitleKey: 'onb_echo_p1_sub',
        chapterIndex: 6,
      ),
      _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.mascotPage2,
        companion: echo,
        badgeTitle: echo.name,
        badgeIcon: Icons.auto_stories_rounded,
        accentColor: echo.accentColor,
        lightInkColor: echo.lightInkColor,
        spriteAsset: 'assets/mascots/sprites/echo/reflect.png',
        altSpriteAsset: 'assets/mascots/sprites/echo/grateful.png',
        headlineLeadKey: 'onb_echo_p2_lead',
        headlineHighlightKey: 'onb_echo_p2_hl',
        subtitleKey: 'onb_echo_p2_sub',
        chapterIndex: 6,
      ),
      // 13: Ready
      const _OnboardingSlideSpec(
        kind: _OnboardingSlideKind.ready,
        badgeTitle: 'Nestin',
        badgeIcon: Icons.check_rounded,
        accentColor: AppColors.primary,
        lightInkColor: AppColors.primaryDark,
        headlineLeadKey: 'onb_ready_lead',
        headlineHighlightKey: 'onb_ready_hl',
        subtitleKey: 'onb_ready_sub',
        chapterIndex: 7,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, _slides.length - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant MascotOnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPage != oldWidget.initialPage) {
      final target = widget.initialPage.clamp(0, _slides.length - 1);
      _currentPage = target;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(target);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    final target = index.clamp(0, _slides.length - 1);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    HapticFeedback.selectionClick();
    if (_pageController.hasClients) {
      if (disableAnimations) {
        _pageController.jumpToPage(target);
      } else {
        _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      setState(() => _currentPage = target);
    }
  }

  void _jumpToChapter(int chapterIndex) {
    if (chapterIndex == 0) {
      _goToPage(0);
    } else if (chapterIndex == 7) {
      _goToPage(_slides.length - 1);
    } else {
      // Bird chapters 1..6 start at slide indices 1, 3, 5, 7, 9, 11
      _goToPage((chapterIndex - 1) * 2 + 1);
    }
  }

  void _toggleSlidePose(int slideIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_tappedSlides.contains(slideIndex)) {
        _tappedSlides.remove(slideIndex);
      } else {
        _tappedSlides.add(slideIndex);
      }
    });
  }

  Future<void> _finishTour() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    HapticFeedback.mediumImpact();

    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await settings.completeMascotOnboarding();
    } catch (_) {
      // Isolated widget tests without SettingsProvider still close cleanly.
    }

    if (!mounted) return;
    widget.onCompleted?.call();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final activeSlide = _slides[_currentPage];

    SettingsProvider? settings;
    try {
      settings = Provider.of<SettingsProvider>(context);
    } catch (_) {}

    // Crisp pure minimalist canvas: white in Light, obsidian darkBg in Dark
    final canvasBg = isDark ? AppColors.darkBg : Colors.white;

    return Scaffold(
      key: const Key('mascot_onboarding_screen'),
      backgroundColor: canvasBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildMinimalTopBar(context, l10n, settings, activeSlide),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final spec = _slides[index];
                  return _MinimalOnboardingSlide(
                    spec: spec,
                    slideIndex: index,
                    isAlternatePose: _tappedSlides.contains(index),
                    onTapHero: () => _toggleSlidePose(index),
                    onSelectBirdChapter: (mascotIndex) =>
                        _jumpToChapter(mascotIndex + 1),
                  );
                },
              ),
            ),
            _buildMinimalBottomArea(context, l10n, activeSlide),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalTopBar(
    BuildContext context,
    AppLocalizations l10n,
    SettingsProvider? settings,
    _OnboardingSlideSpec slide,
  ) {
    final isDark = AppColors.isDark(context);
    final isFirst = _currentPage == 0;
    final isId = l10n.isIndonesian;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Left: subtle Back icon on pages > 0
            Align(
              alignment: Alignment.centerLeft,
              child: isFirst
                  ? const SizedBox(width: 40)
                  : IconButton(
                      key: const Key('onboarding_back_button'),
                      onPressed: () => _goToPage(_currentPage - 1),
                      tooltip: l10n.tr('onb_back'),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
            ),

            // Center: Minimalist dark rounded icon badge + clean name (reference style)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCardElevated
                        : AppColors.lightTextPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    slide.badgeIcon,
                    size: 14,
                    color: slide.accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  slide.badgeTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                if (slide.kind == _OnboardingSlideKind.mascotPage1 ||
                    slide.kind == _OnboardingSlideKind.mascotPage2) ...[
                  const SizedBox(width: 6),
                  Text(
                    slide.kind == _OnboardingSlideKind.mascotPage1
                        ? '1/2'
                        : '2/2',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ],
            ),

            // Right: Quiet language switch + Skip/Close
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (settings != null)
                    InkWell(
                      key: const Key('onboarding_lang_toggle'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final next = settings.language == AppLanguage.en
                            ? AppLanguage.id
                            : AppLanguage.en;
                        settings.setLanguage(next);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 6,
                        ),
                        child: Text(
                          isId ? 'ID' : 'EN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ),
                  TextButton(
                    key: const Key('onboarding_skip_button'),
                    onPressed: _isFinishing ? null : _finishTour,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      widget.isReplay
                          ? l10n.tr('onb_close')
                          : l10n.tr('onb_skip'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
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
  }

  Widget _buildMinimalBottomArea(
    BuildContext context,
    AppLocalizations l10n,
    _OnboardingSlideSpec slide,
  ) {
    final isLast = slide.kind == _OnboardingSlideKind.ready;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final ctaLabel = switch (slide.kind) {
      _OnboardingSlideKind.welcome => l10n.tr('onb_cta_explore'),
      _OnboardingSlideKind.mascotPage1 => l10n.tr('onb_cta_learn_more'),
      _OnboardingSlideKind.mascotPage2 => l10n.tr('onb_cta_continue'),
      _OnboardingSlideKind.ready => widget.isReplay
          ? l10n.tr('onb_cta_finish')
          : l10n.tr('onb_cta_enter'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ultra-slim 8-chapter progress indicator (Welcome + 6 Birds + Ready)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(8, (chapter) {
              final isCurrentChapter = slide.chapterIndex == chapter;
              final isCompletedChapter = slide.chapterIndex > chapter;
              final chapterColor = chapter >= 1 && chapter <= 6
                  ? NestinFlock.companions[chapter - 1].accentColor
                  : AppColors.primary;

              final double fillFraction;
              if (isCompletedChapter) {
                fillFraction = 1.0;
              } else if (!isCurrentChapter) {
                fillFraction = 0.0;
              } else if (slide.kind == _OnboardingSlideKind.mascotPage1) {
                fillFraction = 0.5;
              } else {
                fillFraction = 1.0;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  key: Key('onboarding_chapter_$chapter'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _jumpToChapter(chapter),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: AnimatedContainer(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: isCurrentChapter ? 28 : 10,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.trackSurface(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fillFraction,
                        child: Container(
                          decoration: BoxDecoration(
                            color: chapterColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Centered minimalist pill CTA matching the reference silhouette
          SizedBox(
            width: 210,
            height: 48,
            child: isLast
                ? FilledButton(
                    key: const Key('onboarding_primary_cta'),
                    onPressed: _isFinishing ? null : _finishTour,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      ctaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : OutlinedButton(
                    key: const Key('onboarding_primary_cta'),
                    onPressed: _isFinishing
                        ? null
                        : () => _goToPage(_currentPage + 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary(context),
                      backgroundColor: AppColors.isDark(context)
                          ? AppColors.darkCard
                          : Colors.white,
                      side: BorderSide(
                        color: AppColors.border(context),
                        width: 1.2,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      ctaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MinimalOnboardingSlide extends StatelessWidget {
  final _OnboardingSlideSpec spec;
  final int slideIndex;
  final bool isAlternatePose;
  final VoidCallback onTapHero;
  final void Function(int mascotIndex) onSelectBirdChapter;

  const _MinimalOnboardingSlide({
    required this.spec,
    required this.slideIndex,
    required this.isAlternatePose,
    required this.onTapHero,
    required this.onSelectBirdChapter,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final highlightColor = AppColors.adaptive(
      context,
      dark: spec.accentColor,
      light: spec.lightInkColor,
    );

    // Soft gallery-minimalist circle backdrop
    final circleBg = isDark
        ? Color.lerp(AppColors.darkCard, spec.accentColor, 0.08)!
        : Color.lerp(const Color(0xFFF6F7F9), spec.accentColor, 0.04)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availH = constraints.maxHeight;
        final availW = constraints.maxWidth;
        final circleSize = math.min(
          availW * 0.62,
          (availH * 0.46).clamp(148.0, 236.0),
        );
        final spriteSize = circleSize * 0.72;
        final isCompact = availH < 440;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Centered Soft Circular Hero Stage
              _buildHeroCircle(
                context,
                circleSize: circleSize,
                spriteSize: spriteSize,
                circleBg: circleBg,
                highlightColor: highlightColor,
                disableAnimations: disableAnimations,
              ),

              SizedBox(height: isCompact ? 22 : 34),

              // Minimalist Editorial 2-Line Headline with Accent Highlight
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l10n.tr(spec.headlineLeadKey),
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      TextSpan(
                        text: l10n.tr(spec.headlineHighlightKey),
                        style: TextStyle(
                          color: highlightColor,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isCompact ? 21 : 24,
                    fontWeight: FontWeight.w700,
                    height: 1.32,
                    letterSpacing: -0.45,
                  ),
                ),
              ),

              SizedBox(height: isCompact ? 8 : 12),

              // Quiet 1–2 line whisper subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 276),
                child: Text(
                  l10n.tr(spec.subtitleKey),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 12.5 : 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCircle(
    BuildContext context, {
    required double circleSize,
    required double spriteSize,
    required Color circleBg,
    required Color highlightColor,
    required bool disableAnimations,
  }) {
    if (spec.kind == _OnboardingSlideKind.welcome) {
      return Container(
        key: const Key('onboarding_hero_welcome'),
        width: circleSize,
        height: circleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: circleBg,
        ),
        child: Center(
          child: ClipOval(
            child: Image.asset(
              'assets/logo.jpg',
              width: spriteSize * 0.78,
              height: spriteSize * 0.78,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: spriteSize * 0.78,
                height: spriteSize * 0.78,
                color: AppColors.primary,
                child: Icon(
                  Icons.wb_twilight_rounded,
                  color: Colors.white,
                  size: spriteSize * 0.42,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (spec.kind == _OnboardingSlideKind.ready) {
      final miniSize = (circleSize * 0.24).clamp(36.0, 54.0);
      return Container(
        key: const Key('onboarding_hero_ready'),
        width: circleSize,
        height: circleSize,
        padding: EdgeInsets.all(circleSize * 0.14),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: circleBg,
        ),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: circleSize * 0.05,
            runSpacing: circleSize * 0.05,
            children: List.generate(NestinFlock.companions.length, (i) {
              final bird = NestinFlock.companions[i];
              return GestureDetector(
                key: Key('onboarding_ready_bird_${bird.id.name}'),
                onTap: () => onSelectBirdChapter(i),
                child: SizedBox(
                  width: miniSize,
                  height: miniSize,
                  child: Image.asset(
                    bird.primarySpriteAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      bird.fallbackIcon,
                      color: bird.accentColor,
                      size: miniSize * 0.65,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );
    }

    final companion = spec.companion!;
    final activeAsset = (isAlternatePose && spec.altSpriteAsset != null)
        ? spec.altSpriteAsset!
        : spec.spriteAsset!;

    return GestureDetector(
      key: Key('onboarding_mascot_${companion.id.name}_$slideIndex'),
      onTap: onTapHero,
      child: AnimatedScale(
        scale: isAlternatePose ? 1.04 : 1.0,
        duration:
            disableAnimations ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleBg,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: Image.asset(
                activeAsset,
                key: ValueKey(activeAsset),
                width: spriteSize,
                height: spriteSize,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  companion.fallbackIcon,
                  size: spriteSize * 0.55,
                  color: highlightColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
