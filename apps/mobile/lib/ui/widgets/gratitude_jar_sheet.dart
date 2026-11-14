import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/gratitude_pebble.dart';
import '../../data/models/journal_entry.dart';
import '../../providers/journal_provider.dart';

/// Animated hand-drawn Echo Gratitude Jar filled with colorful pebbles
/// derived from the user's [JournalEntry.gratitudeNote] reflections.
class EchoGratitudeJarVisual extends StatelessWidget {
  final List<GratitudePebble> pebbles;
  final double shakeProgress;
  final double width;
  final double height;
  final GratitudePebble? highlightedPebble;

  const EchoGratitudeJarVisual({
    super.key,
    required this.pebbles,
    this.shakeProgress = 0.0,
    this.width = 148,
    this.height = 176,
    this.highlightedPebble,
  });

  @override
  Widget build(BuildContext context) {
    final t = shakeProgress.clamp(0.0, 1.0);
    final decay = 1.0 - t;
    final angle = sin(t * pi * 6) * 0.09 * decay;
    final dx = sin(t * pi * 6) * 7.0 * decay;
    final dy = -sin(t * pi * 4).abs() * 5.0 * decay;
    final isDark = AppColors.isDark(context);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: angle,
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _EchoGratitudeJarPainter(
              pebbles: pebbles,
              shakeProgress: t,
              isDark: isDark,
              highlightedPebbleId: highlightedPebble?.entryId,
            ),
          ),
        ),
      ),
    );
  }
}

class _EchoGratitudeJarPainter extends CustomPainter {
  final List<GratitudePebble> pebbles;
  final double shakeProgress;
  final bool isDark;
  final String? highlightedPebbleId;

