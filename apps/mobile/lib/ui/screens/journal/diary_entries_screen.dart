import 'package:flutter/material.dart';
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
    final titleController = TextEditingController(
      text: existing?.title ?? (initialPrompt?.prompt ?? ''),
    );
    final contentController = TextEditingController(
      text: existing?.content ?? '',
    );
    final gratitudeController = TextEditingController(
      text: existing?.gratitudeNote ?? '',
    );
    final customClueController = TextEditingController(
      text: existing?.customLockHint ?? '',
    );
    JournalMood mood = existing?.mood ?? JournalMood.good;
    bool isPrivate = existing?.isPrivate ?? false;
    bool useCustomLock = existing?.hasCustomLock ?? false;
    DiaryLockType? customLockType = existing?.customLockType;
    String? customLockHash = existing?.customLockHash;
    String? customLockSalt = existing?.customLockSalt;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> configureCustomLock() async {
              final result = await SecurityPinGateSheet.setupCustomEntryLock(
                context,
                initialType: customLockType ?? DiaryLockType.pin,
                initialHint: customClueController.text,
              );
              if (result != null) {
                setSheetState(() {
                  customLockType = result.type;
                  customLockHash = result.hash;
                  customLockSalt = result.salt;
                  customClueController.text = result.hint ?? '';
                });
              }
            }

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.sheetSurface(ctx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                          existing == null
                              ? (initialPrompt != null
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
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'How are you feeling today?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(ctx),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Mood selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: JournalMood.values.map((m) {
                        final isSelected = mood == m;
                        final accentInk = AppColors.adaptive(
                          ctx,
                          dark: AppColors.accent,
                          light: const Color(0xFFB45309),
                        );
                        return InkWell(
                          onTap: () => setSheetState(() => mood = m),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent.withValues(alpha: 0.2)
                                  : AppColors.cardSurface(ctx),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.border(ctx),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  m.emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? accentInk
                                        : AppColors.textSecondary(ctx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: titleController,
                      autofocus: existing == null && initialPrompt == null,
                      decoration: const InputDecoration(
                        labelText: 'Title / Prompt Highlight',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentController,
                      autofocus: initialPrompt != null,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText:
                            'Dear Diary... reflection, observations, memories',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: gratitudeController,
                      decoration: const InputDecoration(
                        labelText:
                            'One thing I am grateful for today (Optional)',
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
                        color: AppColors.cardSurface(ctx),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPrivate
                              ? AppColors.accent.withValues(alpha: 0.4)
                              : AppColors.border(ctx),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPrivate
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            size: 18,
                            color: isPrivate
                                ? AppColors.adaptive(
                                    ctx,
                                    dark: AppColors.accent,
                                    light: const Color(0xFFB45309),
                                  )
                                : AppColors.textSecondary(ctx),
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
                                    color: AppColors.textSecondary(ctx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isPrivate,
                            activeColor: AppColors.accent,
                            onChanged: (val) {
                              setSheetState(() => isPrivate = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    if (isPrivate) ...[
                      const SizedBox(height: 10),
                      _buildEntryLockConfigSection(
                        context: context,
                        useCustomLock: useCustomLock,
                        customLockType: customLockType,
                        hasConfiguredCustomSecret:
                            customLockHash != null && customLockSalt != null,
                        customClueController: customClueController,
                        onScopeChanged: (custom) {
                          setSheetState(() => useCustomLock = custom);
                        },
                        onConfigureCustomLock: configureCustomLock,
                      ),
                    ],
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () {
                        final t = titleController.text.trim();
                        final c = contentController.text.trim();
                        final g = gratitudeController.text.trim();
                        if (t.isEmpty && c.isEmpty) return;

                        if (isPrivate &&
                            useCustomLock &&
                            (customLockHash == null ||
                                customLockSalt == null)) {
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
                        final keepCustom = isPrivate && useCustomLock;
                        final normalizedHint = DiaryLockHelper.normalizeHint(
                          customClueController.text,
                        );

                        if (existing == null) {
                          provider.addJournalEntry(
                            JournalEntry(
                              id: const Uuid().v4(),
                              title: t,
                              content: c,
                              gratitudeNote: g.isNotEmpty ? g : null,
                              date: now,
                              mood: mood,
                              isPrivate: isPrivate,
                              customLockType:
                                  keepCustom ? customLockType : null,
                              customLockHash:
                                  keepCustom ? customLockHash : null,
                              customLockSalt:
                                  keepCustom ? customLockSalt : null,
                              customLockHint:
                                  keepCustom ? normalizedHint : null,
                              createdAt: now,
                              updatedAt: now,
                            ),
                          );
                        } else {
                          provider.updateJournalEntry(
                            existing.copyWith(
                              title: t,
                              content: c,
                              gratitudeNote: g.isNotEmpty ? g : null,
                              mood: mood,
                              isPrivate: isPrivate,
                              customLockType:
                                  keepCustom ? customLockType : null,
                              customLockHash:
                                  keepCustom ? customLockHash : null,
                              customLockSalt:
                                  keepCustom ? customLockSalt : null,
                              customLockHint:
                                  keepCustom ? normalizedHint : null,
                              clearCustomLock: !keepCustom,
                              clearCustomLockHint:
                                  keepCustom && normalizedHint == null,
                              updatedAt: now,
                            ),
                          );
                        }
                        Navigator.of(ctx).pop();
                        if (JournalProvider.isLowOrToughMood(mood) &&
                            parentContext.mounted) {
                          GratitudeJarSheet.show(
                            parentContext,
                            triggeredByMood: mood,
                            autoShake: true,
                            onCreateReflection: () =>
                                _showAddEntryDialog(parentContext),
                            onOpenEntry: (pebble) {
                              final linked = provider.findEntryById(
                                pebble.entryId,
                              );
                              if (linked != null && parentContext.mounted) {
                                _showAddEntryDialog(
                                  parentContext,
                                  existing: linked,
                                );
                              }
                            },
                          );
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
          },
        );
      },
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
                context.l10n.pick(
                  'REFLECTIONS (${entries.length})',
                  'REFLEKSI (${entries.length})',
                ),
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
                            context.l10n.pick(
                              'Private reflections locked.',
                              'Refleksi pribadi dikunci.',
                            ),
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } else {
                      await SecurityPinGateSheet.verifyOrPrompt(
                        context,
                        title: context.l10n.pick(
                          'Unlock Private Reflections',
                          'Buka Refleksi Pribadi',
                        ),
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
                              ? context.l10n.pick(
                                  'Unlocked (Tap to Lock)',
                                  'Terbuka (Ketuk untuk Kunci)',
                                )
                              : context.l10n.pick(
                                  'Locked (Tap to Unlock)',
                                  'Terkunci (Ketuk untuk Buka)',
                                ),
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
                          context.l10n.pick('Set Lock', 'Atur Kunci'),
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
                      context.l10n.pick(
                        'No diary entries yet',
                        'Belum ada entri diari',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.pick(
                        'Tap a prompt above or the + button to capture your thoughts',
                        'Ketuk pertanyaan di atas atau tombol + untuk menulis pikiranmu',
                      ),
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
                              color: AppColors.primary.withOpacity(0.12),
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
