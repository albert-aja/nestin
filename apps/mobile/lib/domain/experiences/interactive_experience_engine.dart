import '../../data/models/interactive_experience_models.dart';
import '../../data/models/reading_item.dart';
import '../../data/services/weather_service.dart';

/// Deterministic Shared Interactive Experience Engine (Phase 2).
///
/// Combines:
/// 1. Questionnaire Engine (conditional branching, optional questions, multi-type inputs)
/// 2. Scoring & Recommendation Engine (weighted tag scoring, constraint matching,
///    ranking multipliers, and explainable outcome generation)
class InteractiveExperienceEngine {
  const InteractiveExperienceEngine();

  /// Returns only the questions that should be visible given the current draft's answers.
  List<ExperienceQuestion> visibleQuestions(
    ExperienceDefinition definition,
    ExperienceSessionDraft draft,
  ) {
    final visible = <ExperienceQuestion>[];
    for (final q in definition.questions) {
      if (q.showIfQuestionId == null || q.showIfOptionIds.isEmpty) {
        visible.add(q);
        continue;
      }
      final parentSelected =
          draft.selectedOptionIdsByQuestion[q.showIfQuestionId!] ?? const [];
      final shouldShow =
          q.showIfOptionIds.any((optId) => parentSelected.contains(optId));
      if (shouldShow) {
        visible.add(q);
      }
    }
    return visible;
  }

  /// Checks whether the user has provided a valid answer (or skipped an optional question).
  bool isQuestionSatisfied(
    ExperienceQuestion question,
    ExperienceSessionDraft draft,
  ) {
    if (question.isOptional &&
        draft.skippedQuestionIds.contains(question.id)) {
      return true;
    }
    switch (question.type) {
      case ExperienceQuestionType.slider:
      case ExperienceQuestionType.numericInput:
        return true; // Slider/numeric always has a valid numeric value or defaultValue
      case ExperienceQuestionType.singleChoice:
      case ExperienceQuestionType.multipleChoice:
      case ExperienceQuestionType.visualSelection:
      case ExperienceQuestionType.ranking:
        final selected =
            draft.selectedOptionIdsByQuestion[question.id] ?? const [];
        return selected.isNotEmpty || question.isOptional;
    }
  }

