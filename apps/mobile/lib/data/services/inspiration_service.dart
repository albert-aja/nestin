import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/inspiration_models.dart';
import 'backend_gateway_service.dart';

class PaginatedQuotesResponse {
  final List<InspirationQuote> items;
  final int page;
  final int limit;
  final int total;
  final bool fromCache;

  const PaginatedQuotesResponse({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    this.fromCache = false,
  });

  bool get hasMore => page * limit < total;
}

class _NoopOfflineTransport implements BackendHttpTransport {
  const _NoopOfflineTransport();

  @override
  Future<BackendHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    throw const SocketExceptionPlaceholder();
  }
}

class SocketExceptionPlaceholder implements Exception {
  const SocketExceptionPlaceholder();
}

/// Offline-first repository & API client for Nestin's Inspiration module.
class InspirationService {
  static const String _keyCachedQuotes = 'nestin_insp_cached_quotes_v1';
  static const String _keyCachedFeaturedEn = 'nestin_insp_cached_featured_en_v1';
  static const String _keyCachedFeaturedId = 'nestin_insp_cached_featured_id_v1';
  static const String _keyCachedCategories = 'nestin_insp_cached_categories_v1';
  static const String _keyCachedAuthors = 'nestin_insp_cached_authors_v1';
  static const String _keyCachedWallpapers = 'nestin_insp_cached_wallpapers_v1';
  static const String _keyFavoriteQuotes = 'nestin_insp_favorites_v1';
  static const String _keyPersonalQuotes = 'nestin_insp_user_quotes_v1';
  static const String _keySubmissions = 'nestin_insp_submissions_v1';
  static const String _keyNotificationPrefs = 'nestin_insp_notif_prefs_v1';

  final SharedPreferences _prefs;
  final BackendGatewayService _gateway;
  final BackendGatewayConfig _config;
  final BackendHttpTransport _transport;
  final Uuid _uuid;

  InspirationService(
    this._prefs,
    this._gateway, {
    BackendGatewayConfig? config,
    BackendHttpTransport? transport,
    Uuid? uuid,
  })  : _config = config ?? BackendGatewayConfig.fromEnvironment(),
        _transport = transport ?? const _NoopOfflineTransport(),
        _uuid = uuid ?? const Uuid();

  /// Constructs an instance wired with a real HTTP transport (from [BackendGatewayService] conventions).
  factory InspirationService.live(
    SharedPreferences prefs,
    BackendGatewayService gateway, {
    BackendGatewayConfig? config,
    BackendHttpTransport? transport,
  }) {
    return InspirationService(
      prefs,
      gateway,
      config: config,
      transport: transport ?? gatewayTransportShim(gateway),
    );
  }

  static BackendHttpTransport gatewayTransportShim(
    BackendGatewayService gateway,
  ) =>
      _DelegatingGatewayTransport();

  bool get hasAuthenticatedUser {
    final session = _gateway.loadStoredAuthSession();
    return session != null && !session.isExpired && session.accessToken.isNotEmpty;
  }

  String? get _accessToken {
    final session = _gateway.loadStoredAuthSession();
    if (session == null || session.isExpired || session.accessToken.isEmpty) {
      return null;
    }
    return session.accessToken;
  }

  // ===========================================================================
  // Featured & Public Catalog (Backend-first with offline cache fallback)
  // ===========================================================================

  Future<InspirationQuote> fetchDailyFeaturedQuote({
    String locale = 'en',
  }) async {
    final uri = _config.buildApiUri('/inspiration/featured', {'locale': locale});
    if (uri != null) {
      try {
        final res = await _transport.send(
          method: 'GET',
          uri: uri,
          headers: const {'Accept': 'application/json'},
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final data = decoded['data'];
          if (data is Map<String, dynamic>) {
            final quoteRaw = data['quote'] ?? data;
            if (quoteRaw is Map<String, dynamic>) {
              final quote = InspirationQuote.fromJson(quoteRaw);
              await _saveCachedFeatured(quote, locale);
              return quote;
            }
          }
        }
      } catch (_) {
        // Offline / error -> serve cached featured quote
      }
    }

    return loadCachedFeaturedQuote(locale: locale);
  }

