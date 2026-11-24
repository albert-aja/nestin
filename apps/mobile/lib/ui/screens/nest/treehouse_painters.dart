import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

/// Complete 4-phase time-of-day cycle for the Living Animated Treehouse.
///
/// - **05:00 – 07:59 (`dawn`):** `assets/images/treehouse_dawn.jpg`
/// - **08:00 – 16:59 (`day`):** `assets/images/treehouse_day.jpg`
/// - **17:00 – 19:29 (`sunset`):** `assets/images/treehouse_sunset.jpg`
/// - **19:30 – 04:59 (`night`):** `assets/images/treehouse_night.jpg`
enum TreehouseDayPhase { dawn, day, sunset, night }

extension TreehouseDayPhaseX on TreehouseDayPhase {
  /// Resolves the exact 4-phase cycle from local wall-clock time.
  static TreehouseDayPhase resolve(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    if (minutes >= 300 && minutes < 480) return TreehouseDayPhase.dawn; // 05:00–07:59
    if (minutes >= 480 && minutes < 1020) return TreehouseDayPhase.day; // 08:00–16:59
    if (minutes >= 1020 && minutes < 1170) return TreehouseDayPhase.sunset; // 17:00–19:29
    return TreehouseDayPhase.night; // 19:30–04:59
  }