  /// Evaluates a completed [ExperienceSessionDraft] against [definition] deterministically
  /// and returns an ordered list of top [ExperienceMatchedOutcome]s with explainable reasons.
  List<ExperienceMatchedOutcome> evaluateHobbyFinder({
    required ExperienceDefinition definition,
    required ExperienceSessionDraft draft,
    int maxResults = 3,
  }) {
    final visible = visibleQuestions(definition, draft);
    final accumulatedTags = <String, double>{};
    ExperienceBudgetTier? selectedBudgetTier;
    ExperienceEnvironmentType? selectedEnvironment;
    final weeklyHours = draft.numericValueByQuestion['q_weekly_hours'] ?? 3.0;

    for (final question in visible) {
      if (draft.skippedQuestionIds.contains(question.id)) {
        continue;
      }
      final selectedIds =
          draft.selectedOptionIdsByQuestion[question.id] ?? const [];
      for (var i = 0; i < selectedIds.length; i++) {
        final optId = selectedIds[i];
        ExperienceOption? option;
        for (final candidate in question.options) {
          if (candidate.id == optId) {
            option = candidate;
            break;
          }
        }
        if (option == null) continue;

        if (option.budgetTier != null) {
          selectedBudgetTier = option.budgetTier;
        }
        if (option.environmentType != null) {
          selectedEnvironment = option.environmentType;
        }

        // For ranking questions, earlier ranked choices receive a higher weight multiplier.
        final rankMultiplier =
            question.type == ExperienceQuestionType.ranking
                ? (1.0 - (i * 0.25)).clamp(0.4, 1.0)
                : 1.0;

        option.tagWeights.forEach((tag, weight) {
          accumulatedTags[tag] =
              (accumulatedTags[tag] ?? 0.0) + (weight * rankMultiplier);
        });
      }
    }

    final scoredOutcomes = <ExperienceMatchedOutcome>[];

    for (final profile in definition.hobbyProfiles) {
      var rawScore = 0.0;
      var maxPossibleTagScore = 0.0;

      profile.tagAffinities.forEach((tag, affinity) {
        maxPossibleTagScore += affinity * 3.5;
        final userTagScore = accumulatedTags[tag] ?? 0.0;
        rawScore += userTagScore * affinity;
      });

      final reasonKeys = <String>[profile.whyItFitsKey];
      final reasonParams = <String, Map<String, dynamic>>{};

      // Constraint 1: Weekly time availability
      if (weeklyHours >= profile.minHoursPerWeek) {
        rawScore += 6.0;
        reasonKeys.add('exp_reason_time_fit');
        reasonParams['exp_reason_time_fit'] = {
          'hours': weeklyHours.toStringAsFixed(0),
        };
      } else {
        rawScore -= (profile.minHoursPerWeek - weeklyHours) * 3.5;
      }

      // Constraint 2: Starter budget comfort
      if (selectedBudgetTier != null) {
        if (profile.budgetTier.index <= selectedBudgetTier.index) {
          rawScore += 6.5;
          reasonKeys.add('exp_reason_budget_fit');
          reasonParams['exp_reason_budget_fit'] = {
            'cost': profile.estimatedStarterCostUsd.toString(),
          };
        } else {
          final tierDiff = profile.budgetTier.index - selectedBudgetTier.index;
          rawScore -= tierDiff * 4.5;
        }
      }

      // Constraint 3: Environment & workspace fit
      if (selectedEnvironment != null) {
        if (profile.preferredEnvironments.contains(selectedEnvironment)) {
          rawScore += 6.0;
          reasonKeys.add('exp_reason_env_fit');
        } else {
          rawScore -= 2.5;
        }
      }

      final normalizedDenominator =
          (maxPossibleTagScore + 18.5).clamp(20.0, 120.0);
      final normalizedRatio =
          (rawScore / normalizedDenominator).clamp(0.15, 0.99);
      final matchPercentage = (58 + (normalizedRatio * 40)).round().clamp(55, 98);

      scoredOutcomes.add(
        ExperienceMatchedOutcome(
          profileId: profile.id,
          matchPercentage: matchPercentage,
          rawScore: rawScore,
          reasonKeys: reasonKeys,
          reasonParamsByKey: reasonParams,
        ),
      );
    }

    scoredOutcomes.sort((a, b) {
      final byScore = b.rawScore.compareTo(a.rawScore);
      if (byScore != 0) return byScore;
      return a.profileId.compareTo(b.profileId);
    });

    return scoredOutcomes.take(maxResults).toList();
  }

