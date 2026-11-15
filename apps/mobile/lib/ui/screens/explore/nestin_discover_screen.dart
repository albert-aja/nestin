import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/interactive_experience_models.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/cross_module_link_provider.dart';
import '../../../providers/hobby_provider.dart';
import '../../../providers/interactive_experience_provider.dart';
import '../../../providers/seren_relaxation_provider.dart';
import '../../../providers/task_provider.dart';

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

/// Interactive step-by-step Questionnaire Sheet for Pippin's Hobby Finder.
class HobbyFinderFlowSheet extends StatelessWidget {
  const HobbyFinderFlowSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const definition = ExperienceCatalog.hobbyFinderV1;

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.tr('exp_question_progress', {
                        'current': currentIndex + 1,
                        'total': visibleQuestions.length,
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('btn_save_draft_and_exit'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.bookmark_outline_rounded, size: 16),
                      label: Text(l10n.tr('exp_save_and_exit')),
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
                    if (question.isOptional && !isLastStep) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        key: const ValueKey('btn_skip_optional_question'),
                        onPressed: () => expProvider.skipOptionalQuestion(
                          definition: definition,
                          question: question,
                        ),
                        child: Text(l10n.tr('exp_skip_question')),
                      ),
                    ],
                    const Spacer(),
                    ElevatedButton(
                      key: const ValueKey('btn_next_or_complete_question'),
                      onPressed: isSatisfied
                          ? () async {
                              if (isLastStep) {
                                await expProvider.completeSession(definition);
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
      return Column(
        children: [
          Text(
            '${currentVal.toStringAsFixed(0)}h / week',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Slider(
            value: currentVal.clamp(question.minValue, question.maxValue),
            min: question.minValue,
            max: question.maxValue,
            divisions: (question.maxValue - question.minValue).round(),
            label: '${currentVal.toStringAsFixed(0)}h',
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
