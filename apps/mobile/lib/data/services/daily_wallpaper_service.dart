import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../ui/widgets/inspiration/lock_screen_wallpaper_canvas.dart';
import '../models/daily_wallpaper_config.dart';
import '../models/inspiration_models.dart';
import 'quote_card_export_service.dart';

typedef DailyWallpaperPngRenderer = Future<Uint8List> Function(
  Widget widget,
  Size logicalSize,
  double pixelRatio,
);

typedef DailyWallpaperChannelInvoker = Future<dynamic> Function(
  String method, [
  Map<String, dynamic>? arguments,
]);

/// Manages the 7-day rolling PNG wallpaper cache (`<appDocsDir>/daily_wallpapers/yyyy-MM-dd.png`),
/// expired cache cleanup, Android MethodChannel (`com.nestin.app/wallpaper`) calls,
/// and honest iOS manual-save export fallback.
class DailyWallpaperService {
  static const String channelName = 'com.nestin.app/wallpaper';
  static const MethodChannel _defaultChannel = MethodChannel(channelName);
  static const String cacheFolderName = 'daily_wallpapers';
  static const int rollingCacheDays = 7;
  static const int minFutureCachedDaysThreshold = 5;
  static const Size defaultLogicalCanvasSize = Size(360, 640);
  static const double defaultPixelRatio = 3.0; // 1080 x 1920 px

  final Future<Directory> Function()? directoryProvider;
  final DateTime Function()? nowProvider;
  final DailyWallpaperPngRenderer? pngRenderer;
  final DailyWallpaperChannelInvoker? channelInvoker;
  final QuoteCardExportService exportService;
  final bool? isAndroidOverride;
  final bool? isIosOverride;

  const DailyWallpaperService({
    this.directoryProvider,
    this.nowProvider,
    this.pngRenderer,
    this.channelInvoker,
    this.exportService = const QuoteCardExportService(),
    this.isAndroidOverride,
    this.isIosOverride,
  });

