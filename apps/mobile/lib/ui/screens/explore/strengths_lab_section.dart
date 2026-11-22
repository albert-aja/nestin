import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/interactive_experience_models.dart';
import '../../../providers/interactive_experience_provider.dart';
import '../../../providers/journal_provider.dart';
import '../inspiration/quote_card_studio_screen.dart';

/// Hero card for Echo's Strengths & Quiet Life Skills Lab (`strengths_life_skills_v1`)
/// inside [NestinDiscoverScreen].
class StrengthsLabHeroCard extends StatelessWidget {
  final InteractiveExperienceProvider expProvider;
  final ExperienceSessionDraft? draft;
  final ExperienceResultRecord? latestResult;

  const StrengthsLabHeroCard({
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
    final hasResult = latestResult != null && latestResult!.topMatches.isNotEmpty;

    const accent = Color(0xFF8B5CF6);
    final buttonLabel = hasDraft
        ? l10n.tr('exp_continue_draft')
        : (hasResult
            ? l10n.tr('exp_sl_retake_lab')
            : l10n.tr('exp_sl_start_lab'));

    return Container(
      key: const Key('exp_strengths_lab_hero_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            const Color(0xFF0EA5E9).withValues(alpha: 0.10),
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
                child: const Text('🦉', style: TextStyle(fontSize: 22)),
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
                            l10n.tr('exp_sl_echo_badge'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.adaptive(
                                context,
                                dark: const Color(0xFFC4B5FD),
                                light: const Color(0xFF5B21B6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.tr('exp_strengths_lab_title'),
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
            l10n.tr('exp_strengths_lab_desc'),
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
              key: const Key('exp_sl_launch_btn'),
              onPressed: () => StrengthsLabWizardSheet.show(
                context,
                expProvider: expProvider,
                initialDraft: draft,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.psychology_alt_rounded, size: 18),
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

/// Result & Echo 1-Tap Handoff Card for `strengths_life_skills_v1`.
class StrengthsLabResultCard extends StatelessWidget {
  final InteractiveExperienceProvider expProvider;
  final ExperienceResultRecord result;

  const StrengthsLabResultCard({
    super.key,
    required this.expProvider,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final top = result.topMatches.first;
    final profile = ExperienceCatalog.findStrengthProfileById(top.profileId);

    return Container(
      key: const Key('exp_strengths_lab_result_card'),
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
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${top.matchPercentage}%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.adaptive(
                      context,
                      dark: const Color(0xFFC4B5FD),
                      light: const Color(0xFF5B21B6),
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
          if (top.reasonKeys.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: top.reasonKeys
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
                  l10n.tr('exp_sl_quiet_practice_label'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.tr(profile.quietSkillPracticeKey),
                  style: TextStyle(
                    fontSize: 12.5,
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
                key: const Key('exp_sl_save_journal_btn'),
                onPressed: () async {
                  final journal = context.read<JournalProvider>();
                  await expProvider.saveStrengthInsightToJournal(
                    journalProvider: journal,
                    strengthTitle: l10n.tr(profile.titleKey),
                    strengthDescription: l10n.tr(profile.descriptionKey),
                    quietPractice: l10n.tr(profile.quietSkillPracticeKey),
                    practicePromptPrefix:
                        l10n.tr('exp_sl_quiet_practice_label'),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.tr('exp_sl_saved_to_journal')),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.menu_book_rounded, size: 17),
                label: Text(
                  l10n.tr('exp_sl_handoff_journal'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('exp_sl_create_card_btn'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuoteCardStudioScreen(
                        quoteText: l10n.tr(profile.keepsakeQuoteKey),
                        authorName:
                            '${l10n.tr(profile.titleKey)} · Echo',
                        initialMascotDomain: 'echo',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                label: Text(
                  l10n.tr('exp_sl_handoff_quote_card'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Interactive 5-scenario modal wizard for Echo's Strengths & Quiet Life Skills Lab.
class StrengthsLabWizardSheet extends StatefulWidget {
  final InteractiveExperienceProvider expProvider;
  final ExperienceSessionDraft? initialDraft;

  const StrengthsLabWizardSheet({
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
      builder: (_) => StrengthsLabWizardSheet(
        expProvider: expProvider,
        initialDraft: initialDraft,
      ),
    );
  }

  @override
  State<StrengthsLabWizardSheet> createState() =>
      _StrengthsLabWizardSheetState();
}

class _StrengthsLabWizardSheetState extends State<StrengthsLabWizardSheet> {
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
        .clamp(0, StrengthsLabCatalog.questions.length - 1);
  }

  Future<void> _selectOption(
    ExperienceQuestion question,
    String optionId,
  ) async {
    setState(() {
      _answers[question.id] = optionId;
    });
    await widget.expProvider.selectOption(
      definition: StrengthsLabCatalog.definition,
      question: question,
      optionId: optionId,
    );
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await widget.expProvider.completeStrengthsLab(_answers);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final questions = StrengthsLabCatalog.questions;
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
                const Text('🦉', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.tr('exp_strengths_lab_title'),
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
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  key: Key('exp_sl_opt_${question.id}_${opt.id}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectOption(question, opt.id),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.14)
                          : AppColors.cardSurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF8B5CF6)
                            : AppColors.border(context),
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(opt.emoji, style: const TextStyle(fontSize: 20)),
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
                            color: Color(0xFF8B5CF6),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    child: Text(l10n.tr('previous')),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('exp_sl_next_or_finish_btn'),
                  onPressed: selectedOptionId == null
                      ? null
                      : (isLast
                          ? _finish
                          : () => setState(() => _step++)),
                  child: Text(
                    isLast ? l10n.tr('exp_sl_finish_btn') : l10n.tr('next'),
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
