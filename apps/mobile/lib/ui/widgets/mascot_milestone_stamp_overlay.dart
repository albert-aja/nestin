import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// Supported mascot milestone stamp celebrations across Nestin life domains.
enum MascotMilestoneType {
  /// Pippin explorer passport stamp on reading or bucket-list completion.
  pippinStamped,

  /// Roo blazing flame stamp on reaching a 7-day+ habit routine streak.
  rooOnFire,

  /// Seren refreshed crown stamp on reaching the daily hydration target.
  serenRefreshed,
}

/// Visual metadata and localization helpers for a [MascotMilestoneType].
class MascotMilestoneSpec {
  final MascotMilestoneType type;
  final String mascotName;
  final String assetPath;
  final Color accentColor;
  final Color secondaryColor;
  final IconData fallbackIcon;
  final IconData stampIcon;
  final String stampEn;
  final String stampId;

  const MascotMilestoneSpec({
    required this.type,
    required this.mascotName,
    required this.assetPath,
    required this.accentColor,
    required this.secondaryColor,
    required this.fallbackIcon,
    required this.stampIcon,
    required this.stampEn,
    required this.stampId,
  });

  String stampLabel(bool isIndonesian) => isIndonesian ? stampId : stampEn;

  static MascotMilestoneSpec forType(MascotMilestoneType type) {
    switch (type) {
      case MascotMilestoneType.pippinStamped:
        return const MascotMilestoneSpec(
          type: MascotMilestoneType.pippinStamped,
          mascotName: 'Pippin',
          assetPath: 'assets/mascots/sprites/pippin/stamped.png',
          accentColor: Color(0xFF10B981),
          secondaryColor: Color(0xFFF59E0B),
          fallbackIcon: Icons.explore_rounded,
          stampIcon: Icons.verified_rounded,
          stampEn: 'STAMPED!',
          stampId: 'TERCAP!',
        );
      case MascotMilestoneType.rooOnFire:
        return const MascotMilestoneSpec(
          type: MascotMilestoneType.rooOnFire,
          mascotName: 'Roo',
          assetPath: 'assets/mascots/sprites/roo/on_fire.png',
          accentColor: AppColors.primary,
          secondaryColor: AppColors.accent,
          fallbackIcon: Icons.local_fire_department_rounded,
          stampIcon: Icons.local_fire_department_rounded,
          stampEn: 'ON FIRE!',
          stampId: 'MEMBARA!',
        );
      case MascotMilestoneType.serenRefreshed:
        return const MascotMilestoneSpec(
          type: MascotMilestoneType.serenRefreshed,
          mascotName: 'Seren',
          assetPath: 'assets/mascots/sprites/seren/refreshed.png',
          accentColor: Color(0xFF8B5CF6),
          secondaryColor: Color(0xFFF59E0B),
          fallbackIcon: Icons.water_drop_rounded,
          stampIcon: Icons.workspace_premium_rounded,
          stampEn: 'REFRESHED!',
          stampId: 'SEGAR!',
        );
    }
  }
}

/// Reusable animated mascot sprite + slamming celebratory ink stamp badge.
///
/// Embedded both inside [MascotMilestoneStampOverlay] and inline inside
/// celebration dialogs (such as reading completion) so the artwork and stamp
/// physics share one single implementation.
class MascotMilestoneStampBadge extends StatefulWidget {
  final MascotMilestoneType type;
  final double spriteSize;
  final bool isIndonesian;

  const MascotMilestoneStampBadge({
    super.key,
    required this.type,
    this.spriteSize = 104,
    this.isIndonesian = false,
  });

  @override
  State<MascotMilestoneStampBadge> createState() =>
      _MascotMilestoneStampBadgeState();
}

