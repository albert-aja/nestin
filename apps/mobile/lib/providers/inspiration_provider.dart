import 'package:material_ui/material_ui.dart';
import '../core/l10n/app_localizations.dart';
import '../data/models/daily_wallpaper_config.dart';
import '../data/models/inspiration_models.dart';
import '../data/services/backend_gateway_service.dart';
import '../data/services/daily_wallpaper_service.dart';
import '../data/services/inspiration_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/quote_card_export_service.dart';
import '../data/services/storage_service.dart';
import '../ui/widgets/inspiration/lock_screen_wallpaper_canvas.dart';

class InspirationProvider extends ChangeNotifier {
  final InspirationService _service;
  final NotificationService? _notifications;
  final StorageService? _storage;
  final DailyWallpaperService _dailyWallpaperService;

  InspirationQuote? _featuredQuote;
  List<InspirationQuote> _quotes = [];
  List<InspirationCategory> _categories = [];
  List<InspirationAuthor> _authors = [];
  List<InspirationWallpaperTemplate> _templates = [];
  List<InspirationQuote> _favorites = [];
  List<InspirationUserQuote> _userQuotes = [];
  List<InspirationSubmission> _submissions = [];
  InspirationNotificationPreferences _notificationPreferences =
      const InspirationNotificationPreferences();
  DailyWallpaperConfig _dailyWallpaperConfig = const DailyWallpaperConfig();
  bool _isPreparingDailyWallpapers = false;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  bool _isFromCache = false;
  bool _hasMore = false;
  int _page = 1;
  int _totalQuotes = 0;

  String? _selectedCategorySlug;
  String? _selectedAuthor;
  String? _selectedLocale;
  String _searchQuery = '';
  bool _favoritesOnlyFilter = false;
  String? _highlightedQuoteId;

  InspirationProvider(
    this._service, {
    NotificationService? notificationService,
    StorageService? storageService,
    DailyWallpaperService? dailyWallpaperService,
  })  : _notifications = notificationService,
        _storage = storageService,
        _dailyWallpaperService =
            dailyWallpaperService ?? const DailyWallpaperService() {
    _hydrateFromCache();
  }

  void _hydrateFromCache() {
    _categories = _service.loadCachedCategories();
    _authors = _service.loadCachedAuthors();
    _templates = _service.loadCachedWallpapers();
    _featuredQuote = _service.loadCachedFeaturedQuote(locale: _selectedLocale ?? 'en');
    _quotes = _service.loadCachedQuotes();
    _totalQuotes = _quotes.length;
    _favorites = _service.loadFavorites();
    _userQuotes = _service.loadUserQuotes();
    _submissions = _service.loadSubmissions();
    _notificationPreferences = _service.loadNotificationPreferences();
    if (_storage != null) {
      _dailyWallpaperConfig = _storage.loadDailyWallpaperConfig();
    }
  }

  InspirationQuote get featuredQuote =>
      _featuredQuote ?? InspirationService.starterQuotes.first;
  List<InspirationQuote> get quotes =>
      _favoritesOnlyFilter ? filteredFavorites : _quotes;
  List<InspirationCategory> get categories => _categories;
  List<InspirationAuthor> get authors => _authors;
  List<InspirationWallpaperTemplate> get templates => _templates;
  List<InspirationQuote> get favorites => _favorites;
  List<InspirationUserQuote> get userQuotes => _userQuotes;
  List<InspirationSubmission> get submissions => _submissions;
  InspirationNotificationPreferences get notificationPreferences =>
      _notificationPreferences;

  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  bool get isFromCache => _isFromCache;
  bool get hasMore => !_favoritesOnlyFilter && _hasMore;
  int get totalQuotes => _totalQuotes;
  bool get hasSignedInAccount => _service.hasAuthenticatedUser;

  String? get selectedCategorySlug => _selectedCategorySlug;
  String? get selectedAuthor => _selectedAuthor;
  String? get selectedLocale => _selectedLocale;
  String get searchQuery => _searchQuery;
  bool get favoritesOnlyFilter => _favoritesOnlyFilter;
  String? get highlightedQuoteId => _highlightedQuoteId;

