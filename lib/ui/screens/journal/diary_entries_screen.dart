import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/journal_entry.dart';
import '../../../data/models/journal_prompt.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/throwback_section.dart';
import '../../widgets/journal_prompt_carousel.dart';
import '../../widgets/security_pin_gate_sheet.dart';

class DiaryEntriesScreen extends StatelessWidget {
  const DiaryEntriesScreen({super.key});

  void _showAddEntryDialog(
    BuildContext context, {
    JournalEntry? existing,
    JournalPrompt? initialPrompt,
  }) {
    final titleController = TextEditingController(
      text: existing?.title ?? (initialPrompt?.prompt ?? ''),
    );
    final contentController = TextEditingController(
      text: existing?.content ?? '',
    );
    final gratitudeController = TextEditingController(
      text: existing?.gratitudeNote ?? '',
    );
    JournalMood mood = existing?.mood ?? JournalMood.good;
    bool isPrivate = existing?.isPrivate ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF16171D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    const Text(
                      'How are you feeling today?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8E929E),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Mood selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: JournalMood.values.map((m) {
                        final isSelected = mood == m;
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
                                  ? AppColors.accent.withOpacity(0.2)
                                  : const Color(0xFF1E2028),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : const Color(0xFF2C2F3A),
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
                                        ? AppColors.accent
                                        : const Color(0xFF8E929E),
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
                        color: const Color(0xFF1E2028),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPrivate
                              ? AppColors.accent.withOpacity(0.4)
                              : const Color(0xFF2C2F3A),
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
                                ? AppColors.accent
                                : const Color(0xFF8E929E),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Private Reflection',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Requires PIN / Biometric to view',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF8E929E),
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
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () {
                        final t = titleController.text.trim();
                        final c = contentController.text.trim();
                        final g = gratitudeController.text.trim();
                        if (t.isNotEmpty || c.isNotEmpty) {
                          final now = DateTime.now();
                          final provider = Provider.of<JournalProvider>(
                            context,
                            listen: false,
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
                                updatedAt: now,
                              ),
                            );
                          }
                          Navigator.of(ctx).pop();
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

  @override
  Widget build(BuildContext context) {
    final journalProvider = Provider.of<JournalProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final entries = journalProvider.journalEntries;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. On This Day Nostalgic Throwback
          const ThrowbackSection(),

          // 2. Daily Journal Prompt Carousel
          JournalPromptCarousel(
            onAnswerPrompt: (prompt) {
              _showAddEntryDialog(context, initialPrompt: prompt);
            },
          ),

          // 3. Section Header with Lock Status
          Row(
            children: [
              Text(
                'REFLECTIONS (${entries.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8E929E),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (settings.isDiaryLockEnabled)
                InkWell(
                  onTap: () async {
                    if (settings.isDiaryUnlocked) {
                      settings.lockDiary();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Private reflections locked.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    } else {
                      await SecurityPinGateSheet.verifyOrPrompt(
                        context,
                        title: 'Unlock Private Reflections',
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
                          settings.isDiaryUnlocked
                              ? Icons.lock_open_rounded
                              : Icons.lock_rounded,
                          size: 14,
                          color: settings.isDiaryUnlocked
                              ? AppColors.success
                              : AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          settings.isDiaryUnlocked
                              ? 'Unlocked (Tap to Lock)'
                              : 'Locked (Tap to Unlock)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: settings.isDiaryUnlocked
                                ? AppColors.success
                                : AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () => SecurityPinGateSheet.verifyOrPrompt(
                    context,
                    title: 'Setup Diary Lock',
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: Color(0xFF8E929E),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Set Lock',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8E929E),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.book_outlined,
                      size: 44,
                      color: Color(0xFF8E929E),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No diary entries yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap a prompt above or the + button to capture your thoughts',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E929E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...entries.map((entry) {
              final isLocked = entry.isPrivate && !settings.isDiaryUnlocked;

              if (isLocked) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: const Color(0xFF1B1D25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppColors.accent.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () async {
                      await SecurityPinGateSheet.verifyOrPrompt(
                        context,
                        title: 'Unlock Private Entry',
                        subtitle:
                            'Enter your PIN or Biometrics to read this reflection',
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
                              color: AppColors.accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Private Reflection',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('EEE, MMM d, yyyy')
                                      .format(entry.date),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8E929E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap to unlock with PIN or Biometrics',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF8E929E),
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
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8E929E),
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
                                  color: AppColors.accent.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 10,
                                      color: AppColors.accent,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Private',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Color(0xFF8E929E),
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
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFD1D5DB),
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
