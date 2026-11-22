import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/interactive_experience_models.dart';
import '../../../data/models/reading_item.dart';
import '../../../providers/before_you_go_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/cross_module_link_provider.dart';
import '../../../providers/geofence_provider.dart';
import '../../../providers/hobby_provider.dart';
import '../../../providers/interactive_experience_provider.dart';
import '../../../providers/money_provider.dart';
import '../../../providers/note_provider.dart';
import '../../../providers/reading_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/seren_relaxation_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/timer_provider.dart';
import 'daily_creative_prompt_section.dart';
import 'interest_explorer_section.dart';
import 'strengths_lab_section.dart';

/// Compact summary card for ExploreHubScreen & HobbyPracticeSheet that opens [NestinDiscoverScreen].
class NestinDiscoverBannerCard extends StatelessWidget {
  const NestinDiscoverBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<InteractiveExperienceProvider>(
      builder: (context, expProvider, _) {
        final draft = expProvider.draftFor(ExperienceCatalog.hobbyFinderId);
        final latestResult =
            expProvider.latestResultFor(ExperienceCatalog.hobbyFinderId);
        final topProfile = latestResult != null &&
                latestResult.topMatches.isNotEmpty
            ? ExperienceCatalog.findHobbyProfileById(
                latestResult.topMatches.first.profileId,
              )
            : null;

        return InkWell(
          key: const ValueKey('nestin_discover_banner_card'),
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NestinDiscoverScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                  const Color(0xFF10B981).withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('🧭', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.tr('exp_nestin_discover_title'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l10n.tr('exp_hobby_finder_title'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.adaptive(
                                      context,
                                      dark: const Color(0xFF34D399),
                                      light: const Color(0xFF047857),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.tr('exp_nestin_discover_subtitle'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ),
                if (draft != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pause_circle_filled_rounded,
                          size: 15,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.tr('exp_draft_saved_banner', {
                              'answered': draft.answeredCount,
                              'total': expProvider
                                  .visibleQuestionsFor(
                                      ExperienceCatalog.hobbyFinderV1)
                                  .length,
                            }),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (topProfile != null && latestResult != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(topProfile.iconEmoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.tr(topProfile.titleKey),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l10n.tr('exp_match_score_pill', {
                            'score':
                                latestResult.topMatches.first.matchPercentage,
                          }),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Full Nestin Discover hub screen (Section 7) with:
/// - Conceptual groupings (Discover Yourself, Explore the World, Learn Something, Make Something)
/// - Pippin's Hobby Finder Reference Experience (start / resume draft / view results)
/// - Connected Multi-Bird 1-Tap Journey actions (Pippin + Twill + Roo + Seren)
/// - Candidate Backlog & Product Integration browser
class NestinDiscoverScreen extends StatefulWidget {
  const NestinDiscoverScreen({super.key});

  @override
  State<NestinDiscoverScreen> createState() => _NestinDiscoverScreenState();
}

class _NestinDiscoverScreenState extends State<NestinDiscoverScreen> {
  DiscoverGrouping? _selectedGrouping;
  int _selectedMatchIndex = 0;
  int _selectedBookMatchIndex = 0;
  int _selectedWeekendMatchIndex = 0;
  int _selectedWeekendDay = DateTime.saturday;
  bool _includeWeekendGeofence = true;
  bool _includeWeekendPocketBudget = true;
  bool _isEnrichingBooks = false;
  KnowledgeArenaTopic _selectedArenaTopic = KnowledgeArenaTopic.all;
  BrainPlaygroundCategory _selectedBrainCategory = BrainPlaygroundCategory.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('exp_nestin_discover_title')),
      ),
      body: Consumer<InteractiveExperienceProvider>(
        builder: (context, expProvider, _) {
          final draft = expProvider.draftFor(ExperienceCatalog.hobbyFinderId);
          final latestResult =
              expProvider.latestResultFor(ExperienceCatalog.hobbyFinderId);
          final bookDraft =
              expProvider.draftFor(ExperienceCatalog.bookMatcherId);
          final latestBookResult =
              expProvider.latestResultFor(ExperienceCatalog.bookMatcherId);
          final filteredBacklog = _selectedGrouping == null
              ? ExperienceCatalog.candidateBacklog
              : ExperienceCatalog.candidateBacklog
                  .where((c) => c.grouping == _selectedGrouping)
                  .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.tr('exp_nestin_discover_subtitle'),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 14),

              // 4 Conceptual Groupings Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final group in DiscoverGrouping.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            '${group.iconEmoji} ${l10n.tr(group.titleKey)}',
                          ),
                          selected: _selectedGrouping == group,
                          onSelected: (selected) {
                            setState(() {
                              _selectedGrouping = selected ? group : null;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Hero Reference Experience Card: Pippin's Hobby Finder
              _buildHobbyFinderHeroCard(context, l10n, expProvider, draft),

              if (latestResult != null &&
                  latestResult.topMatches.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildLatestResultAndMultiBirdJourney(
                  context,
                  l10n,
                  expProvider,
                  latestResult,
                ),
              ],

              const SizedBox(height: 20),
              // Hero Experience Card 2: Echo's Knowledge Arena
              _buildKnowledgeArenaHeroCard(context, l10n, expProvider),

              const SizedBox(height: 20),
              // Hero Experience Card 3: Echo's Brain Playground
              _buildBrainPlaygroundHeroCard(context, l10n, expProvider),

              const SizedBox(height: 20),
              // Hero Experience Card 4: Pippin's Reading Taste & Next-Book Matcher
              _buildBookMatcherHeroCard(context, l10n, expProvider, bookDraft),

              if (latestBookResult != null &&
                  latestBookResult.topMatches.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildBookMatcherResultAndJourney(
                  context,
                  l10n,
                  expProvider,
                  latestBookResult,
                ),
              ],

              const SizedBox(height: 20),
              // Hero Experience Card 5: Scout's Weekend Generator
              _buildWeekendGeneratorHeroCard(
                context,
                l10n,
                expProvider,
                expProvider.draftFor(ExperienceCatalog.weekendGeneratorId),
              ),

              Builder(
                builder: (context) {
                  final latestWeekendResult = expProvider.latestResultFor(
                    ExperienceCatalog.weekendGeneratorId,
                  );
                  if (latestWeekendResult == null ||
                      latestWeekendResult.topMatches.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _buildWeekendGeneratorResultAndJourney(
                      context,
                      l10n,
                      expProvider,
                      latestWeekendResult,
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              // Hero Experience Card 6: Echo's Strengths & Quiet Life Skills Lab
              StrengthsLabHeroCard(
                expProvider: expProvider,
                draft: expProvider.draftFor(
                  ExperienceCatalog.strengthsLifeSkillsId,
                ),
                latestResult: expProvider.latestResultFor(
                  ExperienceCatalog.strengthsLifeSkillsId,
                ),
              ),

              Builder(
                builder: (context) {
                  final latestStrengthsResult = expProvider.latestResultFor(
                    ExperienceCatalog.strengthsLifeSkillsId,
                  );
                  if (latestStrengthsResult == null ||
                      latestStrengthsResult.topMatches.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: StrengthsLabResultCard(
                      expProvider: expProvider,
                      result: latestStrengthsResult,
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              // Hero Experience Card 7: Pippin's Daily Creative Prompt
              DailyCreativePromptHeroCard(
                expProvider: expProvider,
                latestResult: expProvider.latestResultFor(
                  ExperienceCatalog.dailyCreativePromptId,
                ),
              ),

              const SizedBox(height: 20),
              // Hero Experience Card 8: Pippin's Interest Explorer ("This or That")
              InterestExplorerHeroCard(
                expProvider: expProvider,
                draft: expProvider.draftFor(
                  ExperienceCatalog.interestExplorerId,
                ),
                latestResult: expProvider.latestResultFor(
                  ExperienceCatalog.interestExplorerId,
                ),
              ),

              Builder(
                builder: (context) {
                  final latestInterestResult = expProvider.latestResultFor(
                    ExperienceCatalog.interestExplorerId,
                  );
                  if (latestInterestResult == null ||
                      latestInterestResult.topMatches.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: InterestExplorerResultCard(
                      expProvider: expProvider,
                      result: latestInterestResult,
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              Text(
                l10n.tr('exp_backlog_section_title'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tr('exp_backlog_section_desc'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              for (final candidate in filteredBacklog)
                _buildCandidateAuditCard(context, l10n, candidate),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHobbyFinderHeroCard(
    BuildContext context,
    AppLocalizations l10n,
    InteractiveExperienceProvider expProvider,
    ExperienceSessionDraft? draft,
  ) {
    final visibleTotal = expProvider
        .visibleQuestionsFor(ExperienceCatalog.hobbyFinderV1)
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌱', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.tr('exp_hobby_finder_badge'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('exp_hobby_finder_title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tr('exp_hobby_finder_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 14),
          if (draft != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.tr('exp_draft_saved_banner', {
                  'answered': draft.answeredCount,
                  'total': visibleTotal,
                }),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('btn_resume_hobby_finder'),
                    onPressed: () => _openQuestionnaireSheet(
                      context,
                      resumeDraft: true,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(l10n.tr('exp_resume_draft')),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  key: const ValueKey('btn_restart_hobby_finder'),
                  onPressed: () => _openQuestionnaireSheet(
                    context,
                    resumeDraft: false,
                  ),
                  child: Text(l10n.tr('exp_restart_fresh')),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_start_hobby_finder'),
                onPressed: () => _openQuestionnaireSheet(
                  context,
                  resumeDraft: false,
                ),
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: Text(l10n.tr('exp_start_hobby_finder')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openQuestionnaireSheet(
    BuildContext context, {
    required bool resumeDraft,
  }) async {
    final expProvider = context.read<InteractiveExperienceProvider>();
    if (resumeDraft) {
      await expProvider.startOrResumeSession(ExperienceCatalog.hobbyFinderV1);
    } else {
      await expProvider.startFreshSession(ExperienceCatalog.hobbyFinderV1);
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HobbyFinderFlowSheet(),
    );
    if (mounted) {
      setState(() {
        _selectedMatchIndex = 0;
      });
    }
  }

  Widget _buildBookMatcherHeroCard(
    BuildContext context,
    AppLocalizations l10n,
    InteractiveExperienceProvider expProvider,
    ExperienceSessionDraft? bookDraft,
  ) {
    final visibleTotal = expProvider
        .visibleQuestionsFor(ExperienceCatalog.bookMatcherV1)
        .length;

    return Container(
      key: const ValueKey('book_matcher_hero_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.tr('bm_badge'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('bm_title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tr('bm_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 14),
          if (bookDraft != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.tr('exp_draft_saved_banner', {
                  'answered': bookDraft.answeredCount,
                  'total': visibleTotal,
                }),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('btn_resume_book_matcher'),
                    onPressed: () => _openBookMatcherSheet(
                      context,
                      resumeDraft: true,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(l10n.tr('exp_resume_draft')),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  key: const ValueKey('btn_restart_book_matcher'),
                  onPressed: () => _openBookMatcherSheet(
                    context,
                    resumeDraft: false,
                  ),
                  child: Text(l10n.tr('exp_restart_fresh')),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_start_book_matcher'),
                onPressed: () => _openBookMatcherSheet(
                  context,
                  resumeDraft: false,
                ),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(l10n.tr('bm_start_button')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('btn_book_matcher_unread_shelf'),
                onPressed: () => _openBookMatcherSheet(
                  context,
                  resumeDraft: false,
                  preselectUnreadShelfMode: true,
                ),
                icon: const Icon(Icons.shelves, size: 16),
                label: Text(l10n.tr('bm_pick_unread_shelf_btn')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openBookMatcherSheet(
    BuildContext context, {
    required bool resumeDraft,
    bool preselectUnreadShelfMode = false,
  }) async {
    final expProvider = context.read<InteractiveExperienceProvider>();
    if (resumeDraft) {
      await expProvider.startOrResumeSession(ExperienceCatalog.bookMatcherV1);
    } else {
      await expProvider.startFreshSession(ExperienceCatalog.bookMatcherV1);
      if (preselectUnreadShelfMode) {
        final modeQuestion = ExperienceCatalog.bookMatcherV1.questions.firstWhere(
          (q) => q.id == 'bm_q_shelf_mode',
        );
        await expProvider.selectOption(
          definition: ExperienceCatalog.bookMatcherV1,
          question: modeQuestion,
          optionId: 'bm_opt_mode_unread_shelf',
        );
      }
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HobbyFinderFlowSheet(
        definition: ExperienceCatalog.bookMatcherV1,
      ),
    );
    if (mounted) {
      setState(() {
        _selectedBookMatchIndex = 0;
      });
    }
  }

  Widget _buildBookMatcherResultAndJourney(
    BuildContext context,
    AppLocalizations l10n,
    InteractiveExperienceProvider expProvider,
    ExperienceResultRecord result,
  ) {
    final safeIndex =
        _selectedBookMatchIndex.clamp(0, result.topMatches.length - 1);
    final selectedMatch = result.topMatches[safeIndex];
    ReadingProvider? readingProvider;
    try {
      readingProvider = context.read<ReadingProvider>();
    } catch (_) {}
    final userItems = readingProvider?.items ?? const <ReadingItem>[];
    final profile = expProvider.resolveBookProfile(
          selectedMatch.profileId,
          userReadingItems: userItems,
        ) ??
        ExperienceCatalog.curatedBooks.first;
    final langCode = Localizations.localeOf(context).languageCode;
    final dailyMins =
        (result.answersSnapshot['bm_q_daily_mins'] as num?)?.toInt() ?? 20;
    final estDays = profile.estimatedDaysToFinish(dailyMins);

    String tierBadgeKey = 'bm_tier_1_badge';
    Color tierColor = const Color(0xFF10B981);
    if (profile.tierSource == 2) {
      tierBadgeKey = 'bm_tier_2_badge';
      tierColor = const Color(0xFFD97706);
    } else if (profile.tierSource == 3) {
      tierBadgeKey = 'bm_tier_3_badge';
      tierColor = const Color(0xFF6366F1);
    }

    return Container(
      key: const ValueKey('book_matcher_result_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.tr('bm_title'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('btn_book_matcher_enrich_online'),
                onPressed: _isEnrichingBooks
                    ? null
                    : () async {
                        setState(() {
                          _isEnrichingBooks = true;
                        });
                        try {
                          await expProvider.enrichBookMatcherViaOpenLibrary(
                            userReadingItems: userItems,
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isEnrichingBooks = false;
                            });
                          }
                        }
                      },
                icon: const Icon(Icons.cloud_download_outlined, size: 15),
                label: Text(
                  l10n.tr('bm_enrich_online_btn'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Top 3 book match selector tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < result.topMatches.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final m = result.topMatches[i];
                      final p = expProvider.resolveBookProfile(
                        m.profileId,
                        userReadingItems: userItems,
                      );
                      if (p == null) return const SizedBox.shrink();
                      final isSelected = i == safeIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: ValueKey('bm_match_chip_$i'),
                          selected: isSelected,
                          label: Text(
                            '${p.iconEmoji} ${p.localizedTitleFor(langCode)} (${m.matchPercentage}%)',
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedBookMatchIndex = i;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Selected Book Detail Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.iconEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.tr(tierBadgeKey),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: tierColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.localizedTitleFor(langCode),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.tr('bm_author_by', {'author': profile.author}),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.tr(profile.genre.titleKey)} • ${l10n.tr('bm_pages_and_days', {
                            'pages': profile.pageCount,
                            'days': estDays,
                            'mins': dailyMins,
                          })}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.tr('exp_match_score_pill', {
                    'score': selectedMatch.matchPercentage,
                  }),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            profile.localizedSynopsisFor(langCode),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),

          // Explainable "Why This Fits You" Breakdown
          Text(
            l10n.tr('exp_why_this_fits'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              profile.localizedWhyItFitsFor(langCode),
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          for (final reasonKey in selectedMatch.reasonKeys)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 15,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.tr(
                        reasonKey,
                        selectedMatch.reasonParamsByKey[reasonKey],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 24),

          // Connected 1-Tap Multi-Bird Handoffs (Pippin + Seren + Roo)
          Text(
            l10n.tr('exp_connected_bird_journey_title'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.tr('exp_connected_bird_journey_desc'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 10),

          // 1. Pippin: Add matched book to ReadingProvider (Want to Read / Currently Reading)
          _buildConnectedActionTile(
            context: context,
            keyName: 'btn_bm_pippin_add_book',
            icon: Icons.auto_stories_rounded,
            accentColor: const Color(0xFF10B981),
            label: result.addedToPippinBookId != null
                ? l10n.tr('bm_action_pippin_added')
                : l10n.tr('bm_action_pippin_add_book', {
                    'pages': profile.pageCount,
                  }),
            isCompleted: result.addedToPippinBookId != null,
            onTap: () async {
              final rp = context.read<ReadingProvider>();
              await expProvider.addMatchedBookToPippinReading(
                resultId: result.id,
                profile: profile,
                readingProvider: rp,
                status: ReadingStatus.wantToRead,
              );
            },
          ),

          // 2. Seren: Start paired reading soundscape (nylon_guitar, gentle_rain, warm_piano)
          _buildConnectedActionTile(
            context: context,
            keyName: 'btn_bm_seren_play_sound',
            icon: Icons.spa_rounded,
            accentColor: const Color(0xFFEC4899),
            label: result.playedSerenSoundId != null
                ? l10n.tr('bm_action_seren_sound_done')
                : l10n.tr('bm_action_seren_sound', {
                    'sound': profile.pairedSerenSoundId,
                  }),
            isCompleted: result.playedSerenSoundId != null,
            onTap: () async {
              final serenProvider = context.read<SerenRelaxationProvider>();
              await expProvider.startBookMatcherSerenSoundscape(
                resultId: result.id,
                profile: profile,
                serenProvider: serenProvider,
              );
            },
          ),

          // 3. Roo: Schedule 20-minute evening reading habit block in RoutineProvider & TaskProvider
          _buildConnectedActionTile(
            context: context,
            keyName: 'btn_bm_roo_schedule_habit',
            icon: Icons.schedule_rounded,
            accentColor: const Color(0xFF8B5CF6),
            label: result.createdRooRoutineId != null ||
                    result.createdRooTaskId != null
                ? l10n.tr('bm_action_roo_habit_done')
                : l10n.tr('bm_action_roo_habit', {
                    'mins': dailyMins,
                  }),
            isCompleted: result.createdRooRoutineId != null ||
                result.createdRooTaskId != null,
            onTap: () async {
              RoutineProvider? routineProvider;
              CrossModuleLinkProvider? linkProvider;
              final taskProvider = context.read<TaskProvider>();
              try {
                routineProvider = context.read<RoutineProvider>();
              } catch (_) {}
              try {
                linkProvider = context.read<CrossModuleLinkProvider>();
              } catch (_) {}
              await expProvider.scheduleBookReadingHabitInRoo(
                resultId: result.id,
                profile: profile,
                taskProvider: taskProvider,
                routineProvider: routineProvider,
                linkProvider: linkProvider,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekendGeneratorHeroCard(
    BuildContext context,
    AppLocalizations l10n,
    InteractiveExperienceProvider expProvider,
    ExperienceSessionDraft? weekendDraft,
  ) {
    final visibleTotal = expProvider
        .visibleQuestionsFor(ExperienceCatalog.weekendGeneratorV1)
        .length;
    BeforeYouGoProvider? bygProvider;
    try {
      bygProvider = context.watch<BeforeYouGoProvider>();
    } catch (_) {}
    final weather = bygProvider?.currentWeather;

    return Container(
      key: const ValueKey('weekend_generator_hero_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/mascots/sprites/duos/duo_scout_pippin_weather_outing.png',
                width: 46,
                height: 46,
                errorBuilder: (_, _, _) =>
                    const Text('⛺', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.tr('wg_badge'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('wg_title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tr('wg_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          if (weather != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    weather.isRainy
                        ? Icons.umbrella_rounded
                        : Icons.wb_sunny_rounded,
                    size: 15,
                    color: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.tr('wg_live_weather_pill', {
                        'temp': weather.temperatureCelsius.round(),
                        'cond': weather.condition,
                        'rain': weather.rainChancePercent,
                      }),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (weekendDraft != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.tr('exp_draft_saved_banner', {
                  'answered': weekendDraft.answeredCount,
                  'total': visibleTotal,
                }),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('btn_resume_weekend_generator'),
                    onPressed: () => _openWeekendGeneratorSheet(
                      context,
                      resumeDraft: true,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(l10n.tr('exp_resume_draft')),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  key: const ValueKey('btn_restart_weekend_generator'),
                  onPressed: () => _openWeekendGeneratorSheet(
                    context,
                    resumeDraft: false,
                  ),
                  child: Text(l10n.tr('exp_restart_fresh')),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_start_weekend_generator'),
                onPressed: () => _openWeekendGeneratorSheet(
                  context,
                  resumeDraft: false,
                ),
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: Text(l10n.tr('wg_start_button')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openWeekendGeneratorSheet(
    BuildContext context, {
    required bool resumeDraft,
  }) async {
    final expProvider = context.read<InteractiveExperienceProvider>();
    BeforeYouGoProvider? bygProvider;
    try {
      bygProvider = context.read<BeforeYouGoProvider>();
    } catch (_) {}
    if (bygProvider != null && bygProvider.currentWeather == null) {
      unawaited(
        bygProvider.refreshWeatherPrompts(rescheduleNotifications: false),
      );
    }

    if (resumeDraft) {
      await expProvider.startOrResumeSession(
        ExperienceCatalog.weekendGeneratorV1,
      );
    } else {
      await expProvider.startFreshSession(
        ExperienceCatalog.weekendGeneratorV1,
      );
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HobbyFinderFlowSheet(
        definition: ExperienceCatalog.weekendGeneratorV1,
      ),
    );
    if (mounted) {
      setState(() {
        _selectedWeekendMatchIndex = 0;
      });
    }
  }

  Widget _buildWeekendGeneratorResultAndJourney(
    BuildContext context,
    AppLocalizations l10n,
    InteractiveExperienceProvider expProvider,
    ExperienceResultRecord result,
  ) {
    final safeIndex =
        _selectedWeekendMatchIndex.clamp(0, result.topMatches.length - 1);
    final selectedMatch = result.topMatches[safeIndex];
    final profile =
        WeekendGeneratorCatalog.findById(selectedMatch.profileId) ??
            WeekendGeneratorCatalog.itineraries.first;
    final localizedTitle = l10n.tr(profile.titleKey);
    final localizedPlaceName = l10n.tr(profile.suggestedPlaceNameKey);
    final localizedGearItems =
        profile.checklistItemKeys.map((k) => l10n.tr(k)).toList();

    return Container(
      key: const ValueKey('weekend_generator_result_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tr('wg_result_section_title'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          // Top 3 Weekend Itinerary Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < result.topMatches.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final m = result.topMatches[i];
                      final p = WeekendGeneratorCatalog.findById(m.profileId);
                      if (p == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: ValueKey('wg_match_chip_$i'),
                          selected: i == safeIndex,
                          label: Text(
                            '${p.iconEmoji} ${l10n.tr(p.titleKey)} (${m.matchPercentage}%)',
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedWeekendMatchIndex = i;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Selected Itinerary Detail Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.iconEmoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${l10n.tr(profile.categoryKey)} • ${profile.durationHours.toStringAsFixed(1)}h • \$${profile.estimatedPocketBudgetUsd}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.tr('exp_match_score_pill', {
                    'score': selectedMatch.matchPercentage,
                  }),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tr(profile.descriptionKey),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),

          // Micro-Itinerary Flow Steps
          Text(
            l10n.tr('wg_itinerary_steps_title'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (var idx = 0; idx < profile.timelineStepKeys.length; idx++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${idx + 1}.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.tr(profile.timelineStepKeys[idx]),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // Explainable Breakdown + Live Weather Fit
          Text(
            l10n.tr('exp_why_this_fits'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final reasonKey in selectedMatch.reasonKeys)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 15,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.tr(
                        reasonKey,
                        selectedMatch.reasonParamsByKey[reasonKey],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 24),

          // Connected 1-Tap Multi-Bird Handoffs (Scout + Roo + Twill)
          Text(
            l10n.tr('exp_connected_bird_journey_title'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          // Weekend Day + Optional Geofence & Budget Toggles
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                key: const ValueKey('wg_chip_saturday'),
                selected: _selectedWeekendDay == DateTime.saturday,
                label: Text(l10n.tr('wg_day_saturday')),
                onSelected: (_) => setState(() {
                  _selectedWeekendDay = DateTime.saturday;
                }),
              ),
              ChoiceChip(
                key: const ValueKey('wg_chip_sunday'),
                selected: _selectedWeekendDay == DateTime.sunday,
                label: Text(l10n.tr('wg_day_sunday')),
                onSelected: (_) => setState(() {
                  _selectedWeekendDay = DateTime.sunday;
                }),
              ),
              FilterChip(
                key: const ValueKey('wg_chip_geofence_opt'),
                selected: _includeWeekendGeofence,
                label: Text(l10n.tr('wg_opt_geofence_pin')),
                onSelected: (v) => setState(() {
                  _includeWeekendGeofence = v;
                }),
              ),
              if (profile.estimatedPocketBudgetUsd > 0)
                FilterChip(
                  key: const ValueKey('wg_chip_budget_opt'),
                  selected: _includeWeekendPocketBudget,
                  label: Text(
                    l10n.tr('wg_opt_pocket_cap', {
                      'usd': profile.estimatedPocketBudgetUsd,
                    }),
                  ),
                  onSelected: (v) => setState(() {
                    _includeWeekendPocketBudget = v;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Scout: Create BeforeYouGo Preset (+ weather gear & optional Geofence)
          _buildConnectedActionTile(
            context: context,
            keyName: 'btn_wg_scout_before_you_go',
            icon: Icons.explore_rounded,
            accentColor: const Color(0xFF3B82F6),
            label: result.createdScoutPresetId != null
                ? l10n.tr('wg_action_scout_done')
                : l10n.tr('wg_action_scout_departure'),
            isCompleted: result.createdScoutPresetId != null,
            onTap: () async {
              final byg = context.read<BeforeYouGoProvider>();
              GeofenceProvider? geo;
              CrossModuleLinkProvider? link;
              try {
                geo = context.read<GeofenceProvider>();
              } catch (_) {}
              try {
                link = context.read<CrossModuleLinkProvider>();
              } catch (_) {}
              final langCode = Localizations.localeOf(context).languageCode;
              await expProvider.launchWeekendInScoutBeforeYouGo(
                resultId: result.id,
                profile: profile,
                localizedTitle: localizedTitle,
                localizedGearItems: localizedGearItems,
                localizedPlaceName: localizedPlaceName,
                beforeYouGoProvider: byg,
                geofenceProvider: geo,
                linkProvider: link,
                languageCode: langCode,
                includeGeofenceReminder: _includeWeekendGeofence,
              );
            },
          ),

          // 2. Roo: Block Saturday/Sunday Activity Window on Calendar
          _buildConnectedActionTile(
            context: context,
            keyName: 'btn_wg_roo_calendar',
            icon: Icons.calendar_month_rounded,
            accentColor: const Color(0xFFE04A3A),
            label: result.createdRooCalendarEventId != null
                ? l10n.tr('wg_action_roo_calendar_done')
                : l10n.tr('wg_action_roo_calendar', {
                    'day': _selectedWeekendDay == DateTime.saturday
                        ? l10n.tr('wg_day_saturday')
                        : l10n.tr('wg_day_sunday'),
                  }),
            isCompleted: result.createdRooCalendarEventId != null,
            onTap: () async {
              final cal = context.read<CalendarProvider>();
              CrossModuleLinkProvider? link;
              try {
                link = context.read<CrossModuleLinkProvider>();
              } catch (_) {}
              await expProvider.scheduleWeekendBlockInRooCalendar(
                resultId: result.id,
                profile: profile,
                localizedTitle: localizedTitle,
                localizedDescription: l10n.tr(profile.descriptionKey),
                localizedPlaceName: localizedPlaceName,
                calendarProvider: cal,
                linkProvider: link,
                targetWeekday: _selectedWeekendDay,
              );
            },
          ),

          // 3. Twill: Duplicate Weekend Packing Checklist & Set Optional Pocket Budget Cap
          _buildConnectedActionTile(
            context: context,
            keyName: 'btn_wg_twill_pack_budget',
            icon: Icons.backpack_rounded,
            accentColor: const Color(0xFFF59E0B),
            label: result.createdTwillChecklistId != null
                ? l10n.tr('wg_action_twill_done')
                : l10n.tr('wg_action_twill_pack_budget'),
            isCompleted: result.createdTwillChecklistId != null,
            onTap: () async {
              final coll = context.read<CollectionProvider>();
              MoneyProvider? money;
              try {
                money = context.read<MoneyProvider>();
              } catch (_) {}
              await expProvider.createWeekendPackAndBudgetInTwill(
                resultId: result.id,
                profile: profile,
                localizedTitle: localizedTitle,
                localizedGearItems: localizedGearItems,
                collectionProvider: coll,
                moneyProvider: money,
                setPocketBudgetCap: _includeWeekendPocketBudget,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeArenaHeroCard(
    BuildContext context,
    AppLocalizations l10n,
    InteractiveExperienceProvider expProvider,
  ) {
    final arenaDraft =
        expProvider.draftFor(ExperienceCatalog.knowledgeArenaId);
    final latestArenaResult =
        expProvider.latestResultFor(ExperienceCatalog.knowledgeArenaId);
    final cardsForTopic =
        ExperienceCatalog.cardsForTopic(_selectedArenaTopic);
    final answeredCount = expProvider.knowledgeArenaAnsweredCount();

    return Container(
      key: const ValueKey('knowledge_arena_hero_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏛️', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.tr('ka_badge'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('ka_title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tr('ka_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),

          // Topic Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final topic in KnowledgeArenaTopic.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('ka_topic_chip_${topic.name}'),
                      selected: _selectedArenaTopic == topic,
                      label: Text(
                        '${topic.iconEmoji} ${l10n.tr(topic.titleKey)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedArenaTopic = topic;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (latestArenaResult != null) ...[
            Builder(
              builder: (context) {
                final snap = latestArenaResult.answersSnapshot;
                final correct = (snap['correctCount'] as num?)?.toInt() ?? 0;
                final total = (snap['totalCards'] as num?)?.toInt() ??
                    cardsForTopic.length;
                final percent = latestArenaResult.topMatches.isNotEmpty
                    ? latestArenaResult.topMatches.first.matchPercentage
                    : 0;
                final notesCount =
                    (snap['savedNotes'] as List?)?.length ?? 0;
                final booksCount =
                    (snap['addedBooks'] as List?)?.length ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.tr('ka_summary_title'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.tr('ka_summary_score', {
                              'correct': correct,
                              'total': total,
                              'percent': percent,
                            }),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.tr('ka_summary_saved_stats', {
                          'notes': notesCount,
                          'books': booksCount,
                        }),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          if (arenaDraft != null &&
              expProvider.activeKnowledgeArenaTopic() ==
                  _selectedArenaTopic) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('btn_resume_knowledge_arena'),
                    onPressed: () => _openKnowledgeArenaSheet(
                      context,
                      resumeDraft: true,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      l10n.tr('ka_resume_button', {
                        'answered': answeredCount,
                        'total': cardsForTopic.length,
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  key: const ValueKey('btn_restart_knowledge_arena'),
                  onPressed: () => _openKnowledgeArenaSheet(
                    context,
                    resumeDraft: false,
                  ),
                  child: Text(l10n.tr('exp_restart_fresh')),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_start_knowledge_arena'),
                onPressed: () => _openKnowledgeArenaSheet(
                  context,
                  resumeDraft: false,
                ),
                icon: const Icon(Icons.auto_stories_rounded, size: 18),
                label: Text(l10n.tr('ka_start_button')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openKnowledgeArenaSheet(
    BuildContext context, {
    required bool resumeDraft,
  }) async {
    final expProvider = context.read<InteractiveExperienceProvider>();
    if (resumeDraft) {
      await expProvider.startOrResumeKnowledgeArena(
        topic: _selectedArenaTopic,
      );
    } else {
      await expProvider.startFreshKnowledgeArena(
        topic: _selectedArenaTopic,
      );
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const KnowledgeArenaFlowSheet(),
    );
  }

  Widget _buildBrainPlaygroundHeroCard(
    BuildContext context,
    AppLocalizations l10n,
    InteractiveExperienceProvider expProvider,
  ) {
    final bpDraft =
        expProvider.draftFor(ExperienceCatalog.brainPlaygroundId);
    final latestBpResult =
        expProvider.latestResultFor(ExperienceCatalog.brainPlaygroundId);
    final puzzlesForCat =
        ExperienceCatalog.puzzlesForCategory(_selectedBrainCategory);
    final answeredCount = expProvider.brainPlaygroundAnsweredCount();

    return Container(
      key: const ValueKey('brain_playground_hero_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧩', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.tr('bp_badge'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('bp_title'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tr('bp_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in BrainPlaygroundCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('bp_cat_chip_${cat.name}'),
                      selected: _selectedBrainCategory == cat,
                      label: Text(
                        '${cat.iconEmoji} ${l10n.tr(cat.titleKey)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedBrainCategory = cat;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (latestBpResult != null) ...[
            Builder(
              builder: (context) {
                final snap = latestBpResult.answersSnapshot;
                final correct = (snap['correctCount'] as num?)?.toInt() ?? 0;
                final total = (snap['totalPuzzles'] as num?)?.toInt() ??
                    puzzlesForCat.length;
                final percent = latestBpResult.topMatches.isNotEmpty
                    ? latestBpResult.topMatches.first.matchPercentage
                    : 0;
                final logsCount = (snap['focusLogs'] as List?)?.length ?? 0;
                final notesCount = (snap['savedNotes'] as List?)?.length ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              l10n.tr('bp_summary_title'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            l10n.tr('bp_summary_score', {
                              'correct': correct,
                              'total': total,
                              'percent': percent,
                            }),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.tr('bp_summary_handoffs', {
                          'logs': logsCount,
                          'notes': notesCount,
                        }),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          if (bpDraft != null &&
              expProvider.activeBrainPlaygroundCategory() ==
                  _selectedBrainCategory) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('btn_resume_brain_playground'),
                    onPressed: () => _openBrainPlaygroundSheet(
                      context,
                      resumeDraft: true,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      l10n.tr('bp_resume_button', {
                        'answered': answeredCount,
                        'total': puzzlesForCat.length,
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  key: const ValueKey('btn_restart_brain_playground'),
                  onPressed: () => _openBrainPlaygroundSheet(
                    context,
                    resumeDraft: false,
                  ),
                  child: Text(l10n.tr('exp_restart_fresh')),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_start_brain_playground'),
                onPressed: () => _openBrainPlaygroundSheet(
                  context,
                  resumeDraft: false,
                ),
                icon: const Icon(Icons.extension_rounded, size: 18),
                label: Text(l10n.tr('bp_start_button')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openBrainPlaygroundSheet(
    BuildContext context, {
    required bool resumeDraft,
  }) async {
    final expProvider = context.read<InteractiveExperienceProvider>();
    if (resumeDraft) {
      await expProvider.startOrResumeBrainPlayground(
        category: _selectedBrainCategory,
      );
    } else {
      await expProvider.startFreshBrainPlayground(
        category: _selectedBrainCategory,
      );
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BrainPlaygroundFlowSheet(),
    );
  }

  Widget _buildLatestResultAndMultiBirdJourney(
    BuildContext context,
    AppLocalizations l10n,
    InteractiveExperienceProvider expProvider,
    ExperienceResultRecord result,
  ) {
    final safeIndex =
        _selectedMatchIndex.clamp(0, result.topMatches.length - 1);
    final selectedMatch = result.topMatches[safeIndex];
    final profile =
        ExperienceCatalog.findHobbyProfileById(selectedMatch.profileId) ??
            ExperienceCatalog.hobbyProfiles.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tr('exp_history_title'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          // Top 3 match selector tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < result.topMatches.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final m = result.topMatches[i];
                      final p =
                          ExperienceCatalog.findHobbyProfileById(m.profileId);
                      if (p == null) return const SizedBox.shrink();
                      final isSelected = i == safeIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: isSelected,
                          label: Text(
                            '${p.iconEmoji} ${l10n.tr(p.titleKey)} (${m.matchPercentage}%)',
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedMatchIndex = i;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Selected Hobby Profile Detail Card
          Row(
            children: [
              Text(profile.iconEmoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr(profile.titleKey),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.tr(profile.categoryKey),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.tr('exp_match_score_pill', {
                    'score': selectedMatch.matchPercentage,
                  }),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tr(profile.descriptionKey),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),

          // Explainable "Why This Fits You" Breakdown
          Text(
            l10n.tr('exp_why_this_fits'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final reasonKey in selectedMatch.reasonKeys)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 15,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.tr(
                        reasonKey,
                        selectedMatch.reasonParamsByKey[reasonKey],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 24),

          // Connected Nestin Multi-Bird Journey Handoff Actions
          Text(
            l10n.tr('exp_connected_bird_journey_title'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.tr('exp_connected_bird_journey_desc'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 10),

          // 1. Pippin: Add to Hobbies
          _buildConnectedActionTile(
            context: context,
            keyName: 'action_pippin_add_hobby',
            icon: Icons.emoji_nature_rounded,
            accentColor: const Color(0xFF10B981),
            label: result.addedToPippinHobbyId != null
                ? l10n.tr('exp_action_pippin_added')
                : l10n.tr('exp_action_pippin_add_hobby', {
                    'hours': profile.recommendedTargetHours,
                  }),
            isCompleted: result.addedToPippinHobbyId != null,
            onTap: () async {
              final hobbyProvider = context.read<HobbyProvider>();
              await expProvider.launchHobbyInPippin(
                resultId: result.id,
                profile: profile,
                localizedTitle: l10n.tr(profile.titleKey),
                localizedCategory: l10n.tr(profile.categoryKey),
                localizedDescription: l10n.tr(profile.descriptionKey),
                hobbyProvider: hobbyProvider,
              );
            },
          ),

          // 2. Twill: Starter Gear & Setup Checklist
          _buildConnectedActionTile(
            context: context,
            keyName: 'action_twill_checklist',
            icon: Icons.checklist_rounded,
            accentColor: const Color(0xFF0EA5E9),
            label: result.createdTwillChecklistId != null
                ? l10n.tr('exp_action_twill_checklist_done')
                : l10n.tr('exp_action_twill_checklist'),
            isCompleted: result.createdTwillChecklistId != null,
            onTap: () async {
              final collectionProvider = context.read<CollectionProvider>();
              await expProvider.createStarterChecklistInTwill(
                resultId: result.id,
                profile: profile,
                localizedHobbyTitle: l10n.tr(profile.titleKey),
                collectionProvider: collectionProvider,
              );
            },
          ),

          // 3. Twill: Starter Kit Budget Estimate (Wishlist)
          _buildConnectedActionTile(
            context: context,
            keyName: 'action_twill_wishlist',
            icon: Icons.savings_outlined,
            accentColor: const Color(0xFFF59E0B),
            label: result.createdTwillWishlistId != null
                ? l10n.tr('exp_action_twill_wishlist_done')
                : l10n.tr('exp_action_twill_wishlist', {
                    'cost': profile.estimatedStarterCostUsd,
                  }),
            isCompleted: result.createdTwillWishlistId != null,
            onTap: () async {
              final collectionProvider = context.read<CollectionProvider>();
              await expProvider.createBudgetEstimateInTwillWishlist(
                resultId: result.id,
                profile: profile,
                localizedHobbyTitle: l10n.tr(profile.titleKey),
                collectionProvider: collectionProvider,
              );
            },
          ),

          // 4. Roo: Schedule First 30-Min Starter Session
          _buildConnectedActionTile(
            context: context,
            keyName: 'action_roo_task',
            icon: Icons.task_alt_rounded,
            accentColor: const Color(0xFF8B5CF6),
            label: result.createdRooTaskId != null
                ? l10n.tr('exp_action_roo_task_done')
                : l10n.tr('exp_action_roo_task'),
            isCompleted: result.createdRooTaskId != null,
            onTap: () async {
              final taskProvider = context.read<TaskProvider>();
              CrossModuleLinkProvider? linkProvider;
              try {
                linkProvider = context.read<CrossModuleLinkProvider>();
              } catch (_) {}
              await expProvider.createStarterTaskInRoo(
                resultId: result.id,
                profile: profile,
                localizedHobbyTitle: l10n.tr(profile.titleKey),
                taskProvider: taskProvider,
                linkProvider: linkProvider,
              );
            },
          ),

          // 5. Seren: Play Paired Calm Soundscape
          _buildConnectedActionTile(
            context: context,
            keyName: 'action_seren_sound',
            icon: Icons.spa_rounded,
            accentColor: const Color(0xFFEC4899),
            label: result.playedSerenSoundId != null
                ? l10n.tr('exp_action_seren_sound_done')
                : l10n.tr('exp_action_seren_sound'),
            isCompleted: result.playedSerenSoundId != null,
            onTap: () async {
              final serenProvider = context.read<SerenRelaxationProvider>();
              await expProvider.startSerenPairedSoundscape(
                resultId: result.id,
                profile: profile,
                serenProvider: serenProvider,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedActionTile({
    required BuildContext context,
    required String keyName,
    required IconData icon,
    required Color accentColor,
    required String label,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey(keyName),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCompleted
                ? accentColor.withValues(alpha: 0.14)
                : AppColors.trackSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? accentColor.withValues(alpha: 0.5)
                  : AppColors.border(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle_rounded : icon,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateAuditCard(
    BuildContext context,
    AppLocalizations l10n,
    ExperienceCandidateAudit candidate,
  ) {
    final isLive =
        candidate.status == ExperienceCandidateStatus.referenceImplemented;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(candidate.iconEmoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr(candidate.titleKey),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${candidate.primaryBird} + ${candidate.supportingBirds.join(", ")}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isLive
                            ? const Color(0xFF10B981)
                            : const Color(0xFF0EA5E9))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.tr(candidate.status.badgeKey),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isLive
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tr(candidate.descriptionKey),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive step-by-step Questionnaire Sheet for Pippin's Hobby Finder & Next-Book Matcher.
class HobbyFinderFlowSheet extends StatelessWidget {
  final ExperienceDefinition definition;

  const HobbyFinderFlowSheet({
    super.key,
    this.definition = ExperienceCatalog.hobbyFinderV1,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Consumer<InteractiveExperienceProvider>(
          builder: (context, expProvider, _) {
            final draft = expProvider.draftFor(definition.id);
            if (draft == null) {
              return const SizedBox.shrink();
            }
            final visibleQuestions =
                expProvider.visibleQuestionsFor(definition);
            final currentIndex = draft.currentQuestionIndex
                .clamp(0, visibleQuestions.length - 1);
            final question = visibleQuestions[currentIndex];
            final isSatisfied =
                expProvider.engine.isQuestionSatisfied(question, draft);
            final isLastStep = currentIndex >= visibleQuestions.length - 1;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar: Progress + Save Draft & Exit
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tr('exp_question_progress', {
                          'current': currentIndex + 1,
                          'total': visibleQuestions.length,
                        }),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: TextButton.icon(
                        key: const ValueKey('btn_save_draft_and_exit'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.bookmark_outline_rounded, size: 16),
                        label: Text(
                          l10n.tr('exp_save_and_exit'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (currentIndex + 1) / visibleQuestions.length,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 16),

                // Question Title & Optional Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tr(question.titleKey),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (question.isOptional)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.trackSurface(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.tr('exp_optional_tag'),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.tr(question.subtitleKey),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 16),

                // Question Body
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildQuestionInput(
                      context,
                      l10n,
                      expProvider,
                      definition,
                      question,
                      draft,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bottom Navigation Controls
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (currentIndex > 0)
                            OutlinedButton(
                              key: const ValueKey('btn_prev_question'),
                              onPressed: () => expProvider.goToQuestionIndex(
                                definition: definition,
                                index: currentIndex - 1,
                              ),
                              child: Text(l10n.tr('exp_previous_step')),
                            ),
                          if (question.isOptional && !isLastStep)
                            TextButton(
                              key: const ValueKey('btn_skip_optional_question'),
                              onPressed: () => expProvider.skipOptionalQuestion(
                                definition: definition,
                                question: question,
                              ),
                              child: Text(l10n.tr('exp_skip_question')),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      key: const ValueKey('btn_next_or_complete_question'),
                      onPressed: isSatisfied
                          ? () async {
                              if (isLastStep) {
                                if (definition.id ==
                                    ExperienceCatalog.bookMatcherId) {
                                  ReadingProvider? rp;
                                  try {
                                    rp = context.read<ReadingProvider>();
                                  } catch (_) {}
                                  await expProvider.completeBookMatcherSession(
                                    userReadingItems:
                                        rp?.items ?? const <ReadingItem>[],
                                  );
                                } else if (definition.id ==
                                    ExperienceCatalog.weekendGeneratorId) {
                                  BeforeYouGoProvider? byg;
                                  try {
                                    byg = context.read<BeforeYouGoProvider>();
                                  } catch (_) {}
                                  final weather = byg?.currentWeather ??
                                      await byg?.refreshWeatherPrompts(
                                        rescheduleNotifications: false,
                                      );
                                  await expProvider
                                      .completeWeekendGeneratorSession(
                                    currentWeather: weather,
                                  );
                                } else {
                                  await expProvider.completeSession(definition);
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              } else {
                                await expProvider.goToQuestionIndex(
                                  definition: definition,
                                  index: currentIndex + 1,
                                );
                              }
                            }
                          : null,
                      child: Text(
                        isLastStep
                            ? l10n.tr('exp_see_matches')
                            : l10n.tr('exp_next_step'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuestionInput(
    BuildContext context,
    AppLocalizations l10n,
    InteractiveExperienceProvider expProvider,
    ExperienceDefinition definition,
    ExperienceQuestion question,
    ExperienceSessionDraft draft,
  ) {
    if (question.type == ExperienceQuestionType.slider ||
        question.type == ExperienceQuestionType.numericInput) {
      final currentVal =
          draft.numericValueByQuestion[question.id] ?? question.defaultValue;
      final isMinutes = question.id == 'bm_q_daily_mins';
      final displayText = isMinutes
          ? l10n.tr('bm_daily_mins_unit', {
              'mins': currentVal.toStringAsFixed(0),
            })
          : '${currentVal.toStringAsFixed(0)}h / week';
      final divisions = isMinutes
          ? ((question.maxValue - question.minValue) ~/ 5).clamp(1, 20)
          : (question.maxValue - question.minValue).round().clamp(1, 30);

      return Column(
        children: [
          Text(
            displayText,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Slider(
            value: currentVal.clamp(question.minValue, question.maxValue),
            min: question.minValue,
            max: question.maxValue,
            divisions: divisions,
            label: displayText,
            onChanged: (val) => expProvider.setNumericValue(
              definition: definition,
              question: question,
              value: val,
            ),
          ),
        ],
      );
    }

    final selectedIds =
        draft.selectedOptionIdsByQuestion[question.id] ?? const [];

    return Column(
      children: [
        for (final option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              key: ValueKey('option_${option.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => expProvider.selectOption(
                definition: definition,
                question: question,
                optionId: option.id,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selectedIds.contains(option.id)
                      ? const Color(0xFF10B981).withValues(alpha: 0.16)
                      : AppColors.trackSurface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedIds.contains(option.id)
                        ? const Color(0xFF10B981)
                        : AppColors.border(context),
                  ),
                ),
                child: Row(
                  children: [
                    Text(option.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.tr(option.labelKey),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (question.type == ExperienceQuestionType.ranking &&
                        selectedIds.contains(option.id))
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: const Color(0xFF10B981),
                        child: Text(
                          '${selectedIds.indexOf(option.id) + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else if (selectedIds.contains(option.id))
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Interactive step-by-step Curiosity & Trivia Runner for Echo's Knowledge Arena (`knowledge_arena_v1`).
class KnowledgeArenaFlowSheet extends StatelessWidget {
  const KnowledgeArenaFlowSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Consumer<InteractiveExperienceProvider>(
          builder: (context, expProvider, _) {
            final draft =
                expProvider.draftFor(ExperienceCatalog.knowledgeArenaId);
            if (draft == null) {
              return const SizedBox.shrink();
            }
            final cards = expProvider.activeKnowledgeArenaCards();
            if (cards.isEmpty) {
              return const SizedBox.shrink();
            }
            final currentIndex =
                draft.currentQuestionIndex.clamp(0, cards.length - 1);
            final card = cards[currentIndex];
            final selectedOptionId =
                expProvider.selectedOptionForKnowledgeCard(card.id);
            final isAnswered = selectedOptionId != null;
            final isCorrect = selectedOptionId == card.correctOptionId;
            final isLastCard = currentIndex >= cards.length - 1;
            final isNoteSaved = expProvider.isFactCardSavedToNotes(card.id);
            final isBookAdded =
                expProvider.isSuggestedBookAddedToReading(card.id);
            final localizedBookTitle = l10n.tr(card.suggestedBookTitleKey);
            final localizedBookAuthor = l10n.tr(card.suggestedBookAuthorKey);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Progress & Save Draft Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            card.topic.iconEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.tr('ka_card_progress', {
                                'current': currentIndex + 1,
                                'total': cards.length,
                              }),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('btn_ka_save_and_exit'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.bookmark_outline_rounded, size: 16),
                      label: Text(l10n.tr('exp_save_and_exit')),
                    ),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (currentIndex + 1) / cards.length,
                    minHeight: 6,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Scrollable Question, Options, Explainable Fact Card & Multi-Bird Actions
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr(card.promptKey),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Options
                        for (final option in card.options) ...[
                          Builder(
                            builder: (context) {
                              final isThisSelected =
                                  selectedOptionId == option.id;
                              final showGreen = isAnswered && option.isCorrect;
                              final showAmber = isAnswered &&
                                  isThisSelected &&
                                  !option.isCorrect;

                              Color borderColor = AppColors.border(context);
                              Color bgColor = AppColors.trackSurface(context);
                              if (showGreen) {
                                borderColor = const Color(0xFF10B981);
                                bgColor = const Color(0xFF10B981)
                                    .withValues(alpha: 0.16);
                              } else if (showAmber) {
                                borderColor = const Color(0xFFF59E0B);
                                bgColor = const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.16);
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  key: ValueKey('ka_opt_${option.id}'),
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      expProvider.answerKnowledgeArenaCard(
                                    card: card,
                                    optionId: option.id,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            l10n.tr(option.labelKey),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (showGreen)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF10B981),
                                            size: 18,
                                          )
                                        else if (showAmber)
                                          const Icon(
                                            Icons.lightbulb_outline_rounded,
                                            color: Color(0xFFF59E0B),
                                            size: 18,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],

                        // Explainable Curiosity Fact Card + 1-Tap Echo & Pippin Actions
                        if (isAnswered) ...[
                          const SizedBox(height: 12),
                          Container(
                            key: const ValueKey('ka_explanation_card'),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isCorrect
                                          ? Icons.auto_awesome_rounded
                                          : Icons.menu_book_rounded,
                                      size: 18,
                                      color: isCorrect
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF6366F1),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isCorrect
                                            ? l10n.tr('ka_correct_banner')
                                            : l10n.tr('ka_incorrect_banner'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isCorrect
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF6366F1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.tr(card.factTitleKey),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.tr(card.explanationKey),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 12),

                                // 1. Echo 1-Tap Action: Save Fact Card to Echo Notes
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: const ValueKey(
                                        'btn_ka_save_fact_note'),
                                    onPressed: isNoteSaved
                                        ? null
                                        : () async {
                                            final noteProvider =
                                                context.read<NoteProvider>();
                                            CrossModuleLinkProvider?
                                                linkProvider;
                                            try {
                                              linkProvider = context.read<
                                                  CrossModuleLinkProvider>();
                                            } catch (_) {}
                                            final correctOpt = card.options
                                                .firstWhere(
                                                    (o) => o.isCorrect);
                                            await expProvider
                                                .saveFactCardToEchoNotes(
                                              card: card,
                                              localizedTopic: l10n
                                                  .tr(card.topic.titleKey),
                                              localizedFactTitle:
                                                  l10n.tr(card.factTitleKey),
                                              localizedPrompt:
                                                  l10n.tr(card.promptKey),
                                              localizedCorrectAnswer:
                                                  l10n.tr(correctOpt.labelKey),
                                              localizedExplanation:
                                                  l10n.tr(card.explanationKey),
                                              localizedBookTitle:
                                                  localizedBookTitle,
                                              localizedBookAuthor:
                                                  localizedBookAuthor,
                                              noteProvider: noteProvider,
                                              linkProvider: linkProvider,
                                            );
                                          },
                                    icon: Icon(
                                      isNoteSaved
                                          ? Icons.check_circle_rounded
                                          : Icons.bookmark_add_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isNoteSaved
                                          ? l10n.tr('ka_saved_fact_to_echo')
                                          : l10n.tr('ka_save_fact_to_echo'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // 2. Pippin 1-Tap Action: Add Related Book to ReadingProvider
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: const ValueKey(
                                        'btn_ka_add_pippin_book'),
                                    onPressed: isBookAdded
                                        ? null
                                        : () async {
                                            final readingProvider = context
                                                .read<ReadingProvider>();
                                            CrossModuleLinkProvider?
                                                linkProvider;
                                            try {
                                              linkProvider = context.read<
                                                  CrossModuleLinkProvider>();
                                            } catch (_) {}
                                            await expProvider
                                                .addSuggestedBookToPippinReading(
                                              card: card,
                                              localizedTopic: l10n
                                                  .tr(card.topic.titleKey),
                                              localizedFactTitle:
                                                  l10n.tr(card.factTitleKey),
                                              localizedBookTitle:
                                                  localizedBookTitle,
                                              localizedBookAuthor:
                                                  localizedBookAuthor,
                                              readingProvider: readingProvider,
                                              linkProvider: linkProvider,
                                            );
                                          },
                                    icon: Icon(
                                      isBookAdded
                                          ? Icons.check_circle_rounded
                                          : Icons.menu_book_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isBookAdded
                                          ? l10n.tr('ka_added_book_to_pippin')
                                          : l10n.tr('ka_add_book_to_pippin', {
                                              'book': localizedBookTitle,
                                            }),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bottom Navigation Row
                Row(
                  children: [
                    if (currentIndex > 0)
                      OutlinedButton(
                        key: const ValueKey('btn_ka_prev_card'),
                        onPressed: () => expProvider
                            .goToKnowledgeArenaCardIndex(currentIndex - 1),
                        child: Text(l10n.tr('exp_previous_step')),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      key: const ValueKey('btn_ka_next_or_finish'),
                      onPressed: isAnswered
                          ? () async {
                              if (isLastCard) {
                                await expProvider
                                    .completeKnowledgeArenaSession();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              } else {
                                await expProvider.goToKnowledgeArenaCardIndex(
                                  currentIndex + 1,
                                );
                              }
                            }
                          : null,
                      child: Text(
                        isLastCard
                            ? l10n.tr('ka_finish_arena')
                            : l10n.tr('ka_next_card'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Interactive Calm Cognitive Warm-Up Runner for Echo's Brain Playground (`brain_playground_v1`).
class BrainPlaygroundFlowSheet extends StatefulWidget {
  const BrainPlaygroundFlowSheet({super.key});

  @override
  State<BrainPlaygroundFlowSheet> createState() =>
      _BrainPlaygroundFlowSheetState();
}

class _BrainPlaygroundFlowSheetState extends State<BrainPlaygroundFlowSheet> {
  bool _showOptionalTimer = false;
  int _elapsedSeconds = 0;
  Timer? _paceTimer;
  bool _pomodoroStartedInSession = false;

  void _toggleTimer() {
    setState(() {
      _showOptionalTimer = !_showOptionalTimer;
      if (_showOptionalTimer) {
        _paceTimer?.cancel();
        _paceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _elapsedSeconds++;
            });
          }
        });
      } else {
        _paceTimer?.cancel();
        _paceTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _paceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Consumer<InteractiveExperienceProvider>(
          builder: (context, expProvider, _) {
            final draft =
                expProvider.draftFor(ExperienceCatalog.brainPlaygroundId);
            if (draft == null) {
              return const SizedBox.shrink();
            }
            final puzzles = expProvider.activeBrainPlaygroundPuzzles();
            if (puzzles.isEmpty) {
              return const SizedBox.shrink();
            }
            final currentIndex =
                draft.currentQuestionIndex.clamp(0, puzzles.length - 1);
            final puzzle = puzzles[currentIndex];
            final selectedOptionId =
                expProvider.selectedOptionForBrainPuzzle(puzzle.id);
            final isAnswered = selectedOptionId != null;
            final isCorrect = selectedOptionId == puzzle.correctOptionId;
            final isLastPuzzle = currentIndex >= puzzles.length - 1;
            final isFocusLogged =
                expProvider.isPuzzleLoggedToRooFocus(puzzle.id);
            final isNoteSaved =
                expProvider.isPuzzleSavedToEchoNotes(puzzle.id);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Progress + Save & Exit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            puzzle.category.iconEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.tr('bp_puzzle_progress', {
                                'current': currentIndex + 1,
                                'total': puzzles.length,
                              }),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('btn_bp_save_and_exit'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.bookmark_outline_rounded, size: 16),
                      label: Text(l10n.tr('exp_save_and_exit')),
                    ),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (currentIndex + 1) / puzzles.length,
                    minHeight: 6,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    key: const ValueKey('btn_bp_toggle_timer'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _toggleTimer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showOptionalTimer
                                ? Icons.timer_outlined
                                : Icons.spa_outlined,
                            size: 14,
                            color: const Color(0xFF8B5CF6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showOptionalTimer
                                ? l10n.tr('bp_timer_mode_pill', {
                                    'seconds': _elapsedSeconds,
                                  })
                                : l10n.tr('bp_calm_mode_pill'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Scrollable Puzzle Body
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr(puzzle.titleKey),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Visual Pattern Display Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.30),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              puzzle.visualBanner,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          l10n.tr(puzzle.promptKey),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Options
                        for (final option in puzzle.options) ...[
                          Builder(
                            builder: (context) {
                              final isThisSelected =
                                  selectedOptionId == option.id;
                              final showGreen = isAnswered && option.isCorrect;
                              final showAmber = isAnswered &&
                                  isThisSelected &&
                                  !option.isCorrect;

                              Color borderColor = AppColors.border(context);
                              Color bgColor = AppColors.trackSurface(context);
                              if (showGreen) {
                                borderColor = const Color(0xFF10B981);
                                bgColor = const Color(0xFF10B981)
                                    .withValues(alpha: 0.16);
                              } else if (showAmber) {
                                borderColor = const Color(0xFFF59E0B);
                                bgColor = const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.16);
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  key: ValueKey('bp_opt_${option.id}'),
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      expProvider.answerBrainPlaygroundPuzzle(
                                    puzzle: puzzle,
                                    optionId: option.id,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            l10n.tr(option.labelKey),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (showGreen)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF10B981),
                                            size: 18,
                                          )
                                        else if (showAmber)
                                          const Icon(
                                            Icons.lightbulb_outline_rounded,
                                            color: Color(0xFFF59E0B),
                                            size: 18,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],

                        // Reasoning Explanation + 1-Tap Roo Pomodoro & Echo Notes Handoffs
                        if (isAnswered) ...[
                          const SizedBox(height: 12),
                          Container(
                            key: const ValueKey('bp_explanation_card'),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isCorrect
                                          ? Icons.psychology_alt_rounded
                                          : Icons.lightbulb_outline_rounded,
                                      size: 18,
                                      color: isCorrect
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF8B5CF6),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isCorrect
                                            ? l10n.tr('bp_solved_banner')
                                            : l10n.tr('bp_explore_banner'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isCorrect
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF8B5CF6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.tr(puzzle.explanationKey),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 12),

                                // 1. Roo Action: Log 3-Min Pre-Focus Warm-Up (FocusSessionLog)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: const ValueKey(
                                        'btn_bp_log_focus_session'),
                                    onPressed: isFocusLogged
                                        ? null
                                        : () async {
                                            final timerProvider =
                                                context.read<TimerProvider>();
                                            await expProvider
                                                .logWarmupToRooFocusHistory(
                                              puzzle: puzzle,
                                              localizedPuzzleTitle:
                                                  l10n.tr(puzzle.titleKey),
                                              timerProvider: timerProvider,
                                              durationMinutes: 3,
                                              startPomodoroSprint: false,
                                            );
                                          },
                                    icon: Icon(
                                      isFocusLogged
                                          ? Icons.check_circle_rounded
                                          : Icons.history_edu_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isFocusLogged
                                          ? l10n.tr(
                                              'bp_action_logged_focus_session')
                                          : l10n.tr(
                                              'bp_action_log_focus_session'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // 2. Roo Action: Start 25-Min Pomodoro Sprint Now
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: const ValueKey(
                                        'btn_bp_start_pomodoro'),
                                    onPressed: _pomodoroStartedInSession
                                        ? null
                                        : () async {
                                            final timerProvider =
                                                context.read<TimerProvider>();
                                            if (!isFocusLogged) {
                                              await expProvider
                                                  .logWarmupToRooFocusHistory(
                                                puzzle: puzzle,
                                                localizedPuzzleTitle:
                                                    l10n.tr(puzzle.titleKey),
                                                timerProvider: timerProvider,
                                                durationMinutes: 3,
                                                startPomodoroSprint: true,
                                              );
                                            } else {
                                              timerProvider
                                                  .setPomodoroTaskLabel(
                                                '🧩 ${l10n.tr(puzzle.titleKey)}',
                                              );
                                              await timerProvider
                                                  .startPomodoro();
                                            }
                                            if (mounted) {
                                              setState(() {
                                                _pomodoroStartedInSession =
                                                    true;
                                              });
                                            }
                                          },
                                    icon: Icon(
                                      _pomodoroStartedInSession
                                          ? Icons.check_circle_rounded
                                          : Icons.timer_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _pomodoroStartedInSession
                                          ? l10n
                                              .tr('bp_action_started_pomodoro')
                                          : l10n.tr('bp_action_start_pomodoro'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // 3. Echo Action: Save Reasoning Strategy to Echo Notes
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: const ValueKey(
                                        'btn_bp_save_echo_note'),
                                    onPressed: isNoteSaved
                                        ? null
                                        : () async {
                                            final noteProvider =
                                                context.read<NoteProvider>();
                                            final correctOpt = puzzle.options
                                                .firstWhere(
                                                    (o) => o.isCorrect);
                                            await expProvider
                                                .savePuzzleInsightToEchoNotes(
                                              puzzle: puzzle,
                                              localizedCategory: l10n.tr(
                                                  puzzle.category.titleKey),
                                              localizedPuzzleTitle:
                                                  l10n.tr(puzzle.titleKey),
                                              localizedPrompt:
                                                  l10n.tr(puzzle.promptKey),
                                              localizedCorrectAnswer:
                                                  l10n.tr(correctOpt.labelKey),
                                              localizedExplanation: l10n
                                                  .tr(puzzle.explanationKey),
                                              noteProvider: noteProvider,
                                            );
                                          },
                                    icon: Icon(
                                      isNoteSaved
                                          ? Icons.check_circle_rounded
                                          : Icons.bookmark_add_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isNoteSaved
                                          ? l10n.tr('bp_action_saved_echo_note')
                                          : l10n.tr('bp_action_save_echo_note'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bottom Navigation Row
                Row(
                  children: [
                    if (currentIndex > 0)
                      OutlinedButton(
                        key: const ValueKey('btn_bp_prev_puzzle'),
                        onPressed: () => expProvider
                            .goToBrainPlaygroundPuzzleIndex(currentIndex - 1),
                        child: Text(l10n.tr('exp_previous_step')),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      key: const ValueKey('btn_bp_next_or_finish'),
                      onPressed: isAnswered
                          ? () async {
                              if (isLastPuzzle) {
                                await expProvider
                                    .completeBrainPlaygroundSession();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              } else {
                                await expProvider
                                    .goToBrainPlaygroundPuzzleIndex(
                                  currentIndex + 1,
                                );
                              }
                            }
                          : null,
                      child: Text(
                        isLastPuzzle
                            ? l10n.tr('bp_finish_playground')
                            : l10n.tr('bp_next_puzzle'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