  bool get isAndroid {
    if (isAndroidOverride != null) return isAndroidOverride!;
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  bool get isIOS {
    if (isIosOverride != null) return isIosOverride!;
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  /// Formats [date] as `yyyy-MM-dd` in local calendar date.
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses `yyyy-MM-dd` filename stem into a local [DateTime], or `null`.
  static DateTime? parseDateKey(String raw) {
    final trimmed = raw.endsWith('.png') ? raw.substring(0, raw.length - 4) : raw;
    final parts = trimmed.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  Future<Directory> getCacheDirectory() async {
    final baseDir = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${baseDir.path}${Platform.pathSeparator}$cacheFolderName',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> cacheFileForDate(DateTime date) async {
    final dir = await getCacheDirectory();
    return File(
      '${dir.path}${Platform.pathSeparator}${formatDateKey(date)}.png',
    );
  }

  /// Counts how many calendar days in `[today .. today + 6]` have cached PNGs.
  Future<int> countFutureCachedDays({DateTime? from}) async {
    final base = from ?? _now();
    final start = DateTime(base.year, base.month, base.day);
    final dir = await getCacheDirectory();
    var count = 0;
    for (var i = 0; i < rollingCacheDays; i++) {
      final day = start.add(Duration(days: i));
      final file = File(
        '${dir.path}${Platform.pathSeparator}${formatDateKey(day)}.png',
      );
      if (await file.exists()) {
        count++;
      }
    }
    return count;
  }

  /// Returns `true` when fewer than [minFutureDays] future days remain cached.
  Future<bool> needsCacheTopUp({
    int minFutureDays = minFutureCachedDaysThreshold,
    DateTime? from,
  }) async {
    final remaining = await countFutureCachedDays(from: from);
    return remaining < minFutureDays;
  }

  /// Deletes expired `.png` files older than yesterday (`date < today - 1 day`).
  Future<int> cleanupExpiredCache({DateTime? now}) async {
    final current = now ?? _now();
    final yesterday = DateTime(current.year, current.month, current.day)
        .subtract(const Duration(days: 1));
    final dir = await getCacheDirectory();
    if (!await dir.exists()) return 0;

    var deleted = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (!name.endsWith('.png')) continue;
      final parsed = parseDateKey(name);
      if (parsed != null && parsed.isBefore(yesterday)) {
        try {
          await entity.delete();
          deleted++;
        } catch (_) {}
      }
    }
    return deleted;
  }

  /// Pre-renders the next [days] (default 7) calendar days of 9:16 PNG
  /// wallpapers into `<appDocsDir>/daily_wallpapers/yyyy-MM-dd.png` and cleans
  /// up expired files older than yesterday.
  Future<List<String>> preRenderRollingCache({
    required DailyWallpaperConfig config,
    required InspirationQuote Function(DateTime date, int dayOffset)
        quoteForDate,
    required bool isDark,
    required AppLocalizations l10n,
    int days = rollingCacheDays,
    DateTime? startDate,
    double pixelRatio = defaultPixelRatio,
  }) async {
    final base = startDate ?? _now();
    final start = DateTime(base.year, base.month, base.day);
    final dir = await getCacheDirectory();
    final renderedPaths = <String>[];

    for (var i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      final quote = quoteForDate(date, i);
      final canvasWidget = LockScreenWallpaperCanvas(
        quoteText: quote.quoteText,
        authorName: quote.author,
        mascotDomain: quote.mascotDomain ?? 'pippin',
        template: config.template,
        isDark: isDark,
        showMascotSprite: config.showMascotSprite,
        referenceDate: date,
        l10nOverride: l10n,
      );

      final bytes = await renderCanvasToPng(
        canvasWidget,
        logicalSize: defaultLogicalCanvasSize,
        pixelRatio: pixelRatio,
      );
      final file = File(
        '${dir.path}${Platform.pathSeparator}${formatDateKey(date)}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      renderedPaths.add(file.path);
    }

    await cleanupExpiredCache(now: base);
    return renderedPaths;
  }

  /// Renders a standalone [LockScreenWallpaperCanvas] widget off-screen into
  /// PNG bytes using Flutter's [RenderRepaintBoundary] pipeline.
  Future<Uint8List> renderCanvasToPng(
    Widget canvasWidget, {
    Size logicalSize = defaultLogicalCanvasSize,
    double pixelRatio = defaultPixelRatio,
  }) async {
    if (pngRenderer != null) {
      return pngRenderer!(canvasWidget, logicalSize, pixelRatio);
    }
    return _renderOffscreenWidgetToPng(
      canvasWidget,
      logicalSize: logicalSize,
      pixelRatio: pixelRatio,
    );
  }

  /// Captures an already-mounted preview boundary (reusing [QuoteCardExportService])
  /// and saves it to today's cache file.
  Future<String> captureAndSaveTodayFromBoundary({
    required GlobalKey boundaryKey,
    double pixelRatio = defaultPixelRatio,
  }) async {
    final bytes = await exportService.captureBoundaryPng(
      boundaryKey,
      pixelRatio: pixelRatio,
    );
    final file = await cacheFileForDate(_now());
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Applies the PNG at [filePath] immediately on Android via `WallpaperManager`.
  Future<bool> applyWallpaperNow({
    required String filePath,
    required DailyWallpaperTarget target,
  }) async {
    if (!isAndroid) return false;
    final res = await _invokeChannel('applyWallpaperNow', {
      'filePath': filePath,
      'target': target.toChannelValue(),
    });
    return res == true;
  }

  /// Schedules the native Android WorkManager daily wallpaper job (zero Flutter
  /// engine startup in background).
  Future<bool> scheduleDailyWallpaper(DailyWallpaperConfig config) async {
    if (!isAndroid) return false;
    final dir = await getCacheDirectory();
    final res = await _invokeChannel('scheduleDailyWallpaper', {
      'hour': config.refreshHour,
      'minute': config.refreshMinute,
      'target': config.target.toChannelValue(),
      'cacheDir': dir.path,
    });
    return res == true;
  }

  /// Cancels any scheduled native Android WorkManager daily wallpaper job.
  Future<bool> cancelDailyWallpaper() async {
    if (!isAndroid) return false;
    final res = await _invokeChannel('cancelDailyWallpaper');
    return res == true;
  }

  /// Honest iOS fallback: saves the rendered 9:16 PNG locally and opens the
  /// native share sheet so the user can save to Photos or trigger Shortcuts.
  Future<QuoteCardExportOutcome> saveForIosManualUse({
    required Uint8List pngBytes,
    required String shareText,
  }) async {
    final filePath = await exportService.savePngLocally(
      pngBytes: pngBytes,
      filePrefix: 'nestin_lock_screen',
    );
    final shared = await exportService.shareFile(
      filePath: filePath,
      shareText: shareText,
    );
    return QuoteCardExportOutcome(
      filePath: filePath,
      pngBytes: pngBytes,
      sharedViaNativeSheet: shared,
    );
  }

  Future<dynamic> _invokeChannel(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (channelInvoker != null) {
      return channelInvoker!(method, arguments);
    }
    try {
      return await _defaultChannel.invokeMethod<dynamic>(method, arguments);
    } on MissingPluginException {
      return false;
    }
  }

  static Future<Uint8List> _renderOffscreenWidgetToPng(
    Widget widget, {
    required Size logicalSize,
    required double pixelRatio,
  }) async {
    final repaintBoundary = RenderRepaintBoundary();
    final flutterView = WidgetsBinding.instance.platformDispatcher.views.first;
    final renderView = RenderView(
      view: flutterView,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: repaintBoundary,
      ),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(logicalSize),
        devicePixelRatio: pixelRatio,
      ),
    );

    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(
            size: logicalSize,
            devicePixelRatio: pixelRatio,
          ),
          child: SizedBox(
            width: logicalSize.width,
            height: logicalSize.height,
            child: widget,
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    // Give bundled image assets a brief frame to decode before capturing.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode daily lock-screen wallpaper PNG.');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
