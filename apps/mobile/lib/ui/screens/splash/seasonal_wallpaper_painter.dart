import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'seasonal_loading_theme.dart';

/// Deterministic atmospheric wallpaper painter for Phase 2 of [SplashScreen].
class SeasonalWallpaperPainter extends CustomPainter {
  final SeasonalSplashTheme theme;
  final double progress;
  final bool isDark;
  final Color accentColor;
  final Color secondaryAccentColor;

  const SeasonalWallpaperPainter({
    required this.theme,
    required this.progress,
    required this.isDark,
    required this.accentColor,
    required this.secondaryAccentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (theme) {
      case SeasonalSplashTheme.everydaySunnyPicnic:
        _paintEverydaySunnyPicnic(canvas, size);
      case SeasonalSplashTheme.everydayTreehouse:
        _paintEverydayTreehouse(canvas, size);
      case SeasonalSplashTheme.everydayFireplace:
        _paintEverydayFireplace(canvas, size);
      case SeasonalSplashTheme.everydayStarlight:
        _paintEverydayStarlight(canvas, size);
      case SeasonalSplashTheme.christmas:
        _paintChristmas(canvas, size);
      case SeasonalSplashTheme.newYear:
        _paintNewYear(canvas, size);
      case SeasonalSplashTheme.lunarLantern:
        _paintLunarLantern(canvas, size);
      case SeasonalSplashTheme.friendshipLetters:
        _paintFriendshipLetters(canvas, size);
      case SeasonalSplashTheme.eidLantern:
        _paintEidLantern(canvas, size);
      case SeasonalSplashTheme.springBloom:
        _paintSpringBloom(canvas, size);
      case SeasonalSplashTheme.earthDay:
        _paintEarthDay(canvas, size);
      case SeasonalSplashTheme.summerSun:
        _paintSummerSun(canvas, size);
      case SeasonalSplashTheme.midsummerKite:
        _paintMidsummerKite(canvas, size);
      case SeasonalSplashTheme.midAutumn:
        _paintMidAutumn(canvas, size);
      case SeasonalSplashTheme.autumnHarvest:
        _paintAutumnHarvest(canvas, size);
      case SeasonalSplashTheme.halloween:
        _paintHalloween(canvas, size);
      case SeasonalSplashTheme.cozyLantern:
        _paintCozyLantern(canvas, size);
      case SeasonalSplashTheme.gratitudeHarvest:
        _paintGratitudeHarvest(canvas, size);
    }
  }

  void _paintChristmas(Canvas canvas, Size size) {
    // Soft rolling snowy hills at bottom
    final hillPaint = Paint()
      ..color = (isDark ? Colors.white : accentColor).withValues(
        alpha: isDark ? 0.06 : 0.08,
      );
    final hillPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.84)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.77,
        size.width * 0.62,
        size.height * 0.83,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.87,
        size.width,
        size.height * 0.80,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    // Subtle pine silhouettes on bottom corners
    final pinePaint = Paint()
      ..color = (isDark ? const Color(0xFF2B6F56) : const Color(0xFF1F6E52))
          .withValues(alpha: isDark ? 0.24 : 0.14);
    _drawPineTree(canvas, Offset(size.width * 0.12, size.height * 0.86), 54, pinePaint);
    _drawPineTree(canvas, Offset(size.width * 0.22, size.height * 0.88), 38, pinePaint);
    _drawPineTree(canvas, Offset(size.width * 0.86, size.height * 0.85), 60, pinePaint);

    // Gentle falling snowflakes & warm holiday bokeh
    for (var i = 0; i < 24; i++) {
      final seed = i * 1.37;
      final x = ((math.sin(seed * 3.1) * 0.5 + 0.5) * size.width) +
          math.sin(progress * math.pi * 2 + seed) * 10;
      final baseY = ((i * 0.093) + progress * (0.25 + (i % 3) * 0.08)) % 1.0;
      final y = baseY * size.height;
      final radius = 1.6 + (i % 4) * 0.9;
      final isWarmLight = i % 5 == 0;
      final paint = Paint()
        ..color = (isWarmLight
                ? secondaryAccentColor
                : (isDark ? Colors.white : accentColor))
            .withValues(alpha: isWarmLight ? 0.36 : (isDark ? 0.45 : 0.22));
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawPineTree(Canvas canvas, Offset base, double height, Paint paint) {
    final path = Path()
      ..moveTo(base.dx, base.dy - height)
      ..lineTo(base.dx - height * 0.36, base.dy)
      ..lineTo(base.dx + height * 0.36, base.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintNewYear(Canvas canvas, Size size) {
    // Two radial firework bursts
    _drawFireworkBurst(
      canvas,
      Offset(size.width * 0.22, size.height * 0.24),
      56 + progress * 14,
      accentColor.withValues(alpha: isDark ? 0.34 : 0.26),
      12,
    );
    _drawFireworkBurst(
      canvas,
      Offset(size.width * 0.78, size.height * 0.20),
      44 + progress * 12,
      secondaryAccentColor.withValues(alpha: isDark ? 0.32 : 0.24),
      10,
    );

    // Shimmering champagne confetti particles
    for (var i = 0; i < 22; i++) {
      final x = ((i * 0.173) % 1.0) * size.width;
      final y = (((i * 0.137) + progress * 0.30) % 1.0) * size.height;
      final color = i.isEven ? accentColor : secondaryAccentColor;
      final paint = Paint()
        ..color = color.withValues(alpha: isDark ? 0.35 : 0.28);
      canvas.drawCircle(Offset(x, y), 1.8 + (i % 3) * 0.8, paint);
    }
  }

  void _drawFireworkBurst(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    int rays,
  ) {
    final rayPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = color;

    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * math.pi * 2;
      final inner = Offset(
        center.dx + math.cos(angle) * (radius * 0.35),
        center.dy + math.sin(angle) * (radius * 0.35),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(inner, outer, rayPaint);
      canvas.drawCircle(outer, 2.2, dotPaint);
    }
  }

  void _paintLunarLantern(Canvas canvas, Size size) {
    final lanternCenters = [
      Offset(size.width * 0.18, size.height * 0.22),
      Offset(size.width * 0.80, size.height * 0.26),
      Offset(size.width * 0.50, size.height * 0.14),
    ];
    for (var i = 0; i < lanternCenters.length; i++) {
      final drift = math.sin(progress * math.pi * 2 + i) * 6;
      final c = lanternCenters[i].translate(0, drift);
      final glowPaint = Paint()
        ..color = secondaryAccentColor.withValues(alpha: isDark ? 0.18 : 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(c, 34, glowPaint);

      final bodyPaint = Paint()
        ..color = accentColor.withValues(alpha: isDark ? 0.38 : 0.28);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 28, height: 34),
        bodyPaint,
      );
    }
  }

  void _paintSpringBloom(Canvas canvas, Size size) {
    // Drifting blossom petals
    for (var i = 0; i < 20; i++) {
      final x = ((i * 0.19 + progress * 0.18) % 1.0) * size.width;
      final y = ((i * 0.14 + progress * 0.22) % 1.0) * size.height;
      final paint = Paint()
        ..color = (i.isEven ? secondaryAccentColor : accentColor)
            .withValues(alpha: isDark ? 0.28 : 0.24);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i * 0.7 + progress * 1.4);
      canvas.drawOval(const Rect.fromLTWH(-5, -2.5, 10, 5), paint);
      canvas.restore();
    }
  }

  void _paintSummerSun(Canvas canvas, Size size) {
    // Warm sun glow in upper right
    final sunCenter = Offset(size.width * 0.82, size.height * 0.18);
    final sunGlow = Paint()
      ..color = secondaryAccentColor.withValues(alpha: isDark ? 0.18 : 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(sunCenter, 72, sunGlow);

    // Gentle horizon wave
    final wavePaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.14 : 0.14);
    final wavePath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.83)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.77,
        size.width,
        size.height * 0.84,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(wavePath, wavePaint);
  }

  void _paintMidsummerKite(Canvas canvas, Size size) {
    // Golden meadow fireflies gently bobbing in the breeze
    for (var i = 0; i < 18; i++) {
      final x = ((i * 0.193 + math.sin(progress * math.pi * 2 + i) * 0.03) % 1.0) *
          size.width;
      final y = (0.35 + ((i * 0.117 + progress * 0.15) % 0.55)) * size.height;
      final glow = 0.25 + 0.20 * math.sin(progress * math.pi * 2 + i * 1.3);
      final paint = Paint()
        ..color = secondaryAccentColor.withValues(alpha: glow);
      canvas.drawCircle(Offset(x, y), 2.4 + (i % 3) * 0.7, paint);
    }
  }

  void _paintMidAutumn(Canvas canvas, Size size) {
    // Soft lantern bokeh & moonlit glints
    for (var i = 0; i < 16; i++) {
      final x = ((i * 0.181) % 1.0) * size.width;
      final y = ((i * 0.143 + progress * 0.10) % 0.72) * size.height;
      final twinkle = 0.22 + 0.16 * math.sin(progress * math.pi * 2 + i);
      final paint = Paint()
        ..color = (i.isEven ? secondaryAccentColor : accentColor)
            .withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 3.0 : 1.6, paint);
    }
  }

