import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_environment.dart';
import '../../ui/screens/splash/seasonal_loading_theme.dart';
import 'backend_gateway_service.dart';

/// Service managing personal local photos and downloadable remote holiday
/// wallpaper packs from `/api/v1/media` for Phase 2 of [SplashScreen].
class SplashWallpaperPackService {
  const SplashWallpaperPackService._();

  /// Optional test override for the base sandbox directory so widget tests run
  /// without awaiting `path_provider` timeouts inside `FakeAsync`.
  static Directory? debugBaseDirectoryOverride;

  static Future<Directory> _resolveBaseDirectory() async {
    if (debugBaseDirectoryOverride != null) {
      return debugBaseDirectoryOverride!;
    }
    try {
      return await getApplicationDocumentsDirectory()
          .timeout(const Duration(milliseconds: 120));
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  static Future<Directory> _customPhotoDirectory() async {
    final base = await _resolveBaseDirectory();
    final dir = Directory('${base.path}/splash_wallpapers/custom');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _remotePackDirectory() async {
    final base = await _resolveBaseDirectory();
    final dir = Directory('${base.path}/splash_wallpapers/remote_packs');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Launches the device file picker for an image and copies it into the
  /// app sandbox so it persists across restarts.
  static Future<String?> pickAndImportPersonalPhoto() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isEmpty) return null;
      final picked = files.first;
      final originalPath = picked.path;
      if (originalPath == null || originalPath.trim().isEmpty) return null;
      return importPersonalPhotoFromFile(originalPath);
    } catch (_) {
      return null;
    }
  }

  /// Copies an existing local photo at [sourcePath] into the app's sandboxed
  /// `splash_wallpapers/custom` directory and returns the stored file path.
  static Future<String?> importPersonalPhotoFromFile(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) return null;
      final customDir = await _customPhotoDirectory();
      final ext = _extractExtension(sourcePath);
      final targetPath =
          '${customDir.path}/personal_splash_${const Uuid().v4()}.$ext';
      final copied = await sourceFile.copy(targetPath);
      return copied.path;
    } catch (_) {
      return null;
    }
  }

  /// Removes a previously imported personal splash photo from the app sandbox.
  static Future<void> deletePersonalPhotoFile(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return;
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Queries `/api/v1/media?assetType=wallpaper` when [gateway] is configured
  /// and merges remote metadata onto [RemoteHolidayWallpaperCatalog.packs],
  /// falling back to the built-in catalog when offline.
  static Future<List<RemoteHolidayWallpaperPack>> fetchCatalogPacks({
    BackendGatewayService? gateway,
    String? locale,
  }) async {
    const basePacks = RemoteHolidayWallpaperCatalog.packs;
    if (gateway == null || !gateway.isBackendConfigured) {
      return basePacks;
    }

    final result = await gateway.fetchMediaWallpapers(locale: locale);
    if (!result.isSuccess || result.data == null) {
      return basePacks;
    }

    final rawItems = result.data!['items'];
    if (rawItems is! List) return basePacks;

    final remoteBySlug = <String, Map<String, dynamic>>{};
    for (final item in rawItems) {
      if (item is Map<String, dynamic>) {
        final slug = item['slug'];
        if (slug is String && slug.isNotEmpty) {
          remoteBySlug[slug] = item;
        }
      }
    }

    if (remoteBySlug.isEmpty) return basePacks;

    return basePacks.map((pack) {
      final remote = remoteBySlug[pack.slug];
      return remote != null ? pack.mergeRemoteMetadata(remote) : pack;
    }).toList(growable: false);
  }

  /// Downloads and caches [pack] into the local `splash_wallpapers/remote_packs`
  /// directory. Attempts remote HTTP download first when `publicUrl` or
  /// `AppEnvironment.supabaseUrl` is configured, and falls back to the high-res
  /// bundled asset stream so offline/guest installs always succeed reliably.
  static Future<String?> downloadAndCachePack(
    RemoteHolidayWallpaperPack pack, {
    void Function(double progress)? onProgress,
    Future<Uint8List?> Function(String url)? remoteFetcher,
  }) async {
    try {
      onProgress?.call(0.10);
      final packDir = await _remotePackDirectory();
      final targetFile = File('${packDir.path}/${pack.slug}.jpg');

      String? candidateUrl = pack.publicUrl;
      final supabaseBase = AppEnvironment.supabaseUrl.trim();
      if ((candidateUrl == null || candidateUrl.isEmpty) &&
          supabaseBase.isNotEmpty) {
        final cleanBase = supabaseBase.replaceAll(RegExp(r'/*$'), '');
        candidateUrl =
            '$cleanBase/storage/v1/object/public/${pack.storageBucket}/${pack.storagePath}';
      }

      Uint8List? bytes;
      if (candidateUrl != null && candidateUrl.isNotEmpty) {
        onProgress?.call(0.35);
        final fetcher = remoteFetcher ?? _tryDownloadBytes;
        bytes = await fetcher(candidateUrl);
      }

      onProgress?.call(0.65);
      bytes ??= await _loadBundledPackBytes(pack.bundledPreviewAsset);
      if (bytes == null || bytes.isEmpty) return null;

      await targetFile.writeAsBytes(bytes, flush: true);
      onProgress?.call(1.0);
      return targetFile.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeCachedPack(
    String slug, {
    String? cachedFilePath,
  }) async {
    try {
      if (cachedFilePath != null && cachedFilePath.trim().isNotEmpty) {
        final file = File(cachedFilePath);
        if (file.existsSync()) {
          await file.delete();
        }
      }
      final packDir = await _remotePackDirectory();
      final defaultFile = File('${packDir.path}/$slug.jpg');
      if (defaultFile.existsSync()) {
        await defaultFile.delete();
      }
    } catch (_) {}
  }

  static Future<Uint8List?> _loadBundledPackBytes(String assetPath) async {
    try {
      final directFile = File(assetPath);
      if (directFile.existsSync()) {
        return await directFile.readAsBytes();
      }
    } catch (_) {}

    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _tryDownloadBytes(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 4));
      if (resp.statusCode != HttpStatus.ok) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in resp) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      return bytes.length > 512 ? bytes : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String _extractExtension(String path) {
    final dotIdx = path.lastIndexOf('.');
    if (dotIdx < 0 || dotIdx == path.length - 1) return 'jpg';
    final ext = path.substring(dotIdx + 1).toLowerCase();
    if (const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      return ext;
    }
    return 'jpg';
  }
}
