import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/book_matcher_catalog.dart';
import 'storage_service.dart';

/// Tier-3 Free Online API Enrichment Service for Pippin's Next-Book Matcher.
///
/// Connects to the open-source Open Library API (`https://openlibrary.org/subjects/<subject>.json`)
/// with zero API key required, parses extra book suggestions with ISBN / cover edition keys /
/// page count estimates, and caches results locally in [StorageService] (`SharedPreferences`)
/// so offline sessions and repeat queries resolve in 0ms.
class OpenLibraryBookService {
  final StorageService _storage;
  final Future<String?> Function(Uri uri) _httpFetcher;

  OpenLibraryBookService(
    this._storage, {
    Future<String?> Function(Uri uri)? httpFetcher,
  }) : _httpFetcher = httpFetcher ?? _defaultHttpGet;

  static Future<String?> _defaultHttpGet(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.getUrl(uri).timeout(
            const Duration(seconds: 4),
          );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'NestinPersonalSanctuary/1.0 (https://openlibrary.org)',
      );
      final response = await request.close().timeout(
            const Duration(seconds: 4),
          );
      if (response.statusCode != 200) return null;
      return await response.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Returns cached Open Library books for [genre] (or across all genres when null).
  List<BookRecommendationProfile> getCachedBooks({BookMatcherGenre? genre}) {
    final allCached = _storage.loadCachedOpenLibraryBooks();
    if (genre == null) return allCached;
    return allCached.where((b) => b.genre == genre).toList();
  }

  /// Fetches live book suggestions from `openlibrary.org/subjects/<subject>.json`,
  /// merges them into the local cache, and returns the updated cached list for [genre].
  Future<List<BookRecommendationProfile>> fetchAndCacheSubjectBooks(
    BookMatcherGenre genre, {
    int limit = 5,
  }) async {
    final subject = genre.openLibrarySubject;
    final uri = Uri.parse(
      'https://openlibrary.org/subjects/$subject.json?limit=$limit',
    );
    final body = await _httpFetcher(uri);
    if (body == null || body.trim().isEmpty) {
      return getCachedBooks(genre: genre);
    }

    final parsed = parseOpenLibrarySubjectJson(body, genre);
    if (parsed.isEmpty) {
      return getCachedBooks(genre: genre);
    }

    final existing = _storage
        .loadCachedOpenLibraryBooks()
        .where((b) => b.genre != genre)
        .toList();
    final merged = <BookRecommendationProfile>[...existing, ...parsed];
    await _storage.saveCachedOpenLibraryBooks(merged);
    return parsed;
  }

  /// Parses an Open Library `/subjects/<subject>.json` or `/search.json` payload
  /// into normalized [BookRecommendationProfile] records.
  static List<BookRecommendationProfile> parseOpenLibrarySubjectJson(
    String rawJson,
    BookMatcherGenre genre,
  ) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return const [];

      final works = (decoded['works'] as List?) ?? (decoded['docs'] as List?);
      if (works == null || works.isEmpty) return const [];

      final results = <BookRecommendationProfile>[];
      for (final raw in works) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final title = map['title']?.toString().trim() ?? '';
        if (title.isEmpty) continue;

        String author = 'Unknown Author';
        if (map['authors'] is List && (map['authors'] as List).isNotEmpty) {
          final firstAuthor = (map['authors'] as List).first;
          if (firstAuthor is Map && firstAuthor['name'] != null) {
            author = firstAuthor['name'].toString().trim();
          }
        } else if (map['author_name'] is List &&
            (map['author_name'] as List).isNotEmpty) {
          author = (map['author_name'] as List).first.toString().trim();
        }

        final keySlug = (map['key']?.toString() ?? title)
            .replaceAll('/works/', '')
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final coverEditionKey = map['cover_edition_key']?.toString() ??
            map['lending_edition_s']?.toString() ??
            map['cover_id']?.toString();

        String? isbn;
        if (map['availability'] is Map &&
            (map['availability'] as Map)['isbn'] != null) {
          isbn = (map['availability'] as Map)['isbn'].toString();
        } else if (map['isbn'] is List && (map['isbn'] as List).isNotEmpty) {
          isbn = (map['isbn'] as List).first.toString();
        }

        final medianPages =
            (map['number_of_pages_median'] as num?)?.toInt() ?? 260;

        results.add(
          BookRecommendationProfile(
            id: 'ol_${genre.name}_$keySlug',
            titleEn: title,
            titleId: title,
            author: author,
            genre: genre,
            readingCategory: genre.readingCategory,
            pageCount: medianPages.clamp(80, 1200),
            avgChapterMinutes: 15,
            synopsisEn:
                'Discovered via Open Library (${genre.openLibrarySubject.replaceAll('_', ' ')}) • by $author.',
            synopsisId:
                'Ditemukan lewat Open Library (${genre.openLibrarySubject.replaceAll('_', ' ')}) • karya $author.',
            whyItFitsEn:
                'Live Open Library community classic matching your ${genre.readingCategory} interest.',
            whyItFitsId:
                'Rekomendasi pustaka terbuka Open Library yang selaras dengan minat bacaan Anda.',
            tagAffinities: _defaultTagAffinitiesForGenre(genre),
            pairedSerenSoundId: _defaultSoundForGenre(genre),
            isbn: isbn,
            coverEditionKey: coverEditionKey,
            isFromOnlineApi: true,
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  static Map<String, double> _defaultTagAffinitiesForGenre(
    BookMatcherGenre genre,
  ) {
    switch (genre) {
      case BookMatcherGenre.cozyFiction:
        return const {
          'cozy_fiction': 4.0,
          'cozy_comfort': 3.5,
          'warm_characters': 3.0,
        };
      case BookMatcherGenre.natureAndScience:
        return const {
          'nature_science': 4.0,
          'curious_learning': 3.5,
          'observational': 3.0,
        };
      case BookMatcherGenre.mindfulNonFiction:
        return const {
          'mindful_nonfiction': 4.0,
          'mindful_living': 3.5,
          'short_chapters': 3.0,
        };
      case BookMatcherGenre.philosophy:
        return const {
          'philosophy': 4.0,
          'philosophical': 3.5,
        };
      case BookMatcherGenre.historicalAdventure:
        return const {
          'historical_adventure': 4.0,
          'world_building': 3.5,
          'narrative_drive': 3.0,
        };
      case BookMatcherGenre.indonesianAndWorldLit:
        return const {
          'indonesian_world_lit': 4.0,
          'lyrical_prose': 3.5,
        };
    }
  }

  static String _defaultSoundForGenre(BookMatcherGenre genre) {
    switch (genre) {
      case BookMatcherGenre.cozyFiction:
        return 'nylon_guitar';
      case BookMatcherGenre.natureAndScience:
        return 'forest_stream';
      case BookMatcherGenre.mindfulNonFiction:
        return 'singing_bowls';
      case BookMatcherGenre.philosophy:
        return 'warm_cello';
      case BookMatcherGenre.historicalAdventure:
        return 'gentle_rain';
      case BookMatcherGenre.indonesianAndWorldLit:
        return 'warm_piano';
    }
  }
}
