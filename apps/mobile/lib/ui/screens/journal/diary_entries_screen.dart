import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/models/journal_entry.dart';
import '../../../data/models/journal_prompt.dart';
import '../../../domain/security/diary_lock_helper.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/throwback_section.dart';
import '../../widgets/gratitude_jar_sheet.dart';
import '../../widgets/journal_prompt_carousel.dart';
import '../../widgets/security_pin_gate_sheet.dart';

class DiaryEntriesScreen extends StatelessWidget {
  const DiaryEntriesScreen({super.key});

  void _showAddEntryDialog(
    BuildContext context, {
    JournalEntry? existing,
    JournalPrompt? initialPrompt,
  }) {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DiaryEntryEditorSheet(
        existing: existing,
        initialPrompt: initialPrompt,
        buildEntryLockConfigSection: _buildEntryLockConfigSection,
        onLowOrToughMoodSaved: (mood, provider) {
          if (!parentContext.mounted) return;
          GratitudeJarSheet.show(
            parentContext,
            triggeredByMood: mood,
            autoShake: true,
            onCreateReflection: () => _showAddEntryDialog(parentContext),
            onOpenEntry: (pebble) {
              final linked = provider.findEntryById(pebble.entryId);
              if (linked != null && parentContext.mounted) {
                _showAddEntryDialog(parentContext, existing: linked);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildEntryLockConfigSection({
    required BuildContext context,
    required bool useCustomLock,
    required DiaryLockType? customLockType,
    required bool hasConfiguredCustomSecret,
    required TextEditingController customClueController,
    required ValueChanged<bool> onScopeChanged,
    required VoidCallback onConfigureCustomLock,
  }) {
    final accentInk = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );
    final successInk = AppColors.adaptive(
      context,
      dark: AppColors.success,
      light: const Color(0xFF047857),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: useCustomLock
              ? AppColors.accent.withValues(alpha: 0.45)
              : AppColors.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lock Method',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Global Diary Lock'),
                selected: !useCustomLock,
                selectedColor: AppColors.accent.withValues(alpha: 0.24),
                backgroundColor: AppColors.recessedSurface(context),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: !useCustomLock
                      ? accentInk
                      : AppColors.textSecondary(context),
                ),
                side: BorderSide(
                  color: !useCustomLock ? AppColors.accent : Colors.transparent,
                ),
                onSelected: (v) {
                  if (v) onScopeChanged(false);
                },
              ),
              ChoiceChip(
                label: const Text('Custom PIN / Password'),
                selected: useCustomLock,
                selectedColor: AppColors.accent.withValues(alpha: 0.24),
                backgroundColor: AppColors.recessedSurface(context),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: useCustomLock
                      ? accentInk
                      : AppColors.textSecondary(context),
                ),
                side: BorderSide(
                  color: useCustomLock ? AppColors.accent : Colors.transparent,
                ),
                onSelected: (v) {
                  if (v) onScopeChanged(true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!useCustomLock)
            Text(
              'Uses main 4–8 digit Diary PIN and Biometrics.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            )
          else ...[
            Row(
              children: [
                Icon(
                  customLockType == DiaryLockType.password
                      ? Icons.password_rounded
                      : Icons.pin_rounded,
                  size: 16,
                  color: hasConfiguredCustomSecret ? successInk : accentInk,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasConfiguredCustomSecret
                        ? (customLockType == DiaryLockType.password
                            ? 'Custom Password Active (No Biometrics)'
                            : 'Custom 4–8 Digit PIN Active (No Biometrics)')
                        : 'Set a unique PIN or password for this entry',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: hasConfiguredCustomSecret
                          ? successInk
                          : AppColors.textPrimary(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onConfigureCustomLock,
                  child: Text(
                    hasConfiguredCustomSecret ? 'Change' : 'Set Secret',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accentInk,
                    ),
                  ),
                ),
              ],
            ),
            if (hasConfiguredCustomSecret) ...[
              const SizedBox(height: 6),
              TextField(
                controller: customClueController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Password / PIN Clue (Optional)',
                  hintText: 'Edit clue anytime for this entry',
                  prefixIcon: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 17,
                    color: accentInk,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.recessedSurface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border(context)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = Provider.of<JournalProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final entries = journalProvider.journalEntries;
    final headerAccentInk = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );
    final headerSuccessInk = AppColors.adaptive(
      context,
      dark: AppColors.success,
      light: const Color(0xFF047857),
    );

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. On This Day Nostalgic Throwback
          const ThrowbackSection(),

          // 2. Echo Gratitude Jar & Tough-Day Pebble Picker
          GratitudeJarCard(
            onCreateReflection: () => _showAddEntryDialog(context),
            onOpenEntry: (pebble) {
              final linked = journalProvider.findEntryById(pebble.entryId);
              if (linked != null) {
                _showAddEntryDialog(context, existing: linked);
              }
            },
          ),

          // 3. Daily Journal Prompt Carousel
          JournalPromptCarousel(
            onAnswerPrompt: (prompt) {
              _showAddEntryDialog(context, initialPrompt: prompt);
            },
          ),

          // 3. Section Header with Lock Status
          Row(
            children: [
              Text(
                context.l10n.tr('reflections', {'entries_length': entries.length}),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary(context),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (settings.hasActiveDiaryUnlocks || settings.isDiaryLockEnabled)
                InkWell(
                  onTap: () async {
                    if (settings.hasActiveDiaryUnlocks) {
                      settings.lockDiary();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.tr('private_reflections_locked'),
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } else {
                      await SecurityPinGateSheet.verifyOrPrompt(
                        context,
                        title: context.l10n.tr('unlock_private_reflections'),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          settings.hasActiveDiaryUnlocks
                              ? Icons.lock_open_rounded
                              : Icons.lock_rounded,
                          size: 14,
                          color: settings.hasActiveDiaryUnlocks
                              ? headerSuccessInk
                              : headerAccentInk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          settings.hasActiveDiaryUnlocks
                              ? context.l10n.tr('unlocked_tap_to_lock')
                              : context.l10n.tr('locked_tap_to_unlock'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: settings.hasActiveDiaryUnlocks
                                ? headerSuccessInk
                                : headerAccentInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () => SecurityPinGateSheet.setupGlobalPin(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: AppColors.textSecondary(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.tr('set_lock'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Diary Entries List
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.book_outlined,
                      size: 44,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.tr('no_diary_entries_yet'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.tr('tap_a_prompt_above_or_the'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...entries.map((entry) {
              final isLocked = settings.isEntryLocked(entry);
              final accentInk = AppColors.adaptive(
                context,
                dark: AppColors.accent,
                light: const Color(0xFFB45309),
              );

              if (isLocked) {
                final isCustom = entry.hasCustomLock;
                final lockLabel = isCustom
                    ? (entry.usesCustomPassword
                        ? 'Custom Password Lock'
                        : 'Custom PIN Lock')
                    : 'Private Reflection';
                final unlockPrompt = isCustom
                    ? (entry.usesCustomPassword
                        ? 'Tap to unlock with entry password'
                        : 'Tap to unlock with entry PIN')
                    : 'Tap to unlock with PIN or Biometrics';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppColors.cardSurface(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () async {
                      await SecurityPinGateSheet.verifyEntryOrPrompt(
                        context,
                        entry,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              entry.usesCustomPassword
                                  ? Icons.password_rounded
                                  : Icons.lock_rounded,
                              color: accentInk,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lockLabel,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('EEE, MMM d, yyyy')
                                      .format(entry.date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  unlockPrompt,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: accentInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _showAddEntryDialog(context, existing: entry),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.mood.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEE, MMM d, yyyy').format(entry.date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            if (entry.isPrivate) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      entry.usesCustomPassword
                                          ? Icons.password_rounded
                                          : Icons.lock_rounded,
                                      size: 10,
                                      color: accentInk,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      entry.hasCustomLock
                                          ? (entry.usesCustomPassword
                                              ? 'Custom Password'
                                              : 'Custom PIN')
                                          : 'Private',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: accentInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (entry.hasCustomLock)
                              IconButton(
                                icon: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                  color: accentInk,
                                ),
                                tooltip: 'Lock Entry Now',
                                onPressed: () => settings.lockEntry(entry.id),
                                visualDensity: VisualDensity.compact,
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.textSecondary(context),
                              ),
                              onPressed: () =>
                                  journalProvider.deleteJournalEntry(entry.id),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (entry.title.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            entry.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        if (entry.content.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.content,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (entry.gratitudeNote != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 13,
                                  color: AppColors.primaryLight,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Grateful: ${entry.gratitudeNote!}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.primaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
              );
            }),
          const SizedBox(height: 60),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('diary_new_entry_fab'),
        onPressed: () => _showAddEntryDialog(context),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.edit_note_rounded, color: Colors.black),
        label: const Text(
          'New Entry',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
        ),
      ),
    );
  }
}

class _DiaryEntryEditorSheet extends StatefulWidget {
  final JournalEntry? existing;
  final JournalPrompt? initialPrompt;
  final Widget Function({
    required BuildContext context,
    required bool useCustomLock,
    required DiaryLockType? customLockType,
    required bool hasConfiguredCustomSecret,
    required TextEditingController customClueController,
    required ValueChanged<bool> onScopeChanged,
    required VoidCallback onConfigureCustomLock,
  }) buildEntryLockConfigSection;
  final void Function(JournalMood mood, JournalProvider provider)
      onLowOrToughMoodSaved;

  const _DiaryEntryEditorSheet({
    this.existing,
    this.initialPrompt,
    required this.buildEntryLockConfigSection,
    required this.onLowOrToughMoodSaved,
  });

  @override
  State<_DiaryEntryEditorSheet> createState() => _DiaryEntryEditorSheetState();
}

class _DiaryEntryEditorSheetState extends State<_DiaryEntryEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _gratitudeController;
  late final TextEditingController _customClueController;
  late final List<TextEditingController> _templateAnswerControllers;

  late JournalMood _mood;
  late bool _isPrivate;
  late bool _useCustomLock;
  DiaryLockType? _customLockType;
  String? _customLockHash;
  String? _customLockSalt;
  GuidedReflectionTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(
      text: e?.title ?? (widget.initialPrompt?.prompt ?? ''),
    );
    _contentController = TextEditingController(text: e?.content ?? '');
    _gratitudeController =
        TextEditingController(text: e?.gratitudeNote ?? '');
    _customClueController =
        TextEditingController(text: e?.customLockHint ?? '');
    _templateAnswerControllers =
        List.generate(3, (_) => TextEditingController());
    _mood = e?.mood ?? JournalMood.good;
    _isPrivate = e?.isPrivate ?? false;
    _useCustomLock = e?.hasCustomLock ?? false;
    _customLockType = e?.customLockType;
    _customLockHash = e?.customLockHash;
    _customLockSalt = e?.customLockSalt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _gratitudeController.dispose();
    _customClueController.dispose();
    for (final ctrl in _templateAnswerControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _selectTemplate(GuidedReflectionTemplate? next) {
    final l10n = context.l10n;
    final prev = _selectedTemplate;
    setState(() {
      if (next == null && prev != null) {
        final answers =
            _templateAnswerControllers.map((c) => c.text).toList();
        if (prev.hasAnyAnswer(answers)) {
          _contentController.text = prev.formatGuidedContent(
            tr: l10n.tr,
            answers: answers,
            extraNotes: _contentController.text,
          );
          for (final ctrl in _templateAnswerControllers) {
            ctrl.clear();
          }
        }
      }
      if (next != null) {
        final currentTitle = _titleController.text.trim();
        final matchesPreviousTemplate = GuidedReflectionTemplate.eveningTemplates
            .any((t) => l10n.tr(t.titleKey) == currentTitle);
        if (currentTitle.isEmpty || matchesPreviousTemplate) {
          _titleController.text = l10n.tr(next.titleKey);
        }
      }
      _selectedTemplate = next;
    });
  }

  Future<void> _configureCustomLock() async {
    final result = await SecurityPinGateSheet.setupCustomEntryLock(
      context,
      initialType: _customLockType ?? DiaryLockType.pin,
      initialHint: _customClueController.text,
    );
    if (result != null && mounted) {
      setState(() {
        _customLockType = result.type;
        _customLockHash = result.hash;
        _customLockSalt = result.salt;
        _customClueController.text = result.hint ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = widget.existing;
    final activeTpl = _selectedTemplate;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e == null
                      ? (widget.initialPrompt != null
                          ? 'Answer Reflection Prompt'
                          : 'New Diary Entry')
                      : 'Edit Entry',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'How are you feeling today?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),

            // Mood selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: JournalMood.values.map((m) {
                final isSelected = _mood == m;
                final accentInk = AppColors.adaptive(
                  context,
                  dark: AppColors.accent,
                  light: const Color(0xFFB45309),
                );
                return InkWell(
                  onTap: () => setState(() => _mood = m),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : AppColors.cardSurface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.border(context),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(m.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 2),
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? accentInk
                                : AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Guided Evening Reflection Templates selector
            Text(
              l10n.tr('diary_tpl_section_label'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  key: const Key('diary_tpl_chip_free'),
                  selected: activeTpl == null,
                  label: Text(
                    l10n.tr('diary_tpl_free_write'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  onSelected: (_) => _selectTemplate(null),
                ),
                ...GuidedReflectionTemplate.eveningTemplates.map((tpl) {
                  return ChoiceChip(
                    key: Key('diary_tpl_chip_${tpl.id}'),
                    avatar: Icon(tpl.icon, size: 15, color: tpl.color),
                    selected: activeTpl?.id == tpl.id,
                    label: Text(
                      l10n.tr(tpl.titleKey),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onSelected: (_) => _selectTemplate(tpl),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              key: const Key('diary_title_input'),
              controller: _titleController,
              autofocus: e == null && widget.initialPrompt == null,
              decoration: const InputDecoration(
                labelText: 'Title / Prompt Highlight',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            if (activeTpl != null) ...[
              const SizedBox(height: 12),
              Container(
                key: Key('diary_tpl_panel_${activeTpl.id}'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: activeTpl.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: activeTpl.color.withValues(alpha: 0.30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.tr(activeTpl.subtitleKey),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < activeTpl.questionKeys.length; i++) ...[
                      Text(
                        l10n.tr(activeTpl.questionKeys[i]),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        key: Key('diary_tpl_q_$i'),
                        controller: _templateAnswerControllers[i],
                        maxLines: 2,
                        decoration: const InputDecoration(
                          isDense: true,
                        ),
                      ),
                      if (i < activeTpl.questionKeys.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              key: const Key('diary_content_input'),
              controller: _contentController,
              autofocus: widget.initialPrompt != null,
              maxLines: activeTpl == null ? 5 : 2,
              decoration: InputDecoration(
                labelText: activeTpl == null
                    ? 'Dear Diary... reflection, observations, memories'
                    : l10n.tr('diary_tpl_extra_notes_label'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _gratitudeController,
              decoration: const InputDecoration(
                labelText: 'One thing I am grateful for today (Optional)',
                prefixIcon: Icon(
                  Icons.favorite_outline_rounded,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Private reflection lock toggle
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardSurface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPrivate
                      ? AppColors.accent.withValues(alpha: 0.4)
                      : AppColors.border(context),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 18,
                    color: _isPrivate
                        ? AppColors.adaptive(
                            context,
                            dark: AppColors.accent,
                            light: const Color(0xFFB45309),
                          )
                        : AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Private Reflection',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Protect with Global Lock or Entry-Only Secret',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPrivate,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) => setState(() => _isPrivate = val),
                  ),
                ],
              ),
            ),
            if (_isPrivate) ...[
              const SizedBox(height: 10),
              widget.buildEntryLockConfigSection(
                context: context,
                useCustomLock: _useCustomLock,
                customLockType: _customLockType,
                hasConfiguredCustomSecret:
                    _customLockHash != null && _customLockSalt != null,
                customClueController: _customClueController,
                onScopeChanged: (custom) =>
                    setState(() => _useCustomLock = custom),
                onConfigureCustomLock: _configureCustomLock,
              ),
            ],
            const SizedBox(height: 20),

            ElevatedButton(
              key: const Key('diary_save_entry_btn'),
              onPressed: () {
                final t = _titleController.text.trim();
                final finalContent = activeTpl != null
                    ? activeTpl.formatGuidedContent(
                        tr: l10n.tr,
                        answers: _templateAnswerControllers
                            .map((c) => c.text)
                            .toList(),
                        extraNotes: _contentController.text,
                      )
                    : _contentController.text.trim();
                final g = _gratitudeController.text.trim();
                if (t.isEmpty && finalContent.isEmpty) return;

                if (_isPrivate &&
                    _useCustomLock &&
                    (_customLockHash == null || _customLockSalt == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Set a custom PIN/password or switch to Global Lock.',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                final now = DateTime.now();
                final provider = Provider.of<JournalProvider>(
                  context,
                  listen: false,
                );
                final keepCustom = _isPrivate && _useCustomLock;
                final normalizedHint = DiaryLockHelper.normalizeHint(
                  _customClueController.text,
                );
                final mergedTags = <String>[
                  ...(e?.tags ?? const []),
                  if (activeTpl != null) ...[
                    if (!(e?.tags.contains('EveningReflection') ?? false))
                      'EveningReflection',
                    if (!(e?.tags.contains(activeTpl.tag) ?? false))
                      activeTpl.tag,
                  ],
                ];

                if (e == null) {
                  provider.addJournalEntry(
                    JournalEntry(
                      id: const Uuid().v4(),
                      title: t,
                      content: finalContent,
                      tags: mergedTags,
                      gratitudeNote: g.isNotEmpty ? g : null,
                      date: now,
                      mood: _mood,
                      isPrivate: _isPrivate,
                      customLockType: keepCustom ? _customLockType : null,
                      customLockHash: keepCustom ? _customLockHash : null,
                      customLockSalt: keepCustom ? _customLockSalt : null,
                      customLockHint: keepCustom ? normalizedHint : null,
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
                } else {
                  provider.updateJournalEntry(
                    e.copyWith(
                      title: t,
                      content: finalContent,
                      tags: mergedTags,
                      gratitudeNote: g.isNotEmpty ? g : null,
                      mood: _mood,
                      isPrivate: _isPrivate,
                      customLockType: keepCustom ? _customLockType : null,
                      customLockHash: keepCustom ? _customLockHash : null,
                      customLockSalt: keepCustom ? _customLockSalt : null,
                      customLockHint: keepCustom ? normalizedHint : null,
                      clearCustomLock: !keepCustom,
                      clearCustomLockHint:
                          keepCustom && normalizedHint == null,
                      updatedAt: now,
                    ),
                  );
                }
                Navigator.of(context).pop();
                if (JournalProvider.isLowOrToughMood(_mood)) {
                  widget.onLowOrToughMoodSaved(_mood, provider);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save Entry',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