  List<InspirationQuote> get filteredFavorites {
    final q = _searchQuery.trim().toLowerCase();
    return _favorites.where((item) {
      if (_selectedCategorySlug != null &&
          _selectedCategorySlug!.isNotEmpty &&
          item.category != _selectedCategorySlug) {
        return false;
      }
      if (_selectedAuthor != null &&
          _selectedAuthor!.isNotEmpty &&
          !item.author.toLowerCase().contains(_selectedAuthor!.toLowerCase())) {
        return false;
      }
      if (_selectedLocale != null &&
          _selectedLocale!.isNotEmpty &&
          item.locale != _selectedLocale) {
        return false;
      }
      if (q.isNotEmpty &&
          !item.quoteText.toLowerCase().contains(q) &&
          !item.author.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  bool isFavorite(String quoteId) => _favorites.any((q) => q.id == quoteId);

  void highlightQuote(String? quoteId) {
    _highlightedQuoteId = quoteId;
    notifyListeners();
  }

  Future<void> initialize({String locale = 'en'}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.fetchDailyFeaturedQuote(locale: locale),
        _service.fetchCategories(locale: locale),
        _service.fetchAuthors(),
        _service.fetchWallpapers(),
        _service.fetchQuotes(
          category: _selectedCategorySlug,
          author: _selectedAuthor,
          locale: _selectedLocale,
          search: _searchQuery.isEmpty ? null : _searchQuery,
          page: 1,
          limit: 20,
        ),
        _service.syncMySubmissions(),
      ]);

      _featuredQuote = results[0] as InspirationQuote;
      _categories = results[1] as List<InspirationCategory>;
      _authors = results[2] as List<InspirationAuthor>;
      _templates = results[3] as List<InspirationWallpaperTemplate>;
      final pageRes = results[4] as PaginatedQuotesResponse;
      _quotes = pageRes.items;
      _page = pageRes.page;
      _totalQuotes = pageRes.total;
      _hasMore = pageRes.hasMore;
      _isFromCache = pageRes.fromCache;
      _submissions = results[5] as List<InspirationSubmission>;
      _hasLoadedOnce = true;

      if (_notificationPreferences.dailyEnabled) {
        await _scheduleDailyLocalNotification();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilters({
    String? categorySlug,
    bool clearCategory = false,
    String? author,
    bool clearAuthor = false,
    String? locale,
    bool clearLocale = false,
    String? search,
    bool? favoritesOnly,
  }) async {
    if (clearCategory) {
      _selectedCategorySlug = null;
    } else if (categorySlug != null) {
      _selectedCategorySlug = categorySlug;
    }

    if (clearAuthor) {
      _selectedAuthor = null;
    } else if (author != null) {
      _selectedAuthor = author;
    }

    if (clearLocale) {
      _selectedLocale = null;
    } else if (locale != null) {
      _selectedLocale = locale;
    }

    if (search != null) {
      _searchQuery = search;
    }
    if (favoritesOnly != null) {
      _favoritesOnlyFilter = favoritesOnly;
    }

    _page = 1;
    if (_favoritesOnlyFilter) {
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final res = await _service.fetchQuotes(
        category: _selectedCategorySlug,
        author: _selectedAuthor,
        locale: _selectedLocale,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        page: 1,
        limit: 20,
      );
      _quotes = res.items;
      _totalQuotes = res.total;
      _hasMore = res.hasMore;
      _isFromCache = res.fromCache;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreQuotes() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();
    try {
      final nextPage = _page + 1;
      final res = await _service.fetchQuotes(
        category: _selectedCategorySlug,
        author: _selectedAuthor,
        locale: _selectedLocale,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        page: nextPage,
        limit: 20,
      );
      final existingIds = _quotes.map((e) => e.id).toSet();
      _quotes = [
        ..._quotes,
        ...res.items.where((q) => !existingIds.contains(q.id)),
      ];
      _page = nextPage;
      _totalQuotes = res.total;
      _hasMore = res.hasMore;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(InspirationQuote quote) async {
    if (isFavorite(quote.id)) {
      _favorites = await _service.removeFavorite(quote.id);
    } else {
      _favorites = await _service.saveFavorite(quote);
    }
    notifyListeners();
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
    final created = await _service.createPersonalQuote(
      quoteText: quoteText,
      authorName: authorName,
      category: category,
      locale: locale,
      sourceReference: sourceReference,
      displayPreference: displayPreference,
      rightsConfirmed: rightsConfirmed,
    );
    _userQuotes = _service.loadUserQuotes();
    notifyListeners();
    return created;
  }

  Future<void> updatePersonalQuote(
    InspirationUserQuote quote, {
    required String quoteText,
    String? authorName,
    InspirationCategory? category,
    String? displayPreference,
  }) async {
    await _service.updatePersonalQuote(
      quote,
      quoteText: quoteText,
      authorName: authorName,
      category: category,
      displayPreference: displayPreference,
    );
    _userQuotes = _service.loadUserQuotes();
    await _service.syncMySubmissions();
    _submissions = _service.loadSubmissions();
    notifyListeners();
  }

  Future<void> deletePersonalQuote(String quoteId) async {
    await _service.deletePersonalQuote(quoteId);
    _userQuotes = _service.loadUserQuotes();
    _submissions = _service.loadSubmissions();
    notifyListeners();
  }

  Future<BackendResult<InspirationSubmission>> submitQuoteGlobally({
    required InspirationUserQuote quote,
    required bool anonymousPublication,
    required bool rightsConfirmed,
  }) async {
    final res = await _service.submitQuoteForGlobalModeration(
      quote: quote,
      anonymousPublication: anonymousPublication,
      rightsConfirmed: rightsConfirmed,
    );
    _submissions = _service.loadSubmissions();
    notifyListeners();
    return res;
  }

  Future<bool> withdrawSubmission(String submissionId) async {
    final ok = await _service.withdrawSubmission(submissionId);
    _submissions = _service.loadSubmissions();
    notifyListeners();
    return ok;
  }

  Future<void> updateNotificationPreferences(
    InspirationNotificationPreferences updated,
  ) async {
    final saved = await _service.saveNotificationPreferences(updated);
    _notificationPreferences = saved;

    if (saved.dailyEnabled) {
      await _notifications?.requestPermissions();
      await _scheduleDailyLocalNotification();
    } else {
      await _notifications?.cancelDailyInspirationNotification();
    }
    notifyListeners();
  }

  Future<void> rescheduleNotificationsIfEnabled() async {
    if (_notificationPreferences.dailyEnabled) {
      await _scheduleDailyLocalNotification();
    }
  }

  Future<void> _scheduleDailyLocalNotification() async {
    if (_notifications == null || !_notificationPreferences.dailyEnabled) return;
    final quote = _pickQuoteForPreferences(_notificationPreferences);
    final l10n = AppLocalizations.current;
    await _notifications.scheduleDailyInspirationNotification(
      hour: _notificationPreferences.preferredHour,
      minute: _notificationPreferences.preferredMinute,
      title: l10n.tr('a_little_inspiration_for_today'),
      body: '"${quote.quoteText}" — ${quote.author}',
      frequency: _notificationPreferences.frequency.toApi(),
      quoteId: quote.id,
    );
  }

  InspirationQuote _pickQuoteForPreferences(
    InspirationNotificationPreferences prefs,
  ) {
    final localePool = _quotes
        .where((q) => q.locale == prefs.preferredLocale)
        .toList();
    final pool = localePool.isNotEmpty ? localePool : _quotes;
    if (prefs.preferredCategoryIds.isNotEmpty) {
      final catPool = pool
          .where((q) =>
              q.categoryId != null &&
              prefs.preferredCategoryIds.contains(q.categoryId))
          .toList();
      if (catPool.isNotEmpty) return catPool.first;
    }
    return pool.isNotEmpty ? pool.first : featuredQuote;
  }

  Future<void> sendPreviewNotification() async {
    final quote = featuredQuote;
    final l10n = AppLocalizations.current;
    await _notifications?.showInspirationPreviewNotification(
      title: l10n.tr('nestin_inspiration'),
      body: '"${quote.quoteText}" — ${quote.author}',
      quoteId: quote.id,
    );
  }

  // ===========================================================================
  // Daily Affirmation Lock-Screen Wallpaper (Opt-in)
  // ===========================================================================

  DailyWallpaperConfig get dailyWallpaperConfig => _dailyWallpaperConfig;
  bool get isPreparingDailyWallpapers => _isPreparingDailyWallpapers;
  bool get isDailyWallpaperAndroid => _dailyWallpaperService.isAndroid;
  bool get isDailyWallpaperIOS => _dailyWallpaperService.isIOS;

  static const Set<String> _calmGroundedCategories = {
    'calm',
    'mindfulness',
    'gratitude',
    'peace',
    'focus',
    'reflection',
    'rest',
    'patience',
    'simplicity',
    'self-care',
    'gentle-living',
  };

  /// Deterministically picks a grounded quote for [date] and [dayOffset]
  /// according to the active [DailyWallpaperSource].
  InspirationQuote selectQuoteForDailyWallpaper({
    required DateTime date,
    required int dayOffset,
    required DailyWallpaperSource source,
    required String locale,
  }) {
    final allCached =
        _quotes.isNotEmpty ? _quotes : InspirationService.starterQuotes;
    final localePool = allCached.where((q) => q.locale == locale).toList();
    final basePool = localePool.isNotEmpty ? localePool : allCached;

    List<InspirationQuote> pool;
    switch (source) {
      case DailyWallpaperSource.favorites:
        final favLocale =
            _favorites.where((q) => q.locale == locale).toList();
        pool = favLocale.isNotEmpty
            ? favLocale
            : (_favorites.isNotEmpty ? _favorites : basePool);
      case DailyWallpaperSource.calmGrounded:
        final calm = basePool.where((q) {
          final cat = q.category.toLowerCase();
          final domain = (q.mascotDomain ?? '').toLowerCase();
          return _calmGroundedCategories.contains(cat) ||
              domain == 'seren' ||
              domain == 'echo' ||
              domain == 'pippin';
        }).toList();
        pool = calm.isNotEmpty ? calm : basePool;
      case DailyWallpaperSource.dailyFeatured:
        if (dayOffset == 0) {
          return _service.loadCachedFeaturedQuote(locale: locale);
        }
        pool = basePool;
    }

    if (pool.isEmpty) return featuredQuote;
    final seed = (date.year * 372) + (date.month * 31) + date.day + dayOffset;
    return pool[seed.abs() % pool.length];
  }

  Future<void> updateDailyWallpaperConfig(
    DailyWallpaperConfig updated, {
    required bool isDark,
    required AppLocalizations l10n,
  }) async {
    _dailyWallpaperConfig = updated;
    await _storage?.saveDailyWallpaperConfig(updated);
    notifyListeners();

    if (!_dailyWallpaperService.isAndroid) {
      return;
    }

    if (!updated.enabled) {
      await _dailyWallpaperService.cancelDailyWallpaper();
      return;
    }

    await _preRenderAndScheduleDailyWallpapers(
      config: updated,
      isDark: isDark,
      l10n: l10n,
    );
  }

  Future<void> _preRenderAndScheduleDailyWallpapers({
    required DailyWallpaperConfig config,
    required bool isDark,
    required AppLocalizations l10n,
  }) async {
    if (_isPreparingDailyWallpapers) return;
    _isPreparingDailyWallpapers = true;
    notifyListeners();
    try {
      final locale = l10n.isIndonesian ? 'id' : 'en';
      final userPrefs = _storage?.loadPreferences();
      final backdrop = DailyWallpaperBackdrop.resolve(
        customWallpaperId: config.customWallpaperId,
        customPhotoPath: userPrefs?.customSplashPhotoPath,
        installedPackPaths: userPrefs?.installedRemoteSplashPackPaths,
      );
      await _dailyWallpaperService.preRenderRollingCache(
        config: config,
        quoteForDate: (date, offset) => selectQuoteForDailyWallpaper(
          date: date,
          dayOffset: offset,
          source: config.quoteSource,
          locale: locale,
        ),
        isDark: isDark,
        l10n: l10n,
        customWallpaperAsset: backdrop.assetPath,
        customWallpaperFilePath: backdrop.filePath,
      );
      await _dailyWallpaperService.scheduleDailyWallpaper(config);
    } catch (_) {
      // Non-fatal: keep saved preferences intact even if rendering fails in headless env.
    } finally {
      _isPreparingDailyWallpapers = false;
      notifyListeners();
    }
  }

  /// Called on `AppLifecycleState.resumed` to silently top up the 7-day cache
  /// whenever fewer than 5 future days remain cached.
  Future<void> topUpDailyWallpaperCacheIfNeeded({
    required bool isDark,
    required AppLocalizations l10n,
  }) async {
    if (!_dailyWallpaperConfig.enabled || !_dailyWallpaperService.isAndroid) {
      return;
    }
    final needsTopUp = await _dailyWallpaperService.needsCacheTopUp();
    if (!needsTopUp) return;
    await _preRenderAndScheduleDailyWallpapers(
      config: _dailyWallpaperConfig,
      isDark: isDark,
      l10n: l10n,
    );
  }

  Future<bool> applyTodayWallpaperNow({
    required GlobalKey boundaryKey,
    required bool isDark,
    required AppLocalizations l10n,
  }) async {
    final filePath =
        await _dailyWallpaperService.captureAndSaveTodayFromBoundary(
      boundaryKey: boundaryKey,
    );
    final applied = await _dailyWallpaperService.applyWallpaperNow(
      filePath: filePath,
      target: _dailyWallpaperConfig.target,
    );
    if (applied) {
      final todayKey = DailyWallpaperService.formatDateKey(DateTime.now());
      _dailyWallpaperConfig =
          _dailyWallpaperConfig.copyWith(lastAppliedDate: todayKey);
      await _storage?.saveDailyWallpaperConfig(_dailyWallpaperConfig);
      notifyListeners();
    }
    if (_dailyWallpaperConfig.enabled) {
      // Refresh remaining 6 days asynchronously so schedule stays aligned.
      await _preRenderAndScheduleDailyWallpapers(
        config: _dailyWallpaperConfig,
        isDark: isDark,
        l10n: l10n,
      );
    }
    return applied;
  }

  Future<QuoteCardExportOutcome> saveTodayWallpaperForIos({
    required GlobalKey boundaryKey,
    String? quoteText,
    String? authorName,
  }) async {
    final bytes = await _dailyWallpaperService.exportService.captureBoundaryPng(
      boundaryKey,
      pixelRatio: DailyWallpaperService.defaultPixelRatio,
    );
    final text = quoteText ?? featuredQuote.quoteText;
    final author = authorName ?? featuredQuote.author;
    return _dailyWallpaperService.saveForIosManualUse(
      pngBytes: bytes,
      shareText: '“$text” — $author (Nestin)',
    );
  }
}
