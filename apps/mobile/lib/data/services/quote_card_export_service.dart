import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class QuoteCardExportOutcome {
  final String filePath;
  final Uint8List pngBytes;
  final bool sharedViaNativeSheet;

  const QuoteCardExportOutcome({
    required this.filePath,
    required this.pngBytes,
    required this.sharedViaNativeSheet,
  });
}

/// Renders [RenderRepaintBoundary] quote cards and wallpapers locally into PNG
/// bytes, stores them under the app's local files directory, and invokes native
/// platform sharing without requiring server-side image rendering.
class QuoteCardExportService {
  static const MethodChannel _shareChannel = MethodChannel('com.nestin.app/share');

  final Future<Directory> Function()? directoryProvider;
  final Future<bool> Function(String filePath, String shareText)? shareInvoker;
  final Future<Uint8List> Function(GlobalKey boundaryKey, double pixelRatio)?
      capturePng;

  const QuoteCardExportService({
    this.directoryProvider,
    this.shareInvoker,
    this.capturePng,
  });

  Future<Uint8List> captureBoundaryPng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    if (capturePng != null) {
      return capturePng!(boundaryKey, pixelRatio);
    }
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Quote card preview boundary is not mounted yet.');
    }
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode quote card PNG bytes.');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<String> savePngLocally({
    required Uint8List pngBytes,
    String filePrefix = 'nestin_quote_card',
  }) async {
    final baseDir = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationDocumentsDirectory();
    final cardsDir = Directory(
      '${baseDir.path}${Platform.pathSeparator}nestin_quote_cards',
    );
    if (!await cardsDir.exists()) {
      await cardsDir.create(recursive: true);
    }
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final file = File(
      '${cardsDir.path}${Platform.pathSeparator}${filePrefix}_$ts.png',
    );
    await file.writeAsBytes(pngBytes, flush: true);
    return file.path;
  }

  Future<QuoteCardExportOutcome> exportCardPng({
    required GlobalKey boundaryKey,
    required String shareText,
    bool shareImmediately = false,
    double pixelRatio = 3.0,
  }) async {
    final bytes = await captureBoundaryPng(boundaryKey, pixelRatio: pixelRatio);
    final filePath = await savePngLocally(pngBytes: bytes);

    var shared = false;
    if (shareImmediately) {
      shared = await shareFile(filePath: filePath, shareText: shareText);
    }

    return QuoteCardExportOutcome(
      filePath: filePath,
      pngBytes: bytes,
      sharedViaNativeSheet: shared,
    );
  }

  Future<bool> shareFile({
    required String filePath,
    required String shareText,
  }) async {
    if (shareInvoker != null) {
      return shareInvoker!(filePath, shareText);
    }
    try {
      final invoked = await _shareChannel.invokeMethod<bool>('shareImageFile', {
        'filePath': filePath,
        'text': shareText,
      });
      return invoked ?? true;
    } on MissingPluginException {
      // Fallback: copy quote text to clipboard when native share sheet plugin isn't registered
      await Clipboard.setData(ClipboardData(text: shareText));
      return false;
    }
  }
}