  void _paintHalloween(Canvas canvas, Size size) {
    // Friendly glowing fireflies & drifting autumn leaves
    for (var i = 0; i < 16; i++) {
      final x = ((i * 0.167 + math.sin(progress * math.pi * 2 + i) * 0.04) % 1.0) *
          size.width;
      final y = ((i * 0.131 + progress * 0.20) % 1.0) * size.height;
      final paint = Paint()
        ..color = (i.isEven ? secondaryAccentColor : accentColor)
            .withValues(alpha: isDark ? 0.34 : 0.24);
      canvas.drawCircle(Offset(x, y), 2.0 + (i % 3) * 0.8, paint);
    }
  }

  void _paintAutumnHarvest(Canvas canvas, Size size) {
    for (var i = 0; i < 18; i++) {
      final x = ((i * 0.21 + math.sin(progress * math.pi * 2 + i) * 0.04) % 1.0) *
          size.width;
      final y = ((i * 0.13 + progress * 0.25) % 1.0) * size.height;
      final paint = Paint()
        ..color = (i.isEven ? accentColor : secondaryAccentColor)
            .withValues(alpha: isDark ? 0.30 : 0.25);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i * 0.9 + progress * 1.2);
      canvas.drawOval(const Rect.fromLTWH(-6, -3, 12, 6), paint);
      canvas.restore();
    }
  }

  void _paintCozyLantern(Canvas canvas, Size size) {
    // Soft starry sanctuary night dots & warm glow
    for (var i = 0; i < 20; i++) {
      final x = ((i * 0.173) % 1.0) * size.width;
      final y = ((i * 0.119) % 0.65) * size.height;
      final twinkle = 0.20 + 0.18 * math.sin(progress * math.pi * 2 + i);
      final paint = Paint()
        ..color = (i % 4 == 0 ? secondaryAccentColor : Colors.white)
            .withValues(alpha: isDark ? twinkle : twinkle * 0.85);
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 2.2 : 1.3, paint);
    }
  }

  void _paintFriendshipLetters(Canvas canvas, Size size) {
    // Soft drifting rose petals & warm golden sparkles
    for (var i = 0; i < 16; i++) {
      final x = ((i * 0.18 + progress * 0.16) % 1.0) * size.width;
      final y = ((i * 0.15 + progress * 0.20) % 1.0) * size.height;
      final paint = Paint()
        ..color = (i.isEven ? accentColor : secondaryAccentColor)
            .withValues(alpha: isDark ? 0.26 : 0.22);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i * 0.6 + progress);
      canvas.drawOval(const Rect.fromLTWH(-4.5, -2.2, 9, 4.4), paint);
      canvas.restore();
    }
  }

  void _paintEidLantern(Canvas canvas, Size size) {
    // Twinkling crescent starlight & warm brass lantern bokeh
    for (var i = 0; i < 18; i++) {
      final x = ((i * 0.169) % 1.0) * size.width;
      final y = ((i * 0.131 + progress * 0.08) % 0.72) * size.height;
      final twinkle = 0.22 + 0.18 * math.sin(progress * math.pi * 2 + i);
      final paint = Paint()
        ..color = (i.isEven ? secondaryAccentColor : accentColor)
            .withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 2.8 : 1.5, paint);
    }
  }

  void _paintEarthDay(Canvas canvas, Size size) {
    // Refreshing spring rain droplets gently slanting down
    final dropPaint = Paint()
      ..color = secondaryAccentColor.withValues(alpha: isDark ? 0.28 : 0.22)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 18; i++) {
      final x = ((i * 0.173) % 1.0) * size.width;
      final y = (((i * 0.139) + progress * 0.55) % 1.0) * size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 4, y + 12), dropPaint);
    }
  }

  void _paintGratitudeHarvest(Canvas canvas, Size size) {
    // Warm golden starlight & gratitude jar embers rising softly
    for (var i = 0; i < 16; i++) {
      final x = ((i * 0.19 + math.sin(progress * math.pi * 2 + i) * 0.03) % 1.0) *
          size.width;
      final y = (1.0 - (((i * 0.12 + progress * 0.22) % 0.85))) * size.height;
      final twinkle = 0.24 + 0.18 * math.sin(progress * math.pi * 2 + i);
      final paint = Paint()
        ..color = (i.isEven ? secondaryAccentColor : accentColor)
            .withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 2.6 : 1.5, paint);
    }
  }

  void _paintEverydaySunnyPicnic(Canvas canvas, Size size) {
    // Gentle morning sunbeams & floating pollen motes
    for (var i = 0; i < 14; i++) {
      final x = ((i * 0.197 + progress * 0.12) % 1.0) * size.width;
      final y = ((i * 0.151 + math.sin(progress * math.pi * 2 + i) * 0.04) % 0.85) *
          size.height;
      final paint = Paint()
        ..color = secondaryAccentColor.withValues(alpha: isDark ? 0.28 : 0.22);
      canvas.drawCircle(Offset(x, y), 2.0 + (i % 3) * 0.7, paint);
    }
  }

  void _paintEverydayTreehouse(Canvas canvas, Size size) {
    // Warm golden lantern fireflies drifting gently around treehouse canopy
    for (var i = 0; i < 16; i++) {
      final x = ((i * 0.183 + math.sin(progress * math.pi * 2 + i) * 0.03) % 1.0) *
          size.width;
      final y = ((i * 0.137 + progress * 0.10) % 0.90) * size.height;
      final twinkle = 0.22 + 0.16 * math.sin(progress * math.pi * 2 + i);
      final paint = Paint()
        ..color = secondaryAccentColor.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 2.6 : 1.5, paint);
    }
  }

  void _paintEverydayFireplace(Canvas canvas, Size size) {
    // Soft warm hearth embers & window raindrop shimmer
    for (var i = 0; i < 14; i++) {
      final x = ((i * 0.179) % 1.0) * size.width;
      final y = (1.0 - (((i * 0.13 + progress * 0.18) % 0.85))) * size.height;
      final paint = Paint()
        ..color = secondaryAccentColor.withValues(alpha: isDark ? 0.26 : 0.20);
      canvas.drawCircle(Offset(x, y), 1.8 + (i % 3) * 0.6, paint);
    }
  }

  void _paintEverydayStarlight(Canvas canvas, Size size) {
    // Twinkling night sky stars & canopy firefly glints
    for (var i = 0; i < 18; i++) {
      final x = ((i * 0.171) % 1.0) * size.width;
      final y = ((i * 0.123) % 0.92) * size.height;
      final twinkle = 0.20 + 0.18 * math.sin(progress * math.pi * 2 + i * 1.2);
      final paint = Paint()
        ..color = secondaryAccentColor.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 2.6 : 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SeasonalWallpaperPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark;
  }
}