  /// Parses an optional persisted override name (`'dawn'`, `'day'`, `'sunset'`,
  /// `'night'`); returns `null` for `'auto'` or unknown values.
  static TreehouseDayPhase? fromNameOrNull(String? name) {
    if (name == null || name.isEmpty || name == 'auto') return null;
    for (final value in TreehouseDayPhase.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  String get backdropAsset => switch (this) {
        TreehouseDayPhase.dawn => 'assets/images/treehouse_dawn.jpg',
        TreehouseDayPhase.day => 'assets/images/treehouse_day.jpg',
        TreehouseDayPhase.sunset => 'assets/images/treehouse_sunset.jpg',
        TreehouseDayPhase.night => 'assets/images/treehouse_night.jpg',
      };

  String get labelKey => switch (this) {
        TreehouseDayPhase.dawn => 'treehouse_phase_dawn',
        TreehouseDayPhase.day => 'treehouse_phase_day',
        TreehouseDayPhase.sunset => 'treehouse_phase_sunset',
        TreehouseDayPhase.night => 'treehouse_phase_night',
      };

  String get shortLabelKey => switch (this) {
        TreehouseDayPhase.dawn => 'treehouse_phase_short_dawn',
        TreehouseDayPhase.day => 'treehouse_phase_short_day',
        TreehouseDayPhase.sunset => 'treehouse_phase_short_sunset',
        TreehouseDayPhase.night => 'treehouse_phase_short_night',
      };

  String get bannerTitleKey => switch (this) {
        TreehouseDayPhase.dawn => 'nest_treehouse_dawn',
        TreehouseDayPhase.day => 'nest_treehouse_day',
        TreehouseDayPhase.sunset => 'nest_treehouse_dusk',
        TreehouseDayPhase.night => 'nest_treehouse_night',
      };

  IconData get icon => switch (this) {
        TreehouseDayPhase.dawn => Icons.wb_twilight_rounded,
        TreehouseDayPhase.day => Icons.wb_sunny_rounded,
        TreehouseDayPhase.sunset => Icons.flare_rounded,
        TreehouseDayPhase.night => Icons.dark_mode_rounded,
      };

  bool get isNight => this == TreehouseDayPhase.night;
  bool get isDay => this == TreehouseDayPhase.day;
  bool get isDawn => this == TreehouseDayPhase.dawn;
  bool get isSunset => this == TreehouseDayPhase.sunset;
}

/// Curated 2-frame blink and 2-frame wing-flutter PNG sprite packs for all 6
/// birds in the Living Animated Treehouse (`AnimatedMascotSprite`).
abstract final class TreehouseMascotFrameSheets {
  static const List<String> rooBlinkFrames = [
    'assets/mascots/sprites/roo/rest.png',
    'assets/mascots/sprites/roo/quiet_day.png',
  ];
  static const List<String> rooFlutterFrames = [
    'assets/mascots/sprites/roo/morning.png',
    'assets/mascots/sprites/roo/yay.png',
  ];

  static const List<String> echoBlinkFrames = [
    'assets/mascots/sprites/echo/goodnight.png',
    'assets/mascots/sprites/echo/unwind.png',
  ];
  static const List<String> echoFlutterFrames = [
    'assets/mascots/sprites/echo/stargazing.png',
    'assets/mascots/sprites/echo/grateful.png',
  ];

  static const List<String> scoutBlinkFrames = [
    'assets/mascots/sprites/scout/ready.png',
    'assets/mascots/sprites/scout/dawn_brief.png',
  ];
  static const List<String> scoutFlutterFrames = [
    'assets/mascots/sprites/scout/express_fly.png',
    'assets/mascots/sprites/scout/all_ready_salute.png',
  ];

  static const List<String> serenBlinkFrames = [
    'assets/mascots/sprites/seren/breathe.png',
    'assets/mascots/sprites/seren/peace.png',
  ];
  static const List<String> serenFlutterFrames = [
    'assets/mascots/sprites/seren/gentle.png',
    'assets/mascots/sprites/seren/open_arms_welcome.png',
  ];

  static const List<String> pippinBlinkFrames = [
    'assets/mascots/sprites/pippin/reading.png',
    'assets/mascots/sprites/pippin/curious.png',
  ];
  static const List<String> pippinFlutterFrames = [
    'assets/mascots/sprites/pippin/book_bookmark_wing.png',
    'assets/mascots/sprites/pippin/inspired.png',
  ];

  static const List<String> twillBlinkFrames = [
    'assets/mascots/sprites/twill/noted.png',
    'assets/mascots/sprites/twill/sorted.png',
  ];
  static const List<String> twillFlutterFrames = [
    'assets/mascots/sprites/twill/checklist.png',
    'assets/mascots/sprites/twill/nest_building.png',
  ];

  static const List<List<String>> allFrameLists = [
    rooBlinkFrames,
    rooFlutterFrames,
    echoBlinkFrames,
    echoFlutterFrames,
    scoutBlinkFrames,
    scoutFlutterFrames,
    serenBlinkFrames,
    serenFlutterFrames,
    pippinBlinkFrames,
    pippinFlutterFrames,
    twillBlinkFrames,
    twillFlutterFrames,
  ];
}

/// Calibrated fractional (`0.0–1.0`) anchor geometry measured 1:1 against the
/// `1536×2752` illustrated treehouse backgrounds (`treehouse_dawn/day/sunset/night.jpg`).
abstract final class TreehouseSceneAnchors {
  static const Size artworkSize = Size(1536, 2752);

  /// Computes the exact rendered rectangle of the `1536×2752` treehouse image
  /// inside [viewport] so every fractional `(fx, fy)` overlay locks identically
  /// across phone sizes and aspect ratios.
  ///
  /// Uses full-bleed [BoxFit.cover] on portrait phones (`aspect <= 0.72`) and
  /// gracefully switches to [BoxFit.contain] on ultra-wide/landscape surfaces so
  /// no upper/lower rooms ever get clipped out of reach.
  static ({Rect rect, BoxFit fit}) resolveImageLayout(Size viewport) {
    final aspect = viewport.height > 0 ? viewport.width / viewport.height : 0.56;
    final fit = aspect <= 0.72 ? BoxFit.cover : BoxFit.contain;
    final scale = fit == BoxFit.cover
        ? math.max(
            viewport.width / artworkSize.width,
            viewport.height / artworkSize.height,
          )
        : math.min(
            viewport.width / artworkSize.width,
            viewport.height / artworkSize.height,
          );
    final drawW = artworkSize.width * scale;
    final drawH = artworkSize.height * scale;
    final left = (viewport.width - drawW) / 2;
    final top = (viewport.height - drawH) / 2;
    return (rect: Rect.fromLTWH(left, top, drawW, drawH), fit: fit);
  }

  static Offset mapPoint(Rect imageRect, double fx, double fy) {
    return Offset(
      imageRect.left + imageRect.width * fx,
      imageRect.top + imageRect.height * fy,
    );
  }

  /// Maps a fractional (`0.0–1.0`) room rectangle onto [imageRect].
  static Rect mapRect(Rect imageRect, Rect fractional) {
    return Rect.fromLTRB(
      imageRect.left + imageRect.width * fractional.left,
      imageRect.top + imageRect.height * fractional.top,
      imageRect.left + imageRect.width * fractional.right,
      imageRect.top + imageRect.height * fractional.bottom,
    );
  }

  // --- 6 Calibrated Non-Overlapping Cutaway Room Bounds (0.0–1.0) ---
  // Top Attic (Observatory): Echo
  static const Rect echoRoomBounds = Rect.fromLTRB(0.40, 0.115, 0.75, 0.265);
  // Upper-Left (Clockwork Room): Roo
  static const Rect rooRoomBounds = Rect.fromLTRB(0.11, 0.245, 0.51, 0.422);
  // Mid-Left (Open Balcony): Scout
  static const Rect scoutRoomBounds = Rect.fromLTRB(0.05, 0.435, 0.46, 0.568);
  // Mid-Right (Tea & Lavender Room): Seren
  static const Rect serenRoomBounds = Rect.fromLTRB(0.515, 0.38, 0.92, 0.572);
  // Lower-Left (Explorer Library): Pippin
  static const Rect pippinRoomBounds = Rect.fromLTRB(0.09, 0.585, 0.505, 0.782);
  // Lower-Right (Organizer Workshop): Twill
  static const Rect twillRoomBounds = Rect.fromLTRB(0.515, 0.585, 0.93, 0.778);

  // --- 6 Bird Room Floor / Balcony Bottom-Center Perches ---
  static const Offset echoPerch = Offset(0.562, 0.256);
  static const Offset rooPerch = Offset(0.326, 0.400);
  static const Offset scoutPerch = Offset(0.265, 0.528);
  static const Offset serenPerch = Offset(0.705, 0.542);
  static const Offset pippinPerch = Offset(0.308, 0.752);
  static const Offset twillPerch = Offset(0.742, 0.750);

  // --- Safe Horizontal Walk Floor Bounds (fractional X) per Room ---
  // Calibrated inside each room's open timber floor clear of furniture/walls.
  static const ({double minFx, double maxFx}) echoWalkSpan =
      (minFx: 0.500, maxFx: 0.624);
  static const ({double minFx, double maxFx}) rooWalkSpan =
      (minFx: 0.276, maxFx: 0.390);
  static const ({double minFx, double maxFx}) scoutWalkSpan =
      (minFx: 0.165, maxFx: 0.365);
  static const ({double minFx, double maxFx}) serenWalkSpan =
      (minFx: 0.638, maxFx: 0.772);
  static const ({double minFx, double maxFx}) pippinWalkSpan =
      (minFx: 0.256, maxFx: 0.366);
  static const ({double minFx, double maxFx}) twillWalkSpan =
      (minFx: 0.680, maxFx: 0.798);

  // --- Roo's Room Props (Upper-Left) ---
  static const Offset rooClockDialCenter = Offset(0.214, 0.312);
  static const double rooClockDialRadiusFraction = 0.0235;
  static const Offset rooPendulumPivot = Offset(0.214, 0.336);
  static const double rooPendulumLengthFraction = 0.039;
  static const Offset rooGearLarge = Offset(0.378, 0.296);
  static const Offset rooGearRight = Offset(0.425, 0.315);
  static const Offset rooGearSmall = Offset(0.334, 0.317);

  // --- Seren's Room Props (Mid-Right) ---
  static const Offset serenLeftCupRim = Offset(0.640, 0.503);
  static const Offset serenRightCupRim = Offset(0.770, 0.503);
  static const Offset serenLampCenter = Offset(0.705, 0.424);
  static const Offset serenLeftLavender = Offset(0.580, 0.515);
  static const Offset serenRightLavender = Offset(0.830, 0.515);

  // --- Echo's Attic Props (Top) ---
  static const List<Offset> echoSkylightCorners = [
    Offset(0.495, 0.118),
    Offset(0.545, 0.125),
    Offset(0.460, 0.180),
    Offset(0.408, 0.172),
  ];
  static const Offset echoWarmGlowCenter = Offset(0.565, 0.212);
  static const Offset echoTelescopeLens = Offset(0.642, 0.203);
  static const Offset echoTelescopeEyepiece = Offset(0.695, 0.221);

  // --- Scout's Balcony Props (Mid-Left) ---
  static const Offset scoutLanternRopeTop = Offset(0.075, 0.355);
  static const Offset scoutLanternGlass = Offset(0.075, 0.408);
  static const Offset scoutMapAnchor = Offset(0.105, 0.472);

  // --- Pippin's Explorer Library Props (Lower-Left) ---
  static const Offset pippinLampCenter = Offset(0.300, 0.625);
  static const Offset pippinMapCompass = Offset(0.410, 0.672);
  static const Offset pippinOpenBook = Offset(0.408, 0.724);

  // --- Twill's Organizer Workshop Props (Lower-Right) ---
  static const Offset twillLampCenter = Offset(0.726, 0.618);
  static const List<Offset> twillHangingKeys = [
    Offset(0.606, 0.654),
    Offset(0.632, 0.654),
    Offset(0.658, 0.654),
    Offset(0.684, 0.654),
    Offset(0.710, 0.654),
  ];
  static const List<Offset> twillHangingTools = [
    Offset(0.624, 0.690),
    Offset(0.646, 0.690),
    Offset(0.672, 0.690),
  ];

  // --- 4 Outdoor Hanging Lantern Glass Centers ---
  static const List<Offset> outdoorLanterns = [
    Offset(0.075, 0.408), // Upper-left branch above Scout's balcony
    Offset(0.920, 0.325), // Upper-right branch
    Offset(0.153, 0.835), // Lower-left under Pippin's room
    Offset(0.842, 0.835), // Lower-right under Twill's room
  ];
}

/// Paints all live interior room prop animations across ALL 6 rooms mapped
/// directly onto the treehouse artwork via [imageRect]:
/// - **Roo's Clockwork Room (Upper-Left):** High-contrast rotating antique
///   brass/gold wall gears with crisp teeth & warm highlight, real-time
///   grandfather clock hands (always painted), and swinging brass pendulum.
/// - **Echo's Attic Observatory (Top):** Twinkling stars inside the skylight +
///   subtle warm attic lantern & brass telescope lens shimmer.
/// - **Scout's Balcony (Mid-Left):** Gently swaying hanging lantern & balcony
///   map corner + weather-reactive particles (diagonal rain streaks, cool
///   breeze lines, or sunlit motes from `LocalWeatherService`).
/// - **Seren's Tea Room (Mid-Right):** Soft rising translucent sine-wave steam
///   wisps over both teacups + gentle breathing lavender & hanging lamp glow.
/// - **Pippin's Explorer Library (Lower-Left):** Floating warm dust motes in
///   the hanging Edison lamp beam + subtle pulsing lightbulb & compass glow.
/// - **Twill's Organizer Workshop (Lower-Right):** Subtle gentle sway shimmer
///   on the hanging keys/tools + warm workshop dome lamp glow.
class TreehouseRoomEffectsPainter extends CustomPainter {
  final Animation<double> animation;
  final Rect imageRect;
  final TreehouseDayPhase phase;
  final DateTime currentTime;
  final bool disableAnimations;
  final bool isSerenPlaying;
  final bool hasLoggedTodayReflection;
  final bool isRainy;
  final bool isHeavyRain;
  final bool isCoolBreeze;

  const TreehouseRoomEffectsPainter({
    required this.animation,
    required this.imageRect,
    required this.phase,
    required this.currentTime,
    required this.disableAnimations,
    required this.isSerenPlaying,
    required this.hasLoggedTodayReflection,
    required this.isRainy,
    this.isHeavyRain = false,
    this.isCoolBreeze = false,
  }) : super(repaint: animation);

  static const _softGlowBlur = MaskFilter.blur(BlurStyle.normal, 12);
  static const _steamBlur = MaskFilter.blur(BlurStyle.normal, 2.2);
  static const _lanternBlur = MaskFilter.blur(BlurStyle.normal, 9);
  static const _moteBlur = MaskFilter.blur(BlurStyle.normal, 3.2);

  static const List<({double x, double y, double size, int freq, double phase})>
      _skylightStars = [
    (x: 0.435, y: 0.165, size: 2.3, freq: 3, phase: 0.2),
    (x: 0.464, y: 0.152, size: 2.8, freq: 2, phase: 1.4),
    (x: 0.490, y: 0.138, size: 2.0, freq: 4, phase: 2.7),
    (x: 0.514, y: 0.130, size: 2.5, freq: 3, phase: 4.1),
    (x: 0.452, y: 0.145, size: 1.7, freq: 5, phase: 5.0),
    // Soft background stars in the night attic sky window
    (x: 0.556, y: 0.162, size: 2.6, freq: 2, phase: 0.9),
    (x: 0.585, y: 0.146, size: 2.0, freq: 3, phase: 2.3),
    (x: 0.618, y: 0.175, size: 2.2, freq: 4, phase: 3.8),
  ];

  // 8 warm floating dust motes inside Pippin's hanging Edison lamp cone
  static const List<
      ({
        double cx,
        double cy,
        double rx,
        double ry,
        double r,
        int fx,
        int fy,
        double phase,
      })> _pippinDustMotes = [
    (cx: 0.275, cy: 0.662, rx: 0.014, ry: 0.010, r: 1.7, fx: 1, fy: 2, phase: 0.2),
    (cx: 0.305, cy: 0.674, rx: 0.018, ry: 0.012, r: 2.1, fx: 2, fy: 1, phase: 1.3),
    (cx: 0.332, cy: 0.660, rx: 0.015, ry: 0.009, r: 1.6, fx: 1, fy: 1, phase: 2.4),
    (cx: 0.262, cy: 0.698, rx: 0.016, ry: 0.013, r: 1.9, fx: 2, fy: 1, phase: 3.5),
    (cx: 0.296, cy: 0.710, rx: 0.020, ry: 0.011, r: 2.2, fx: 1, fy: 2, phase: 4.4),
    (cx: 0.342, cy: 0.702, rx: 0.017, ry: 0.012, r: 1.8, fx: 1, fy: 2, phase: 5.1),
    (cx: 0.316, cy: 0.735, rx: 0.018, ry: 0.009, r: 1.6, fx: 2, fy: 1, phase: 0.9),
    (cx: 0.282, cy: 0.738, rx: 0.014, ry: 0.008, r: 1.5, fx: 1, fy: 1, phase: 2.9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = disableAnimations ? 0.0 : animation.value;

    _paintRooWallCogs(canvas, t);
    _paintRooGrandfatherClock(canvas, t);
    _paintEchoAttic(canvas, t);
    _paintScoutBalcony(canvas, t);
    _paintSerenSteamAndLamp(canvas, t);
    _paintPippinLibrary(canvas, t);
    _paintTwillWorkshop(canvas, t);
  }

  void _paintRooWallCogs(Canvas canvas, double t) {
    final w = imageRect.width;
    // Boosted antique brass/gold tones with crisp contour & specular highlight
    final brassFill = phase.isNight || phase.isSunset
        ? const Color(0xFFE5AE49)
        : const Color(0xFFD09434);
    final bronzeOutline = phase.isNight || phase.isSunset
        ? const Color(0xFF7B4A1B)
        : const Color(0xFF6B3E17);
    final warmHighlight = const Color(0xFFFFF4C8);
    final alpha = phase.isNight ? 0.88 : 0.86;

    // 12-tooth primary gear rotating clockwise (+1 rev per 12s), meshed with
    // 8-tooth secondary gears counter-rotating (-1.5 revs -> use 6-tooth/-2 revs
    // for exact seamless integer looping at t = 0 == 1).
    final mainAngle = disableAnimations ? 0.15 : t * 2 * math.pi;
    final subAngle = disableAnimations ? -0.30 : -t * 2 * math.pi * 2 + 0.28;

    _drawGear(
      canvas,
      center: TreehouseSceneAnchors.mapPoint(
        imageRect,
        TreehouseSceneAnchors.rooGearLarge.dx,
        TreehouseSceneAnchors.rooGearLarge.dy,
      ),
      radius: w * 0.0285,
      teeth: 12,
      rotation: mainAngle,
      brassColor: brassFill.withValues(alpha: alpha),
      outlineColor: bronzeOutline.withValues(alpha: alpha * 0.86),
      highlightColor: warmHighlight.withValues(alpha: phase.isNight ? 0.62 : 0.54),
    );
    _drawGear(
      canvas,
      center: TreehouseSceneAnchors.mapPoint(
        imageRect,
        TreehouseSceneAnchors.rooGearRight.dx,
        TreehouseSceneAnchors.rooGearRight.dy,
      ),
      radius: w * 0.0175,
      teeth: 6,
      rotation: subAngle,
      brassColor: brassFill.withValues(alpha: alpha * 0.94),
      outlineColor: bronzeOutline.withValues(alpha: alpha * 0.82),
      highlightColor: warmHighlight.withValues(alpha: phase.isNight ? 0.56 : 0.48),
    );
    _drawGear(
      canvas,
      center: TreehouseSceneAnchors.mapPoint(
        imageRect,
        TreehouseSceneAnchors.rooGearSmall.dx,
        TreehouseSceneAnchors.rooGearSmall.dy,
      ),
      radius: w * 0.0155,
      teeth: 6,
      rotation: subAngle + 0.52,
      brassColor: brassFill.withValues(alpha: alpha * 0.90),
      outlineColor: bronzeOutline.withValues(alpha: alpha * 0.78),
      highlightColor: warmHighlight.withValues(alpha: phase.isNight ? 0.52 : 0.44),
    );
  }

  void _drawGear(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required int teeth,
    required double rotation,
    required Color brassColor,
    required Color outlineColor,
    required Color highlightColor,
  }) {
    // 1. Subtle recessed wall shadow for crisp 3D contrast on tan timber wall
    canvas.save();
    canvas.translate(center.dx + 1.2, center.dy + 1.6);
    canvas.rotate(rotation);
    final shadowPaint = Paint()
      ..color = const Color(0xFF3E220E).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (radius * 0.28).clamp(1.6, 3.6);
    canvas.drawCircle(Offset.zero, radius * 0.72, shadowPaint);
    canvas.restore();

    // 2. Main antique brass/gold gear body
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final step = (2 * math.pi) / teeth;

    // Crisp dark bronze contour behind gear teeth for unmistakable readability
    final toothContourPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (radius * 0.34).clamp(2.2, 4.4)
      ..strokeCap = StrokeCap.square;
    final toothBrassPaint = Paint()
      ..color = brassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (radius * 0.22).clamp(1.4, 3.0)
      ..strokeCap = StrokeCap.square;

    for (var i = 0; i < teeth; i++) {
      final a = i * step;
      final p0 = Offset(math.cos(a) * radius * 0.70, math.sin(a) * radius * 0.70);
      final p1 = Offset(math.cos(a) * radius * 1.05, math.sin(a) * radius * 1.05);
      canvas.drawLine(p0, p1, toothContourPaint);
      canvas.drawLine(p0, p1, toothBrassPaint);
    }

    // Outer rim contour + rich brass rim + inner rim line
    canvas.drawCircle(
      Offset.zero,
      radius * 0.72,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (radius * 0.34).clamp(2.2, 4.2),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.72,
      Paint()
        ..color = brassColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (radius * 0.22).clamp(1.4, 2.9),
    );

    // 4 crisp brass interior spokes
    final spokeContour = Paint()
      ..color = outlineColor
      ..strokeWidth = (radius * 0.20).clamp(1.4, 2.5);
    final spokeBrass = Paint()
      ..color = brassColor
      ..strokeWidth = (radius * 0.12).clamp(0.9, 1.8);
    for (var s = 0; s < 4; s++) {
      final a = s * (math.pi / 2);
      final end = Offset(math.cos(a) * radius * 0.66, math.sin(a) * radius * 0.66);
      canvas.drawLine(Offset.zero, end, spokeContour);
      canvas.drawLine(Offset.zero, end, spokeBrass);
    }

    // Center hub + warm brass rivet highlight
    canvas.drawCircle(Offset.zero, radius * 0.28, Paint()..color = outlineColor);
    canvas.drawCircle(Offset.zero, radius * 0.22, Paint()..color = brassColor);
    canvas.drawCircle(
      Offset(-radius * 0.06, -radius * 0.06),
      (radius * 0.09).clamp(0.8, 1.8),
      Paint()..color = highlightColor,
    );

    canvas.restore();

    // 3. Subtle fixed top-left specular gold sheen arc across gear rim
    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.74);
    canvas.drawArc(
      arcRect,
      -math.pi * 0.85,
      math.pi * 0.55,
      false,
      Paint()
        ..color = highlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (radius * 0.09).clamp(0.8, 1.6)
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintRooGrandfatherClock(Canvas canvas, double t) {
    final w = imageRect.width;
    final h = imageRect.height;

    // 1. Matching circular clock dial with real-time hour & minute hands
    //    (Always drawn — including when reduced motion is enabled!)
    final dialCenter = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.rooClockDialCenter.dx,
      TreehouseSceneAnchors.rooClockDialCenter.dy,
    );
    final dialRadius = w * TreehouseSceneAnchors.rooClockDialRadiusFraction;

    // Crisp matching ivory dial ring & subtle ticks
    final dialBg = phase.isNight || phase.isSunset
        ? const Color(0xFFF6E7C6)
        : const Color(0xFFFAF3E3);
    canvas.drawCircle(dialCenter, dialRadius * 0.94, Paint()..color = dialBg);
    canvas.drawCircle(
      dialCenter,
      dialRadius * 0.94,
      Paint()
        ..color = const Color(0xFF6B442A).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (dialRadius * 0.10).clamp(0.8, 1.8),
    );

    final tickPaint = Paint()
      ..color = const Color(0xFF5A3B24).withValues(alpha: 0.72)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * (math.pi / 6) - math.pi / 2;
      final isCardinal = i % 3 == 0;
      tickPaint.strokeWidth = isCardinal
          ? (dialRadius * 0.10).clamp(0.9, 1.6)
          : (dialRadius * 0.06).clamp(0.6, 1.1);
      final inner = dialRadius * (isCardinal ? 0.66 : 0.76);
      final outer = dialRadius * 0.87;
      canvas.drawLine(
        dialCenter + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        dialCenter + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        tickPaint,
      );
    }

    final hourFraction =
        ((currentTime.hour % 12) + currentTime.minute / 60.0) / 12.0;
    final minuteFraction =
        (currentTime.minute + currentTime.second / 60.0) / 60.0;
    final hourAngle = hourFraction * 2 * math.pi - math.pi / 2;
    final minuteAngle = minuteFraction * 2 * math.pi - math.pi / 2;

    // Hour hand
    canvas.drawLine(
      dialCenter,
      dialCenter +
          Offset(
            math.cos(hourAngle) * dialRadius * 0.48,
            math.sin(hourAngle) * dialRadius * 0.48,
          ),
      Paint()
        ..color = const Color(0xFF3E2618)
        ..strokeWidth = (dialRadius * 0.15).clamp(1.3, 2.4)
        ..strokeCap = StrokeCap.round,
    );

    // Minute hand
    canvas.drawLine(
      dialCenter,
      dialCenter +
          Offset(
            math.cos(minuteAngle) * dialRadius * 0.72,
            math.sin(minuteAngle) * dialRadius * 0.72,
          ),
      Paint()
        ..color = const Color(0xFF5C3620)
        ..strokeWidth = (dialRadius * 0.10).clamp(1.0, 1.8)
        ..strokeCap = StrokeCap.round,
    );

    // Center brass pin
    canvas.drawCircle(
      dialCenter,
      (dialRadius * 0.11).clamp(1.0, 2.0),
      Paint()..color = const Color(0xFFD99B38),
    );

    // 2. Smoothly swinging brass pendulum below the clock dial
    final pivot = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.rooPendulumPivot.dx,
      TreehouseSceneAnchors.rooPendulumPivot.dy,
    );
    final rodLength = h * TreehouseSceneAnchors.rooPendulumLengthFraction;
    // 6 full oscillations per 12s = classic 2-second pendulum beat
    final swingAngle = disableAnimations ? 0.0 : math.sin(t * 2 * math.pi * 6) * 0.16;

    final bobCenter = pivot +
        Offset(
          math.sin(swingAngle) * rodLength,
          math.cos(swingAngle) * rodLength,
        );
    final bobRadius = (w * 0.0085).clamp(2.5, 5.5);

    canvas.drawLine(
      pivot,
      bobCenter,
      Paint()
        ..color = const Color(0xFFD4A24C).withValues(alpha: 0.90)
        ..strokeWidth = (w * 0.003).clamp(1.0, 2.0)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      bobCenter,
      bobRadius,
      Paint()..color = const Color(0xFFE6B655),
    );
    canvas.drawCircle(
      bobCenter.translate(-bobRadius * 0.25, -bobRadius * 0.25),
      bobRadius * 0.35,
      Paint()..color = const Color(0xFFFFF4C9).withValues(alpha: 0.85),
    );
  }