  InspirationQuote loadCachedFeaturedQuote({String locale = 'en'}) {
    final key = locale == 'id' ? _keyCachedFeaturedId : _keyCachedFeaturedEn;
    final raw = _prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        return InspirationQuote.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    return starterQuotes.firstWhere(
      (q) => q.locale == locale && q.isFeatured,
      orElse: () => starterQuotes.firstWhere(
        (q) => q.locale == locale,
        orElse: () => starterQuotes.first,
      ),
    );
  }

  Future<void> _saveCachedFeatured(InspirationQuote quote, String locale) async {
    final key = locale == 'id' ? _keyCachedFeaturedId : _keyCachedFeaturedEn;
    await _prefs.setString(key, jsonEncode(quote.toJson()));
  }

  Future<PaginatedQuotesResponse> fetchQuotes({
    String? category,
    String? author,
    String? locale,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (author != null && author.isNotEmpty) {
      queryParams['author'] = author;
    }
    if (locale != null && locale.isNotEmpty) {
      queryParams['locale'] = locale;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = _config.buildApiUri('/inspiration/quotes', queryParams);
    if (uri != null) {
      try {
        final res = await _transport.send(
          method: 'GET',
          uri: uri,
          headers: const {'Accept': 'application/json'},
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final listRaw = decoded['data'];
          final metaRaw = decoded['meta'];
          if (listRaw is List) {
            final items = listRaw
                .whereType<Map<String, dynamic>>()
                .map(InspirationQuote.fromJson)
                .toList();
            if (page == 1 &&
                category == null &&
                author == null &&
                search == null) {
              await _mergeIntoQuoteCache(items);
            }
            final total = metaRaw is Map && metaRaw['total'] is num
                ? (metaRaw['total'] as num).toInt()
                : items.length;
            return PaginatedQuotesResponse(
              items: items,
              page: page,
              limit: limit,
              total: total,
              fromCache: false,
            );
          }
        }
      } catch (_) {}
    }

    return queryCachedQuotes(
      category: category,
      author: author,
      locale: locale,
      search: search,
      page: page,
      limit: limit,
    );
  }

  PaginatedQuotesResponse queryCachedQuotes({
    String? category,
    String? author,
    String? locale,
    String? search,
    int page = 1,
    int limit = 20,
  }) {
    final all = loadCachedQuotes();
    final q = search?.trim().toLowerCase();
    final a = author?.trim().toLowerCase();
    final filtered = all.where((item) {
      if (locale != null && locale.isNotEmpty && item.locale != locale) {
        return false;
      }
      if (category != null && category.isNotEmpty && item.category != category) {
        return false;
      }
      if (a != null && a.isNotEmpty && !item.author.toLowerCase().contains(a)) {
        return false;
      }
      if (q != null &&
          q.isNotEmpty &&
          !item.quoteText.toLowerCase().contains(q) &&
          !item.author.toLowerCase().contains(q) &&
          !item.category.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    final start = (page - 1) * limit;
    final pageItems = start >= filtered.length
        ? const <InspirationQuote>[]
        : filtered.skip(start).take(limit).toList();
    return PaginatedQuotesResponse(
      items: pageItems,
      page: page,
      limit: limit,
      total: filtered.length,
      fromCache: true,
    );
  }

  List<InspirationQuote> loadCachedQuotes() {
    final raw = _prefs.getString(_keyCachedQuotes);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        final list = decoded
            .whereType<Map<String, dynamic>>()
            .map(InspirationQuote.fromJson)
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return List<InspirationQuote>.from(starterQuotes);
  }

  Future<void> _mergeIntoQuoteCache(List<InspirationQuote> fresh) async {
    final existing = loadCachedQuotes();
    final byId = {for (final q in existing) q.id: q};
    for (final q in fresh) {
      byId[q.id] = q;
    }
    await _prefs.setString(
      _keyCachedQuotes,
      jsonEncode(byId.values.map((q) => q.toJson()).toList()),
    );
  }

  Future<List<InspirationCategory>> fetchCategories({String? locale}) async {
    final uri = _config.buildApiUri(
      '/inspiration/categories',
      locale != null ? {'locale': locale} : null,
    );
    if (uri != null) {
      try {
        final res = await _transport.send(
          method: 'GET',
          uri: uri,
          headers: const {'Accept': 'application/json'},
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final listRaw = decoded['data'];
          if (listRaw is List) {
            final cats = listRaw
                .whereType<Map<String, dynamic>>()
                .map(InspirationCategory.fromJson)
                .toList();
            if (cats.isNotEmpty) {
              await _prefs.setString(
                _keyCachedCategories,
                jsonEncode(cats.map((c) => c.toJson()).toList()),
              );
              return cats;
            }
          }
        }
      } catch (_) {}
    }
    return loadCachedCategories();
  }

  List<InspirationCategory> loadCachedCategories() {
    final raw = _prefs.getString(_keyCachedCategories);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .whereType<Map<String, dynamic>>()
            .map(InspirationCategory.fromJson)
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return List<InspirationCategory>.from(starterCategories);
  }

  Future<List<InspirationAuthor>> fetchAuthors({String? search}) async {
    final uri = _config.buildApiUri(
      '/inspiration/authors',
      search != null && search.isNotEmpty ? {'search': search} : null,
    );
    if (uri != null) {
      try {
        final res = await _transport.send(
          method: 'GET',
          uri: uri,
          headers: const {'Accept': 'application/json'},
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final listRaw = decoded['data'];
          if (listRaw is List) {
            final authors = listRaw
                .whereType<Map<String, dynamic>>()
                .map(InspirationAuthor.fromJson)
                .toList();
            if (authors.isNotEmpty && search == null) {
              await _prefs.setString(
                _keyCachedAuthors,
                jsonEncode(authors.map((a) => a.toJson()).toList()),
              );
            }
            return authors;
          }
        }
      } catch (_) {}
    }
    return loadCachedAuthors();
  }

  List<InspirationAuthor> loadCachedAuthors() {
    final raw = _prefs.getString(_keyCachedAuthors);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .whereType<Map<String, dynamic>>()
            .map(InspirationAuthor.fromJson)
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return List<InspirationAuthor>.from(starterAuthors);
  }

  Future<List<InspirationWallpaperTemplate>> fetchWallpapers() async {
    final uri = _config.buildApiUri('/inspiration/wallpapers');
    if (uri != null) {
      try {
        final res = await _transport.send(
          method: 'GET',
          uri: uri,
          headers: const {'Accept': 'application/json'},
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final listRaw = decoded['data'];
          if (listRaw is List) {
            final templates = listRaw
                .whereType<Map<String, dynamic>>()
                .map(InspirationWallpaperTemplate.fromJson)
                .toList();
            if (templates.isNotEmpty) {
              await _prefs.setString(
                _keyCachedWallpapers,
                jsonEncode(templates.map((t) => t.toJson()).toList()),
              );
              return templates;
            }
          }
        }
      } catch (_) {}
    }
    return loadCachedWallpapers();
  }

  List<InspirationWallpaperTemplate> loadCachedWallpapers() {
    final raw = _prefs.getString(_keyCachedWallpapers);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .whereType<Map<String, dynamic>>()
            .map(InspirationWallpaperTemplate.fromJson)
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return List<InspirationWallpaperTemplate>.from(starterWallpaperTemplates);
  }

  // ===========================================================================
  // Favorites (Local-first storage + optional cloud sync when signed in)
  // ===========================================================================

  List<InspirationQuote> loadFavorites() {
    final raw = _prefs.getString(_keyFavoriteQuotes);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(InspirationQuote.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<InspirationQuote>> saveFavorite(InspirationQuote quote) async {
    final list = loadFavorites();
    if (!list.any((q) => q.id == quote.id)) {
      list.insert(0, quote);
      await _prefs.setString(
        _keyFavoriteQuotes,
        jsonEncode(list.map((q) => q.toJson()).toList()),
      );
    }

    final token = _accessToken;
    final uri = _config.buildApiUri('/inspiration/me/favorites');
    if (token != null && uri != null) {
      try {
        await _transport.send(
          method: 'POST',
          uri: uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'quoteId': quote.id}),
          timeout: const Duration(seconds: 6),
        );
      } catch (_) {}
    }

    return list;
  }

  Future<List<InspirationQuote>> removeFavorite(String quoteId) async {
    final list = loadFavorites()..removeWhere((q) => q.id == quoteId);
    await _prefs.setString(
      _keyFavoriteQuotes,
      jsonEncode(list.map((q) => q.toJson()).toList()),
    );

    final token = _accessToken;
    final uri = _config.buildApiUri('/inspiration/me/favorites/$quoteId');
    if (token != null && uri != null) {
      try {
        await _transport.send(
          method: 'DELETE',
          uri: uri,
          headers: {'Authorization': 'Bearer $token'},
          timeout: const Duration(seconds: 6),
        );
      } catch (_) {}
    }

    return list;
  }

  // ===========================================================================
  // Personal Quotes & Global Publication Submissions
  // ===========================================================================

  List<InspirationUserQuote> loadUserQuotes() {
    final raw = _prefs.getString(_keyPersonalQuotes);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(InspirationUserQuote.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistUserQuotes(List<InspirationUserQuote> items) async {
    await _prefs.setString(
      _keyPersonalQuotes,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  List<InspirationSubmission> loadSubmissions() {
    final raw = _prefs.getString(_keySubmissions);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(InspirationSubmission.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistSubmissions(List<InspirationSubmission> items) async {
    await _prefs.setString(
      _keySubmissions,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<InspirationSubmission>> syncMySubmissions() async {
    final token = _accessToken;
    final uri = _config.buildApiUri('/inspiration/me/submissions');
    if (token != null && uri != null) {
      try {
        final res = await _transport.send(
          method: 'GET',
          uri: uri,
          headers: {'Authorization': 'Bearer $token'},
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final listRaw = decoded['data'];
          if (listRaw is List) {
            final serverItems = listRaw
                .whereType<Map<String, dynamic>>()
                .map(InspirationSubmission.fromJson)
                .toList();
            // Keep any unsynced local-only drafts separated from server-confirmed items
            final localDrafts = loadSubmissions()
                .where((s) => !s.isConfirmedByServer)
                .toList();
            final merged = [...serverItems, ...localDrafts];
            await _persistSubmissions(merged);
            return merged;
          }
        }
      } catch (_) {}
    }
    return loadSubmissions();
  }

  Future<InspirationUserQuote> createPersonalQuote({
    required String quoteText,
    String? authorName,
    required InspirationCategory category,
    String locale = 'en',
    String? sourceReference,
    String displayPreference = 'anonymous',
    bool rightsConfirmed = false,
  }) async {
    final now = DateTime.now().toUtc();
    var created = InspirationUserQuote(
      id: _uuid.v4(),
      quoteText: quoteText.trim(),
      authorName: authorName?.trim().isEmpty == true ? null : authorName?.trim(),
      categoryId: category.id,
      categorySlug: category.slug,
      locale: locale,
      sourceReference:
          sourceReference?.trim().isEmpty == true ? null : sourceReference?.trim(),
      displayPreference: displayPreference,
      rightsConfirmed: rightsConfirmed,
      isPersonalOnly: true,
      isLocalOnlyDraft: true,
      createdAt: now,
      updatedAt: now,
    );

    final token = _accessToken;
    final uri = _config.buildApiUri('/inspiration/me/quotes');
    if (token != null && uri != null) {
      try {
        final res = await _transport.send(
          method: 'POST',
          uri: uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'quoteText': created.quoteText,
            if (created.authorName != null) 'authorName': created.authorName,
            'categoryId': created.categoryId,
            'locale': created.locale,
            if (created.sourceReference != null)
              'sourceReference': created.sourceReference,
            'displayPreference': created.displayPreference,
            'rightsConfirmed': created.rightsConfirmed,
            'isPersonalOnly': true,
          }),
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final data = decoded['data'];
          if (data is Map<String, dynamic>) {
            created = InspirationUserQuote.fromJson(data);
          }
        }
      } catch (_) {}
    }

    final existing = loadUserQuotes()..insert(0, created);
    await _persistUserQuotes(existing);
    return created;
  }

  Future<InspirationUserQuote> updatePersonalQuote(
    InspirationUserQuote quote, {
    required String quoteText,
    String? authorName,
    InspirationCategory? category,
    String? displayPreference,
  }) async {
    var updated = quote.copyWith(
      quoteText: quoteText.trim(),
      authorName: authorName?.trim().isEmpty == true ? null : authorName?.trim(),
      categoryId: category?.id ?? quote.categoryId,
      categorySlug: category?.slug ?? quote.categorySlug,
      displayPreference: displayPreference ?? quote.displayPreference,
      updatedAt: DateTime.now().toUtc(),
    );

    final token = _accessToken;
    final uri = _config.buildApiUri('/inspiration/me/quotes/${quote.id}');
    if (token != null && uri != null && !quote.isLocalOnlyDraft) {
      try {
        final res = await _transport.send(
          method: 'PUT',
          uri: uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'quoteText': updated.quoteText,
            if (updated.authorName != null) 'authorName': updated.authorName,
            'categoryId': updated.categoryId,
            'displayPreference': updated.displayPreference,
          }),
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          if (decoded['data'] is Map<String, dynamic>) {
            updated = InspirationUserQuote.fromJson(
              decoded['data'] as Map<String, dynamic>,
            );
          }
        }
      } catch (_) {}
    }

    final list = loadUserQuotes();
    final idx = list.indexWhere((q) => q.id == quote.id);
    if (idx >= 0) {
      list[idx] = updated;
      await _persistUserQuotes(list);
    }
    return updated;
  }

  Future<void> deletePersonalQuote(String quoteId) async {
    final list = loadUserQuotes()..removeWhere((q) => q.id == quoteId);
    await _persistUserQuotes(list);

    final token = _accessToken;
    final uri = _config.buildApiUri('/inspiration/me/quotes/$quoteId');
    if (token != null && uri != null) {
      try {
        await _transport.send(
          method: 'DELETE',
          uri: uri,
          headers: {'Authorization': 'Bearer $token'},
          timeout: const Duration(seconds: 6),
        );
      } catch (_) {}
    }
  }

  Future<BackendResult<InspirationSubmission>> submitQuoteForGlobalModeration({
    required InspirationUserQuote quote,
    required bool anonymousPublication,
    required bool rightsConfirmed,
  }) async {
    if (!rightsConfirmed) {
      return BackendResult.error(
        'Please confirm you have rights or permission to submit this quote.',
      );
    }
    final token = _accessToken;
    if (token == null) {
      return BackendResult.error(
        'Please sign in with a Nestin account to submit quotes for global moderation.',
      );
    }

    final uri = _config.buildApiUri('/inspiration/me/submissions');
    if (uri != null) {
      try {
        final res = await _transport.send(
          method: 'POST',
          uri: uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'userQuoteId': quote.id,
            'anonymousPublication': anonymousPublication,
            'rightsConfirmed': rightsConfirmed,
          }),
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final sub = InspirationSubmission.fromJson(
            decoded['data'] as Map<String, dynamic>,
          );
          final subs = loadSubmissions()
            ..removeWhere((s) => s.userQuoteId == quote.id && !s.isConfirmedByServer)
            ..insert(0, sub);
          await _persistSubmissions(subs);
          return BackendResult.ok(sub);
        } else {
          String message = 'Submission rejected (${res.statusCode})';
          try {
            final err = jsonDecode(res.body) as Map<String, dynamic>;
            final msg = err['error']?['message'] ?? err['message'];
            if (msg is String && msg.isNotEmpty) message = msg;
          } catch (_) {}
          return BackendResult.error(message);
        }
      } catch (_) {
        // Offline queueing: store explicitly as NOT confirmed by server
      }
    }

    final draftSubmission = InspirationSubmission(
      id: _uuid.v4(),
      userQuoteId: quote.id,
      status: InspirationSubmissionStatus.draft,
      anonymousPublication: anonymousPublication,
      quoteText: quote.quoteText,
      authorName: quote.authorName,
      categoryId: quote.categoryId,
      categorySlug: quote.categorySlug,
      locale: quote.locale,
      submittedAt: null,
      isConfirmedByServer: false,
    );
    final subs = loadSubmissions()
      ..removeWhere((s) => s.userQuoteId == quote.id && !s.isConfirmedByServer)
      ..insert(0, draftSubmission);
    await _persistSubmissions(subs);
    return BackendResult.offline(
      'Offline: Saved as local submission draft. Connect and tap Submit again to send to moderators.',
    );
  }

  Future<bool> withdrawSubmission(String submissionId) async {
    final token = _accessToken;
    final uri = _config.buildApiUri(
      '/inspiration/me/submissions/$submissionId/withdraw',
    );
    if (token != null && uri != null) {
      try {
        final res = await _transport.send(
          method: 'POST',
          uri: uri,
          headers: {'Authorization': 'Bearer $token'},
          timeout: const Duration(seconds: 6),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final updated = InspirationSubmission.fromJson(
            decoded['data'] as Map<String, dynamic>,
          );
          final subs = loadSubmissions();
          final idx = subs.indexWhere((s) => s.id == submissionId);
          if (idx >= 0) {
            subs[idx] = updated;
          }
          await _persistSubmissions(subs);
          return true;
        }
      } catch (_) {}
    }

    final subs = loadSubmissions();
    final idx = subs.indexWhere((s) => s.id == submissionId && !s.isConfirmedByServer);
    if (idx >= 0) {
      subs.removeAt(idx);
      await _persistSubmissions(subs);
      return true;
    }
    return false;
  }

  // ===========================================================================
  // Notification Preferences (Opt-in OFF by default)
  // ===========================================================================

  InspirationNotificationPreferences loadNotificationPreferences() {
    return InspirationNotificationPreferences.decodeOrDefault(
      _prefs.getString(_keyNotificationPrefs),
    );
  }

  Future<InspirationNotificationPreferences> saveNotificationPreferences(
    InspirationNotificationPreferences prefsValue,
  ) async {
    await _prefs.setString(
      _keyNotificationPrefs,
      jsonEncode(prefsValue.toJson()),
    );

    final token = _accessToken;
    final uri = _config.buildApiUri('/inspiration/me/notification-preferences');
    if (token != null && uri != null) {
      try {
        await _transport.send(
          method: 'PUT',
          uri: uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(prefsValue.toJson()),
          timeout: const Duration(seconds: 6),
        );
      } catch (_) {}
    }
    return prefsValue;
  }

  // ===========================================================================
  // Bundled Offline Starter Data (matches database seed.sql)
  // ===========================================================================

  static const List<InspirationCategory> starterCategories = [
    InspirationCategory(
      id: '51000000-0000-0000-0000-000000000001',
      slug: 'motivation',
      name: 'Motivation',
      localizedNames: {'en': 'Motivation', 'id': 'Motivasi'},
      mascotDomain: 'roo',
      sortOrder: 1,
    ),
    InspirationCategory(
      id: '51000000-0000-0000-0000-000000000002',
      slug: 'personal-growth',
      name: 'Personal Growth',
      localizedNames: {'en': 'Personal Growth', 'id': 'Pengembangan Diri'},
      mascotDomain: 'pippin',
      sortOrder: 2,
    ),
    InspirationCategory(
      id: '51000000-0000-0000-0000-000000000003',
      slug: 'productivity',
      name: 'Productivity',
      localizedNames: {'en': 'Productivity', 'id': 'Produktivitas'},
      mascotDomain: 'roo',
      sortOrder: 3,
    ),
    InspirationCategory(
      id: '51000000-0000-0000-0000-000000000004',
      slug: 'mental-wellness',
      name: 'Mental Wellness',
      localizedNames: {'en': 'Mental Wellness', 'id': 'Kesehatan Mental'},
      mascotDomain: 'seren',
      sortOrder: 4,
    ),
    InspirationCategory(
      id: '51000000-0000-0000-0000-000000000005',
      slug: 'gratitude',
      name: 'Gratitude',
      localizedNames: {'en': 'Gratitude', 'id': 'Rasa Syukur'},
      mascotDomain: 'echo',
      sortOrder: 5,
    ),
    InspirationCategory(
      id: '51000000-0000-0000-0000-000000000006',
      slug: 'relationships',
      name: 'Relationships',
      localizedNames: {'en': 'Relationships', 'id': 'Hubungan'},
      mascotDomain: 'echo',
      sortOrder: 6,
    ),
    InspirationCategory(
      id: '51000000-0000-0000-0000-000000000007',
      slug: 'philosophy',
      name: 'Philosophy',
      localizedNames: {'en': 'Philosophy', 'id': 'Filosofi'},
      mascotDomain: 'scout',
      sortOrder: 7,
    ),
    InspirationCategory(
      id: '51000000-0000-0000-0000-000000000008',
      slug: 'financial-mindset',
      name: 'Financial Mindset',
      localizedNames: {'en': 'Financial Mindset', 'id': 'Pola Pikir Keuangan'},
      mascotDomain: 'twill',
      sortOrder: 8,
    ),
    InspirationCategory(
      id: '51000000-0000-0000-0000-000000000009',
      slug: 'life-lessons',
      name: 'Life Lessons',
      localizedNames: {'en': 'Life Lessons', 'id': 'Pelajaran Hidup'},
      mascotDomain: 'pippin',
      sortOrder: 9,
    ),
  ];

  static const List<InspirationAuthor> starterAuthors = [
    InspirationAuthor(
      id: '52000000-0000-0000-0000-000000000001',
      name: 'Roo • Time & Planning',
      slug: 'roo-time-planning',
      mascotDomain: 'roo',
    ),
    InspirationAuthor(
      id: '52000000-0000-0000-0000-000000000002',
      name: 'Seren • Personal Wellness',
      slug: 'seren-personal-wellness',
      mascotDomain: 'seren',
    ),
    InspirationAuthor(
      id: '52000000-0000-0000-0000-000000000003',
      name: 'Twill • Notes & Organization',
      slug: 'twill-notes-organization',
      mascotDomain: 'twill',
    ),
    InspirationAuthor(
      id: '52000000-0000-0000-0000-000000000004',
      name: 'Anonymous Contributor',
      slug: 'anonymous',
      isAnonymousOrUnknown: true,
    ),
  ];

  static const List<InspirationQuote> starterQuotes = [
    InspirationQuote(
      id: '10000000-0000-0000-0000-000000000001',
      quoteText: 'Small progress is still progress. Keep moving forward.',
      author: 'Roo • Time & Planning',
      authorId: '52000000-0000-0000-0000-000000000001',
      category: 'motivation',
      categoryId: '51000000-0000-0000-0000-000000000001',
      locale: 'en',
      mascotDomain: 'roo',
      isFeatured: true,
      scheduledFor: '2026-11-14',
      sourceReference: 'Nestin Morning Almanac',
    ),
    InspirationQuote(
      id: '10000000-0000-0000-0000-000000000002',
      quoteText:
          'Langkah kecil tetaplah sebuah kemajuan. Teruslah berjalan dengan tenang.',
      author: 'Roo • Time & Planning',
      authorId: '52000000-0000-0000-0000-000000000001',
      category: 'motivation',
      categoryId: '51000000-0000-0000-0000-000000000001',
      locale: 'id',
      mascotDomain: 'roo',
      isFeatured: true,
      scheduledFor: '2026-11-14',
      sourceReference: 'Almanak Pagi Nestin',
    ),
    InspirationQuote(
      id: '10000000-0000-0000-0000-000000000003',
      quoteText:
          'Rest is part of the craft. Lower the lights and protect your deepest sleep.',
      author: 'Seren • Personal Wellness',
      authorId: '52000000-0000-0000-0000-000000000002',
      category: 'mental-wellness',
      categoryId: '51000000-0000-0000-0000-000000000004',
      locale: 'en',
      mascotDomain: 'seren',
      sourceReference: 'Seren Evening Notes',
    ),
    InspirationQuote(
      id: '10000000-0000-0000-0000-000000000004',
      quoteText:
          'Simplicity in your budget buys peace of mind for every ordinary day.',
      author: 'Twill • Notes & Organization',
      authorId: '52000000-0000-0000-0000-000000000003',
      category: 'financial-mindset',
      categoryId: '51000000-0000-0000-0000-000000000008',
      locale: 'en',
      mascotDomain: 'twill',
      sourceReference: 'Twill Practical Ledger',
    ),
    InspirationQuote(
      id: '10000000-0000-0000-0000-000000000005',
      quoteText:
          'Notice three quiet things going right today before chasing what comes next.',
      author: 'Echo • Journal & Memories',
      category: 'gratitude',
      categoryId: '51000000-0000-0000-0000-000000000005',
      locale: 'en',
      mascotDomain: 'echo',
      sourceReference: 'Echo Gratitude Cards',
    ),
    InspirationQuote(
      id: '10000000-0000-0000-0000-000000000006',
      quoteText:
          'Deep focus is kind to your future self; finish one honest thing well.',
      author: 'Pippin • Curiosity & Craft',
      category: 'productivity',
      categoryId: '51000000-0000-0000-0000-000000000003',
      locale: 'en',
      mascotDomain: 'pippin',
      sourceReference: 'Pippin Field Notes',
    ),
  ];

  static const List<InspirationWallpaperTemplate> starterWallpaperTemplates = [
    InspirationWallpaperTemplate(
      id: '53000000-0000-0000-0000-000000000001',
      slug: 'sunrise-nest',
      name: 'Sunrise Nest',
      layoutType: 'quote_card_portrait',
      aspectRatio: '4:5',
      backgroundType: 'gradient',
      gradientColors: ['#1F1627', '#3A1D2E', '#E04A3A'],
      textColor: '#FFF8F3',
      fontFamily: 'serif',
      textAlignment: 'center',
      showBranding: true,
      mascotIllustration: 'roo',
    ),
    InspirationWallpaperTemplate(
      id: '53000000-0000-0000-0000-000000000002',
      slug: 'seren-twilight',
      name: 'Seren Twilight',
      layoutType: 'lock_screen',
      aspectRatio: '9:16',
      backgroundType: 'gradient',
      gradientColors: ['#0F172A', '#1E293B', '#312E81'],
      textColor: '#F8FAFC',
      fontFamily: 'sans',
      textAlignment: 'center',
      showBranding: true,
      mascotIllustration: 'seren',
    ),
    InspirationWallpaperTemplate(
      id: '53000000-0000-0000-0000-000000000003',
      slug: 'pippin-sage',
      name: 'Pippin Sage',
      layoutType: 'quote_card_square',
      aspectRatio: '1:1',
      backgroundType: 'gradient',
      gradientColors: ['#102A26', '#164E46', '#059669'],
      textColor: '#ECFDF5',
      fontFamily: 'serif',
      textAlignment: 'left',
      showBranding: true,
      mascotIllustration: 'pippin',
    ),
    InspirationWallpaperTemplate(
      id: '53000000-0000-0000-0000-000000000004',
      slug: 'paper-almanac',
      name: 'Paper Almanac',
      layoutType: 'home_screen',
      aspectRatio: '9:16',
      backgroundType: 'solid',
      gradientColors: ['#FBF7F0', '#F2E9DC'],
      textColor: '#1E2028',
      fontFamily: 'serif',
      textAlignment: 'center',
      showBranding: true,
      mascotIllustration: 'twill',
    ),
  ];
}

class _DelegatingGatewayTransport implements BackendHttpTransport {
  @override
  Future<BackendHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.openUrl(method, uri).timeout(timeout);
      headers.forEach((key, value) {
        req.headers.set(key, value);
      });
      if (body != null) {
        req.add(utf8.encode(body));
      }
      final res = await req.close().timeout(timeout);
      final responseBody = await utf8.decoder.bind(res).join();
      return BackendHttpResponse(
        statusCode: res.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}
