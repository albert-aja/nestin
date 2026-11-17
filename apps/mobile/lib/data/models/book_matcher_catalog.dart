import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_localizations.dart';
import 'interactive_experience_models.dart';

/// Six core literary & non-fiction genres in Pippin's Reading Taste & Next-Book Matcher.
enum BookMatcherGenre {
  cozyFiction,
  natureAndScience,
  mindfulNonFiction,
  philosophy,
  historicalAdventure,
  indonesianAndWorldLit,
}

extension BookMatcherGenreExt on BookMatcherGenre {
  String get titleKey {
    switch (this) {
      case BookMatcherGenre.cozyFiction:
        return 'bm_genre_cozy_fiction';
      case BookMatcherGenre.natureAndScience:
        return 'bm_genre_nature_science';
      case BookMatcherGenre.mindfulNonFiction:
        return 'bm_genre_mindful_nonfiction';
      case BookMatcherGenre.philosophy:
        return 'bm_genre_philosophy';
      case BookMatcherGenre.historicalAdventure:
        return 'bm_genre_historical_adventure';
      case BookMatcherGenre.indonesianAndWorldLit:
        return 'bm_genre_indo_world_lit';
    }
  }

  String get label => AppLocalizations.current.tr(titleKey);

  String get iconEmoji {
    switch (this) {
      case BookMatcherGenre.cozyFiction:
        return '☕';
      case BookMatcherGenre.natureAndScience:
        return '🌿';
      case BookMatcherGenre.mindfulNonFiction:
        return '🕯️';
      case BookMatcherGenre.philosophy:
        return '🏛️';
      case BookMatcherGenre.historicalAdventure:
        return '🧭';
      case BookMatcherGenre.indonesianAndWorldLit:
        return '🌏';
    }
  }

  /// Maps to ReadingItem.category values used in ReadingTrackerSheet.
  String get readingCategory {
    switch (this) {
      case BookMatcherGenre.cozyFiction:
      case BookMatcherGenre.indonesianAndWorldLit:
        return 'Fiction';
      case BookMatcherGenre.natureAndScience:
        return 'Science';
      case BookMatcherGenre.mindfulNonFiction:
        return 'Self-Growth';
      case BookMatcherGenre.philosophy:
        return 'Creativity';
      case BookMatcherGenre.historicalAdventure:
        return 'Biography';
    }
  }

  /// Subject slug used for Tier 3 Open Library API enrichment (`openlibrary.org/subjects/<slug>.json`).
  String get openLibrarySubject {
    switch (this) {
      case BookMatcherGenre.cozyFiction:
        return 'cozy_fiction';
      case BookMatcherGenre.natureAndScience:
        return 'natural_history';
      case BookMatcherGenre.mindfulNonFiction:
        return 'mindfulness';
      case BookMatcherGenre.philosophy:
        return 'philosophy';
      case BookMatcherGenre.historicalAdventure:
        return 'exploration';
      case BookMatcherGenre.indonesianAndWorldLit:
        return 'indonesian_literature';
    }
  }
}

/// Curated or dynamically enriched book recommendation profile across Tier 1 (Offline Catalog),
/// Tier 2 (On-Device User Unread Shelf), and Tier 3 (Open Library API Enrichment).
class BookRecommendationProfile {
  final String id;
  final String titleEn;
  final String titleId;
  final String author;
  final BookMatcherGenre genre;
  final String readingCategory;
  final int pageCount;
  final int avgChapterMinutes;
  final String synopsisEn;
  final String synopsisId;
  final String whyItFitsEn;
  final String whyItFitsId;
  final Map<String, double> tagAffinities;
  final String pairedSerenSoundId;
  final String? isbn;
  final String? coverEditionKey;
  final bool isFromUserShelf;
  final bool isFromOnlineApi;
  final String? existingReadingItemId;

  const BookRecommendationProfile({
    required this.id,
    required this.titleEn,
    String? titleId,
    required this.author,
    required this.genre,
    required this.readingCategory,
    required this.pageCount,
    this.avgChapterMinutes = 15,
    required this.synopsisEn,
    String? synopsisId,
    required this.whyItFitsEn,
    String? whyItFitsId,
    required this.tagAffinities,
    required this.pairedSerenSoundId,
    this.isbn,
    this.coverEditionKey,
    this.isFromUserShelf = false,
    this.isFromOnlineApi = false,
    this.existingReadingItemId,
  })  : titleId = titleId ?? titleEn,
        synopsisId = synopsisId ?? synopsisEn,
        whyItFitsId = whyItFitsId ?? whyItFitsEn;

  String get localizedTitle =>
      AppLocalizations.currentLanguage == AppLanguage.id ? titleId : titleEn;

  String get localizedSynopsis =>
      AppLocalizations.currentLanguage == AppLanguage.id
          ? synopsisId
          : synopsisEn;

  String get localizedWhyItFits =>
      AppLocalizations.currentLanguage == AppLanguage.id
          ? whyItFitsId
          : whyItFitsEn;

  String localizedTitleFor(String langCode) =>
      langCode.toLowerCase().startsWith('id') ? titleId : titleEn;

  String localizedSynopsisFor(String langCode) =>
      langCode.toLowerCase().startsWith('id') ? synopsisId : synopsisEn;

  String localizedWhyItFitsFor(String langCode) =>
      langCode.toLowerCase().startsWith('id') ? whyItFitsId : whyItFitsEn;

  String get iconEmoji => genre.iconEmoji;

  int get tierSource => isFromOnlineApi ? 3 : (isFromUserShelf ? 2 : 1);

  /// Canonical Seren sound ID normalizing shorthand aliases (`nylon_guitar`, `gentle_rain`, `warm_piano`).
  String get canonicalSerenSoundId =>
      BookMatcherCatalog.normalizeSerenSoundId(pairedSerenSoundId);

  /// Optional Open Library cover thumbnail URL (`covers.openlibrary.org`).
  String? get coverImageUrl {
    if (coverEditionKey != null && coverEditionKey!.isNotEmpty) {
      if (RegExp(r'^\d+$').hasMatch(coverEditionKey!)) {
        return 'https://covers.openlibrary.org/b/id/$coverEditionKey-M.jpg';
      }
      return 'https://covers.openlibrary.org/b/olid/$coverEditionKey-M.jpg';
    }
    if (isbn != null && isbn!.isNotEmpty) {
      return 'https://covers.openlibrary.org/b/isbn/$isbn-M.jpg';
    }
    return null;
  }

  /// Estimates days to finish based on [dailyMinutes] (~0.85 pages per minute average pace).
  int estimatedDaysToFinish(int dailyMinutes) {
    final safeMins = dailyMinutes.clamp(5, 180);
    final pagesPerDay = (safeMins * 0.85).round().clamp(4, 150);
    return (pageCount / pagesPerDay).ceil().clamp(1, 365);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleEn': titleEn,
        'titleId': titleId,
        'author': author,
        'genre': genre.name,
        'readingCategory': readingCategory,
        'pageCount': pageCount,
        'avgChapterMinutes': avgChapterMinutes,
        'synopsisEn': synopsisEn,
        'synopsisId': synopsisId,
        'whyItFitsEn': whyItFitsEn,
        'whyItFitsId': whyItFitsId,
        'tagAffinities': tagAffinities,
        'pairedSerenSoundId': pairedSerenSoundId,
        'isbn': isbn,
        'coverEditionKey': coverEditionKey,
        'isFromUserShelf': isFromUserShelf,
        'isFromOnlineApi': isFromOnlineApi,
        'existingReadingItemId': existingReadingItemId,
      };

  factory BookRecommendationProfile.fromJson(Map<String, dynamic> json) {
    final genreName = json['genre'] as String? ?? 'cozyFiction';
    final parsedGenre = BookMatcherGenre.values.firstWhere(
      (g) => g.name == genreName,
      orElse: () => BookMatcherGenre.cozyFiction,
    );
    final rawTags = json['tagAffinities'] as Map<String, dynamic>? ?? const {};
    final parsedTags = <String, double>{};
    rawTags.forEach((k, v) {
      if (v is num) parsedTags[k] = v.toDouble();
    });

    return BookRecommendationProfile(
      id: json['id'] as String? ?? 'bm_custom',
      titleEn: json['titleEn'] as String? ?? 'Untitled Book',
      titleId: json['titleId'] as String?,
      author: json['author'] as String? ?? 'Unknown Author',
      genre: parsedGenre,
      readingCategory:
          json['readingCategory'] as String? ?? parsedGenre.readingCategory,
      pageCount: ((json['pageCount'] as num?)?.toInt() ?? 240).clamp(20, 2000),
      avgChapterMinutes:
          ((json['avgChapterMinutes'] as num?)?.toInt() ?? 15).clamp(5, 90),
      synopsisEn: json['synopsisEn'] as String? ?? '',
      synopsisId: json['synopsisId'] as String?,
      whyItFitsEn: json['whyItFitsEn'] as String? ?? '',
      whyItFitsId: json['whyItFitsId'] as String?,
      tagAffinities: parsedTags,
      pairedSerenSoundId:
          json['pairedSerenSoundId'] as String? ?? 'gentlePiano',
      isbn: json['isbn'] as String?,
      coverEditionKey: json['coverEditionKey'] as String?,
      isFromUserShelf: json['isFromUserShelf'] as bool? ?? false,
      isFromOnlineApi: json['isFromOnlineApi'] as bool? ?? false,
      existingReadingItemId: json['existingReadingItemId'] as String?,
    );
  }
}