  void _paintSerenSteamAndLamp(Canvas canvas, double t) {
    final w = imageRect.width;
    final h = imageRect.height;

    // 1. Rising sine-wave translucent steam wisps over the two teacups
    if (!disableAnimations) {
      final leftRim = TreehouseSceneAnchors.mapPoint(
        imageRect,
        TreehouseSceneAnchors.serenLeftCupRim.dx,
        TreehouseSceneAnchors.serenLeftCupRim.dy,
      );
      final rightRim = TreehouseSceneAnchors.mapPoint(
        imageRect,
        TreehouseSceneAnchors.serenRightCupRim.dx,
        TreehouseSceneAnchors.serenRightCupRim.dy,
      );
      final riseHeight = h * 0.032;
      final swayAmp = w * 0.009;

      for (final cupIdx in [0, 1]) {
        final origin = cupIdx == 0 ? leftRim : rightRim;
        for (var wisp = 0; wisp < 2; wisp++) {
          final life = (t * 2.0 + cupIdx * 0.37 + wisp * 0.5) % 1.0;
          final alpha = math.sin(life * math.pi) * (phase.isNight ? 0.36 : 0.44);
          if (alpha <= 0.02) continue;

          final baseX = origin.dx + (wisp == 0 ? -w * 0.006 : w * 0.006);
          final startY = origin.dy - life * (riseHeight * 0.35);
          final path = Path()..moveTo(baseX, startY);

          const segments = 8;
          for (var s = 1; s <= segments; s++) {
            final frac = s / segments;
            final y = startY - frac * (riseHeight * 0.72);
            final x = baseX +
                math.sin(frac * math.pi * 2.2 + life * math.pi * 2 + wisp) *
                    swayAmp *
                    (0.5 + frac * 0.7);
            path.lineTo(x, y);
          }

          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = (w * 0.0045).clamp(1.2, 2.4)
              ..strokeCap = StrokeCap.round
              ..maskFilter = _steamBlur,
          );
        }
      }
    }

