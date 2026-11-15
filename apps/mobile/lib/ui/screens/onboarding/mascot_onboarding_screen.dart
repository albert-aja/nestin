import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/mascot_companion.dart';
import '../../../providers/settings_provider.dart';

/// Interactive mascot-led onboarding tour introducing first-time users (and
/// returning users replaying from Settings) to Nestin's 6 bird companions and
/// their everyday life roles.
class MascotOnboardingScreen extends StatefulWidget {
  final bool isReplay;
  final int initialPage;
  final VoidCallback? onCompleted;

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
  static const int _totalPages = 8; // Welcome + 6 Birds + Ready Summary

  late final PageController _pageController;
  late int _currentPage;
  final Set<NestinMascotId> _alternatePoseIds = <NestinMascotId>{};
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, _totalPages - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant MascotOnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPage != oldWidget.initialPage) {
      final target = widget.initialPage.clamp(0, _totalPages - 1);
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

  MascotCompanionProfile? get _activeCompanion {
    if (_currentPage >= 1 && _currentPage <= NestinFlock.companions.length) {
      return NestinFlock.companions[_currentPage - 1];
    }
    return null;
  }

  Color _accentForPage(BuildContext context) {
    final active = _activeCompanion;
    if (active == null) return AppColors.primary;
    return AppColors.adaptive(
      context,
      dark: active.accentColor,
      light: active.lightInkColor,
    );
  }

  Color _rawAccentForPage() =>
      _activeCompanion?.accentColor ?? AppColors.primary;

  void _goToPage(int index) {
    final target = index.clamp(0, _totalPages - 1);
    HapticFeedback.selectionClick();
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() => _currentPage = target);
    }
  }

  void _toggleCompanionPose(NestinMascotId id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_alternatePoseIds.contains(id)) {
        _alternatePoseIds.remove(id);
      } else {
        _alternatePoseIds.add(id);
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
      // Isolated widget tests without SettingsProvider still allow closing cleanly.
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
    final isId = l10n.language == AppLanguage.id;
    final pageAccent = _rawAccentForPage();
    final inkAccent = _accentForPage(context);

    SettingsProvider? settings;
    try {
      settings = Provider.of<SettingsProvider>(context);
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.65),
              radius: 1.15,
              colors: [
                pageAccent.withValues(
                  alpha: AppColors.isDark(context) ? 0.14 : 0.10,
                ),
                AppColors.scaffoldBg(context),
              ],
            ),
          ),
          child: Column(
            children: [
              _buildTopBar(context, settings, isId, inkAccent),
              _buildProgressRail(context, isId),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _totalPages,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _WelcomeSlide(
                        isId: isId,
                        onSelectMascotSlide: (mascotIndex) =>
                            _goToPage(mascotIndex + 1),
                      );
                    }
                    if (index <= NestinFlock.companions.length) {
                      final companion = NestinFlock.companions[index - 1];
                      final isAlt = _alternatePoseIds.contains(companion.id);
                      return _CompanionSlide(
                        companion: companion,
                        isId: isId,
                        isAlternatePose: isAlt,
                        onTapMascot: () => _toggleCompanionPose(companion.id),
                      );
                    }
                    return _SummarySlide(
                      isId: isId,
                      onSelectMascotSlide: (mascotIndex) =>
                          _goToPage(mascotIndex + 1),
                    );
                  },
                ),
              ),
              _buildBottomBar(context, isId, pageAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    SettingsProvider? settings,
    bool isId,
    Color inkAccent,
  ) {
    final active = _activeCompanion;
    final stepTitle = _currentPage == 0
        ? (isId ? 'Selamat Datang' : 'Welcome')
        : (active != null
            ? active.name
            : (isId ? 'Kawanan Siap' : 'All Set'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _rawAccentForPage().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _rawAccentForPage().withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${_currentPage + 1}/$_totalPages • $stepTitle',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: inkAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (settings != null)
            InkWell(
              key: const Key('onboarding_lang_toggle'),
              onTap: () {
                final next = settings.language == AppLanguage.en
                    ? AppLanguage.id
                    : AppLanguage.en;
                settings.setLanguage(next);
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Text(
                  isId ? '🇮🇩 ID' : '🇺🇸 EN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          TextButton(
            key: const Key('onboarding_skip_button'),
            onPressed: _isFinishing ? null : _finishTour,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              widget.isReplay
                  ? (isId ? 'Tutup' : 'Close')
                  : (isId ? 'Lewati' : 'Skip'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRail(BuildContext context, bool isId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalPages, (index) {
          final isSelected = index == _currentPage;
          final isMascotStep =
              index >= 1 && index <= NestinFlock.companions.length;
          final companion =
              isMascotStep ? NestinFlock.companions[index - 1] : null;
          final dotColor = companion?.accentColor ?? AppColors.primary;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              key: Key('onboarding_step_$index'),
              onTap: () => _goToPage(index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 22,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 10 : (isMascotStep ? 7 : 6),
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? dotColor
                      : dotColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? dotColor
                        : dotColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    index == 0
                        ? '★'
                        : (companion != null ? companion.shortInitial : '✓'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary(context),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    bool isId,
    Color pageAccent,
  ) {
    final isFirst = _currentPage == 0;
    final isLast = _currentPage == _totalPages - 1;

    final primaryLabel = isFirst
        ? (isId ? 'Kenali 6 Burung' : 'Meet the 6 Birds')
        : (isLast
            ? (widget.isReplay
                ? (isId ? 'Selesai Tur' : 'Finish Tour')
                : (isId ? 'Masuk ke Nestin' : 'Enter Nestin'))
            : (isId ? 'Lanjut' : 'Next'));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg(context).withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: Row(
        children: [
          if (!isFirst) ...[
            OutlinedButton.icon(
              key: const Key('onboarding_back_button'),
              onPressed: () => _goToPage(_currentPage - 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: Text(isId ? 'Kembali' : 'Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary(context),
                side: BorderSide(color: AppColors.border(context)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ElevatedButton.icon(
              key: const Key('onboarding_primary_cta'),
              onPressed: _isFinishing
                  ? null
                  : (isLast ? _finishTour : () => _goToPage(_currentPage + 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: pageAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                isLast
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                primaryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeSlide extends StatelessWidget {
  final bool isId;
  final void Function(int mascotIndex) onSelectMascotSlide;

  const _WelcomeSlide({
    required this.isId,
    required this.onSelectMascotSlide,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.35),
                    AppColors.accent.withValues(alpha: 0.30),
                  ],
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.jpg',
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 78,
                    height: 78,
                    color: AppColors.primary,
                    child: const Icon(
                      Icons.wb_twilight_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isId ? 'Selamat Datang di Nestin' : 'Welcome to Nestin',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isId
                ? 'Ruang Harian Pribadi yang tenang, offline, dan dipandu oleh 6 sahabat burung.'
                : 'Your calm, offline-first Personal Everyday Space guided by 6 feathered companions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isId
                      ? 'Ketuk burung mana saja untuk berkenalan:'
                      : 'Tap any companion to jump straight to their intro:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(NestinFlock.companions.length, (i) {
                    final bird = NestinFlock.companions[i];
                    final labelColor = AppColors.adaptive(
                      context,
                      dark: bird.accentColor,
                      light: bird.lightInkColor,
                    );
                    return InkWell(
                      onTap: () => onSelectMascotSlide(i),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: bird.accentColor.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: bird.accentColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MiniBirdAvatar(companion: bird, size: 30),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  bird.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: labelColor,
                                  ),
                                ),
                                Text(
                                  bird.domainTitle(isId),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: AppColors.adaptive(
                    context,
                    dark: AppColors.success,
                    light: const Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isId
                        ? '100% lokal di perangkatmu: alarm, rutinitas, kebugaran, catatan, dompet manual, dan diari pribadimu tetap aman tanpa ketergantungan cloud.'
                        : '100% local-first on your device: alarms, wellness, notes, offline personal budgets, and private diary entries stay yours without forced cloud accounts.',
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
        ],
      ),
    );
  }
}

class _CompanionSlide extends StatelessWidget {
  final MascotCompanionProfile companion;
  final bool isId;
  final bool isAlternatePose;
  final VoidCallback onTapMascot;

  const _CompanionSlide({
    required this.companion,
    required this.isId,
    required this.isAlternatePose,
    required this.onTapMascot,
  });

  @override
  Widget build(BuildContext context) {
    final accent = companion.accentColor;
    final ink = AppColors.adaptive(
      context,
      dark: accent,
      light: companion.lightInkColor,
    );
    final spritePath = isAlternatePose
        ? companion.altSpriteAsset
        : companion.primarySpriteAsset;
    final speechText = companion.speech(isId, alternate: isAlternatePose);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: InkWell(
              key: Key('onboarding_mascot_${companion.id.name}'),
              onTap: onTapMascot,
              borderRadius: BorderRadius.circular(90),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: isAlternatePose ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 152,
                        height: 152,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(
                                alpha: AppColors.isDark(context) ? 0.34 : 0.22,
                              ),
                              accent.withValues(alpha: 0.04),
                            ],
                          ),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.38),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Image.asset(
                              spritePath,
                              key: ValueKey(spritePath),
                              width: 126,
                              height: 126,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(
                                companion.fallbackIcon,
                                size: 64,
                                color: ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isId
                          ? 'Ketuk ${companion.name} untuk menyapa'
                          : 'Tap ${companion.name} to say hi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _MascotSpeechBalloon(
            text: speechText,
            accentColor: accent,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _PillTag(
                label: companion.domainTitle(isId),
                color: accent,
                textColor: ink,
              ),
              _PillTag(
                label: companion.dayWindow(isId),
                color: AppColors.textSecondary(context),
                textColor: AppColors.textSecondary(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${companion.name} • ${companion.species(isId)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '"${companion.archetype(isId)}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isId
                      ? 'Peran Harian ${companion.name}:'
                      : "How ${companion.name} Helps Every Day:",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                ...companion.roles.map(
                  (role) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(role.icon, size: 16, color: ink),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              role.label(isId),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySlide extends StatelessWidget {
  final bool isId;
  final void Function(int mascotIndex) onSelectMascotSlide;

  const _SummarySlide({
    required this.isId,
    required this.onSelectMascotSlide,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isId
                ? 'Kawanan Sahabatmu Siap!'
                : 'Your 6 Companions Are Ready!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isId
                ? 'Dari alarm pagi bersama Roo hingga refleksi malam bersama Echo, setiap sudut harimu punya pemandunya sendiri.'
                : 'From dawn wake-ups with Roo to dusk reflections with Echo, every corner of your day has its own gentle guide.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(NestinFlock.companions.length, (i) {
              final bird = NestinFlock.companions[i];
              final ink = AppColors.adaptive(
                context,
                dark: bird.accentColor,
                light: bird.lightInkColor,
              );
              return LayoutBuilder(
                builder: (ctx, constraints) {
                  final halfWidth = (constraints.maxWidth - 10) / 2;
                  return SizedBox(
                    width: halfWidth > 140 ? halfWidth : constraints.maxWidth,
                    child: InkWell(
                      onTap: () => onSelectMascotSlide(i),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: bird.accentColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            _MiniBirdAvatar(companion: bird, size: 42),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    bird.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                    ),
                                  ),
                                  Text(
                                    bird.domainTitle(isId),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.replay_circle_filled_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isId
                        ? 'Ingin memutar ulang tur ini nanti? Buka Pengaturan → Sahabat Burung.'
                        : 'Want to revisit this tour anytime? Open Settings → Meet the 6 Bird Companions.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBirdAvatar extends StatelessWidget {
  final MascotCompanionProfile companion;
  final double size;

  const _MiniBirdAvatar({
    required this.companion,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: companion.accentColor.withValues(alpha: 0.16),
        border: Border.all(
          color: companion.accentColor.withValues(alpha: 0.40),
        ),
      ),
      child: Image.asset(
        companion.primarySpriteAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          companion.fallbackIcon,
          size: size * 0.55,
          color: companion.accentColor,
        ),
      ),
    );
  }
}

class _MascotSpeechBalloon extends StatelessWidget {
  final String text;
  final Color accentColor;

  const _MascotSpeechBalloon({
    required this.text,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.cardSurface(context);
    final borderColor = accentColor.withValues(alpha: 0.45);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 9),
          painter: _SpeechPointerPainter(
            fillColor: fill,
            borderColor: borderColor,
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              text,
              key: ValueKey(text),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeechPointerPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  const _SpeechPointerPainter({
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    final fillPaint = Paint()..color = fillColor;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final edgePath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(edgePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechPointerPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class _PillTag extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _PillTag({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