  static String _normalizeBookTitle(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static BookMatcherGenre _inferGenreFromReadingCategory(String category) {
    switch (category.toLowerCase()) {
      case 'science':
      case 'tech':
        return BookMatcherGenre.natureAndScience;
      case 'self-growth':
      case 'productivity':
        return BookMatcherGenre.mindfulNonFiction;
      case 'creativity':
        return BookMatcherGenre.philosophy;
      case 'biography':
        return BookMatcherGenre.historicalAdventure;
      case 'fiction':
      default:
        return BookMatcherGenre.cozyFiction;
    }
  }

  static Map<String, double> _inferTagsForUserShelfBook(ReadingItem item) {
    final genre = _inferGenreFromReadingCategory(item.category);
    final tags = <String, double>{};
    switch (genre) {
      case BookMatcherGenre.cozyFiction:
        tags['cozy_fiction'] = 3.8;
        tags['cozy_comfort'] = 3.5;
        tags['warm_characters'] = 3.0;
        break;
      case BookMatcherGenre.natureAndScience:
        tags['nature_science'] = 3.8;
        tags['curious_learning'] = 3.5;
        tags['observational'] = 3.0;
        break;
      case BookMatcherGenre.mindfulNonFiction:
        tags['mindful_nonfiction'] = 3.8;
        tags['mindful_living'] = 3.5;
        tags['short_chapters'] = 2.5;
        break;
      case BookMatcherGenre.philosophy:
        tags['philosophy'] = 3.8;
        tags['philosophical'] = 3.5;
        break;
      case BookMatcherGenre.historicalAdventure:
        tags['historical_adventure'] = 3.8;
        tags['world_building'] = 3.2;
        tags['narrative_drive'] = 3.0;
        break;
      case BookMatcherGenre.indonesianAndWorldLit:
        tags['indonesian_world_lit'] = 3.8;
        tags['lyrical_prose'] = 3.2;
        break;
    }
    if (item.totalPages > 0 && item.totalPages <= 220) {
      tags['short_book'] = 3.5;
      tags['short_chapters'] = 2.5;
    } else if (item.totalPages <= 360) {
      tags['medium_book'] = 3.5;
    } else {
      tags['deep_volume'] = 3.5;
    }
    return tags;
  }

  /// Converts an unread [ReadingItem] from the user's shelf into a [BookRecommendationProfile].
  static BookRecommendationProfile profileFromUserReadingItem(
    ReadingItem item,
  ) {
    final genre = _inferGenreFromReadingCategory(item.category);
    final pages = item.totalPages > 0 ? item.totalPages : 250;
    return BookRecommendationProfile(
      id: 'shelf_${item.id}',
      titleEn: item.title,
      titleId: item.title,
      author: item.author.trim().isEmpty ? 'Personal Shelf' : item.author,
      genre: genre,
      readingCategory: item.category,
      pageCount: pages,
      avgChapterMinutes: pages <= 220 ? 12 : (pages <= 360 ? 16 : 20),
      synopsisEn: item.notes != null && item.notes!.trim().isNotEmpty
          ? item.notes!.trim()
          : 'Waiting on your personal Want to Read shelf (${item.category} • ${pages}p).',
      synopsisId: item.notes != null && item.notes!.trim().isNotEmpty
          ? item.notes!.trim()
          : 'Menunggu di rak Ingin Dibaca pribadi Anda (${item.category} • $pages hal).',
      whyItFitsEn:
          'Already waiting on your own Unread Shelf and matches tonight\'s reading mood.',
      whyItFitsId:
          'Sudah ada di rak Ingin Dibaca Anda dan cocok dengan suasana baca malam ini.',
      tagAffinities: _inferTagsForUserShelfBook(item),
      pairedSerenSoundId: genre == BookMatcherGenre.natureAndScience
          ? 'forest_stream'
          : (genre == BookMatcherGenre.mindfulNonFiction
              ? 'singing_bowls'
              : 'nylon_guitar'),
      isFromUserShelf: true,
      existingReadingItemId: item.id,
    );
  }

  /// Evaluates Pippin's Reading Taste & Next-Book Matcher (`book_matcher_v1`)
  /// across Tier 1 (42 Bundled Curated Books), Tier 2 (User's `ReadingProvider` Shelf),
  /// and Tier 3 (Cached Open Library API books).
  List<ExperienceMatchedOutcome> evaluateBookMatcher({
    required ExperienceSessionDraft draft,
    List<ReadingItem> userReadingItems = const [],
    List<BookRecommendationProfile> extraOnlineBooks = const [],
    int maxResults = 3,
  }) {
    const definition = BookMatcherCatalog.definition;
    final visible = visibleQuestions(definition, draft);
    final accumulatedTags = <String, double>{};
    final dailyMinutes =
        (draft.numericValueByQuestion['bm_q_daily_mins'] ?? 20.0)
            .round()
            .clamp(10, 60);

    final selectedShelfModeIds =
        draft.selectedOptionIdsByQuestion['bm_q_shelf_mode'] ?? const [];
    final preferUnreadShelf =
        selectedShelfModeIds.contains('bm_opt_mode_unread_shelf');

    final selectedLengthIds =
        draft.selectedOptionIdsByQuestion['bm_q_length'] ?? const [];
    final wantShort = selectedLengthIds.contains('bm_opt_len_short');
    final wantMedium = selectedLengthIds.contains('bm_opt_len_medium');
    final wantDeep = selectedLengthIds.contains('bm_opt_len_deep');

    for (final question in visible) {
      if (draft.skippedQuestionIds.contains(question.id)) continue;
      final selectedIds =
          draft.selectedOptionIdsByQuestion[question.id] ?? const [];
      for (final optId in selectedIds) {
        for (final candidate in question.options) {
          if (candidate.id == optId) {
            candidate.tagWeights.forEach((tag, weight) {
              accumulatedTags[tag] = (accumulatedTags[tag] ?? 0.0) + weight;
            });
            break;
          }
        }
      }
    }

    // Tier 2A: Completed books set (normalized titles) so we never recommend already finished books
    final completedNormalizedTitles = <String>{};
    // Tier 2B: Favorite categories from 4–5 star rated books
    final highRatedCategories = <String>{};
    // Tier 2C: Unread books sitting in user's Want to Read shelf
    final unreadShelfProfiles = <BookRecommendationProfile>[];

    for (final item in userReadingItems) {
      final normTitle = _normalizeBookTitle(item.title);
      if (item.isCompleted || item.status == ReadingStatus.finished) {
        if (normTitle.isNotEmpty) {
          completedNormalizedTitles.add(normTitle);
        }
      }
      if ((item.rating ?? 0) >= 4 && item.category.trim().isNotEmpty) {
        highRatedCategories.add(item.category.trim().toLowerCase());
      }
      if (item.status == ReadingStatus.wantToRead && !item.isCompleted) {
        unreadShelfProfiles.add(profileFromUserReadingItem(item));
      }
    }

    // Assemble candidate pool (Tier 2 unread shelf + Tier 1 curated + Tier 3 Open Library)
    final candidateBooks = <BookRecommendationProfile>[];
    final seenTitles = <String>{};

    for (final shelfBook in unreadShelfProfiles) {
      final norm = _normalizeBookTitle(shelfBook.titleEn);
      if (norm.isEmpty || completedNormalizedTitles.contains(norm)) continue;
      seenTitles.add(norm);
      candidateBooks.add(shelfBook);
    }

    for (final curated in BookMatcherCatalog.curatedBooks) {
      final norm = _normalizeBookTitle(curated.titleEn);
      final normId = _normalizeBookTitle(curated.titleId);
      if (completedNormalizedTitles.contains(norm) ||
          completedNormalizedTitles.contains(normId) ||
          seenTitles.contains(norm)) {
        continue;
      }
      seenTitles.add(norm);
      candidateBooks.add(curated);
    }

    for (final online in extraOnlineBooks) {
      final norm = _normalizeBookTitle(online.titleEn);
      if (norm.isEmpty ||
          completedNormalizedTitles.contains(norm) ||
          seenTitles.contains(norm)) {
        continue;
      }
      seenTitles.add(norm);
      candidateBooks.add(online);
    }

    final scoredOutcomes = <ExperienceMatchedOutcome>[];

    for (final book in candidateBooks) {
      var rawScore = 0.0;
      var maxPossibleTagScore = 0.0;

      book.tagAffinities.forEach((tag, affinity) {
        maxPossibleTagScore += affinity * 3.5;
        final userTagScore = accumulatedTags[tag] ?? 0.0;
        rawScore += userTagScore * affinity;
      });

      final reasonKeys = <String>[];
      final reasonParams = <String, Map<String, dynamic>>{};

      if (book.isFromUserShelf) {
        reasonKeys.add('bm_reason_from_unread_shelf');
        if (preferUnreadShelf) {
          rawScore += 18.0;
        } else {
          rawScore += 4.5;
        }
      }

      if (book.isFromOnlineApi) {
        reasonKeys.add('bm_reason_open_library');
      }

      // Tier 2 Taste Boost: 4–5 star rated category affinity
      if (highRatedCategories.contains(book.readingCategory.toLowerCase())) {
        rawScore += 5.5;
        reasonKeys.add('bm_reason_taste_boost');
        reasonParams['bm_reason_taste_boost'] = {
          'category': book.readingCategory,
        };
      }

      // Page-length preference constraint
      final isShortBook = book.pageCount <= 220;
      final isMediumBook = book.pageCount > 220 && book.pageCount <= 360;
      final isDeepBook = book.pageCount > 360;
      if ((wantShort && isShortBook) ||
          (wantMedium && isMediumBook) ||
          (wantDeep && isDeepBook)) {
        rawScore += 6.0;
        reasonKeys.add('bm_reason_length_fit');
        reasonParams['bm_reason_length_fit'] = {
          'pages': book.pageCount.toString(),
        };
      } else if (wantShort && isDeepBook) {
        rawScore -= 4.0;
      }

      // Daily reading minutes cadence fit
      final estDays = book.estimatedDaysToFinish(dailyMinutes);
      if (dailyMinutes >= book.avgChapterMinutes) {
        rawScore += 5.0;
      } else {
        rawScore -= (book.avgChapterMinutes - dailyMinutes) * 0.4;
      }
      reasonKeys.add('bm_reason_daily_mins_fit');
      reasonParams['bm_reason_daily_mins_fit'] = {
        'mins': dailyMinutes.toString(),
        'days': estDays.toString(),
      };

      final normalizedDenominator =
          (maxPossibleTagScore + 18.0).clamp(24.0, 110.0);
      final normalizedRatio =
          (rawScore / normalizedDenominator).clamp(0.18, 0.99);
      final matchPercentage =
          (60 + (normalizedRatio * 38)).round().clamp(58, 99);

      scoredOutcomes.add(
        ExperienceMatchedOutcome(
          profileId: book.id,
          matchPercentage: matchPercentage,
          rawScore: rawScore,
          reasonKeys: reasonKeys,
          reasonParamsByKey: reasonParams,
        ),
      );
    }

    scoredOutcomes.sort((a, b) {
      final byScore = b.rawScore.compareTo(a.rawScore);
      if (byScore != 0) return byScore;
      return a.profileId.compareTo(b.profileId);
    });

    return scoredOutcomes.take(maxResults).toList();
  }

  /// Evaluates Scout's Weekend Generator (`weekend_generator_v1`) against the
  /// bundled offline micro-itinerary catalog and live/simulated [WeatherInfo].
  List<ExperienceMatchedOutcome> evaluateWeekendGenerator({
    required ExperienceSessionDraft draft,
    WeatherInfo? currentWeather,
    int maxResults = 3,
  }) {
    const definition = WeekendGeneratorCatalog.definition;
    final visible = visibleQuestions(definition, draft);
    final accumulatedTags = <String, double>{};

    for (final question in visible) {
      if (draft.skippedQuestionIds.contains(question.id)) continue;
      final selectedIds =
          draft.selectedOptionIdsByQuestion[question.id] ?? const [];
      for (final optId in selectedIds) {
        for (final candidate in question.options) {
          if (candidate.id == optId) {
            candidate.tagWeights.forEach((tag, weight) {
              accumulatedTags[tag] = (accumulatedTags[tag] ?? 0.0) + weight;
            });
            break;
          }
        }
      }
    }

    // Time window constraint
    final selectedTimeIds =
        draft.selectedOptionIdsByQuestion['wg_q_time_window'] ?? const [];
    final desiredTimeWindow = selectedTimeIds.contains('wg_opt_time_micro')
        ? WeekendTimeWindow.micro2h
        : selectedTimeIds.contains('wg_opt_time_full')
            ? WeekendTimeWindow.fullWeekend
            : WeekendTimeWindow.halfDay;

    // Weather preference constraint
    final selectedWeatherPrefIds =
        draft.selectedOptionIdsByQuestion['wg_q_weather_pref'] ?? const [];
    final wantStrictOutdoor =
        selectedWeatherPrefIds.contains('wg_opt_pref_outdoor');
    final wantStrictIndoor =
        selectedWeatherPrefIds.contains('wg_opt_pref_indoor');
    final wantWeatherAdaptive =
        selectedWeatherPrefIds.contains('wg_opt_pref_adaptive') ||
            selectedWeatherPrefIds.isEmpty;

    // Personal pocket-budget constraint
    final selectedBudgetIds =
        draft.selectedOptionIdsByQuestion['wg_q_budget'] ?? const [];
    final wantZeroSpend = selectedBudgetIds.contains('wg_opt_budget_zero');
    var maxBudgetTier = ExperienceBudgetTier.high;
    if (wantZeroSpend || selectedBudgetIds.contains('wg_opt_budget_low')) {
      maxBudgetTier = ExperienceBudgetTier.low;
    } else if (selectedBudgetIds.contains('wg_opt_budget_mid')) {
      maxBudgetTier = ExperienceBudgetTier.mid;
    }

    final scoredOutcomes = <ExperienceMatchedOutcome>[];

    for (final itinerary in WeekendGeneratorCatalog.itineraries) {
      var rawScore = 0.0;
      var maxPossibleTagScore = 0.0;
      final reasonKeys = <String>[];
      final reasonParams = <String, Map<String, String>>{};

      accumulatedTags.forEach((tag, userWeight) {
        final affinity = itinerary.tagAffinities[tag] ?? 0.0;
        rawScore += affinity * userWeight;
        maxPossibleTagScore += 4.0 * userWeight;
      });

      // 1. Time window fit
      if (itinerary.timeWindow == desiredTimeWindow) {
        rawScore += 10.0;
        reasonKeys.add('wg_reason_time_fit');
        reasonParams['wg_reason_time_fit'] = {
          'hours': itinerary.durationHours.toStringAsFixed(1),
        };
      } else if ((itinerary.timeWindow == WeekendTimeWindow.micro2h &&
              desiredTimeWindow == WeekendTimeWindow.fullWeekend) ||
          (itinerary.timeWindow == WeekendTimeWindow.fullWeekend &&
              desiredTimeWindow == WeekendTimeWindow.micro2h)) {
        rawScore -= 6.0;
      }

      // 2. Setting + Live Weather Adaptation (LocalWeatherService)
      final rainyNow = currentWeather?.isRainy ?? false;
      final coolNow = currentWeather?.isCool ?? false;

      if (wantStrictIndoor) {
        if (!itinerary.isOutdoor) {
          rawScore += 10.0;
          reasonKeys.add('wg_reason_indoor_comfort');
        } else {
          rawScore -= 14.0;
        }
      } else if (wantStrictOutdoor) {
        if (itinerary.isOutdoor) {
          rawScore += rainyNow && !itinerary.rainFriendly ? 2.0 : 9.0;
        } else {
          rawScore -= 10.0;
        }
      }

      if (currentWeather != null) {
        if (rainyNow) {
          if (itinerary.rainFriendly || !itinerary.isOutdoor) {
            rawScore += wantWeatherAdaptive ? 12.0 : 5.0;
            reasonKeys.add('wg_reason_weather_rain_adapt');
            reasonParams['wg_reason_weather_rain_adapt'] = {
              'temp': currentWeather.temperatureCelsius.round().toString(),
              'rain': currentWeather.rainChancePercent.toString(),
            };
          } else {
            rawScore -= wantWeatherAdaptive ? 10.0 : 4.0;
          }
        } else {
          if (itinerary.isOutdoor) {
            rawScore += wantWeatherAdaptive ? 8.0 : 5.0;
            reasonKeys.add('wg_reason_weather_clear_boost');
            reasonParams['wg_reason_weather_clear_boost'] = {
              'temp': currentWeather.temperatureCelsius.round().toString(),
              'cond': currentWeather.condition,
            };
          }
        }

        if (coolNow &&
            !reasonKeys.contains('wg_reason_weather_rain_adapt')) {
          reasonKeys.add('wg_reason_weather_cool_layer');
          reasonParams['wg_reason_weather_cool_layer'] = {
            'temp': currentWeather.temperatureCelsius.round().toString(),
          };
        }
      } else if (itinerary.isOutdoor && !rainyNow) {
        reasonKeys.add('wg_reason_outdoor_fresh');
      }

      // 3. Personal Pocket Budget Tier Compliance (strictly offline personal budgeting)
      final fitsBudget = wantZeroSpend
          ? itinerary.estimatedPocketBudgetUsd == 0
          : itinerary.budgetTier.index <= maxBudgetTier.index;
      if (fitsBudget) {
        rawScore += wantZeroSpend ? 14.0 : 8.0;
        reasonKeys.add('wg_reason_budget_fit');
        reasonParams['wg_reason_budget_fit'] = {
          'usd': itinerary.estimatedPocketBudgetUsd.toString(),
        };
      } else {
        final overSteps = wantZeroSpend
            ? 1 + (itinerary.estimatedPocketBudgetUsd > 15 ? 1 : 0)
            : (itinerary.budgetTier.index - maxBudgetTier.index);
        rawScore -= overSteps * 14.0;
      }

      final normalizedDenominator =
          (maxPossibleTagScore + 28.0).clamp(32.0, 145.0);
      final normalizedRatio =
          (rawScore / normalizedDenominator).clamp(0.15, 0.99);
      final matchPercentage =
          (58 + (normalizedRatio * 40)).round().clamp(56, 99);

      scoredOutcomes.add(
        ExperienceMatchedOutcome(
          profileId: itinerary.id,
          matchPercentage: matchPercentage,
          rawScore: rawScore,
          reasonKeys: reasonKeys,
          reasonParamsByKey: reasonParams,
        ),
      );
    }

    scoredOutcomes.sort((a, b) {
      final byScore = b.rawScore.compareTo(a.rawScore);
      if (byScore != 0) return byScore;
      return a.profileId.compareTo(b.profileId);
    });

    return scoredOutcomes.take(maxResults).toList();
  }

  /// Deterministic, non-clinical scoring for Echo's Strengths & Quiet Life
  /// Skills Lab (`strengths_life_skills_v1`).
  List<ExperienceMatchedOutcome> evaluateStrengthsLab(
    Map<String, dynamic> answers, {
    int maxResults = 3,
  }) {
    final accumulatedTags = <String, double>{};
    for (final question in StrengthsLabCatalog.questions) {
      final selectedId = answers[question.id] as String?;
      if (selectedId == null) continue;
      for (final opt in question.options) {
        if (opt.id == selectedId) {
          opt.tagWeights.forEach((tag, weight) {
            accumulatedTags[tag] = (accumulatedTags[tag] ?? 0.0) + weight;
          });
          break;
        }
      }
    }

    final scoredOutcomes = <ExperienceMatchedOutcome>[];
    for (final profile in StrengthsLabCatalog.profiles) {
      var rawScore = 0.0;
      var maxPossibleTagScore = 0.0;
      final matchedTags = <MapEntry<String, double>>[];

      profile.tagAffinities.forEach((tag, affinity) {
        maxPossibleTagScore += affinity * 3.0;
        final userWeight = accumulatedTags[tag] ?? 0.0;
        if (userWeight > 0) {
          final contribution = userWeight * affinity;
          rawScore += contribution;
          matchedTags.add(MapEntry(tag, contribution));
        }
      });

      matchedTags.sort((a, b) => b.value.compareTo(a.value));
      final reasonKeys = <String>[];
      for (final entry in matchedTags.take(2)) {
        switch (entry.key) {
          case 'boundaries':
            reasonKeys.add('exp_sl_reason_boundaries');
            break;
          case 'calm':
          case 'reset':
            if (!reasonKeys.contains('exp_sl_reason_calm')) {
              reasonKeys.add('exp_sl_reason_calm');
            }
            break;
          case 'pacing':
          case 'steady':
            if (!reasonKeys.contains('exp_sl_reason_pacing')) {
              reasonKeys.add('exp_sl_reason_pacing');
            }
            break;
          case 'empathy':
          case 'presence':
            if (!reasonKeys.contains('exp_sl_reason_empathy')) {
              reasonKeys.add('exp_sl_reason_empathy');
            }
            break;
          case 'clarity':
          case 'prioritize':
            if (!reasonKeys.contains('exp_sl_reason_clarity')) {
              reasonKeys.add('exp_sl_reason_clarity');
            }
            break;
          case 'adaptable':
            reasonKeys.add('exp_sl_reason_adaptable');
            break;
        }
      }

      if (reasonKeys.isEmpty) {
        reasonKeys.add('exp_sl_reason_calm');
      }

      final denominator = maxPossibleTagScore.clamp(16.0, 80.0);
      final normalizedRatio = (rawScore / denominator).clamp(0.15, 0.99);
      final matchPercentage =
          (60 + (normalizedRatio * 38)).round().clamp(58, 99);

      scoredOutcomes.add(
        ExperienceMatchedOutcome(
          profileId: profile.id,
          matchPercentage: matchPercentage,
          rawScore: rawScore,
          reasonKeys: reasonKeys,
        ),
      );
    }

    scoredOutcomes.sort((a, b) {
      final byScore = b.rawScore.compareTo(a.rawScore);
      if (byScore != 0) return byScore;
      return a.profileId.compareTo(b.profileId);
    });

    return scoredOutcomes.take(maxResults).toList();
  }
}