    // 2. Gentle breathing halo on Seren's hanging lamp + soft lavender pot glow
    final lampCenter = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.serenLampCenter.dx,
      TreehouseSceneAnchors.serenLampCenter.dy,
    );
    final pulse = disableAnimations
        ? 0.5
        : 0.5 - 0.5 * math.cos(t * 2 * math.pi * 2); // 6s calm breathing cycle
    final lampBaseIntensity = isSerenPlaying
        ? 1.0
        : (phase.isNight || phase.isSunset ? 0.58 : 0.34);
    final lampRadius =
        w * ((isSerenPlaying ? 0.048 : 0.036) + 0.022 * pulse * lampBaseIntensity);

    canvas.drawCircle(
      lampCenter,
      lampRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFDE68A)
                .withValues(alpha: (0.42 + 0.18 * pulse) * lampBaseIntensity),
            const Color(0xFFC4B5FD)
                .withValues(alpha: (0.24 + 0.12 * pulse) * lampBaseIntensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Rect.fromCircle(center: lampCenter, radius: lampRadius)),
    );

    // Subtle meditative breathing lavender aura around both lavender pots
    final lavenderPulse = disableAnimations
        ? 0.5
        : 0.5 - 0.5 * math.cos(t * 2 * math.pi * 2 + 1.4);
    final lavenderAlpha = (phase.isNight ? 0.24 : 0.17) *
        (0.65 + 0.35 * lavenderPulse) *
        (isSerenPlaying ? 1.35 : 1.0);
    for (final potAnchor in const [
      TreehouseSceneAnchors.serenLeftLavender,
      TreehouseSceneAnchors.serenRightLavender,
    ]) {
      final potCenter =
          TreehouseSceneAnchors.mapPoint(imageRect, potAnchor.dx, potAnchor.dy);
      final potRadius = w * (0.034 + 0.010 * lavenderPulse);
      canvas.drawCircle(
        potCenter,
        potRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFC4B5FD).withValues(alpha: lavenderAlpha),
              const Color(0xFFA78BFA).withValues(alpha: lavenderAlpha * 0.35),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: potCenter, radius: potRadius)),
      );
    }
  }

  void _paintEchoAttic(Canvas canvas, double t) {
    final w = imageRect.width;

    // 1. Twinkling stars inside Echo's skylight (bright at Night/Sunset, soft glints at Dawn/Day)
    final starIntensity = switch (phase) {
      TreehouseDayPhase.night => 1.0,
      TreehouseDayPhase.sunset => 0.72,
      TreehouseDayPhase.dawn => 0.42,
      TreehouseDayPhase.day => 0.24,
    };
    final starCount = phase.isNight ? _skylightStars.length : 5;
    for (var i = 0; i < starCount; i++) {
      final star = _skylightStars[i];
      final pos = TreehouseSceneAnchors.mapPoint(imageRect, star.x, star.y);
      final twinkle = disableAnimations
          ? 0.75
          : 0.22 +
              0.78 *
                  (0.5 +
                      0.5 *
                          math.sin(
                            t * 2 * math.pi * star.freq + star.phase,
                          ));
      final radius = (star.size * (w / 390.0)).clamp(1.2, 3.6) *
          (0.75 + 0.35 * twinkle);
      _drawFourPointStar(
        canvas,
        pos,
        radius,
        const Color(0xFFFFFBEB).withValues(alpha: twinkle * starIntensity),
      );
    }

    // 2. Subtle brass telescope lens & eyepiece shimmer
    final lensGlint = disableAnimations
        ? 0.55
        : 0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + 0.8));
    final lensPos = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.echoTelescopeLens.dx,
      TreehouseSceneAnchors.echoTelescopeLens.dy,
    );
    final eyePos = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.echoTelescopeEyepiece.dx,
      TreehouseSceneAnchors.echoTelescopeEyepiece.dy,
    );
    _drawFourPointStar(
      canvas,
      lensPos,
      (w * 0.011).clamp(2.4, 5.2) * (0.75 + 0.35 * lensGlint),
      const Color(0xFFFFF4C4).withValues(alpha: 0.42 + 0.45 * lensGlint),
    );
    canvas.drawCircle(
      eyePos,
      (w * 0.016).clamp(3.0, 7.0),
      Paint()
        ..color = const Color(0xFFFDE68A).withValues(alpha: 0.24 * lensGlint)
        ..maskFilter = _moteBlur,
    );

    // 3. Cozy warm attic lantern shimmer (boosted when today's reflection isn't logged yet)
    final center = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.echoWarmGlowCenter.dx,
      TreehouseSceneAnchors.echoWarmGlowCenter.dy,
    );
    final breathe = disableAnimations
        ? 0.5
        : 0.5 - 0.5 * math.cos(t * 2 * math.pi * 2 + 1.1);
    final unloggedBoost = hasLoggedTodayReflection ? 0.52 : 1.0;
    final radius = w * ((hasLoggedTodayReflection ? 0.064 : 0.088) + 0.018 * breathe);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFBBF24)
                .withValues(alpha: (0.28 + 0.12 * breathe) * unloggedBoost),
            const Color(0xFFFDE68A)
                .withValues(alpha: (0.12 + 0.06 * breathe) * unloggedBoost),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..maskFilter = _softGlowBlur,
    );
  }

  void _paintScoutBalcony(Canvas canvas, double t) {
    final w = imageRect.width;
    final h = imageRect.height;

    // 1. Gently swaying balcony branch lantern glow + crisp swing glint
    final ropeTop = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.scoutLanternRopeTop.dx,
      TreehouseSceneAnchors.scoutLanternRopeTop.dy,
    );
    final glassRest = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.scoutLanternGlass.dx,
      TreehouseSceneAnchors.scoutLanternGlass.dy,
    );
    final swayAmp = isRainy || isCoolBreeze ? 0.095 : 0.055;
    final swayAngle =
        disableAnimations ? 0.0 : math.sin(t * 2 * math.pi * 3 + 0.4) * swayAmp;
    final ropeLen = (glassRest - ropeTop).distance;
    final swayedCenter = ropeTop +
        Offset(math.sin(swayAngle) * ropeLen, math.cos(swayAngle) * ropeLen);

    final glowAlpha = switch (phase) {
      TreehouseDayPhase.night => 0.36,
      TreehouseDayPhase.sunset => 0.32,
      TreehouseDayPhase.dawn => 0.24,
      TreehouseDayPhase.day => isRainy ? 0.20 : 0.12,
    };

    canvas.drawCircle(
      swayedCenter,
      w * 0.044,
      Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: glowAlpha)
        ..maskFilter = _lanternBlur,
    );

    // 2. Subtle gentle flutter shimmer along Scout's balcony map stand
    final mapPos = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.scoutMapAnchor.dx,
      TreehouseSceneAnchors.scoutMapAnchor.dy,
    );
    final mapFlutter = disableAnimations
        ? 0.0
        : math.sin(t * 2 * math.pi * 3 + 1.2) * (isCoolBreeze || isRainy ? 2.6 : 1.5);
    final mapEdgePath = Path()
      ..moveTo(mapPos.dx - w * 0.032, mapPos.dy - h * 0.012)
      ..quadraticBezierTo(
        mapPos.dx + mapFlutter * 0.6,
        mapPos.dy - h * 0.016 + mapFlutter * 0.4,
        mapPos.dx + w * 0.034,
        mapPos.dy - h * 0.014 + mapFlutter,
      );
    canvas.drawPath(
      mapEdgePath,
      Paint()
        ..color = const Color(0xFFFFF8E1).withValues(alpha: phase.isNight ? 0.32 : 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (w * 0.0036).clamp(1.0, 2.0)
        ..strokeCap = StrokeCap.round,
    );

    // 3. Weather-reactive particles from LocalWeatherService outside Scout's balcony
    final balconySkyRect = Rect.fromLTRB(
      imageRect.left,
      imageRect.top + h * 0.31,
      imageRect.left + w * 0.44,
      imageRect.top + h * 0.59,
    );
    canvas.save();
    canvas.clipRect(balconySkyRect);

    if (isRainy) {
      // Diagonal rain streaks (heavier & faster in storm conditions)
      final rainPaint = Paint()
        ..color = (phase.isNight
                ? const Color(0xFFBFDBFE)
                : const Color(0xFFE0F2FE))
            .withValues(alpha: phase.isNight ? 0.36 : 0.48)
        ..strokeWidth = (w * (isHeavyRain ? 0.0038 : 0.0032)).clamp(1.0, 2.0)
        ..strokeCap = StrokeCap.round;

      final streakLen = h * (isHeavyRain ? 0.032 : 0.026);
      final slantDx = -streakLen * (isHeavyRain ? 0.34 : 0.28);
      final dropCount = isHeavyRain ? 32 : 24;
      final speedMult = isHeavyRain ? 10.0 : 8.0;

      for (var i = 0; i < dropCount; i++) {
        final seedX = ((i * 37 + 13) % 100) / 100.0;
        final seedY = ((i * 53 + 7) % 100) / 100.0;
        final fallProgress = disableAnimations
            ? seedY
            : (seedY + t * speedMult * (i.isEven ? 1.0 : 1.5)) % 1.0;

        final x = balconySkyRect.left + seedX * balconySkyRect.width;
        final y = balconySkyRect.top + fallProgress * balconySkyRect.height;

        final edgeFade = (1.0 -
            ((x - balconySkyRect.left) / balconySkyRect.width - 0.72)
                    .clamp(0.0, 0.28) /
                0.28);
        if (edgeFade <= 0.05) continue;

        rainPaint.color = rainPaint.color.withValues(
          alpha: (phase.isNight ? 0.36 : 0.48) * edgeFade,
        );
        canvas.drawLine(
          Offset(x, y),
          Offset(x + slantDx, y + streakLen),
          rainPaint,
        );
      }
    } else if (isCoolBreeze) {
      // Graceful translucent curved breeze ribbons drifting across Scout's balcony
      const breezeCount = 5;
      for (var i = 0; i < breezeCount; i++) {
        final progress = disableAnimations ? (i * 0.2) : (t * 2.0 + i * 0.23) % 1.0;
        final alpha = math.sin(progress * math.pi) * (phase.isNight ? 0.26 : 0.38);
        if (alpha <= 0.03) continue;

        final startX = balconySkyRect.left + (progress - 0.15) * balconySkyRect.width * 0.92;
        final baseY = balconySkyRect.top + balconySkyRect.height * (0.20 + i * 0.15);
        final segLen = balconySkyRect.width * (0.24 + (i % 2) * 0.08);
        final waveAmp = h * 0.008;

        final path = Path()
          ..moveTo(startX, baseY)
          ..cubicTo(
            startX + segLen * 0.33,
            baseY - waveAmp,
            startX + segLen * 0.66,
            baseY + waveAmp,
            startX + segLen,
            baseY - waveAmp * 0.4,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = (phase.isNight
                    ? const Color(0xFFBAE6FD)
                    : Colors.white)
                .withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (w * 0.0034).clamp(1.0, 1.8)
            ..strokeCap = StrokeCap.round,
        );
      }
    } else {
      // Clear/Warm skies: soft drifting golden sunlit balcony motes
      const moteCount = 8;
      for (var i = 0; i < moteCount; i++) {
        final seedX = ((i * 29 + 11) % 85) / 100.0;
        final seedY = ((i * 41 + 19) % 80) / 100.0;
        final driftX = disableAnimations
            ? 0.0
            : math.sin(t * 2 * math.pi + i * 1.1) * w * 0.015;
        final driftY = disableAnimations
            ? 0.0
            : math.cos(t * 2 * math.pi + i * 1.6) * h * 0.010;
        final shimmer = disableAnimations
            ? 0.34
            : 0.16 + 0.42 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + i * 0.9));

        final pos = Offset(
          balconySkyRect.left + seedX * balconySkyRect.width + driftX,
          balconySkyRect.top + seedY * balconySkyRect.height + driftY,
        );
        final r = (1.6 + (i % 3) * 0.5) * (w / 390.0);
        canvas.drawCircle(
          pos,
          r * 2.1,
          Paint()
            ..color = const Color(0xFFFFF3C4).withValues(alpha: shimmer * 0.42)
            ..maskFilter = _moteBlur,
        );
        canvas.drawCircle(
          pos,
          r,
          Paint()..color = const Color(0xFFFFFBEB).withValues(alpha: shimmer),
        );
      }
    }

    canvas.restore();
  }

  void _paintPippinLibrary(Canvas canvas, double t) {
    final w = imageRect.width;
    final h = imageRect.height;

    final bulbCenter = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.pippinLampCenter.dx,
      TreehouseSceneAnchors.pippinLampCenter.dy,
    );
    final pulse = disableAnimations
        ? 0.5
        : 0.5 - 0.5 * math.cos(t * 2 * math.pi * 2 + 0.7);
    final intensity = switch (phase) {
      TreehouseDayPhase.night => 1.0,
      TreehouseDayPhase.sunset => 0.85,
      TreehouseDayPhase.dawn => 0.65,
      TreehouseDayPhase.day => 0.48,
    };

    // 1. Subtle pulsing Edison lightbulb halo
    final bulbRadius = w * (0.036 + 0.012 * pulse);
    canvas.drawCircle(
      bulbCenter,
      bulbRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFEF08A).withValues(alpha: (0.44 + 0.16 * pulse) * intensity),
            const Color(0xFFF59E0B).withValues(alpha: (0.16 + 0.08 * pulse) * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(Rect.fromCircle(center: bulbCenter, radius: bulbRadius)),
    );

    // 2. Soft warm conical hanging lamp beam illuminating the reading rug
    final beamBottomY = imageRect.top + h * 0.752;
    final beamPath = Path()
      ..moveTo(bulbCenter.dx - w * 0.012, bulbCenter.dy + h * 0.004)
      ..lineTo(bulbCenter.dx + w * 0.012, bulbCenter.dy + h * 0.004)
      ..lineTo(bulbCenter.dx + w * 0.105, beamBottomY)
      ..lineTo(bulbCenter.dx - w * 0.095, beamBottomY)
      ..close();
    canvas.drawPath(
      beamPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFDE68A).withValues(alpha: (0.18 + 0.05 * pulse) * intensity),
            const Color(0xFFFDE68A).withValues(alpha: 0.06 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(
          Rect.fromLTRB(
            bulbCenter.dx - w * 0.11,
            bulbCenter.dy,
            bulbCenter.dx + w * 0.11,
            beamBottomY,
          ),
        ),
    );

    // 3. Floating warm dust motes drifting lazily inside the lamp beam
    for (final mote in _pippinDustMotes) {
      final dx = disableAnimations
          ? 0.0
          : math.sin(t * 2 * math.pi * mote.fx + mote.phase) * w * mote.rx;
      final dy = disableAnimations
          ? 0.0
          : math.cos(t * 2 * math.pi * mote.fy + mote.phase * 1.2) * h * mote.ry;
      final shimmer = disableAnimations
          ? 0.45
          : 0.22 +
              0.68 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + mote.phase));
      final pos = TreehouseSceneAnchors.mapPoint(imageRect, mote.cx, mote.cy) +
          Offset(dx, dy);
      final r = (mote.r * (w / 390.0)).clamp(1.1, 2.8);

      canvas.drawCircle(
        pos,
        r * 2.0,
        Paint()
          ..color = const Color(0xFFFDE68A)
              .withValues(alpha: shimmer * 0.36 * (0.55 + 0.45 * intensity))
          ..maskFilter = _moteBlur,
      );
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = const Color(0xFFFFFBEB)
              .withValues(alpha: shimmer * (0.65 + 0.35 * intensity)),
      );
    }

    // 4. Subtle pulsing compass / explorer map glint
    final compassPulse = disableAnimations
        ? 0.5
        : 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + 2.5));
    final mapPos = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.pippinMapCompass.dx,
      TreehouseSceneAnchors.pippinMapCompass.dy,
    );
    _drawFourPointStar(
      canvas,
      mapPos,
      (w * 0.010).clamp(2.2, 4.6) * (0.75 + 0.30 * compassPulse),
      const Color(0xFF6EE7B7).withValues(alpha: 0.36 + 0.42 * compassPulse),
    );
    final bookPos = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.pippinOpenBook.dx,
      TreehouseSceneAnchors.pippinOpenBook.dy,
    );
    canvas.drawCircle(
      bookPos,
      w * 0.026,
      Paint()
        ..color = const Color(0xFFFDE68A)
            .withValues(alpha: (0.14 + 0.08 * compassPulse) * intensity)
        ..maskFilter = _moteBlur,
    );
  }

  void _paintTwillWorkshop(Canvas canvas, double t) {
    final w = imageRect.width;
    final h = imageRect.height;

    // 1. Warm pulsing workshop dome lamp glow + subtle workbench cone
    final lampCenter = TreehouseSceneAnchors.mapPoint(
      imageRect,
      TreehouseSceneAnchors.twillLampCenter.dx,
      TreehouseSceneAnchors.twillLampCenter.dy,
    );
    final pulse = disableAnimations
        ? 0.5
        : 0.5 - 0.5 * math.cos(t * 2 * math.pi * 2 + 2.1);
    final intensity = switch (phase) {
      TreehouseDayPhase.night => 1.0,
      TreehouseDayPhase.sunset => 0.85,
      TreehouseDayPhase.dawn => 0.65,
      TreehouseDayPhase.day => 0.46,
    };

    final lampRadius = w * (0.044 + 0.014 * pulse);
    canvas.drawCircle(
      lampCenter,
      lampRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFEF3C7).withValues(alpha: (0.46 + 0.16 * pulse) * intensity),
            const Color(0xFFF59E0B).withValues(alpha: (0.18 + 0.08 * pulse) * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Rect.fromCircle(center: lampCenter, radius: lampRadius)),
    );

    final benchBottomY = imageRect.top + h * 0.742;
    final conePath = Path()
      ..moveTo(lampCenter.dx - w * 0.030, lampCenter.dy + h * 0.006)
      ..lineTo(lampCenter.dx + w * 0.030, lampCenter.dy + h * 0.006)
      ..lineTo(lampCenter.dx + w * 0.145, benchBottomY)
      ..lineTo(lampCenter.dx - w * 0.145, benchBottomY)
      ..close();
    canvas.drawPath(
      conePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFEF3C7).withValues(alpha: (0.14 + 0.04 * pulse) * intensity),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromLTRB(
            lampCenter.dx - w * 0.15,
            lampCenter.dy,
            lampCenter.dx + w * 0.15,
            benchBottomY,
          ),
        ),
    );

    // 2. Subtle gentle staggered sway highlights on the 5 hanging keys & tools
    final keyLen = h * 0.022;
    for (var i = 0; i < TreehouseSceneAnchors.twillHangingKeys.length; i++) {
      final peg = TreehouseSceneAnchors.mapPoint(
        imageRect,
        TreehouseSceneAnchors.twillHangingKeys[i].dx,
        TreehouseSceneAnchors.twillHangingKeys[i].dy,
      );
      final sway = disableAnimations
          ? 0.0
          : math.sin(t * 2 * math.pi * 2 + i * 0.85) * 0.085;
      final tip = peg + Offset(math.sin(sway) * keyLen, math.cos(sway) * keyLen);
      final glint = disableAnimations
          ? 0.45
          : 0.30 + 0.55 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 3 + i * 1.3));

      canvas.drawLine(
        peg,
        tip,
        Paint()
          ..color = const Color(0xFFFFF8DC).withValues(alpha: 0.34 + 0.24 * glint)
          ..strokeWidth = (w * 0.0042).clamp(1.2, 2.2)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        tip,
        (w * 0.0048).clamp(1.3, 2.4),
        Paint()
          ..color = const Color(0xFFFDE68A).withValues(alpha: 0.48 + 0.32 * glint),
      );
    }

    final toolLen = h * 0.015;
    for (var i = 0; i < TreehouseSceneAnchors.twillHangingTools.length; i++) {
      final peg = TreehouseSceneAnchors.mapPoint(
        imageRect,
        TreehouseSceneAnchors.twillHangingTools[i].dx,
        TreehouseSceneAnchors.twillHangingTools[i].dy,
      );
      final sway = disableAnimations
          ? 0.0
          : math.sin(t * 2 * math.pi * 2 + i * 1.15 + 1.8) * 0.075;
      final tip =
          peg + Offset(math.sin(sway) * toolLen, math.cos(sway) * toolLen);
      canvas.drawLine(
        peg,
        tip,
        Paint()
          ..color = const Color(0xFFFFF8DC).withValues(alpha: 0.40)
          ..strokeWidth = (w * 0.0036).clamp(1.0, 1.9)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawFourPointStar(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TreehouseRoomEffectsPainter oldDelegate) {
    return oldDelegate.imageRect != imageRect ||
        oldDelegate.phase != phase ||
        oldDelegate.currentTime.minute != currentTime.minute ||
        oldDelegate.currentTime.hour != currentTime.hour ||
        oldDelegate.disableAnimations != disableAnimations ||
        oldDelegate.isSerenPlaying != isSerenPlaying ||
        oldDelegate.hasLoggedTodayReflection != hasLoggedTodayReflection ||
        oldDelegate.isRainy != isRainy ||
        oldDelegate.isHeavyRain != isHeavyRain ||
        oldDelegate.isCoolBreeze != isCoolBreeze;
  }
}

/// Paints the phase-aware outdoor atmospheric effects mapped onto [imageRect]:
/// - **Dawn (`05:00–07:59`):** Soft drifting morning mist + fading warm glow on
///   all 4 hanging lanterns.
/// - **Day (`08:00–16:59`):** 4 fluttering butterflies along curved Bézier paths
///   with animated flapping wings + drifting sunlit motes + subtle cloud drift.
/// - **Sunset (`17:00–19:29`):** Warm pulsing glow on the 4 hanging lanterns +
///   first 4 softly drifting fireflies.
/// - **Night (`19:30–04:59`):** Twinkling sky stars + pulsing warm glow on the
///   4 hanging lanterns + 10 glowing fireflies curving around lower branches/trunk.
class TreehouseAtmospherePainter extends CustomPainter {
  final Animation<double> animation;
  final Rect imageRect;
  final TreehouseDayPhase phase;
  final bool disableAnimations;

  const TreehouseAtmospherePainter({
    required this.animation,
    required this.imageRect,
    required this.phase,
    required this.disableAnimations,
  }) : super(repaint: animation);

  static const _mistBlur = MaskFilter.blur(BlurStyle.normal, 18);
  static const _cloudBlur = MaskFilter.blur(BlurStyle.normal, 8);
  static const _fireflyHaloBlur = MaskFilter.blur(BlurStyle.normal, 5);

  static const List<({double x, double y, double r, int freq, double phase})>
      _nightSkyStars = [
    (x: 0.05, y: 0.21, r: 2.0, freq: 3, phase: 0.1),
    (x: 0.11, y: 0.24, r: 1.5, freq: 4, phase: 1.3),
    (x: 0.18, y: 0.19, r: 1.9, freq: 2, phase: 2.5),
    (x: 0.04, y: 0.44, r: 1.7, freq: 3, phase: 3.1),
    (x: 0.09, y: 0.56, r: 1.5, freq: 5, phase: 0.7),
    (x: 0.04, y: 0.64, r: 1.8, freq: 2, phase: 4.4),
    (x: 0.83, y: 0.25, r: 2.1, freq: 3, phase: 1.9),
    (x: 0.90, y: 0.27, r: 1.6, freq: 4, phase: 3.6),
    (x: 0.96, y: 0.35, r: 2.0, freq: 2, phase: 5.1),
    (x: 0.86, y: 0.40, r: 1.5, freq: 3, phase: 2.2),
    (x: 0.94, y: 0.45, r: 1.8, freq: 4, phase: 0.6),
    (x: 0.91, y: 0.54, r: 1.6, freq: 2, phase: 3.9),
    (x: 0.81, y: 0.32, r: 1.5, freq: 5, phase: 4.8),
    (x: 0.97, y: 0.65, r: 1.7, freq: 3, phase: 1.1),
  ];

  // 10 firefly orbits concentrated around lower branches, pine edge & trunk
  static const List<
      ({
        double cx,
        double cy,
        double rx,
        double ry,
        int fx,
        int fy,
        double phase,
        int glowFreq,
      })> _fireflies = [
    (cx: 0.12, cy: 0.86, rx: 0.055, ry: 0.028, fx: 1, fy: 2, phase: 0.2, glowFreq: 3),
    (cx: 0.25, cy: 0.82, rx: 0.060, ry: 0.025, fx: 2, fy: 1, phase: 1.1, glowFreq: 2),
    (cx: 0.40, cy: 0.88, rx: 0.070, ry: 0.032, fx: 1, fy: 2, phase: 2.4, glowFreq: 4),
    (cx: 0.56, cy: 0.84, rx: 0.065, ry: 0.028, fx: 2, fy: 1, phase: 3.5, glowFreq: 3),
    (cx: 0.72, cy: 0.87, rx: 0.058, ry: 0.030, fx: 1, fy: 2, phase: 4.7, glowFreq: 2),
    (cx: 0.88, cy: 0.84, rx: 0.052, ry: 0.026, fx: 1, fy: 1, phase: 5.3, glowFreq: 3),
    (cx: 0.31, cy: 0.93, rx: 0.055, ry: 0.022, fx: 2, fy: 1, phase: 0.9, glowFreq: 4),
    (cx: 0.64, cy: 0.92, rx: 0.060, ry: 0.024, fx: 1, fy: 2, phase: 2.9, glowFreq: 2),
    (cx: 0.08, cy: 0.72, rx: 0.042, ry: 0.026, fx: 1, fy: 2, phase: 1.8, glowFreq: 3),
    (cx: 0.92, cy: 0.69, rx: 0.045, ry: 0.028, fx: 2, fy: 1, phase: 4.0, glowFreq: 3),
  ];

  // 4 gentle daytime butterflies along closed cubic Bézier flight paths
  static const List<
      ({
        Offset p0,
        Offset p1,
        Offset p2,
        Offset p3,
        Color color,
        double phase,
        double scale,
      })> _butterflies = [
    (
      p0: Offset(0.07, 0.45),
      p1: Offset(0.18, 0.38),
      p2: Offset(0.24, 0.47),
      p3: Offset(0.12, 0.54),
      color: Color(0xFFFBBF24),
      phase: 0.0,
      scale: 1.0,
    ),
    (
      p0: Offset(0.84, 0.37),
      p1: Offset(0.95, 0.32),
      p2: Offset(0.94, 0.45),
      p3: Offset(0.82, 0.44),
      color: Color(0xFF60A5FA),
      phase: 0.28,
      scale: 0.92,
    ),
    (
      p0: Offset(0.16, 0.84),
      p1: Offset(0.32, 0.78),
      p2: Offset(0.36, 0.90),
      p3: Offset(0.20, 0.92),
      color: Color(0xFFFB7185),
      phase: 0.56,
      scale: 0.95,
    ),
    (
      p0: Offset(0.72, 0.83),
      p1: Offset(0.88, 0.79),
      p2: Offset(0.90, 0.91),
      p3: Offset(0.74, 0.92),
      color: Color(0xFFC084FC),
      phase: 0.81,
      scale: 0.88,
    ),
  ];

  static const List<({double x, double y, double r, double phase})>
      _sunlightMotes = [
    (x: 0.14, y: 0.14, r: 2.6, phase: 0.1),
    (x: 0.28, y: 0.11, r: 3.1, phase: 1.2),
    (x: 0.36, y: 0.18, r: 2.2, phase: 2.4),
    (x: 0.09, y: 0.29, r: 2.4, phase: 3.1),
    (x: 0.85, y: 0.22, r: 2.8, phase: 0.7),
    (x: 0.92, y: 0.38, r: 2.3, phase: 4.0),
    (x: 0.18, y: 0.57, r: 2.5, phase: 1.9),
    (x: 0.88, y: 0.58, r: 2.4, phase: 5.2),
    (x: 0.22, y: 0.82, r: 2.7, phase: 2.8),
    (x: 0.52, y: 0.86, r: 2.2, phase: 3.7),
    (x: 0.78, y: 0.84, r: 2.6, phase: 0.5),
    (x: 0.42, y: 0.79, r: 2.0, phase: 4.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = disableAnimations ? 0.0 : animation.value;

    switch (phase) {
      case TreehouseDayPhase.dawn:
        _paintMorningMist(canvas, t);
        _paintOutdoorLanternGlows(canvas, t, baseIntensity: 0.26);
      case TreehouseDayPhase.day:
        _paintDayClouds(canvas, t);
        _paintSunlightMotes(canvas, t);
        _paintButterflies(canvas, t);
      case TreehouseDayPhase.sunset:
        _paintOutdoorLanternGlows(canvas, t, baseIntensity: 0.44);
        _paintFireflies(canvas, t, count: 4);
      case TreehouseDayPhase.night:
        _paintNightSkyStars(canvas, t);
        _paintOutdoorLanternGlows(canvas, t, baseIntensity: 0.56);
        _paintFireflies(canvas, t, count: _fireflies.length);
    }
  }

  void _paintMorningMist(Canvas canvas, double t) {
    final w = imageRect.width;
    final h = imageRect.height;

    final mistBands = [
      (y: 0.81, amp: 0.05, alpha: 0.16, height: 0.065, phase: 0.0),
      (y: 0.88, amp: -0.06, alpha: 0.20, height: 0.075, phase: 2.1),
      (y: 0.94, amp: 0.04, alpha: 0.18, height: 0.060, phase: 4.2),
    ];

    for (final band in mistBands) {
      final dx = disableAnimations
          ? 0.0
          : math.sin(t * 2 * math.pi + band.phase) * w * band.amp;
      final rect = Rect.fromCenter(
        center: Offset(
          imageRect.left + w * 0.50 + dx,
          imageRect.top + h * band.y,
        ),
        width: w * 1.18,
        height: h * band.height,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = const Color(0xFFFFF1E6).withValues(alpha: band.alpha)
          ..maskFilter = _mistBlur,
      );
    }
  }

  void _paintDayClouds(Canvas canvas, double t) {
    final w = imageRect.width;
    final h = imageRect.height;
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..maskFilter = _cloudBlur;

    // Gentle cloud drift across upper/side visible sky pockets
    final driftA = disableAnimations ? 0.0 : math.sin(t * 2 * math.pi) * w * 0.045;
    final driftB = disableAnimations
        ? 0.0
        : math.cos(t * 2 * math.pi + 1.0) * w * 0.040;

    _drawCloudWisp(
      canvas,
      Offset(imageRect.left + w * 0.14 + driftA, imageRect.top + h * 0.22),
      w * 0.055,
      cloudPaint,
    );
    _drawCloudWisp(
      canvas,
      Offset(imageRect.left + w * 0.90 + driftB, imageRect.top + h * 0.36),
      w * 0.065,
      cloudPaint,
    );
    _drawCloudWisp(
      canvas,
      Offset(imageRect.left + w * 0.07 - driftB * 0.8, imageRect.top + h * 0.45),
      w * 0.048,
      cloudPaint,
    );
  }

  void _drawCloudWisp(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2.5, height: r * 0.92),
      paint,
    );
    canvas.drawCircle(c.translate(-r * 0.45, -r * 0.18), r * 0.52, paint);
    canvas.drawCircle(c.translate(r * 0.38, -r * 0.14), r * 0.44, paint);
  }

  void _paintSunlightMotes(Canvas canvas, double t) {
    final w = imageRect.width;
    final h = imageRect.height;

    for (final mote in _sunlightMotes) {
      final dx = disableAnimations
          ? 0.0
          : math.sin(t * 2 * math.pi + mote.phase) * w * 0.018;
      final dy = disableAnimations
          ? 0.0
          : math.cos(t * 2 * math.pi + mote.phase * 1.4) * h * 0.012;
      final shimmer = disableAnimations
          ? 0.35
          : 0.14 +
              0.42 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + mote.phase));
      final pos = TreehouseSceneAnchors.mapPoint(imageRect, mote.x, mote.y) +
          Offset(dx, dy);
      final radius = (mote.r * (w / 390.0)).clamp(1.5, 4.0);

      canvas.drawCircle(
        pos,
        radius * 2.2,
        Paint()
          ..color = const Color(0xFFFFF3C4).withValues(alpha: shimmer * 0.45)
          ..maskFilter = _fireflyHaloBlur,
      );
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = const Color(0xFFFFFBEB).withValues(alpha: shimmer),
      );
    }
  }

  void _paintButterflies(Canvas canvas, double t) {
    final w = imageRect.width;

    for (final b in _butterflies) {
      // Smooth closed figure-loop along cubic Bézier segments (out & return)
      final u = (t + b.phase) % 1.0;
      final pos = _evalClosedButterflyLoop(b, u);
      final nextPos = _evalClosedButterflyLoop(b, (u + 0.008) % 1.0);
      final heading = math.atan2(nextPos.dy - pos.dy, nextPos.dx - pos.dx);

      // Animated wing flapping (18 flaps per 12s = lively natural flutter)
      final flap = disableAnimations
          ? 0.85
          : 0.25 + 0.75 * math.sin(t * 2 * math.pi * 18 + b.phase * 12).abs();
      final wingSpan = (w * 0.017 * b.scale).clamp(4.5, 9.0);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(heading + math.pi / 2);

      final wingPaint = Paint()..color = b.color.withValues(alpha: 0.88);
      final accentPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);

      // Left & right upper/lower wings scaled horizontally by flap factor
      final rx = wingSpan * flap;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-rx * 0.55, -wingSpan * 0.18),
          width: rx,
          height: wingSpan * 0.72,
        ),
        wingPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rx * 0.55, -wingSpan * 0.18),
          width: rx,
          height: wingSpan * 0.72,
        ),
        wingPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-rx * 0.42, wingSpan * 0.26),
          width: rx * 0.76,
          height: wingSpan * 0.52,
        ),
        wingPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rx * 0.42, wingSpan * 0.26),
          width: rx * 0.76,
          height: wingSpan * 0.52,
        ),
        wingPaint,
      );

      // Tiny wing highlight & slender dark body
      canvas.drawCircle(
        Offset(-rx * 0.45, -wingSpan * 0.20),
        (wingSpan * 0.14).clamp(0.7, 1.5),
        accentPaint,
      );
      canvas.drawCircle(
        Offset(rx * 0.45, -wingSpan * 0.20),
        (wingSpan * 0.14).clamp(0.7, 1.5),
        accentPaint,
      );
      canvas.drawLine(
        Offset(0, -wingSpan * 0.35),
        Offset(0, wingSpan * 0.40),
        Paint()
          ..color = const Color(0xFF3E2723).withValues(alpha: 0.85)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );

      canvas.restore();
    }
  }

  Offset _evalClosedButterflyLoop(
    ({
      Offset p0,
      Offset p1,
      Offset p2,
      Offset p3,
      Color color,
      double phase,
      double scale,
    }) b,
    double u,
  ) {
    // 2 smooth cubic Bézier arcs forming a seamless closed loop (u in 0..1)
    final p0 = TreehouseSceneAnchors.mapPoint(imageRect, b.p0.dx, b.p0.dy);
    final p1 = TreehouseSceneAnchors.mapPoint(imageRect, b.p1.dx, b.p1.dy);
    final p2 = TreehouseSceneAnchors.mapPoint(imageRect, b.p2.dx, b.p2.dy);
    final p3 = TreehouseSceneAnchors.mapPoint(imageRect, b.p3.dx, b.p3.dy);

    if (u < 0.5) {
      final s = u * 2.0;
      return _cubicBezier(p0, p1, p2, p3, s);
    } else {
      final s = (u - 0.5) * 2.0;
      // Mirror return control points for a figure-eight / gentle oval return
      final c1 = Offset(p3.dx - (p2.dx - p3.dx) * 0.6, p3.dy + 12);
      final c2 = Offset(p0.dx - (p1.dx - p0.dx) * 0.6, p0.dy + 10);
      return _cubicBezier(p3, c1, c2, p0, s);
    }
  }

  Offset _cubicBezier(Offset a, Offset b, Offset c, Offset d, double t) {
    final mt = 1.0 - t;
    final mt2 = mt * mt;
    final t2 = t * t;
    return Offset(
      mt2 * mt * a.dx + 3 * mt2 * t * b.dx + 3 * mt * t2 * c.dx + t2 * t * d.dx,
      mt2 * mt * a.dy + 3 * mt2 * t * b.dy + 3 * mt * t2 * c.dy + t2 * t * d.dy,
    );
  }

  void _paintNightSkyStars(Canvas canvas, double t) {
    final w = imageRect.width;
    for (final star in _nightSkyStars) {
      final pos = TreehouseSceneAnchors.mapPoint(imageRect, star.x, star.y);
      final twinkle = disableAnimations
          ? 0.70
          : 0.18 +
              0.82 *
                  (0.5 +
                      0.5 * math.sin(t * 2 * math.pi * star.freq + star.phase));
      final r = (star.r * (w / 390.0)).clamp(1.0, 2.8) * (0.75 + 0.35 * twinkle);
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = const Color(0xFFFFFBEB).withValues(alpha: twinkle),
      );
    }
  }

  void _paintOutdoorLanternGlows(
    Canvas canvas,
    double t, {
    required double baseIntensity,
  }) {
    final w = imageRect.width;
    for (var i = 0; i < TreehouseSceneAnchors.outdoorLanterns.length; i++) {
      final anchor = TreehouseSceneAnchors.outdoorLanterns[i];
      final center =
          TreehouseSceneAnchors.mapPoint(imageRect, anchor.dx, anchor.dy);
      final pulse = disableAnimations
          ? 0.5
          : 0.5 + 0.5 * math.sin(t * 2 * math.pi * 3 + i * 1.55);
      final radius = w * (0.048 + 0.016 * pulse);
      final alpha = (baseIntensity * (0.78 + 0.34 * pulse)).clamp(0.0, 0.78);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFEF08A).withValues(alpha: alpha),
              const Color(0xFFF59E0B).withValues(alpha: alpha * 0.42),
              Colors.transparent,
            ],
            stops: const [0.0, 0.48, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  void _paintFireflies(Canvas canvas, double t, {required int count}) {
    final w = imageRect.width;
    final h = imageRect.height;
    final limit = count.clamp(0, _fireflies.length);

    for (var i = 0; i < limit; i++) {
      final f = _fireflies[i];
      final angleX = t * 2 * math.pi * f.fx + f.phase;
      final angleY = t * 2 * math.pi * f.fy + f.phase * 1.3;
      final fx = f.cx + (disableAnimations ? 0.0 : math.sin(angleX) * f.rx);
      final fy = f.cy + (disableAnimations ? 0.0 : math.cos(angleY) * f.ry);
      final pos = TreehouseSceneAnchors.mapPoint(imageRect, fx, fy);

      final glow = disableAnimations
          ? 0.70
          : 0.18 +
              0.82 *
                  (0.5 +
                      0.5 *
                          math.sin(t * 2 * math.pi * f.glowFreq + f.phase * 2));
      final coreR = (w * 0.0055).clamp(1.6, 3.0);
      final haloR = coreR * (3.2 + glow * 1.8);

      canvas.drawCircle(
        pos,
        haloR,
        Paint()
          ..color = const Color(0xFFFDE047).withValues(alpha: glow * 0.45)
          ..maskFilter = _fireflyHaloBlur,
      );
      canvas.drawCircle(
        pos,
        coreR,
        Paint()..color = const Color(0xFFFEF9C3).withValues(alpha: glow),
      );
      // Avoid unused variable warning on h while keeping symmetrical scale ready
      assert(h >= 0);
    }
  }

  @override
  bool shouldRepaint(covariant TreehouseAtmospherePainter oldDelegate) {
    return oldDelegate.imageRect != imageRect ||
        oldDelegate.phase != phase ||
        oldDelegate.disableAnimations != disableAnimations;
  }
}

/// Seamless fallback backdrop painted behind [BoxFit.contain] letterboxing on
/// ultra-wide surfaces or if an artwork file is unavailable in isolated tests.
class ProceduralTreehouseBackdropPainter extends CustomPainter {
  final TreehouseDayPhase phase;
  final bool isDark;

  const ProceduralTreehouseBackdropPainter({
    required this.phase,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final List<Color> skyColors = switch (phase) {
      TreehouseDayPhase.dawn => const [
          Color(0xFF6B85A8),
          Color(0xFFE7B8A8),
          Color(0xFF4B5B6E),
        ],
      TreehouseDayPhase.day => const [
          Color(0xFF8CCCEB),
          Color(0xFFD5F0F5),
          Color(0xFF4D7B63),
        ],
      TreehouseDayPhase.sunset => const [
          Color(0xFF3E3556),
          Color(0xFFD9815F),
          Color(0xFF38272B),
        ],
      TreehouseDayPhase.night => const [
          Color(0xFF0E1629),
          Color(0xFF233256),
          Color(0xFF141B2D),
        ],
    };

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: skyColors,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant ProceduralTreehouseBackdropPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.isDark != isDark;
  }
}
