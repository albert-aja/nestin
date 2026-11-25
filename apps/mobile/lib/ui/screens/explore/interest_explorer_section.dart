import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/interactive_experience_models.dart';
import '../../../providers/bucket_list_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/hobby_provider.dart';
import '../../../providers/interactive_experience_provider.dart';
import '../../../providers/reading_provider.dart';

/// Hero card for Pippin's Interest Explorer ("This or That" Scenarios,
/// `interest_explorer_v1`) inside [NestinDiscoverScreen].
class InterestExplorerHeroCard extends StatelessWidget {
  final InteractiveExperienceProvider expProvider;
  final ExperienceSessionDraft? draft;
  final ExperienceResultRecord? latestResult;

  const InterestExplorerHeroCard({
    super.key,
    required this.expProvider,
    required this.draft,
    required this.latestResult,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasDraft =
        draft != null && draft!.selectedOptionIdsByQuestion.isNotEmpty;
    final hasResult =
        latestResult != null && latestResult!.topMatches.isNotEmpty;

    const accent = AppColors.pippin;
    final buttonLabel = hasDraft
        ? l10n.tr('exp_continue_draft')
        : (hasResult
            ? l10n.tr('exp_ie_retake_btn')
            : l10n.tr('exp_ie_start_btn'));

    return Container(
      key: const Key('exp_interest_explorer_hero_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            AppColors.skyMid.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('✨', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.tr('exp_ie_this_or_that_badge'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.adaptive(
                                context,
                                dark: AppColors.pippinLight,
                                light: AppColors.pippinDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('exp_ie_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.tr('exp_ie_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('exp_ie_launch_btn'),
              onPressed: () => InterestExplorerWizardSheet.show(
                context,
                expProvider: expProvider,
                initialDraft: draft,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result & Connected 1-Tap Multi-Bird Handoff Card for `interest_explorer_v1`.
class InterestExplorerResultCard extends StatefulWidget {
  final InteractiveExperienceProvider expProvider;
  final ExperienceResultRecord result;

  const InterestExplorerResultCard({
    super.key,
    required this.expProvider,
    required this.result,
  });

  @override
  State<InterestExplorerResultCard> createState() =>
      _InterestExplorerResultCardState();
}

class _InterestExplorerResultCardState
    extends State<InterestExplorerResultCard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matches = widget.result.topMatches;
    final safeIdx = _selectedIndex.clamp(0, matches.length - 1);
    final selectedMatch = matches[safeIdx];
    final profile = ExperienceCatalog.findInterestSparkById(
      selectedMatch.profileId,
    );

    return Container(
      key: const Key('exp_interest_explorer_result_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (matches.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(matches.length, (i) {
                  final m = matches[i];
                  final p = ExperienceCatalog.findInterestSparkById(m.profileId);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('exp_ie_match_tab_$i'),
                      selected: safeIdx == i,
                      label: Text(
                        '${p.iconEmoji} ${l10n.tr(p.titleKey)}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onSelected: (_) => setState(() => _selectedIndex = i),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Text(profile.iconEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr(profile.titleKey),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      l10n.tr(profile.subtitleKey),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pippin.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedMatch.matchPercentage}%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.adaptive(
                      context,
                      dark: AppColors.pippinLight,
                      light: AppColors.pippinDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.tr(profile.descriptionKey),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
              height: 1.4,
            ),
          ),
          if (selectedMatch.reasonKeys.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedMatch.reasonKeys
                  .map(
                    (key) => Chip(
                      label: Text(
                        l10n.tr(key),
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🌟 ${l10n.tr(profile.bucketTitleKey)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '📖 ${l10n.tr(profile.bookTitleKey)} — ${profile.bookAuthor}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🧰 ${l10n.tr(profile.hobbyTitleKey)} (${profile.starterChecklistItemKeys.length} ${l10n.tr('exp_ie_kit_items_suffix')})',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const Key('exp_ie_add_bucket_btn'),
                onPressed: () async {
                  final bucketProvider = context.read<BucketListProvider>();
                  await widget.expProvider.addInterestSparkToBucketList(
                    profile: profile,
                    localizedBucketTitle: l10n.tr(profile.bucketTitleKey),
                    localizedBucketNote: l10n.tr(profile.bucketNoteKey),
                    bucketListProvider: bucketProvider,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.tr('exp_ie_added_bucket_toast')),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.flag_outlined, size: 17),
                label: Text(
                  l10n.tr('exp_ie_handoff_bucket_btn'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              FilledButton.tonalIcon(
                key: const Key('exp_ie_add_reading_btn'),
                onPressed: () async {
                  final readingProvider = context.read<ReadingProvider>();
                  await widget.expProvider.addInterestSparkToReadingQueue(
                    resultId: widget.result.id,
                    profile: profile,
                    localizedBookTitle: l10n.tr(profile.bookTitleKey),
                    localizedBookNote: l10n.tr(profile.bookNoteKey),
                    readingProvider: readingProvider,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.tr('exp_ie_added_reading_toast')),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.menu_book_rounded, size: 17),
                label: Text(
                  l10n.tr('exp_ie_handoff_reading_btn'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              FilledButton.icon(
                key: const Key('exp_ie_start_hobby_kit_btn'),
                onPressed: () async {
                  final hobbyProvider = context.read<HobbyProvider>();
                  final collectionProvider = context.read<CollectionProvider>();
                  final hobbyTitle = l10n.tr(profile.hobbyTitleKey);
                  final kitTitle = l10n.tr('exp_ie_starter_kit_title', {
                    'hobby': hobbyTitle,
                  });
                  await widget.expProvider
                      .createInterestHobbyAndTwillStarterKit(
                    resultId: widget.result.id,
                    profile: profile,
                    localizedHobbyTitle: hobbyTitle,
                    localizedDescription: l10n.tr(profile.descriptionKey),
                    localizedStarterKitTitle: kitTitle,
                    localizedChecklistItems: profile.starterChecklistItemKeys
                        .map(l10n.tr)
                        .toList(),
                    hobbyProvider: hobbyProvider,
                    collectionProvider: collectionProvider,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.tr('exp_ie_started_hobby_kit_toast')),
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pippin,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                label: Text(
                  l10n.tr('exp_ie_handoff_hobby_kit_btn'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Interactive 5-scenario "This or That" modal wizard for Pippin's Interest Explorer.
class InterestExplorerWizardSheet extends StatefulWidget {
  final InteractiveExperienceProvider expProvider;
  final ExperienceSessionDraft? initialDraft;

  const InterestExplorerWizardSheet({
    super.key,
    required this.expProvider,
    this.initialDraft,
  });

  static Future<void> show(
    BuildContext context, {
    required InteractiveExperienceProvider expProvider,
    ExperienceSessionDraft? initialDraft,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InterestExplorerWizardSheet(
        expProvider: expProvider,
        initialDraft: initialDraft,
      ),
    );
  }

  @override
  State<InterestExplorerWizardSheet> createState() =>
      _InterestExplorerWizardSheetState();
}

class _InterestExplorerWizardSheetState
    extends State<InterestExplorerWizardSheet> {
  late final Map<String, dynamic> _answers;
  int _step = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _answers = <String, dynamic>{};
    widget.initialDraft?.selectedOptionIdsByQuestion.forEach((k, v) {
      if (v.isNotEmpty) _answers[k] = v.first;
    });
    _step = (widget.initialDraft?.currentQuestionIndex ?? 0)
        .clamp(0, InterestExplorerCatalog.questions.length - 1);
  }

  Future<void> _selectOption(
    ExperienceQuestion question,
    String optionId,
  ) async {
    setState(() {
      _answers[question.id] = optionId;
    });
    await widget.expProvider.selectOption(
      definition: InterestExplorerCatalog.definition,
      question: question,
      optionId: optionId,
    );
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await widget.expProvider.completeInterestExplorer(_answers);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final questions = InterestExplorerCatalog.questions;
    final question = questions[_step];
    final selectedOptionId = _answers[question.id] as String?;
    final isLast = _step == questions.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.tr('exp_ie_title'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_step + 1}/${questions.length}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (_step + 1) / questions.length,
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tr(question.titleKey),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            ...question.options.map((opt) {
              final selected = selectedOptionId == opt.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  key: Key('exp_ie_opt_${question.id}_${opt.id}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectOption(question, opt.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.pippin.withValues(alpha: 0.14)
                          : AppColors.cardSurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppColors.pippin
                            : AppColors.border(context),
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(opt.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.tr(opt.labelKey),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.pippin,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    child: Text(l10n.tr('previous')),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('exp_ie_next_or_finish_btn'),
                  onPressed: selectedOptionId == null
                      ? null
                      : (isLast ? _finish : () => setState(() => _step++)),
                  child: Text(
                    isLast ? l10n.tr('exp_ie_finish_btn') : l10n.tr('next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
