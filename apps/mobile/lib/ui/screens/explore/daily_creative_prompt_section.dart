import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/interactive_experience_models.dart';
import '../../../data/models/journal_entry.dart';
import '../../../providers/hobby_provider.dart';
import '../../../providers/interactive_experience_provider.dart';
import '../../../providers/journal_provider.dart';

/// Hero card for Pippin's Daily Creative Prompt (`daily_creative_prompt_v1`)
/// inside [NestinDiscoverScreen].
class DailyCreativePromptHeroCard extends StatefulWidget {
  final InteractiveExperienceProvider expProvider;
  final ExperienceResultRecord? latestResult;

  const DailyCreativePromptHeroCard({
    super.key,
    required this.expProvider,
    required this.latestResult,
  });

  @override
  State<DailyCreativePromptHeroCard> createState() =>
      _DailyCreativePromptHeroCardState();
}

class _DailyCreativePromptHeroCardState
    extends State<DailyCreativePromptHeroCard> {
  late DailyCreativePromptItem _featuredPrompt;

  @override
  void initState() {
    super.initState();
    _featuredPrompt = DailyCreativePromptCatalog.promptForDay(DateTime.now());
  }

  void _shuffleFeatured() {
    setState(() {
      _featuredPrompt =
          DailyCreativePromptCatalog.nextPrompt(_featuredPrompt.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const accent = AppColors.pippin;
    final mediumColor = Color(
      int.parse(_featuredPrompt.medium.colorHex.replaceFirst('#', '0xFF')),
    );
    final lastPromptId =
        widget.latestResult?.answersSnapshot['promptId'] as String?;
    final lastPrompt = lastPromptId != null
        ? DailyCreativePromptCatalog.findById(lastPromptId)
        : null;

    return Container(
      key: const Key('exp_daily_creative_prompt_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            AppColors.twill.withValues(alpha: 0.10),
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
                child: Text(
                  _featuredPrompt.medium.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
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
                            l10n.tr('exp_dcp_pippin_badge'),
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
                      l10n.tr('exp_dcp_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('exp_dcp_shuffle_btn'),
                tooltip: l10n.tr('exp_dcp_shuffle_btn'),
                onPressed: _shuffleFeatured,
                icon: const Icon(Icons.shuffle_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border(context)),
            ),
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
                        color: mediumColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_featuredPrompt.medium.emoji} ${l10n.tr(_featuredPrompt.medium.titleKey)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: mediumColor,
                        ),
                      ),
                    ),
                    Text(
                      l10n.tr('exp_dcp_duration_badge', {
                        'mins': _featuredPrompt.suggestedDurationMinutes,
                      }),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.tr(_featuredPrompt.titleKey),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.tr(_featuredPrompt.promptKey),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (lastPrompt != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.tr('exp_dcp_last_logged_label', {
                'title': l10n.tr(lastPrompt.titleKey),
              }),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('exp_dcp_launch_btn'),
              onPressed: () => DailyCreativePromptSheet.show(
                context,
                expProvider: widget.expProvider,
                initialPrompt: _featuredPrompt,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.brush_rounded, size: 18),
              label: Text(
                l10n.tr('exp_dcp_open_studio_btn'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive 10-minute low-pressure creative studio sheet for Pippin's Daily
/// Creative Prompt (`daily_creative_prompt_v1`) with direct logging into Pippin's
/// [HobbyProvider] or Echo's [JournalProvider].
class DailyCreativePromptSheet extends StatefulWidget {
  final InteractiveExperienceProvider expProvider;
  final DailyCreativePromptItem? initialPrompt;

  const DailyCreativePromptSheet({
    super.key,
    required this.expProvider,
    this.initialPrompt,
  });

  static Future<void> show(
    BuildContext context, {
    required InteractiveExperienceProvider expProvider,
    DailyCreativePromptItem? initialPrompt,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DailyCreativePromptSheet(
        expProvider: expProvider,
        initialPrompt: initialPrompt,
      ),
    );
  }

  @override
  State<DailyCreativePromptSheet> createState() =>
      _DailyCreativePromptSheetState();
}

class _DailyCreativePromptSheetState extends State<DailyCreativePromptSheet> {
  CreativePromptMedium? _selectedMedium;
  late DailyCreativePromptItem _currentPrompt;
  final TextEditingController _notesController = TextEditingController();

  String? _selectedHobbyId;
  int _durationMinutes = 10;
  JournalMood _selectedMood = JournalMood.good;

  Timer? _timer;
  int _remainingSeconds = 600;
  bool _timerRunning = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _currentPrompt = widget.initialPrompt ??
        DailyCreativePromptCatalog.promptForDay(DateTime.now());
    _remainingSeconds = _currentPrompt.suggestedDurationMinutes * 60;
    _durationMinutes = _currentPrompt.suggestedDurationMinutes;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  void _selectMedium(CreativePromptMedium? medium) {
    setState(() {
      _selectedMedium = medium;
      if (medium != null && _currentPrompt.medium != medium) {
        _currentPrompt =
            DailyCreativePromptCatalog.promptsForMedium(medium).first;
      }
    });
  }

  void _shufflePrompt() {
    setState(() {
      _currentPrompt = DailyCreativePromptCatalog.nextPrompt(
        _currentPrompt.id,
        medium: _selectedMedium,
      );
    });
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timer?.cancel();
      setState(() => _timerRunning = false);
      return;
    }
    setState(() => _timerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _timerRunning = false;
        });
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _remainingSeconds = _durationMinutes * 60;
    });
  }

  String _formatSeconds(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _logToPippinHobby(AppLocalizations l10n) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final hobbyProvider = context.read<HobbyProvider>();
      final result = await widget.expProvider.logCreativePromptToPippinHobby(
        prompt: _currentPrompt,
        localizedPromptTitle: l10n.tr(_currentPrompt.titleKey),
        localizedPromptText: l10n.tr(_currentPrompt.promptKey),
        localizedDefaultHobbyName:
            l10n.tr(_currentPrompt.medium.defaultHobbyNameKey),
        hobbyProvider: hobbyProvider,
        hobbyId: _selectedHobbyId,
        durationMinutes: _durationMinutes,
        userNotes: _notesController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.tr('exp_dcp_logged_hobby_toast', {
              'mins': _durationMinutes,
              'hobby': result.hobby.name,
            }),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _logToEchoJournal(AppLocalizations l10n) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final journalProvider = context.read<JournalProvider>();
      await widget.expProvider.logCreativePromptToEchoJournal(
        prompt: _currentPrompt,
        localizedPromptTitle: l10n.tr(_currentPrompt.titleKey),
        localizedPromptText: l10n.tr(_currentPrompt.promptKey),
        journalProvider: journalProvider,
        userNotes: _notesController.text,
        mood: _selectedMood,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('exp_dcp_logged_journal_toast')),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hobbyProvider = context.watch<HobbyProvider>();
    final hobbies = hobbyProvider.activeHobbies;
    final effectiveHobbyId =
        _selectedHobbyId != null && hobbies.any((h) => h.id == _selectedHobbyId)
            ? _selectedHobbyId
            : null;
    final mediumColor = Color(
      int.parse(_currentPrompt.medium.colorHex.replaceFirst('#', '0xFF')),
    );

    return Container(
      key: const Key('exp_dcp_sheet'),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _currentPrompt.medium.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('exp_dcp_title'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.tr('exp_dcp_subtitle'),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Medium Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: const Key('exp_dcp_filter_all'),
                        selected: _selectedMedium == null,
                        label: Text(
                          l10n.tr('all'),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onSelected: (_) => _selectMedium(null),
                      ),
                    ),
                    ...CreativePromptMedium.values.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          key: Key('exp_dcp_filter_${m.id}'),
                          selected: _selectedMedium == m,
                          label: Text(
                            '${m.emoji} ${l10n.tr(m.titleKey)}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onSelected: (_) => _selectMedium(m),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Prompt Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: mediumColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: mediumColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.tr(_currentPrompt.medium.titleKey),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: mediumColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          key: const Key('exp_dcp_sheet_shuffle_btn'),
                          onPressed: _shufflePrompt,
                          icon: const Icon(Icons.shuffle_rounded, size: 15),
                          label: Text(
                            l10n.tr('exp_dcp_shuffle_btn'),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.tr(_currentPrompt.titleKey),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.tr(_currentPrompt.promptKey),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.tips_and_updates_outlined,
                          size: 14,
                          color: AppColors.textSecondary(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.tr(_currentPrompt.gentleTipKey),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Optional Gentle 10-Min Quiet Timer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.recessedSurface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tr('exp_dcp_quiet_timer_label'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _formatSeconds(_remainingSeconds),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _timerRunning
                                  ? mediumColor
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const Key('exp_dcp_timer_toggle_btn'),
                      onPressed: _toggleTimer,
                      child: Text(
                        _timerRunning
                            ? l10n.tr('exp_dcp_timer_pause')
                            : l10n.tr('exp_dcp_timer_start'),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.tr('reset'),
                      onPressed: _resetTimer,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Optional Creative Notes / Micro-Poem / Observation Field
              TextField(
                key: const Key('exp_dcp_notes_field'),
                controller: _notesController,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.tr('exp_dcp_notes_label'),
                  hintText: l10n.tr('exp_dcp_notes_hint'),
                ),
              ),
              const SizedBox(height: 12),

              // Pippin Hobby Target & Duration Selector
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('dcp_hobby_${effectiveHobbyId ?? "auto"}'),
                      isExpanded: true,
                      initialValue: effectiveHobbyId,
                      dropdownColor: AppColors.cardSurface(context),
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: l10n.tr('exp_dcp_hobby_target_label'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            l10n.tr('exp_dcp_hobby_auto_option', {
                              'name': l10n.tr(
                                _currentPrompt.medium.defaultHobbyNameKey,
                              ),
                            }),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        ...hobbies.map(
                          (h) => DropdownMenuItem<String?>(
                            value: h.id,
                            child: Text(
                              '${h.iconEmoji} ${h.name}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedHobbyId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _durationMinutes,
                    underline: const SizedBox.shrink(),
                    items: const [5, 10, 15, 20]
                        .map(
                          (m) => DropdownMenuItem<int>(
                            value: m,
                            child: Text('${m}m',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _durationMinutes = v;
                        if (!_timerRunning) {
                          _remainingSeconds = v * 60;
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Echo Mood Strip for Journal Entry
              Row(
                children: [
                  Text(
                    l10n.tr('exp_dcp_mood_label'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: JournalMood.values.map((m) {
                          final selected = _selectedMood == m;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              selected: selected,
                              label: Text(m.emoji),
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) =>
                                  setState(() => _selectedMood = m),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dual Direct Handoff Buttons: Pippin Hobby Session or Echo Journal Entry
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('exp_dcp_log_hobby_btn'),
                    onPressed:
                        _submitting ? null : () => _logToPippinHobby(l10n),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pippin,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.palette_outlined, size: 17),
                    label: Text(
                      l10n.tr('exp_dcp_log_hobby_btn'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('exp_dcp_log_journal_btn'),
                    onPressed:
                        _submitting ? null : () => _logToEchoJournal(l10n),
                    icon: const Icon(Icons.menu_book_rounded, size: 17),
                    label: Text(
                      l10n.tr('exp_dcp_log_journal_btn'),
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
        ),
      ),
    );
  }
}