/// Bundled Tier-1 Offline Catalog (42 curated timeless books) & 6-Step Questionnaire
/// for Pippin's Reading Taste & Next-Book Matcher (`book_matcher_v1`).
class BookMatcherCatalog {
  static const String bookMatcherId = 'book_matcher_v1';

  /// Resolves shorthand sound aliases (`nylon_guitar`, `gentle_rain`, `warm_piano`)
  /// to canonical `SerenRelaxationCatalog` sound IDs.
  static String normalizeSerenSoundId(String rawSoundId) {
    switch (rawSoundId) {
      case 'nylon_guitar':
      case 'nylonAcousticGuitar':
        return 'nylonAcousticGuitar';
      case 'gentle_rain':
      case 'rain':
        return 'rain';
      case 'warm_piano':
      case 'gentlePiano':
        return 'gentlePiano';
      case 'forest_stream':
      case 'riverStream':
        return 'riverStream';
      case 'singing_bowls':
      case 'singingBowls':
        return 'singingBowls';
      case 'soft_kalimba':
      case 'softKalimba':
        return 'softKalimba';
      case 'warm_cello':
      case 'warmCelloDrone':
        return 'warmCelloDrone';
      default:
        return rawSoundId;
    }
  }

  /// 6-step interactive questionnaire definition for `book_matcher_v1`.
  static const ExperienceDefinition definition = ExperienceDefinition(
    id: bookMatcherId,
    version: 1,
    titleKey: 'bm_title',
    subtitleKey: 'bm_subtitle',
    primaryBird: 'Pippin',
    supportingBirds: ['Seren', 'Roo', 'Echo'],
    grouping: DiscoverGrouping.discoverYourself,
    status: ExperienceCandidateStatus.referenceImplemented,
    questions: [
      // Step 1: Reading Mood
      ExperienceQuestion(
        id: 'bm_q_mood',
        titleKey: 'bm_q_mood_title',
        subtitleKey: 'bm_q_mood_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'bm_opt_mood_cozy',
            labelKey: 'bm_opt_mood_cozy',
            emoji: '☕',
            tagWeights: {
              'cozy_comfort': 3.5,
              'warm_characters': 2.5,
              'cozy_fiction': 2.0,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_mood_curious',
            labelKey: 'bm_opt_mood_curious',
            emoji: '🔭',
            tagWeights: {
              'curious_learning': 3.5,
              'nature_science': 2.5,
              'observational': 2.0,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_mood_philosophical',
            labelKey: 'bm_opt_mood_philosophical',
            emoji: '🕯️',
            tagWeights: {
              'philosophical': 3.5,
              'mindful_living': 2.5,
              'philosophy': 2.0,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_mood_immersive',
            labelKey: 'bm_opt_mood_immersive',
            emoji: '🗺️',
            tagWeights: {
              'world_building': 3.5,
              'historical_adventure': 2.5,
              'indonesian_world_lit': 2.0,
            },
          ),
        ],
      ),
      // Step 2: Pacing Preference
      ExperienceQuestion(
        id: 'bm_q_pacing',
        titleKey: 'bm_q_pacing_title',
        subtitleKey: 'bm_q_pacing_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'bm_opt_pace_turner',
            labelKey: 'bm_opt_pace_turner',
            emoji: '⚡',
            tagWeights: {
              'fast_paced': 3.5,
              'narrative_drive': 2.5,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_pace_unhurried',
            labelKey: 'bm_opt_pace_unhurried',
            emoji: '🌿',
            tagWeights: {
              'unhurried': 3.5,
              'lyrical_prose': 2.5,
              'cozy_comfort': 1.5,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_pace_modular',
            labelKey: 'bm_opt_pace_modular',
            emoji: '🔖',
            tagWeights: {
              'short_chapters': 3.5,
              'mindful_living': 2.0,
              'curious_learning': 1.5,
            },
          ),
        ],
      ),
      // Step 3: Chapter & Book Length Preference
      ExperienceQuestion(
        id: 'bm_q_length',
        titleKey: 'bm_q_length_title',
        subtitleKey: 'bm_q_length_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'bm_opt_len_short',
            labelKey: 'bm_opt_len_short',
            emoji: '🍃',
            tagWeights: {
              'short_book': 3.5,
              'short_chapters': 2.0,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_len_medium',
            labelKey: 'bm_opt_len_medium',
            emoji: '📖',
            tagWeights: {
              'medium_book': 3.5,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_len_deep',
            labelKey: 'bm_opt_len_deep',
            emoji: '🏛️',
            tagWeights: {
              'deep_volume': 3.5,
              'world_building': 2.0,
            },
          ),
        ],
      ),
      // Step 4: Topic & Genre Interest (Up to 2)
      ExperienceQuestion(
        id: 'bm_q_topics',
        titleKey: 'bm_q_topics_title',
        subtitleKey: 'bm_q_topics_sub',
        type: ExperienceQuestionType.multipleChoice,
        maxSelections: 2,
        options: [
          ExperienceOption(
            id: 'bm_opt_topic_cozy_fic',
            labelKey: 'bm_genre_cozy_fiction',
            emoji: '☕',
            tagWeights: {
              'cozy_fiction': 4.0,
              'cozy_comfort': 2.5,
              'warm_characters': 2.0,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_topic_nature_sci',
            labelKey: 'bm_genre_nature_science',
            emoji: '🌿',
            tagWeights: {
              'nature_science': 4.0,
              'curious_learning': 2.5,
              'observational': 2.0,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_topic_mindful',
            labelKey: 'bm_genre_mindful_nonfiction',
            emoji: '🕯️',
            tagWeights: {
              'mindful_nonfiction': 4.0,
              'mindful_living': 2.5,
              'short_chapters': 1.5,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_topic_philosophy',
            labelKey: 'bm_genre_philosophy',
            emoji: '🏛️',
            tagWeights: {
              'philosophy': 4.0,
              'philosophical': 2.5,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_topic_history',
            labelKey: 'bm_genre_historical_adventure',
            emoji: '🧭',
            tagWeights: {
              'historical_adventure': 4.0,
              'world_building': 2.5,
              'narrative_drive': 1.5,
            },
          ),
          ExperienceOption(
            id: 'bm_opt_topic_indo_world',
            labelKey: 'bm_genre_indo_world_lit',
            emoji: '🌏',
            tagWeights: {
              'indonesian_world_lit': 4.0,
              'lyrical_prose': 2.5,
              'world_building': 1.5,
            },
          ),
        ],
      ),
      // Step 5: Daily Available Reading Minutes (Slider 10..60m, default 20m)
      ExperienceQuestion(
        id: 'bm_q_daily_mins',
        titleKey: 'bm_q_daily_mins_title',
        subtitleKey: 'bm_q_daily_mins_sub',
        type: ExperienceQuestionType.slider,
        minValue: 10.0,
        maxValue: 60.0,
        defaultValue: 20.0,
      ),
      // Step 6: Shelf Source Preference (Curated + Taste Boost vs Pick From My Unread Shelf)
      ExperienceQuestion(
        id: 'bm_q_shelf_mode',
        titleKey: 'bm_q_shelf_mode_title',
        subtitleKey: 'bm_q_shelf_mode_sub',
        type: ExperienceQuestionType.singleChoice,
        options: [
          ExperienceOption(
            id: 'bm_opt_mode_curated',
            labelKey: 'bm_opt_mode_curated',
            emoji: '✨',
            tagWeights: {'mode_curated': 1.0},
          ),
          ExperienceOption(
            id: 'bm_opt_mode_unread_shelf',
            labelKey: 'bm_opt_mode_unread_shelf',
            emoji: '📚',
            tagWeights: {'mode_unread_shelf': 1.0},
          ),
        ],
      ),
    ],
    hobbyProfiles: [],
  );

  /// 42 hand-picked timeless books across 6 genres (7 per genre) for 0ms offline matching.
  static const List<BookRecommendationProfile> curatedBooks = [
    // =========================================================================
    // 1. COZY FICTION (7 Books)
    // =========================================================================
    BookRecommendationProfile(
      id: 'bm_cozy_coffee',
      titleEn: 'Before the Coffee Gets Cold',
      titleId: 'Sebelum Kopi Dingin (Before the Coffee Gets Cold)',
      author: 'Toshikazu Kawaguchi',
      genre: BookMatcherGenre.cozyFiction,
      readingCategory: 'Fiction',
      pageCount: 213,
      avgChapterMinutes: 15,
      isbn: '9781529029581',
      synopsisEn:
          'In a quiet Tokyo basement café, four visitors sit in a special seat that lets them travel back in time—as long as they return before their coffee cools.',
      synopsisId:
          'Di sebuah kafe ruang bawah tanah Tokyo yang tenang, empat pengunjung duduk di kursi khusus untuk kembali ke masa lalu—asalkan kembali sebelum kopi mereka dingin.',
      whyItFitsEn:
          'Warm, emotionally restorative linked stories with a gentle café atmosphere.',
      whyItFitsId:
          'Kisah hangat yang menyentuh hati dengan suasana kafe yang menenangkan.',
      tagAffinities: {
        'cozy_fiction': 4.5,
        'cozy_comfort': 4.0,
        'warm_characters': 3.5,
        'short_book': 3.0,
        'short_chapters': 2.5,
        'unhurried': 2.5,
      },
      pairedSerenSoundId: 'nylon_guitar',
    ),
    BookRecommendationProfile(
      id: 'bm_cozy_kamogawa',
      titleEn: 'The Kamogawa Food Detectives',
      titleId: 'Detektif Kuliner Kamogawa',
      author: 'Hisashi Kashiwai',
      genre: BookMatcherGenre.cozyFiction,
      readingCategory: 'Fiction',
      pageCount: 208,
      avgChapterMinutes: 12,
      isbn: '9781529920048',
      synopsisEn:
          'A father-daughter diner in Kyoto recreates forgotten dishes from their guests\' treasured past memories.',
      synopsisId:
          'Pasangan ayah dan anak di kedai Kyoto menghidupkan kembali hidangan masa lalu yang dirindukan para pelanggan mereka.',
      whyItFitsEn:
          'Six bite-sized episodic chapters celebrating comfort food, memory, and quiet kindness.',
      whyItFitsId:
          'Enam bab pendek hangat yang merayakan kuliner rumahan, kenangan, dan kebaikan hati.',
      tagAffinities: {
        'cozy_fiction': 4.5,
        'cozy_comfort': 4.0,
        'short_chapters': 3.5,
        'short_book': 3.0,
        'unhurried': 3.0,
      },
      pairedSerenSoundId: 'warm_piano',
    ),
    BookRecommendationProfile(
      id: 'bm_cozy_sweetbean',
      titleEn: 'Sweet Bean Paste',
      titleId: 'Pasta Kacang Merah (Sweet Bean Paste)',
      author: 'Durian Sukegawa',
      genre: BookMatcherGenre.cozyFiction,
      readingCategory: 'Fiction',
      pageCount: 216,
      avgChapterMinutes: 14,
      isbn: '9781786071958',
      synopsisEn:
          'A lone dorayaki pancake maker hires an elderly woman whose handmade sweet red bean paste transforms his small cherry-blossom shop.',
      synopsisId:
          'Pembuat dorayaki yang kesepian mempekerjakan seorang nenek yang racikan pasta kacang merahnya mengubah kedai kecil di bawah pohon sakura.',
      whyItFitsEn:
          'A tender, deeply humane story about craft, dignity, and seasonal beauty.',
      whyItFitsId:
          'Kisah lembut penuh empati tentang ketekunan meracik rasa dan keindahan musim.',
      tagAffinities: {
        'cozy_fiction': 4.0,
        'cozy_comfort': 3.5,
        'warm_characters': 4.0,
        'philosophical': 2.0,
        'short_book': 3.0,
      },
      pairedSerenSoundId: 'gentle_rain',
    ),
    BookRecommendationProfile(
      id: 'bm_cozy_morisaki',
      titleEn: 'Days at the Morisaki Bookshop',
      titleId: 'Hari-Hari di Toko Buku Morisaki',
      author: 'Satoshi Yagisawa',
      genre: BookMatcherGenre.cozyFiction,
      readingCategory: 'Fiction',
      pageCount: 160,
      avgChapterMinutes: 12,
      isbn: '9780063278677',
      synopsisEn:
          'Heartbroken twenty-five-year-old Takako moves into the tiny room above her eccentric uncle\'s secondhand bookshop in Tokyo\'s Jinbōchō book district.',
      synopsisId:
          'Takako pindah ke kamar mungil di lantai atas toko buku bekas milik pamannya di distrik buku Jinbōchō, Tokyo, dan menemukan semangat baru lewat membaca.',
      whyItFitsEn:
          'A love letter to quiet afternoons surrounded by towering stacks of paperbacks.',
      whyItFitsId:
          'Surat cinta untuk sore yang tenang di tengah tumpukan buku dan aroma kertas tua.',
      tagAffinities: {
        'cozy_fiction': 4.5,
        'cozy_comfort': 4.2,
        'short_book': 4.0,
        'short_chapters': 3.0,
        'unhurried': 3.0,
      },
      pairedSerenSoundId: 'gentle_rain',
    ),
    BookRecommendationProfile(
      id: 'bm_cozy_psalm_wild',
      titleEn: 'A Psalm for the Wild-Built',
      titleId: 'Mazmur bagi Alam Liar (A Psalm for the Wild-Built)',
      author: 'Becky Chambers',
      genre: BookMatcherGenre.cozyFiction,
      readingCategory: 'Fiction',
      pageCount: 160,
      avgChapterMinutes: 14,
      isbn: '9781250236210',
      synopsisEn:
          'A traveling tea monk and a curious forest-dwelling robot share tea and gentle philosophical conversations across a lush, healed world.',
      synopsisId:
          'Seorang biarawan peracik teh keliling dan robot pencinta hutan berbagi teh serta percakapan filosofis hangat di alam yang asri.',
      whyItFitsEn:
          'Hopeful solarpunk warmth that feels like a deep exhale and a hot cup of tea.',
      whyItFitsId:
          'Kehangatan penuh harapan yang terasa seperti hembusan napas lega dan secangkir teh hangat.',
      tagAffinities: {
        'cozy_fiction': 4.0,
        'cozy_comfort': 4.0,
        'philosophical': 3.0,
        'short_book': 4.0,
        'unhurried': 3.0,
      },
      pairedSerenSoundId: 'forest_stream',
    ),
    BookRecommendationProfile(
      id: 'bm_cozy_cat_library',
      titleEn: 'What You Are Looking For Is in the Library',
      titleId: 'Apa yang Kau Cari Ada di Perpustakaan',
      author: 'Michiko Aoyama',
      genre: BookMatcherGenre.cozyFiction,
      readingCategory: 'Fiction',
      pageCount: 288,
      avgChapterMinutes: 16,
      isbn: '9781399713313',
      synopsisEn:
          'An enigmatic community librarian asks visitors "What are you looking for?" and hands them one unexpected book alongside a felted wool charm.',
      synopsisId:
          'Pustakawan bijak bertanya "Apa yang sedang Anda cari?" lalu memberikan satu buku tak terduga beserta boneka rajut wol kecil yang mengubah hidup mereka.',
      whyItFitsEn:
          'Uplifting interconnected tales about finding gentle direction at life\'s crossroads.',
      whyItFitsId:
          'Rangkaian kisah hangat tentang menemukan arah baru lewat rekomendasi buku yang tepat.',
      tagAffinities: {
        'cozy_fiction': 4.5,
        'cozy_comfort': 3.8,
        'warm_characters': 3.8,
        'medium_book': 3.0,
        'short_chapters': 2.8,
      },
      pairedSerenSoundId: 'warm_piano',
    ),
    BookRecommendationProfile(
      id: 'bm_cozy_anne',
      titleEn: 'Anne of Green Gables',
      titleId: 'Anne dari Green Gables',
      author: 'L.M. Montgomery',
      genre: BookMatcherGenre.cozyFiction,
      readingCategory: 'Fiction',
      pageCount: 320,
      avgChapterMinutes: 15,
      isbn: '9780141321592',
      synopsisEn:
          'Imaginative red-haired orphan Anne Shirley brings wonder, mishaps, and boundless affection to Green Gables farm on Prince Edward Island.',
      synopsisId:
          'Gadis yatim penuh imajinasi Anne Shirley membawa keajaiban dan kehangatan ke pertanian Green Gables yang asri.',
      whyItFitsEn:
          'Timeless pastoral charm filled with blossom-lined lanes and kindred spirits.',
      whyItFitsId:
          'Klasik abadi penuh keindahan pedesaan, persahabatan tulus, dan imajinasi ceria.',
      tagAffinities: {
        'cozy_fiction': 4.2,
        'cozy_comfort': 4.0,
        'warm_characters': 4.0,
        'medium_book': 3.0,
        'lyrical_prose': 2.5,
      },
      pairedSerenSoundId: 'soft_kalimba',
    ),

    // =========================================================================
    // 2. NATURE & SCIENCE (7 Books)
    // =========================================================================
    BookRecommendationProfile(
      id: 'bm_nat_sweetgrass',
      titleEn: 'Braiding Sweetgrass',
      titleId: 'Merajut Rumput Manis (Braiding Sweetgrass)',
      author: 'Robin Wall Kimmerer',
      genre: BookMatcherGenre.natureAndScience,
      readingCategory: 'Science',
      pageCount: 390,
      avgChapterMinutes: 18,
      isbn: '9781571313560',
      synopsisEn:
          'A botanist and Indigenous storyteller weaves plant ecology, wild strawberries, and gratitude for the living earth into luminous essays.',
      synopsisId:
          'Seorang ahli botani merajut ilmu ekologi tumbuhan, kearifan alam, dan rasa syukur kepada bumi dalam esai-esai yang puitis.',
      whyItFitsEn:
          'Blends scientific wonder with deep ecological gratitude in standalone essay chapters.',
      whyItFitsId:
          'Memadukan keajaiban sains dengan rasa syukur mendalam pada alam dalam bab-bab esai yang tenang.',
      tagAffinities: {
        'nature_science': 4.5,
        'curious_learning': 3.5,
        'philosophical': 3.0,
        'unhurried': 3.5,
        'lyrical_prose': 3.5,
        'deep_volume': 3.0,
      },
      pairedSerenSoundId: 'forest_stream',
    ),
    BookRecommendationProfile(
      id: 'bm_nat_hidden_trees',
      titleEn: 'The Hidden Life of Trees',
      titleId: 'Kehidupan Rahasia Pepohonan',
      author: 'Peter Wohlleben',
      genre: BookMatcherGenre.natureAndScience,
      readingCategory: 'Science',
      pageCount: 288,
      avgChapterMinutes: 12,
      isbn: '9781771642484',
      synopsisEn:
          'A forester reveals how woodland trees communicate, share nutrients through underground fungal networks, and shelter their saplings.',
      synopsisId:
          'Seorang rimbawan mengungkap bagaimana pohon-pohon di hutan saling berkomunikasi dan berbagi nutrisi lewat jaringan jamur bawah tanah.',
      whyItFitsEn:
          'Short, eye-opening chapters that transform every walk in the park or forest.',
      whyItFitsId:
          'Bab-bab singkat penuh wawasan yang mengubah cara Anda memandang setiap pohon di sekitar.',
      tagAffinities: {
        'nature_science': 4.5,
        'curious_learning': 4.0,
        'observational': 3.5,
        'short_chapters': 3.5,
        'medium_book': 3.0,
      },
      pairedSerenSoundId: 'forest_stream',
    ),
    BookRecommendationProfile(
      id: 'bm_nat_immense_world',
      titleEn: 'An Immense World',
      titleId: 'Dunia yang Mahaluas (An Immense World)',
      author: 'Ed Yong',
      genre: BookMatcherGenre.natureAndScience,
      readingCategory: 'Science',
      pageCount: 464,
      avgChapterMinutes: 22,
      isbn: '9780593133231',
      synopsisEn:
          'An exhilarating tour through animal senses—from songbirds reading Earth\'s magnetic field to bees seeing ultraviolet floral bullseyes.',
      synopsisId:
          'Penjelajahan menakjubkan tentang indra hewan—dari burung yang membaca medan magnet Bumi hingga lebah yang melihat pola ultraviolet bunga.',
      whyItFitsEn:
          'Pure scientific curiosity that expands how you perceive the sensory world around you.',
      whyItFitsId:
          'Rasa ingin tahu sains murni yang memperluas cara Anda memahami keajaiban indra makhluk hidup.',
      tagAffinities: {
        'nature_science': 4.5,
        'curious_learning': 4.5,
        'observational': 3.5,
        'deep_volume': 3.5,
        'narrative_drive': 2.5,
      },
      pairedSerenSoundId: 'soft_kalimba',
    ),
    BookRecommendationProfile(
      id: 'bm_nat_entangled',
      titleEn: 'Entangled Life',
      titleId: 'Jalinan Kehidupan Jamur (Entangled Life)',
      author: 'Merlin Sheldrake',
      genre: BookMatcherGenre.natureAndScience,
      readingCategory: 'Science',
      pageCount: 352,
      avgChapterMinutes: 18,
      isbn: '9780525510314',
      synopsisEn:
          'Explores the hidden kingdom of fungi that builds soil, links forest ecosystems, and challenges our notion of individuality.',
      synopsisId:
          'Menjelajahi kerajaan jamur tersembunyi yang menyuburkan tanah, menghubungkan ekosistem hutan, dan menantang batas individualitas.',
      whyItFitsEn:
          'Fascinating biology told with poetic wonder and adventurous field stories.',
      whyItFitsId:
          'Biologi memikat yang dituturkan dengan rasa takjub dan kisah penelitian lapangan yang seru.',
      tagAffinities: {
        'nature_science': 4.5,
        'curious_learning': 4.0,
        'medium_book': 3.0,
        'observational': 3.0,
      },
      pairedSerenSoundId: 'gentle_rain',
    ),
    BookRecommendationProfile(
      id: 'bm_nat_living_mountain',
      titleEn: 'The Living Mountain',
      titleId: 'Gunung yang Hidup (The Living Mountain)',
      author: 'Nan Shepherd',
      genre: BookMatcherGenre.natureAndScience,
      readingCategory: 'Science',
      pageCount: 128,
      avgChapterMinutes: 12,
      isbn: '9780857861832',
      synopsisEn:
          'A meditative masterpiece of walking into—rather than conquering—the high granite plateaus, snow-burn streams, and silence of the Cairngorms.',
      synopsisId:
          'Mahakarya meditatif tentang menyatu dengan keheningan dataran tinggi granit, sungai lelehan salju, dan kabut pegunungan.',
      whyItFitsEn:
          'Compact, lyrical nature prose ideal for slow 15-minute evening reading.',
      whyItFitsId:
          'Prosa alam ringkas dan puitis yang sangat cocok untuk bacaan malam 15 menit yang tenang.',
      tagAffinities: {
        'nature_science': 4.0,
        'philosophical': 3.5,
        'unhurried': 4.0,
        'lyrical_prose': 4.0,
        'short_book': 4.0,
      },
      pairedSerenSoundId: 'nylon_guitar',
    ),
    BookRecommendationProfile(
      id: 'bm_nat_under_sea_wind',
      titleEn: 'Under the Sea-Wind',
      titleId: 'Di Bawah Angin Laut (Under the Sea-Wind)',
      author: 'Rachel Carson',
      genre: BookMatcherGenre.natureAndScience,
      readingCategory: 'Science',
      pageCount: 272,
      avgChapterMinutes: 16,
      isbn: '9780143104964',
      synopsisEn:
          'Follows shorebirds, mackerel, and silver eels across moonlit tides and deep ocean currents with luminous marine observation.',
      synopsisId:
          'Mengikuti perjalanan burung pantai dan arus samudra di bawah sinar bulan dengan pengamatan biologi laut yang sangat indah.',
      whyItFitsEn:
          'Soothing oceanic imagery paired with timeless natural history.',
      whyItFitsId:
          'Gambaran laut yang menenangkan berpadu dengan kisah sejarah alam yang memikat.',
      tagAffinities: {
        'nature_science': 4.2,
        'unhurried': 3.5,
        'lyrical_prose': 3.5,
        'medium_book': 3.0,
      },
      pairedSerenSoundId: 'gentle_rain',
    ),
    BookRecommendationProfile(
      id: 'bm_nat_cosmos',
      titleEn: 'Cosmos',
      titleId: 'Kosmos (Cosmos)',
      author: 'Carl Sagan',
      genre: BookMatcherGenre.natureAndScience,
      readingCategory: 'Science',
      pageCount: 396,
      avgChapterMinutes: 20,
      isbn: '9780345539434',
      synopsisEn:
          'A sweeping, poetic journey through 14 billion years of cosmic evolution, starlight, and humanity\'s quest to understand the universe.',
      synopsisId:
          'Perjalanan puitis melintasi 14 miliar tahun evolusi kosmik, cahaya bintang, dan pencarian manusia memahami alam semesta.',
      whyItFitsEn:
          'Combines grand astronomical perspective with deeply comforting human wonder.',
      whyItFitsId:
          'Memadukan cakrawala astronomi yang luas dengan rasa takjub yang menenangkan pikiran.',
      tagAffinities: {
        'nature_science': 4.5,
        'curious_learning': 4.2,
        'philosophical': 3.0,
        'deep_volume': 3.0,
      },
      pairedSerenSoundId: 'warm_cello',
    ),

    // =========================================================================
    // 3. MINDFUL NON-FICTION (7 Books)
    // =========================================================================
    BookRecommendationProfile(
      id: 'bm_mind_creative_act',
      titleEn: 'The Creative Act: A Way of Being',
      titleId: 'Tindakan Kreatif (The Creative Act)',
      author: 'Rick Rubin',
      genre: BookMatcherGenre.mindfulNonFiction,
      readingCategory: 'Creativity',
      pageCount: 406,
      avgChapterMinutes: 10,
      isbn: '9780593652886',
      synopsisEn:
          'Seventy-eight short, meditative reflections on tuning in to everyday curiosity, silence, and creative flow without self-judgment.',
      synopsisId:
          'Tujuh puluh delapan bab pendek meditatif tentang kepekaan mengamati keseharian, keheningan, dan aliran kreativitas.',
      whyItFitsEn:
          'Each 3-page chapter can be savored in 10 quiet minutes before sleep or work.',
      whyItFitsId:
          'Setiap bab singkatnya dapat dinikmati dalam 10 menit tenang sebelum tidur atau berkarya.',
      tagAffinities: {
        'mindful_nonfiction': 4.5,
        'mindful_living': 4.0,
        'philosophical': 3.5,
        'short_chapters': 4.5,
        'unhurried': 3.5,
      },
      pairedSerenSoundId: 'singing_bowls',
    ),
    BookRecommendationProfile(
      id: 'bm_mind_atomic_habits',
      titleEn: 'Atomic Habits',
      titleId: 'Kebiasaan Atom (Atomic Habits)',
      author: 'James Clear',
      genre: BookMatcherGenre.mindfulNonFiction,
      readingCategory: 'Self-Growth',
      pageCount: 320,
      avgChapterMinutes: 16,
      isbn: '9780735211292',
      synopsisEn:
          'A practical, encouraging guide to building tiny 1% daily habits that compound into lasting personal transformation.',
      synopsisId:
          'Panduan praktis dan ramah untuk membangun kebiasaan kecil 1% setiap hari yang bertumbuh menjadi perubahan besar.',
      whyItFitsEn:
          'Actionable, clear chapters that pair naturally with your Nestin daily routines.',
      whyItFitsId:
          'Bab-bab jernih dan aplikatif yang selaras dengan rutinitas harian Anda di Nestin.',
      tagAffinities: {
        'mindful_nonfiction': 4.2,
        'curious_learning': 3.5,
        'fast_paced': 3.5,
        'medium_book': 3.5,
        'short_chapters': 2.5,
      },
      pairedSerenSoundId: 'warm_piano',
    ),
    BookRecommendationProfile(
      id: 'bm_mind_deep_work',
      titleEn: 'Deep Work',
      titleId: 'Kerja Fokus Mendalam (Deep Work)',
      author: 'Cal Newport',
      genre: BookMatcherGenre.mindfulNonFiction,
      readingCategory: 'Productivity',
      pageCount: 296,
      avgChapterMinutes: 18,
      isbn: '9781455586691',
      synopsisEn:
          'Explores how cultivating calm, distraction-free concentration creates meaningful craft and protects restful evenings.',
      synopsisId:
          'Membahas bagaimana melatih fokus tenang bebas gangguan menghasilkan karya bermakna sekaligus melindungi waktu istirahat malam.',
      whyItFitsEn:
          'Sharp, motivating insights on digital calm and intentional focus blocks.',
      whyItFitsId:
          'Wawasan tajam dan memotivasi tentang ketenangan digital serta blok waktu fokus.',
      tagAffinities: {
        'mindful_nonfiction': 4.0,
        'curious_learning': 3.5,
        'fast_paced': 3.0,
        'medium_book': 3.5,
      },
      pairedSerenSoundId: 'gentle_rain',
    ),
    BookRecommendationProfile(
      id: 'bm_mind_four_thousand',
      titleEn: 'Four Thousand Weeks: Time Management for Mortals',
      titleId: 'Empat Ribu Minggu (Four Thousand Weeks)',
      author: 'Oliver Burkeman',
      genre: BookMatcherGenre.mindfulNonFiction,
      readingCategory: 'Self-Growth',
      pageCount: 288,
      avgChapterMinutes: 16,
      isbn: '9780374159122',
      synopsisEn:
          'A witty, liberating antidote to hustle culture that invites you to embrace finitude and choose what truly matters today.',
      synopsisId:
          'Bacaan hangat yang membebaskan kita dari tekanan serba terburu-buru agar hadir utuh pada hal yang sungguh bermakna hari ini.',
      whyItFitsEn:
          'Relieves productivity guilt with humor, philosophy, and grounded wisdom.',
      whyItFitsId:
          'Meredakan beban harus selalu produktif lewat humor hangat dan filosofi yang membumi.',
      tagAffinities: {
        'mindful_nonfiction': 4.5,
        'philosophical': 4.0,
        'mindful_living': 4.0,
        'medium_book': 3.5,
      },
      pairedSerenSoundId: 'warm_cello',
    ),
    BookRecommendationProfile(
      id: 'bm_mind_slow_down',
      titleEn: 'The Things You Can See Only When You Slow Down',
      titleId: 'Hal-Hal yang Hanya Terlihat Saat Kita Melambat',
      author: 'Haemin Sunim',
      genre: BookMatcherGenre.mindfulNonFiction,
      readingCategory: 'Self-Growth',
      pageCount: 288,
      avgChapterMinutes: 10,
      isbn: '9780143130772',
      synopsisEn:
          'Illustrated essays and short aphorisms on rest, relationships, mindfulness, and self-compassion amidst a busy world.',
      synopsisId:
          'Esai bergambar dan kutipan pendek menenangkan tentang istirahat, relasi, dan welas asih di tengah dunia yang sibuk.',
      whyItFitsEn:
          'Gentle bite-sized pages designed specifically for calm morning or bedtime reflection.',
      whyItFitsId:
          'Halaman-halaman singkat nan lembut yang dirancang khusus untuk refleksi pagi atau pengantar tidur.',
      tagAffinities: {
        'mindful_nonfiction': 4.5,
        'mindful_living': 4.5,
        'cozy_comfort': 3.5,
        'short_chapters': 4.5,
        'unhurried': 4.0,
      },
      pairedSerenSoundId: 'singing_bowls',
    ),
    BookRecommendationProfile(
      id: 'bm_mind_ikigai',
      titleEn: 'Ikigai: The Japanese Secret to a Long and Happy Life',
      titleId: 'Ikigai: Rahasia Hidup Bahagia & Panjang Umur',
      author: 'Héctor García & Francesc Miralles',
      genre: BookMatcherGenre.mindfulNonFiction,
      readingCategory: 'Self-Growth',
      pageCount: 208,
      avgChapterMinutes: 12,
      isbn: '9780143130727',
      synopsisEn:
          'Visits Okinawa\'s centenarian village to uncover daily rituals of purpose, vegetable gardens, unhurried movement, and community.',
      synopsisId:
          'Mengunjungi desa panjang umur di Okinawa untuk mempelajari kebiasaan harian tentang makna hidup, berkebun, dan ketenangan.',
      whyItFitsEn:
          'Light, inspiring, and compact—easy to read in 15-minute daily sessions.',
      whyItFitsId:
          'Ringan, inspiratif, dan ringkas—sangat nyaman dibaca 15 menit setiap hari.',
      tagAffinities: {
        'mindful_nonfiction': 4.2,
        'mindful_living': 4.0,
        'short_book': 3.8,
        'short_chapters': 3.5,
      },
      pairedSerenSoundId: 'soft_kalimba',
    ),
    BookRecommendationProfile(
      id: 'bm_mind_rest',
      titleEn: 'Rest: Why You Get More Done When You Work Less',
      titleId: 'Seni Beristirahat (Rest)',
      author: 'Alex Soojung-Kim Pang',
      genre: BookMatcherGenre.mindfulNonFiction,
      readingCategory: 'Self-Growth',
      pageCount: 304,
      avgChapterMinutes: 16,
      isbn: '9780465095773',
      synopsisEn:
          'Examines the daily schedules of Darwin, Dickens, and scientists to show how deliberate rest, long walks, and naps fuel creativity.',
      synopsisId:
          'Menelusuri jadwal harian ilmuwan dan penulis besar untuk membuktikan bahwa istirahat berkualitas dan jalan santai menyuburkan kreativitas.',
      whyItFitsEn:
          'Fascinating historical stories that validate taking peaceful daily breaks.',
      whyItFitsId:
          'Kisah sejarah menarik yang menegaskan pentingnya mengambil jeda istirahat setiap hari.',
      tagAffinities: {
        'mindful_nonfiction': 4.2,
        'curious_learning': 3.5,
        'medium_book': 3.5,
        'unhurried': 3.0,
      },
      pairedSerenSoundId: 'nylon_guitar',
    ),

    // =========================================================================
    // 4. PHILOSOPHY (7 Books)
    // =========================================================================
    BookRecommendationProfile(
      id: 'bm_phil_meditations',
      titleEn: 'Meditations',
      titleId: 'Meditasi (Meditations)',
      author: 'Marcus Aurelius',
      genre: BookMatcherGenre.philosophy,
      readingCategory: 'Creativity',
      pageCount: 254,
      avgChapterMinutes: 10,
      isbn: '9780812968255',
      synopsisEn:
          'Private evening notebooks written by a Roman emperor reminding himself to practice equanimity, kindness, and perspective.',
      synopsisId:
          'Catatan harian pribadi kaisar Romawi yang mengingatkan dirinya sendiri untuk menjaga ketenangan batin, kebajikan, dan kejernihan.',
      whyItFitsEn:
          'Timeless paragraph-length reflections you can open to any page at night.',
      whyItFitsId:
          'Refleksi singkat lintas zaman yang dapat dibuka di halaman mana saja pada malam hari.',
      tagAffinities: {
        'philosophy': 4.5,
        'philosophical': 4.5,
        'mindful_living': 3.5,
        'short_chapters': 4.0,
        'medium_book': 3.0,
      },
      pairedSerenSoundId: 'warm_cello',
    ),
    BookRecommendationProfile(
      id: 'bm_phil_letters_stoic',
      titleEn: 'Letters from a Stoic',
      titleId: 'Surat-Surat Seorang Stoik (Letters from a Stoic)',
      author: 'Seneca',
      genre: BookMatcherGenre.philosophy,
      readingCategory: 'Creativity',
      pageCount: 256,
      avgChapterMinutes: 12,
      isbn: '9780140442106',
      synopsisEn:
          'Warm, conversational letters to a friend on friendship, time, simplicity, and staying calm amid life\'s storms.',
      synopsisId:
          'Surat-surat hangat kepada sahabat tentang persahabatan, menghargai waktu, kesederhanaan, dan ketenangan menghadapi hidup.',
      whyItFitsEn:
          'Reads like wise, personal letters from an old friend—one letter per evening.',
      whyItFitsId:
          'Terasa seperti membaca surat pribadi yang hangat dari sahabat bijak—satu surat setiap malam.',
      tagAffinities: {
        'philosophy': 4.5,
        'philosophical': 4.2,
        'short_chapters': 3.8,
        'medium_book': 3.0,
      },
      pairedSerenSoundId: 'warm_piano',
    ),
    BookRecommendationProfile(
      id: 'bm_phil_book_of_tea',
      titleEn: 'The Book of Tea',
      titleId: 'Kitab Teh (The Book of Tea)',
      author: 'Kakuzō Okakura',
      genre: BookMatcherGenre.philosophy,
      readingCategory: 'Creativity',
      pageCount: 128,
      avgChapterMinutes: 12,
      isbn: '9780486200705',
      synopsisEn:
          'A classic 1906 essay exploring tea aesthetics, Wabi-Sabi imperfection, architecture of the tearoom, and appreciation of flowers.',
      synopsisId:
          'Esai klasik tahun 1906 yang menyelami estetika teh, keindahan kesederhanaan Wabi-Sabi, ruang teh yang hening, dan apresiasi bunga.',
      whyItFitsEn:
          'Short, poetic, and steeped in quiet aesthetic contemplation.',
      whyItFitsId:
          'Singkat, puitis, dan sarat perenungan estetika yang menenteramkan hati.',
      tagAffinities: {
        'philosophy': 4.5,
        'philosophical': 4.0,
        'unhurried': 4.0,
        'short_book': 4.2,
        'lyrical_prose': 3.5,
      },
      pairedSerenSoundId: 'singing_bowls',
    ),
    BookRecommendationProfile(
      id: 'bm_phil_courage_disliked',
      titleEn: 'The Courage to Be Disliked',
      titleId: 'Berani Tidak Disukai (The Courage to Be Disliked)',
      author: 'Ichiro Kishimi & Fumitake Koga',
      genre: BookMatcherGenre.philosophy,
      readingCategory: 'Self-Growth',
      pageCount: 288,
      avgChapterMinutes: 16,
      isbn: '9781501197277',
      synopsisEn:
          'Structured as five evening dialogues in a quiet study between a philosopher and a young visitor exploring Adlerian freedom and self-acceptance.',
      synopsisId:
          'Disusun dalam lima percakapan malam di ruang baca tenang antara seorang filsuf dan pemuda tentang kebebasan batin serta penerimaan diri.',
      whyItFitsEn:
          'Engaging Socratic dialogue that flows quickly while sparking deep reflection.',
      whyItFitsId:
          'Format dialog mengalir yang mudah diikuti sekaligus memantik perenungan mendalam.',
      tagAffinities: {
        'philosophy': 4.2,
        'philosophical': 4.0,
        'mindful_nonfiction': 3.5,
        'fast_paced': 3.0,
        'medium_book': 3.5,
      },
      pairedSerenSoundId: 'nylon_guitar',
    ),
    BookRecommendationProfile(
      id: 'bm_phil_mans_search',
      titleEn: 'Man\'s Search for Meaning',
      titleId: 'Mencari Makna Hidup (Man\'s Search for Meaning)',
      author: 'Viktor E. Frankl',
      genre: BookMatcherGenre.philosophy,
      readingCategory: 'Self-Growth',
      pageCount: 184,
      avgChapterMinutes: 15,
      isbn: '9780807014295',
      synopsisEn:
          'A profound reflection on human resilience and finding purpose through creative work, love, and inner dignity.',
      synopsisId:
          'Refleksi mendalam tentang ketangguhan manusia dan menemukan makna hidup melalui karya, kasih sayang, dan martabat batin.',
      whyItFitsEn:
          'A concise, life-affirming classic that leaves a lasting perspective shift.',
      whyItFitsId:
          'Klasik ringkas penggugah jiwa yang memberikan sudut pandang baru tentang makna hidup.',
      tagAffinities: {
        'philosophy': 4.5,
        'philosophical': 4.5,
        'short_book': 3.8,
        'narrative_drive': 3.0,
      },
      pairedSerenSoundId: 'warm_cello',
    ),
    BookRecommendationProfile(
      id: 'bm_phil_zen_mind',
      titleEn: 'Zen Mind, Beginner\'s Mind',
      titleId: 'Pikiran Zen, Pikiran Pemula',
      author: 'Shunryu Suzuki',
      genre: BookMatcherGenre.philosophy,
      readingCategory: 'Creativity',
      pageCount: 176,
      avgChapterMinutes: 10,
      isbn: '9781590308493',
      synopsisEn:
          'Warm, unpretentious talks on approaching posture, breathing, and everyday tasks with open curiosity ("in the beginner\'s mind there are many possibilities").',
      synopsisId:
          'Perbincangan hangat dan sederhana tentang menyambut napas serta keseharian dengan keterbukaan pikiran seorang pemula.',
      whyItFitsEn:
          'Short 4-page talks that pair effortlessly with Seren\'s breathing and meditation.',
      whyItFitsId:
          'Bab-bab pendek 4 halaman yang berpadu selaras dengan latihan napas tenang Seren.',
      tagAffinities: {
        'philosophy': 4.5,
        'philosophical': 4.2,
        'mindful_living': 4.2,
        'short_book': 4.0,
        'short_chapters': 4.0,
      },
      pairedSerenSoundId: 'singing_bowls',
    ),
    BookRecommendationProfile(
      id: 'bm_phil_consolations',
      titleEn: 'The Consolations of Philosophy',
      titleId: 'Penghiburan Filsafat (The Consolations of Philosophy)',
      author: 'Alain de Botton',
      genre: BookMatcherGenre.philosophy,
      readingCategory: 'Creativity',
      pageCount: 272,
      avgChapterMinutes: 16,
      isbn: '9780679779179',
      synopsisEn:
          'Brings Socrates, Epicurus, Seneca, and Montaigne to life as practical companions for everyday frustrations, inadequacy, and heartache.',
      synopsisId:
          'Menghadirkan Sokrates, Epikuros, Seneca, dan Montaigne sebagai sahabat praktis untuk menghadapi kegelisahan sehari-hari.',
      whyItFitsEn:
          'Warm, witty, and accessible—turns classic philosophy into everyday comfort.',
      whyItFitsId:
          'Hangat, cerdas, dan mudah dipahami—mengubah filsafat klasik menjadi penghiburan sehari-hari.',
      tagAffinities: {
        'philosophy': 4.4,
        'philosophical': 4.0,
        'curious_learning': 3.5,
        'medium_book': 3.5,
      },
      pairedSerenSoundId: 'warm_piano',
    ),

    // =========================================================================
    // 5. HISTORICAL ADVENTURE (7 Books)
    // =========================================================================
    BookRecommendationProfile(
      id: 'bm_hist_malay_arch',
      titleEn: 'The Malay Archipelago',
      titleId: 'Kepulauan Nusantara (The Malay Archipelago)',
      author: 'Alfred Russel Wallace',
      genre: BookMatcherGenre.historicalAdventure,
      readingCategory: 'Biography',
      pageCount: 515,
      avgChapterMinutes: 20,
      isbn: '9780140435450',
      synopsisEn:
          'Wallace\'s vivid 1869 expedition journal sailing 14,000 miles across Sumatra, Java, Bali, Lombok, Sulawesi, Maluku, and Papua.',
      synopsisId:
          'Catatan perjalanan legendaris Wallace tahun 1869 melayari 14.000 mil melintasi Sumatera, Jawa, Bali, Lombok, Sulawesi, Maluku, hingga Papua.',
      whyItFitsEn:
          'Rich natural history and archipelago exploration that can be read island by island.',
      whyItFitsId:
          'Petualangan sejarah alam Nusantara yang kaya dan dapat dinikmati pulau demi pulau.',
      tagAffinities: {
        'historical_adventure': 4.5,
        'nature_science': 3.8,
        'world_building': 4.0,
        'deep_volume': 4.0,
        'curious_learning': 3.5,
      },
      pairedSerenSoundId: 'forest_stream',
    ),
    BookRecommendationProfile(
      id: 'bm_hist_shadow_wind',
      titleEn: 'The Shadow of the Wind',
      titleId: 'Bayang-Bayang Angin (The Shadow of the Wind)',
      author: 'Carlos Ruiz Zafón',
      genre: BookMatcherGenre.historicalAdventure,
      readingCategory: 'Fiction',
      pageCount: 487,
      avgChapterMinutes: 18,
      isbn: '9780143034902',
      synopsisEn:
          'In 1945 Barcelona, a bookseller\'s son visits the secret "Cemetery of Forgotten Books" and chooses a mysterious novel that changes his life.',
      synopsisId:
          'Di Barcelona tahun 1945, putra penjual buku mengunjungi "Pemakaman Buku-Buku Terlupakan" dan menemukan satu novel misterius yang memikat.',
      whyItFitsEn:
          'Atmospheric, cobblestone mystery with unforgettable page-turning momentum.',
      whyItFitsId:
          'Misteri klasik bersuasana kota tua yang memikat dari halaman pertama hingga akhir.',
      tagAffinities: {
        'historical_adventure': 4.5,
        'world_building': 4.5,
        'fast_paced': 4.0,
        'narrative_drive': 4.2,
        'deep_volume': 3.8,
      },
      pairedSerenSoundId: 'gentle_rain',
    ),
    BookRecommendationProfile(
      id: 'bm_hist_invisible_cities',
      titleEn: 'Invisible Cities',
      titleId: 'Kota-Kota Tak Kasatmata (Invisible Cities)',
      author: 'Italo Calvino',
      genre: BookMatcherGenre.historicalAdventure,
      readingCategory: 'Fiction',
      pageCount: 165,
      avgChapterMinutes: 8,
      isbn: '9780156453806',
      synopsisEn:
          'In a quiet palace garden at dusk, traveler Marco Polo describes fifty-five dreamlike cities of mirrors, canals, and starlight to Kublai Khan.',
      synopsisId:
          'Di taman istana yang tenang saat senja, penjelajah Marco Polo melukiskan lima puluh lima kota imajinatif penuh kanal dan bintang kepada Kubilai Khan.',
      whyItFitsEn:
          'Two-page poetic city vignettes—ideal for 10-minute dreamy evening reading.',
      whyItFitsId:
          'Sketsa kota puitis sepanjang dua halaman—sempurna untuk bacaan malam 10 menit yang menenangkan.',
      tagAffinities: {
        'historical_adventure': 3.8,
        'world_building': 4.5,
        'lyrical_prose': 4.5,
        'short_book': 4.2,
        'short_chapters': 4.5,
        'unhurried': 4.0,
      },
      pairedSerenSoundId: 'soft_kalimba',
    ),
    BookRecommendationProfile(
      id: 'bm_hist_endurance',
      titleEn: 'Endurance: Shackleton\'s Incredible Voyage',
      titleId: 'Endurance: Pelayaran Luar Biasa Shackleton',
      author: 'Alfred Lansing',
      genre: BookMatcherGenre.historicalAdventure,
      readingCategory: 'Biography',
      pageCount: 357,
      avgChapterMinutes: 18,
      isbn: '9780465062881',
      synopsisEn:
          'The gripping true account of Ernest Shackleton and his 27 crewmen surviving for over a year on the shifting pack ice of the Antarctic sea.',
      synopsisId:
          'Kisah nyata mendebarkan tentang kepemimpinan Ernest Shackleton dan 27 awak kapalnya bertahan hidup melintasi es Antarktika.',
      whyItFitsEn:
          'A masterclass in human camaraderie, resilience, and true expedition suspense.',
      whyItFitsId:
          'Kisah nyata kepemimpinan, persaudaraan, dan ketangguhan manusia yang tak terlupakan.',
      tagAffinities: {
        'historical_adventure': 4.5,
        'fast_paced': 4.5,
        'narrative_drive': 4.5,
        'medium_book': 3.5,
      },
      pairedSerenSoundId: 'gentle_rain',
    ),
    BookRecommendationProfile(
      id: 'bm_hist_longitude',
      titleEn: 'Longitude',
      titleId: 'Garis Bujur (Longitude)',
      author: 'Dava Sobel',
      genre: BookMatcherGenre.historicalAdventure,
      readingCategory: 'Science',
      pageCount: 192,
      avgChapterMinutes: 14,
      isbn: '9780802715296',
      synopsisEn:
          'How eighteenth-century self-taught clockmaker John Harrison built a sea-worthy marine chronometer to solve the greatest navigation puzzle of his age.',
      synopsisId:
          'Kisah pembuat jam abad ke-18 John Harrison yang merancang kronometer laut presisi demi memecahkan teka-teki navigasi samudra.',
      whyItFitsEn:
          'Short, brisk, and richly satisfying—blends craftsmanship, astronomy, and sea voyages.',
      whyItFitsId:
          'Ringkas dan memikat—memadukan ketekunan kriya jam, astronomi, dan pelayaran samudra.',
      tagAffinities: {
        'historical_adventure': 4.2,
        'curious_learning': 4.2,
        'short_book': 4.0,
        'fast_paced': 3.5,
      },
      pairedSerenSoundId: 'warm_piano',
    ),
    BookRecommendationProfile(
      id: 'bm_hist_silk_roads',
      titleEn: 'The Silk Roads: A New History of the World',
      titleId: 'Jalur Sutra (The Silk Roads)',
      author: 'Peter Frankopan',
      genre: BookMatcherGenre.historicalAdventure,
      readingCategory: 'Biography',
      pageCount: 636,
      avgChapterMinutes: 22,
      isbn: '9781101912379',
      synopsisEn:
          'Traces how caravan routes, spice ports, libraries, and ideas connected East and West across two millennia.',
      synopsisId:
          'Menelusuri bagaimana jalur kafilah, pelabuhan rempah Nusantara, perpustakaan, dan gagasan menghubungkan Timur dan Barat.',
      whyItFitsEn:
          'Grand historical panorama for readers who love deep, interconnected world history.',
      whyItFitsId:
          'Panorama sejarah dunia yang luas bagi pembaca yang menyukai wawasan lintas peradaban.',
      tagAffinities: {
        'historical_adventure': 4.5,
        'curious_learning': 4.2,
        'world_building': 4.0,
        'deep_volume': 4.5,
      },
      pairedSerenSoundId: 'warm_cello',
    ),
    BookRecommendationProfile(
      id: 'bm_hist_wind_sand_stars',
      titleEn: 'Wind, Sand and Stars',
      titleId: 'Angin, Pasir, dan Bintang (Wind, Sand and Stars)',
      author: 'Antoine de Saint-Exupéry',
      genre: BookMatcherGenre.historicalAdventure,
      readingCategory: 'Biography',
      pageCount: 240,
      avgChapterMinutes: 15,
      isbn: '9780156027496',
      synopsisEn:
          'Poetic memoir of flying open-cockpit mail planes by starlight across the Sahara and the Andes in the 1930s.',
      synopsisId:
          'Memoar puitis sang penulis Pangeran Cilik saat menerbangkan pesawat pos melintasi malam berbintang di Gurun Sahara dan Pegunungan Andes.',
      whyItFitsEn:
          'Combines high-altitude adventure with luminous philosophical reflection.',
      whyItFitsId:
          'Memadukan petualangan angkasa dengan perenungan filosofis yang sangat indah.',
      tagAffinities: {
        'historical_adventure': 4.2,
        'philosophical': 3.8,
        'lyrical_prose': 4.2,
        'medium_book': 3.5,
      },
      pairedSerenSoundId: 'nylon_guitar',
    ),

    // =========================================================================
    // 6. INDONESIAN & WORLD LITERATURE (7 Books)
    // =========================================================================
    BookRecommendationProfile(
      id: 'bm_indo_bumi_manusia',
      titleEn: 'This Earth of Mankind (Bumi Manusia)',
      titleId: 'Bumi Manusia',
      author: 'Pramoedya Ananta Toer',
      genre: BookMatcherGenre.indonesianAndWorldLit,
      readingCategory: 'Fiction',
      pageCount: 535,
      avgChapterMinutes: 20,
      isbn: '9780140256352',
      synopsisEn:
          'At the turn of the twentieth century in Surabaya, young Javanese student Minke and the formidable Nyai Ontosoroh confront colonial injustice through writing and courage.',
      synopsisId:
          'Di awal abad ke-20 di Surabaya, pelajar muda Minke dan sosok tangguh Nyai Ontosoroh menghadapi ketidakadilan zaman lewat pena, ilmu, dan keberanian.',
      whyItFitsEn:
          'A monumental Indonesian literary masterpiece with unforgettable characters and historical depth.',
      whyItFitsId:
          'Mahakarya sastra Indonesia dengan karakter tak terlupakan dan kedalaman sejarah yang menggugah.',
      tagAffinities: {
        'indonesian_world_lit': 4.8,
        'historical_adventure': 4.0,
        'world_building': 4.2,
        'narrative_drive': 4.0,
        'deep_volume': 4.2,
      },
      pairedSerenSoundId: 'warm_cello',
    ),
    BookRecommendationProfile(
      id: 'bm_indo_laskar_pelangi',
      titleEn: 'The Rainbow Troops (Laskar Pelangi)',
      titleId: 'Laskar Pelangi',
      author: 'Andrea Hirata',
      genre: BookMatcherGenre.indonesianAndWorldLit,
      readingCategory: 'Fiction',
      pageCount: 529,
      avgChapterMinutes: 15,
      isbn: '9780374532741',
      synopsisEn:
          'Ten spirited children and two devoted teachers in a leaning wooden schoolhouse on Belitung Island chase knowledge, friendship, and dreams.',
      synopsisId:
          'Sepuluh anak penuh semangat dan dua guru berdedikasi di sekolah kayu sederhana Pulau Belitung mengejar ilmu, persahabatan, dan mimpi.',
      whyItFitsEn:
          'Brimming with humor, warmth, and inspiring resilience—each chapter sparkles with joy.',
      whyItFitsId:
          'Penuh humor hangat, persahabatan tulus, dan semangat belajar yang menyalakan harapan.',
      tagAffinities: {
        'indonesian_world_lit': 4.8,
        'cozy_comfort': 4.0,
        'warm_characters': 4.5,
        'narrative_drive': 3.8,
        'deep_volume': 3.5,
      },
      pairedSerenSoundId: 'nylon_guitar',
    ),
    BookRecommendationProfile(
      id: 'bm_indo_laut_bercerita',
      titleEn: 'The Sea Speaks His Name (Laut Bercerita)',
      titleId: 'Laut Bercerita',
      author: 'Leila S. Chudori',
      genre: BookMatcherGenre.indonesianAndWorldLit,
      readingCategory: 'Fiction',
      pageCount: 379,
      avgChapterMinutes: 18,
      isbn: '9786024246945',
      synopsisEn:
          'A deeply moving novel of student friendship, book discussions, family love, and memory in 1990s Indonesia.',
      synopsisId:
          'Novel yang sangat menyentuh tentang persahabatan mahasiswa pecinta buku, kasih keluarga, dan ingatan di Indonesia era 1990-an.',
      whyItFitsEn:
          'Poetic, vivid prose with unforgettable emotional resonance and culinary warmth.',
      whyItFitsId:
          'Prosa puitis yang hidup dengan resonansi emosi mendalam dan kehangatan persahabatan.',
      tagAffinities: {
        'indonesian_world_lit': 4.8,
        'lyrical_prose': 4.2,
        'warm_characters': 3.8,
        'deep_volume': 3.5,
      },
      pairedSerenSoundId: 'gentle_rain',
    ),
    BookRecommendationProfile(
      id: 'bm_indo_perahu_kertas',
      titleEn: 'Paper Boats (Perahu Kertas)',
      titleId: 'Perahu Kertas',
      author: 'Dee Lestari',
      genre: BookMatcherGenre.indonesianAndWorldLit,
      readingCategory: 'Fiction',
      pageCount: 444,
      avgChapterMinutes: 16,
      isbn: '9789791227780',
      synopsisEn:
          'Fairy-tale writer Kugy and young painter Keenan navigate art, friendship, and finding their true calling from Bandung to Bali and Jakarta.',
      synopsisId:
          'Penulis dongeng Kugy dan pelukis muda Keenan menavigasi karya seni, persahabatan, dan panggilan hati dari Bandung, Bali, hingga Jakarta.',
      whyItFitsEn:
          'Warm, creative, and effortlessly readable—celebrates artistic passion and sincerity.',
      whyItFitsId:
          'Hangat, kreatif, dan mengalir nyaman—merayakan semangat berkarya dan ketulusan hati.',
      tagAffinities: {
        'indonesian_world_lit': 4.6,
        'cozy_comfort': 3.8,
        'warm_characters': 4.2,
        'fast_paced': 3.5,
        'deep_volume': 3.5,
      },
      pairedSerenSoundId: 'warm_piano',
    ),
    BookRecommendationProfile(
      id: 'bm_indo_cantik_luka',
      titleEn: 'Beauty Is a Wound (Cantik Itu Luka)',
      titleId: 'Cantik Itu Luka',
      author: 'Eka Kurniawan',
      genre: BookMatcherGenre.indonesianAndWorldLit,
      readingCategory: 'Fiction',
      pageCount: 470,
      avgChapterMinutes: 20,
      isbn: '9780811224710',
      synopsisEn:
          'An epic, spellbinding family saga set in the coastal town of Halimunda blending folklore, humor, and magical realism.',
      synopsisId:
          'Kisah epik keluarga di kota pesisir Halimunda yang memadukan cerita rakyat Nusantara, realisme magis, dan sejarah dengan memikat.',
      whyItFitsEn:
          'Rich world-building and internationally acclaimed Indonesian storytelling.',
      whyItFitsId:
          'Pembangunan dunia yang kaya dalam salah satu karya sastra Indonesia paling mendunia.',
      tagAffinities: {
        'indonesian_world_lit': 4.7,
        'world_building': 4.5,
        'narrative_drive': 4.0,
        'deep_volume': 4.0,
      },
      pairedSerenSoundId: 'gentle_rain',
    ),
    BookRecommendationProfile(
      id: 'bm_indo_pulang',
      titleEn: 'Home (Pulang)',
      titleId: 'Pulang',
      author: 'Leila S. Chudori',
      genre: BookMatcherGenre.indonesianAndWorldLit,
      readingCategory: 'Fiction',
      pageCount: 464,
      avgChapterMinutes: 18,
      isbn: '9781908906571',
      synopsisEn:
          'Four Indonesian friends open Restaurant Tanah Air in Paris, keeping the aromas of turmeric, cloves, and homeland alive across generations.',
      synopsisId:
          'Empat sahabat membuka Restoran Tanah Air di Paris, menjaga aroma kunyit, cengkih, dan kerinduan pada kampung halaman lintas generasi.',
      whyItFitsEn:
          'Sensory culinary nostalgia woven into a sweeping historical family drama.',
      whyItFitsId:
          'Nostalgia kuliner Nusantara yang hangat berpadu dengan kisah sejarah lintas generasi.',
      tagAffinities: {
        'indonesian_world_lit': 4.6,
        'historical_adventure': 3.8,
        'warm_characters': 3.8,
        'deep_volume': 3.8,
      },
      pairedSerenSoundId: 'nylon_guitar',
    ),
    BookRecommendationProfile(
      id: 'bm_indo_little_prince',
      titleEn: 'The Little Prince (Pangeran Cilik)',
      titleId: 'Pangeran Cilik (Le Petit Prince)',
      author: 'Antoine de Saint-Exupéry',
      genre: BookMatcherGenre.indonesianAndWorldLit,
      readingCategory: 'Fiction',
      pageCount: 96,
      avgChapterMinutes: 8,
      isbn: '9780156012195',
      synopsisEn:
          'A stranded pilot in the desert meets a young traveler from Asteroid B-612 who teaches him that "what is essential is invisible to the eye."',
      synopsisId:
          'Seorang pilot yang mendarat di gurun bertemu pengembara cilik dari Asteroid B-612 yang mengajarkan bahwa "yang terpenting tak terlihat oleh mata."',
      whyItFitsEn:
          'A poetic 96-page jewel that can be read in just a few peaceful evenings.',
      whyItFitsId:
          'Permata sastra 96 halaman yang lembut dan dapat ditamatkan dalam beberapa malam yang tenang.',
      tagAffinities: {
        'indonesian_world_lit': 4.2,
        'cozy_comfort': 4.2,
        'philosophical': 4.0,
        'short_book': 4.5,
        'short_chapters': 4.5,
      },
      pairedSerenSoundId: 'soft_kalimba',
    ),
  ];

  static BookRecommendationProfile? findBookById(
    String id, {
    List<BookRecommendationProfile> extraBooks = const [],
  }) {
    for (final b in curatedBooks) {
      if (b.id == id) return b;
    }
    for (final b in extraBooks) {
      if (b.id == id) return b;
    }
    return null;
  }
}