class _MascotMilestoneStampBadgeState extends State<MascotMilestoneStampBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _mascotScale;
  late final Animation<double> _stampProgress;
  late final Animation<double> _burstProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _mascotScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.58, curve: Curves.elasticOut),
    );
    _stampProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.24, 0.72, curve: Curves.easeOutBack),
    );
    _burstProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 1.0, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = MascotMilestoneSpec.forType(widget.type);
    final haloSize = widget.spriteSize + 44;

    return SizedBox(
      width: haloSize + 24,
      height: haloSize + 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final stampScale =
              Tween<double>(begin: 1.65, end: 1.0).transform(_stampProgress.value);
          final stampOpacity = _stampProgress.value.clamp(0.0, 1.0);

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Radial celebration burst ring
              CustomPaint(
                size: Size(haloSize, haloSize),
                painter: _MilestoneBurstPainter(
                  progress: _burstProgress.value,
                  primaryColor: spec.accentColor,
                  secondaryColor: spec.secondaryColor,
                  isDark: AppColors.isDark(context),
                ),
              ),
              // Subtle category-tinted radial backdrop so dark ink outlines pop
              Container(
                width: widget.spriteSize + 18,
                height: widget.spriteSize + 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      spec.accentColor.withValues(
                        alpha: AppColors.isDark(context) ? 0.28 : 0.16,
                      ),
                      spec.accentColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              // Mascot sprite pop-in
              Transform.scale(
                scale: 0.35 + (0.65 * _mascotScale.value),
                child: Image.asset(
                  spec.assetPath,
                  width: widget.spriteSize,
                  height: widget.spriteSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: widget.spriteSize * 0.72,
                    height: widget.spriteSize * 0.72,
                    decoration: BoxDecoration(
                      color: spec.accentColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      spec.fallbackIcon,
                      color: spec.accentColor,
                      size: widget.spriteSize * 0.42,
                    ),
                  ),
                ),
              ),
              // Crown / flame / verified top badge for Seren / Roo / Pippin
              Positioned(
                top: 2,
                right: 12,
                child: Opacity(
                  opacity: stampOpacity,
                  child: Transform.scale(
                    scale: 0.6 + (0.4 * _mascotScale.value),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: spec.secondaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.sheetSurface(context),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: spec.secondaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        spec.stampIcon,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Slammed celebratory stamp seal
              Positioned(
                bottom: 0,
                child: Opacity(
                  opacity: stampOpacity,
                  child: Transform.rotate(
                    angle: -0.07,
                    child: Transform.scale(
                      scale: stampScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sheetSurface(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: spec.accentColor,
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: spec.accentColor.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          spec.stampLabel(widget.isIndonesian),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: AppColors.adaptive(
                              context,
                              dark: spec.accentColor == AppColors.primary
                                  ? AppColors.primaryLight
                                  : spec.accentColor,
                              light: spec.accentColor,
                            ),
                          ),
                        ),
                      ),
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
}

class _MilestoneBurstPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  const _MilestoneBurstPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.34;
    final fade = (1.0 - (progress * 0.35)).clamp(0.0, 1.0);

    // Subtle expanding halo ring
    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: (isDark ? 0.32 : 0.22) * (1 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * (1 - progress * 0.5);
    canvas.drawCircle(center, baseRadius + (progress * 26), ringPaint);

    // 10 crisp celebratory rays & sparkles
    const particleCount = 10;
    for (int i = 0; i < particleCount; i++) {
      final angle = (2 * math.pi / particleCount) * i - (math.pi / 2);
      final dist = baseRadius + 6 + (progress * 20);
      final pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      final color = i.isEven ? primaryColor : secondaryColor;
      final dotPaint = Paint()..color = color.withValues(alpha: 0.85 * fade);
      final radius = i.isEven ? 3.2 : 2.2;
      canvas.drawCircle(pos, radius * (1.0 - progress * 0.25), dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MilestoneBurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.isDark != isDark;
}

/// Manages the root-overlay celebratory mascot stamp banner for milestones.
class MascotMilestoneStampOverlay {
  static OverlayEntry? _activeEntry;

  MascotMilestoneStampOverlay._();

  /// Removes any active celebratory stamp overlay if mounted.
  static void dismissActive() {
    final entry = _activeEntry;
    _activeEntry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }

  /// Displays Pippin's `STAMPED!` passport stamp overlay when finishing a
  /// bucket list, places-to-visit checklist, or reading milestone.
  static void showPippinStamped(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) {
    final l10n = context.l10n;
    show(
      context,
      type: MascotMilestoneType.pippinStamped,
      headline: l10n.tr('pippin_stamped_your_passport'),
      title: title,
      subtitle: subtitle ??
          l10n.tr('checklist_milestone_100_completed'),
    );
  }

  /// Displays Roo's `ON FIRE!` celebratory stamp overlay when hitting a 7-day
  /// (or multiple-of-7) habit routine streak.
  static void showRooOnFire(
    BuildContext context, {
    required String routineTitle,
    required int streakDays,
  }) {
    final l10n = context.l10n;
    show(
      context,
      type: MascotMilestoneType.rooOnFire,
      headline: l10n.tr('roo_says_day_streak', {'streakDays': streakDays}),
      title: routineTitle,
      subtitle: l10n.tr('unstoppable_daily_routine_momentum'),
    );
  }

  /// Displays Seren's `REFRESHED!` crown stamp overlay when daily hydration
  /// target is met.
  static void showSerenRefreshed(
    BuildContext context, {
    required int currentMl,
    required int targetMl,
  }) {
    final l10n = context.l10n;
    show(
      context,
      type: MascotMilestoneType.serenRefreshed,
      headline: l10n.tr('hydration_crown_unlocked'),
      title: l10n.tr('daily_target_met_ml', {'currentMl': currentMl}),
      subtitle: l10n.tr('seren_celebrates_ml_full_daily_hydration', {'targetMl': targetMl}),
    );
  }

  /// Renders a non-blocking, auto-dismissing overlay card with mascot sprite
  /// and slamming stamp badge.
  static void show(
    BuildContext context, {
    required MascotMilestoneType type,
    required String headline,
    required String title,
    String? subtitle,
    Duration displayDuration = const Duration(milliseconds: 2400),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismissActive();
    HapticFeedback.mediumImpact();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _MilestoneStampOverlayCard(
        type: type,
        headline: headline,
        title: title,
        subtitle: subtitle,
        displayDuration: displayDuration,
        onDismissed: () {
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _MilestoneStampOverlayCard extends StatefulWidget {
  final MascotMilestoneType type;
  final String headline;
  final String title;
  final String? subtitle;
  final Duration displayDuration;
  final VoidCallback onDismissed;

  const _MilestoneStampOverlayCard({
    required this.type,
    required this.headline,
    required this.title,
    this.subtitle,
    required this.displayDuration,
    required this.onDismissed,
  });

  @override
  State<_MilestoneStampOverlayCard> createState() =>
      _MilestoneStampOverlayCardState();
}

class _MilestoneStampOverlayCardState extends State<_MilestoneStampOverlayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cardController;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  Timer? _autoDismissTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOut,
    );
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: Curves.easeOutBack,
      ),
    );
    _cardController.forward();
    _autoDismissTimer = Timer(widget.displayDuration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_closing || !mounted) return;
    _closing = true;
    _autoDismissTimer?.cancel();
    await _cardController.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = MascotMilestoneSpec.forType(widget.type);
    final l10n = context.l10n;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.28),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: FadeTransition(
                  opacity: _opacity,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                      decoration: BoxDecoration(
                        color: AppColors.sheetSurface(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: spec.accentColor.withValues(alpha: 0.55),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: spec.accentColor.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MascotMilestoneStampBadge(
                            type: widget.type,
                            isIndonesian: l10n.isIndonesian,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.headline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: spec.accentColor,
                            ),
                          ),
                          if (widget.subtitle != null &&
                              widget.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            l10n.tr('tap_to_continue'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