  const _EchoGratitudeJarPainter({
    required this.pebbles,
    required this.shakeProgress,
    required this.isDark,
    this.highlightedPebbleId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final corkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.29, h * 0.03, w * 0.42, h * 0.09),
      Radius.circular(w * 0.05),
    );
    final rimRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.10, w * 0.52, h * 0.065),
      Radius.circular(w * 0.04),
    );

    final bodyRect = Rect.fromLTWH(w * 0.14, h * 0.16, w * 0.72, h * 0.80);
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: Radius.circular(w * 0.18),
      topRight: Radius.circular(w * 0.18),
      bottomLeft: Radius.circular(w * 0.14),
      bottomRight: Radius.circular(w * 0.14),
    );

    // Subtle warm shadow underneath jar
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.965),
        width: w * 0.60,
        height: h * 0.045,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.35 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Glass interior backdrop
    final glassFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF282B36).withValues(alpha: 0.78),
                const Color(0xFF1A1C24).withValues(alpha: 0.88),
              ]
            : [
                const Color(0xFFFFFBEB).withValues(alpha: 0.92),
                const Color(0xFFEFF6FF).withValues(alpha: 0.85),
              ],
      ).createShader(bodyRect);
    canvas.drawRRect(bodyRRect, glassFill);

    // Clip pebbles cleanly inside jar glass walls
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndCorners(
        bodyRect.deflate(w * 0.03),
        topLeft: Radius.circular(w * 0.15),
        topRight: Radius.circular(w * 0.15),
        bottomLeft: Radius.circular(w * 0.12),
        bottomRight: Radius.circular(w * 0.12),
      ),
    );

    final visiblePebbles = pebbles.take(24).toList();
    final innerLeft = bodyRect.left + w * 0.11;
    final innerWidth = bodyRect.width - w * 0.22;
    final baseBottom = bodyRect.bottom - h * 0.06;
    const cols = 4;
    final rowSpacing = h * 0.088;
    final pebbleW = w * 0.155;
    final pebbleH = h * 0.082;

    for (var i = 0; i < visiblePebbles.length; i++) {
      final pebble = visiblePebbles[i];
      final row = i ~/ cols;
      final col = i % cols;
      final seed = pebble.entryId.codeUnits.fold<int>(i + 7, (a, b) => a + b);
      final staggerX = (row.isOdd ? 0.5 : 0.0) * (innerWidth / cols) * 0.45;
      final jitterX = ((seed % 7) - 3) * (w * 0.012);
      final cx = (innerLeft +
              (innerWidth / cols) * (col + 0.42) +
              staggerX +
              jitterX)
          .clamp(bodyRect.left + w * 0.13, bodyRect.right - w * 0.13);

      final bounce = shakeProgress > 0
          ? -sin((shakeProgress * pi * 5) + (i * 0.9)).abs() *
                (h * 0.055) *
                (1.0 - shakeProgress)
          : 0.0;
      final cy = baseBottom - row * rowSpacing + bounce;
      final rot = (((seed % 11) - 5) * 0.055) +
          (shakeProgress > 0
              ? sin(shakeProgress * pi * 6 + i) * 0.14 * (1 - shakeProgress)
              : 0.0);

      final isHighlighted =
          highlightedPebbleId != null && pebble.entryId == highlightedPebbleId;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);

      final pebbleRect = Rect.fromCenter(
        center: Offset.zero,
        width: pebbleW * (isHighlighted ? 1.15 : 1.0),
        height: pebbleH * (isHighlighted ? 1.15 : 1.0),
      );
      final pebbleColor = pebble.color;
      canvas.drawOval(
        pebbleRect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 0.9,
            colors: [
              Color.lerp(pebbleColor, Colors.white, 0.34)!,
              pebbleColor,
              Color.lerp(pebbleColor, Colors.black, 0.22)!,
            ],
          ).createShader(pebbleRect),
      );

      // Subtle glass shine speck on each pebble
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-pebbleW * 0.16, -pebbleH * 0.16),
          width: pebbleW * 0.28,
          height: pebbleH * 0.20,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.38),
      );

      if (isHighlighted) {
        canvas.drawOval(
          pebbleRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: 0.9),
        );
      }

      canvas.restore();
    }

    canvas.restore();

    // Glass wall border + left vertical highlight reflection
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.24)
            : const Color(0xFF94A3B8).withValues(alpha: 0.55),
    );
    final shinePath = Path()
      ..moveTo(bodyRect.left + w * 0.09, bodyRect.top + h * 0.11)
      ..lineTo(bodyRect.left + w * 0.09, bodyRect.bottom - h * 0.11);
    canvas.drawPath(
      shinePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.032
        ..color = Colors.white.withValues(alpha: isDark ? 0.18 : 0.65),
    );

    // Cork stopper & glass rim
    canvas.drawRRect(
      corkRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFB45309)],
        ).createShader(corkRect.outerRect),
    );
    canvas.drawRRect(
      rimRect,
      Paint()
        ..color = isDark
            ? const Color(0xFF475569)
            : const Color(0xFFCBD5E1),
    );
    canvas.drawRRect(
      rimRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.26)
            : const Color(0xFF64748B).withValues(alpha: 0.5),
    );

    // Subtle Echo star on center glass
    if (pebbles.isNotEmpty) {
      final starCenter = Offset(w * 0.50, h * 0.34);
      canvas.drawCircle(
        starCenter,
        w * 0.038,
        Paint()..color = AppColors.accent.withValues(alpha: isDark ? 0.32 : 0.26),
      );
      canvas.drawCircle(
        starCenter,
        w * 0.015,
        Paint()..color = AppColors.accent.withValues(alpha: isDark ? 0.8 : 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EchoGratitudeJarPainter oldDelegate) {
    return oldDelegate.pebbles.length != pebbles.length ||
        oldDelegate.shakeProgress != shakeProgress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.highlightedPebbleId != highlightedPebbleId;
  }
}

/// Compact interactive Echo card displayed in [DiaryEntriesScreen] showing the
/// accumulated gratitude pebbles and launching [GratitudeJarSheet] on tap.
class GratitudeJarCard extends StatelessWidget {
  final VoidCallback? onCreateReflection;
  final void Function(GratitudePebble pebble)? onOpenEntry;

  const GratitudeJarCard({
    super.key,
    this.onCreateReflection,
    this.onOpenEntry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pebbles = Provider.of<JournalProvider>(
      context,
    ).getGratitudePebbles();
    final accentInk = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.28),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(
              alpha: AppColors.isDark(context) ? 0.12 : 0.10,
            ),
            AppColors.cardSurface(context),
          ],
        ),
      ),
      child: InkWell(
        onTap: () => GratitudeJarSheet.show(
          context,
          onCreateReflection: onCreateReflection,
          onOpenEntry: onOpenEntry,
        ),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              EchoGratitudeJarVisual(
                pebbles: pebbles,
                width: 66,
                height: 80,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l10n.pick(
                            'ECHO GRATITUDE JAR',
                            'TOPLES SYUKUR ECHO',
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accentInk,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l10n.pick(
                              '${pebbles.length} ${pebbles.length == 1 ? 'pebble' : 'pebbles'}',
                              '${pebbles.length} kerikil',
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accentInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pebbles.isEmpty
                          ? l10n.pick(
                              'Drop your first gratitude note to fill Echo’s jar.',
                              'Tambahkan catatan syukur pertama untuk mengisi toples Echo.',
                            )
                          : l10n.pick(
                              'Tap to shake & pick a bright gratitude memory.',
                              'Ketuk untuk mengocok & menarik satu kenangan syukur.',
                            ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (pebbles.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '“${pebbles.first.note}”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: accentInk,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.pick('Shake', 'Kocok'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentInk,
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
  }
}

/// Interactive modal bottom sheet for shaking Echo's Gratitude Jar and picking
/// a random uplifting gratitude pebble, especially during Low or Tough moods.
class GratitudeJarSheet extends StatefulWidget {
  final JournalMood? triggeredByMood;
  final bool autoShake;
  final Random? random;
  final VoidCallback? onCreateReflection;
  final void Function(GratitudePebble pebble)? onOpenEntry;

  const GratitudeJarSheet({
    super.key,
    this.triggeredByMood,
    this.autoShake = false,
    this.random,
    this.onCreateReflection,
    this.onOpenEntry,
  });

  static Future<void> show(
    BuildContext context, {
    JournalMood? triggeredByMood,
    bool autoShake = false,
    Random? random,
    VoidCallback? onCreateReflection,
    void Function(GratitudePebble pebble)? onOpenEntry,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GratitudeJarSheet(
        triggeredByMood: triggeredByMood,
        autoShake: autoShake,
        random: random,
        onCreateReflection: onCreateReflection,
        onOpenEntry: onOpenEntry,
      ),
    );
  }

  @override
  State<GratitudeJarSheet> createState() => _GratitudeJarSheetState();
}

class _GratitudeJarSheetState extends State<GratitudeJarSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  GratitudePebble? _pickedPebble;
  int _pickCount = 0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    if (widget.autoShake) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _shakeAndPick(withHaptics: false);
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _shakeAndPick({bool withHaptics = true}) {
    final provider = Provider.of<JournalProvider>(context, listen: false);
    final pebbles = provider.getGratitudePebbles();
    if (withHaptics) {
      HapticFeedback.mediumImpact();
    }
    _shakeController.forward(from: 0.0);

    if (pebbles.isEmpty) {
      return;
    }

    final picked = provider.pickRandomGratitudePebble(
      random: widget.random,
      excludeEntryId: _pickedPebble?.entryId,
    );
    setState(() {
      _pickedPebble = picked;
      _pickCount += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<JournalProvider>(context);
    final pebbles = provider.getGratitudePebbles();
    final isToughTrigger = widget.triggeredByMood != null &&
        JournalProvider.isLowOrToughMood(widget.triggeredByMood!);
    final accentInk = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );
    final localeCode = l10n.isIndonesian ? 'id' : 'en';

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.sheetSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.border(context)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.scrimHandle(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (isToughTrigger)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.triggeredByMood!.emoji,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.pick(
                          'Echo Tough-Day Pebble Picker',
                          'Pemilih Kerikil Syukur Echo',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentInk,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                l10n.pick(
                  'Echo’s Gratitude Jar',
                  'Toples Syukur Echo',
                ),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isToughTrigger
                    ? l10n.pick(
                        'Having a heavy moment? Tap the jar to shake loose a gentle reminder of something you were grateful for.',
                        'Sedang melewati momen berat? Ketuk toples untuk menarik pengingat hangat dari rasa syukurmu dulu.',
                      )
                    : l10n.pick(
                        'Every gratitude note adds a bright pebble. Tap the jar to shake & revisit a warm memory.',
                        'Setiap catatan syukur menjadi kerikil hangat. Ketuk toples untuk mengocok & mengenangnya lagi.',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                button: true,
                label: l10n.pick(
                  'Tap to shake gratitude jar',
                  'Ketuk untuk mengocok toples syukur',
                ),
                child: GestureDetector(
                  key: const Key('echo_gratitude_jar_tap_target'),
                  onTap: () => _shakeAndPick(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.recessedSurface(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, _) {
                            return EchoGratitudeJarVisual(
                              pebbles: pebbles,
                              shakeProgress: _shakeController.value,
                              highlightedPebble: _pickedPebble,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            pebbles.isEmpty
                                ? l10n.pick(
                                    '0 pebbles collected yet',
                                    'Belum ada kerikil terkumpul',
                                  )
                                : l10n.pick(
                                    '${pebbles.length} ${pebbles.length == 1 ? 'pebble' : 'pebbles'} • Tap jar to shake',
                                    '${pebbles.length} kerikil • Ketuk toples untuk kocok',
                                  ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accentInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (pebbles.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.favorite_outline_rounded,
                        color: accentInk,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.pick(
                          'Your jar is waiting for its first pebble',
                          'Toplesmu menunggu kerikil pertamanya',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.pick(
                          'Write a Gratitude Note inside any unlocked Echo diary entry to drop a keepsake pebble here.',
                          'Tulis Catatan Syukur di entri diari Echo (non-privat) untuk menambahkan kerikil kenangan ke sini.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                          height: 1.4,
                        ),
                      ),
                      if (widget.onCreateReflection != null) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onCreateReflection!();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(
                            l10n.pick(
                              'Add Gratitude Note',
                              'Tambah Catatan Syukur',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else if (_pickedPebble == null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _shakeAndPick(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      l10n.pick(
                        'Shake & Pull a Pebble',
                        'Kocok & Ambil Kerikil',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: Container(
                    key: ValueKey('${_pickedPebble!.entryId}_$_pickCount'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _pickedPebble!.color.withValues(alpha: 0.45),
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 18,
                              decoration: BoxDecoration(
                                color: _pickedPebble!.color,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _pickedPebble!.color.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                DateFormat.yMMMd(
                                  localeCode,
                                ).format(_pickedPebble!.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.subtleFill(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_pickedPebble!.mood.emoji} ${_pickedPebble!.mood.label}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '“${_pickedPebble!.note}”',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textPrimary(context),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.pick(
                            'From: ${_pickedPebble!.entryTitle}',
                            'Dari: ${_pickedPebble!.entryTitle}',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _shakeAndPick(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.casino_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  l10n.pick(
                                    'Pick Another Pebble',
                                    'Ambil Kerikil Lain',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.onOpenEntry != null) ...[
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  final pebble = _pickedPebble!;
                                  Navigator.of(context).pop();
                                  widget.onOpenEntry!(pebble);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  l10n.pick('Open', 'Buka'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
