import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/models/note_item.dart';
import '../../../data/models/alarm_category.dart';
import '../../../domain/notes/markdown_checklist_helper.dart';
import '../../../providers/note_provider.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/markdown_content_view.dart';
import '../../widgets/swipe_action_card.dart';
import '../../widgets/linked_entities_section.dart';
import '../../../data/models/entity_link.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  int _tabIndex = 0; // 0 = Active, 1 = Archived

  void _showNoteEditor({NoteItem? existing}) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController = TextEditingController(text: existing?.content ?? '');
    AlarmCategory category =
        existing?.category ?? AlarmCategory.fromType(AlarmCategoryType.personal);
    bool isPreviewMode = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void insertMarkdown(String prefix, [String suffix = '']) {
              final text = contentController.text;
              final selection = contentController.selection;
              final start = selection.start >= 0 ? selection.start : text.length;
              final end = selection.end >= 0 ? selection.end : text.length;
              final selectedText = text.substring(start, end);
              final replacement = '$prefix$selectedText$suffix';
              final newText = text.replaceRange(start, end, replacement);
              contentController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(
                    offset: start + prefix.length + selectedText.length),
              );
              setSheetState(() {});
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: AppColors.sheetSurface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.note_alt_rounded,
                                color: AppColors.adaptive(
                                  context,
                                  dark: AppColors.accent,
                                  light: const Color(0xFFB45309),
                                ),
                                size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            existing == null ? 'New Note' : 'Edit Note',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: AppColors.textSecondary(context)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Segmented Switcher: [Edit] vs [Live Preview]
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => isPreviewMode = false),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: !isPreviewMode
                                    ? AppColors.accent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 15,
                                    color: !isPreviewMode
                                        ? Colors.black
                                        : AppColors.textSecondary(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Edit Markdown',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: !isPreviewMode
                                          ? Colors.black
                                          : AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => isPreviewMode = true),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isPreviewMode
                                    ? AppColors.accent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 15,
                                    color: isPreviewMode
                                        ? Colors.black
                                        : AppColors.textSecondary(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Live Preview',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isPreviewMode
                                          ? Colors.black
                                          : AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title Field
                  TextField(
                    controller: titleController,
                    autofocus: existing == null && !isPreviewMode,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle:
                          TextStyle(color: AppColors.textSecondary(context)),
                      prefixIcon: Icon(Icons.title_rounded,
                          color: AppColors.adaptive(
                            context,
                            dark: AppColors.accent,
                            light: const Color(0xFFB45309),
                          ),
                          size: 20),
                      filled: true,
                      fillColor: AppColors.cardSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Content Editor OR Live Preview
                  Expanded(
                    child: isPreviewMode
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.border(context)),
                            ),
                            child: SingleChildScrollView(
                              child: contentController.text.trim().isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 30),
                                        child: Text(
                                          'No content to preview yet.\nSwitch to "Edit Markdown" to start typing.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: AppColors.textMuted(context),
                                              fontSize: 12),
                                        ),
                                      ),
                                    )
                                  : MarkdownContentView(
                                      content: contentController.text,
                                      isCompact: false,
                                      onChecklistToggle: (lineIndex) {
                                        final updated =
                                            MarkdownChecklistHelper
                                                .toggleChecklistAtLine(
                                          contentController.text,
                                          lineIndex,
                                        );
                                        if (updated != null) {
                                          HapticFeedback.selectionClick();
                                          contentController.text = updated;
                                          setSheetState(() {});
                                        }
                                      },
                                    ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Quick Markdown Toolbar
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.cardSurface(context),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _toolbarButton('H#', () => insertMarkdown('### ')),
                                      _toolbarButton('B', () => insertMarkdown('**', '**'), isBold: true),
                                      _toolbarButton('I', () => insertMarkdown('*', '*'), isItalic: true),
                                      _toolbarButton('•', () => insertMarkdown('- ')),
                                      _toolbarButton('1.', () => insertMarkdown('1. ')),
                                      _toolbarButton('☐', () => insertMarkdown('- [ ] ')),
                                      _toolbarButton('`code`', () => insertMarkdown('`', '`')),
                                      _toolbarButton('"', () => insertMarkdown('> ')),
                                      _toolbarButton('---', () => insertMarkdown('\n---\n')),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Text Field
                              Expanded(
                                child: TextField(
                                  controller: contentController,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary(context),
                                      height: 1.45),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Write your thoughts, # headers, **bold**, `code` or - bullet lists...',
                                    hintStyle: TextStyle(
                                        color: AppColors.textMuted(context),
                                        fontSize: 13),
                                    filled: true,
                                    fillColor: AppColors.cardSurface(context),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Category Selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: AlarmCategory.predefined.map((cat) {
                        final isSelected = category.type == cat.type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            selected: isSelected,
                            label: Text(cat.name),
                            selectedColor: cat.color.withValues(alpha: 0.25),
                            backgroundColor: AppColors.cardSurface(context),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? cat.color
                                  : AppColors.textSecondary(context),
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected ? cat.color : Colors.transparent,
                            ),
                            onSelected: (val) {
                              if (val) setSheetState(() => category = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (existing != null) ...[
                    LinkedEntitiesSection(
                      entityType: LinkEntityType.note,
                      entityId: existing.id,
                      entityTitle:
                          existing.title.isEmpty ? 'Note' : existing.title,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Save Button
                  ElevatedButton(
                    onPressed: () {
                      final t = titleController.text.trim();
                      final c = contentController.text.trim();
                      if (t.isNotEmpty || c.isNotEmpty) {
                        final now = DateTime.now();

                        if (existing == null) {
                          noteProvider.addNote(
                            NoteItem(
                              id: const Uuid().v4(),
                              title: t,
                              content: c,
                              category: category,
                              createdAt: now,
                              updatedAt: now,
                            ),
                          );
                        } else {
                          noteProvider.updateNote(
                            existing.copyWith(
                              title: t,
                              content: c,
                              category: category,
                              updatedAt: now,
                            ),
                          );
                        }
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Note',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.black)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _toolbarButton(String label, VoidCallback onTap,
      {bool isBold = false, bool isItalic = false}) {
    return Builder(
      builder: (context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: AppColors.textPrimary(context),
              fontFamily: label.contains('code') ? 'monospace' : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistProgressPill(ChecklistSummary summary) {
    final allDone = summary.isAllComplete;

    return Builder(
      builder: (context) {
        final emerald = AppColors.adaptive(
          context,
          dark: const Color(0xFF10B981),
          light: const Color(0xFF047857),
        );
        final neutralTint = AppColors.textSecondary(context);
        final neutralFg = AppColors.textPrimary(context);
        final tint = allDone ? emerald : neutralTint;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                allDone ? Icons.check_circle_rounded : Icons.check_box_outlined,
                size: 11,
                color: allDone ? emerald : neutralFg,
              ),
              const SizedBox(width: 3),
              Text(
                '${summary.completed}/${summary.total}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: allDone ? emerald : neutralFg,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _noteLabel(NoteItem note) {
    final trimmed = note.title.trim();
    return trimmed.isNotEmpty ? trimmed : 'Untitled note';
  }

  Future<void> _togglePinWithUndo(
    BuildContext context,
    NoteProvider provider,
    NoteItem note,
  ) async {
    final snapshot = note;
    final originalIndex = provider.indexOfNote(note.id);
    await provider.togglePin(note.id);
    if (!context.mounted) return;
    final label = _noteLabel(note);
    showUndoSnackBar(
      context: context,
      message: note.isPinned ? 'Unpinned "$label"' : 'Pinned "$label"',
      color: AppColors.accent,
      icon: note.isPinned
          ? Icons.push_pin_outlined
          : Icons.push_pin_rounded,
      onUndo: () => provider.restoreNote(snapshot, index: originalIndex),
    );
  }

  Future<void> _toggleArchiveWithUndo(
    BuildContext context,
    NoteProvider provider,
    NoteItem note,
  ) async {
    final snapshot = note;
    final originalIndex = provider.indexOfNote(note.id);
    await provider.toggleArchive(note.id);
    if (!context.mounted) return;
    final label = _noteLabel(note);
    showUndoSnackBar(
      context: context,
      message: note.isArchived ? 'Restored "$label"' : 'Archived "$label"',
      color: note.isArchived ? AppColors.success : AppColors.accent,
      icon: note.isArchived
          ? Icons.unarchive_outlined
          : Icons.archive_outlined,
      onUndo: () => provider.restoreNote(snapshot, index: originalIndex),
    );
  }

  Future<void> _deleteNoteWithUndo(
    BuildContext context,
    NoteProvider provider,
    NoteItem note,
  ) async {
    final snapshot = note;
    final originalIndex = provider.indexOfNote(note.id);
    await provider.deleteNote(note.id);
    if (!context.mounted) return;
    final label = _noteLabel(note);
    showUndoSnackBar(
      context: context,
      message: 'Deleted "$label"',
      color: AppColors.error,
      icon: Icons.delete_outline_rounded,
      onUndo: () => provider.restoreNote(snapshot, index: originalIndex),
    );
  }

  Widget _buildFilterTab(String label, int index) {
    final isSelected = _tabIndex == index;
    return Builder(
      builder: (context) => InkWell(
        onTap: () => setState(() => _tabIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.accent : AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? AppColors.accent : AppColors.border(context),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  isSelected ? Colors.black : AppColors.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final noteProvider = Provider.of<NoteProvider>(context);
    final activeNotes = noteProvider.activeNotes;
    final archivedNotes = noteProvider.archivedNotes;
    final notes = _tabIndex == 0 ? activeNotes : archivedNotes;
    final isArchivedView = _tabIndex == 1;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterTab(
                    l10n.pick(
                      'Active (${activeNotes.length})',
                      'Aktif (${activeNotes.length})',
                    ),
                    0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterTab(
                    l10n.pick(
                      'Archived (${archivedNotes.length})',
                      'Diarsipkan (${archivedNotes.length})',
                    ),
                    1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isArchivedView
                              ? Icons.archive_outlined
                              : Icons.notes_rounded,
                          size: 48,
                          color: AppColors.textSecondary(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isArchivedView
                              ? l10n.pick(
                                  'No archived notes',
                                  'Belum ada catatan terarsip',
                                )
                              : l10n.pick(
                                  'No notes yet',
                                  'Belum ada catatan',
                                ),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isArchivedView
                              ? l10n.pick(
                                  'Swipe left on any active note to archive it',
                                  'Geser kiri pada catatan aktif untuk mengarsipkannya',
                                )
                              : l10n.pick(
                                  'Tap + to jot down thoughts, ideas, or references',
                                  'Ketuk + untuk mencatat ide, pikiran, atau referensi',
                                ),
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final checklistSummary = note.checklistSummary;
                      final hasMarkdown = note.content.contains('#') ||
                          note.content.contains('*') ||
                          note.content.contains('`') ||
                          checklistSummary.hasItems ||
                          note.content.contains('> ');

                      return SwipeActionCard(
                        key: ValueKey('note_swipe_${note.id}'),
                        dismissKey: ValueKey('note_${note.id}_${note.isArchived}'),
                        swipeRightStyle: isArchivedView
                            ? const SwipeActionStyle(
                                label: 'Restore',
                                icon: Icons.unarchive_outlined,
                                color: AppColors.success,
                              )
                            : SwipeActionStyle(
                                label: note.isPinned ? 'Unpin' : 'Pin',
                                icon: note.isPinned
                                    ? Icons.push_pin_outlined
                                    : Icons.push_pin_rounded,
                                color: AppColors.accent,
                              ),
                        swipeLeftStyle: isArchivedView
                            ? const SwipeActionStyle(
                                label: 'Delete',
                                icon: Icons.delete_outline_rounded,
                                color: AppColors.error,
                              )
                            : const SwipeActionStyle(
                                label: 'Archive',
                                icon: Icons.archive_outlined,
                                color: AppColors.accent,
                              ),
                        onSwipeRight: () => isArchivedView
                            ? _toggleArchiveWithUndo(
                                context, noteProvider, note)
                            : _togglePinWithUndo(context, noteProvider, note),
                        onSwipeLeft: () => isArchivedView
                            ? _deleteNoteWithUndo(context, noteProvider, note)
                            : _toggleArchiveWithUndo(
                                context, noteProvider, note),
                        child: Card(
                          child: InkWell(
                            onTap: () => _showNoteEditor(existing: note),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            CategoryBadge(
                                              category: note.category,
                                              compact: true,
                                            ),
                                            if (hasMarkdown)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6)
                                                      .withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'M↓',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFA78BFA),
                                                  ),
                                                ),
                                              ),
                                            if (checklistSummary.hasItems)
                                              _buildChecklistProgressPill(
                                                checklistSummary,
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (!isArchivedView)
                                        IconButton(
                                          icon: Icon(
                                            note.isPinned
                                                ? Icons.push_pin_rounded
                                                : Icons.push_pin_outlined,
                                            size: 18,
                                            color: note.isPinned
                                                ? AppColors.adaptive(
                                                    context,
                                                    dark: AppColors.accent,
                                                    light: const Color(0xFFB45309),
                                                  )
                                                : AppColors.textSecondary(
                                                    context),
                                          ),
                                          onPressed: () =>
                                              noteProvider.togglePin(note.id),
                                          visualDensity: VisualDensity.compact,
                                        )
                                      else
                                        IconButton(
                                          icon: Icon(
                                            Icons.unarchive_outlined,
                                            size: 18,
                                            color: AppColors.adaptive(
                                              context,
                                              dark: AppColors.success,
                                              light: const Color(0xFF047857),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _toggleArchiveWithUndo(
                                                  context, noteProvider, note),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      IconButton(
                                        icon: Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: AppColors.textSecondary(
                                                context)),
                                        onPressed: () => _deleteNoteWithUndo(
                                            context, noteProvider, note),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  if (note.title.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      note.title,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                  if (note.content.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    // Rich Markdown Rendering in Note Card
                                    MarkdownContentView(
                                      content: note.content,
                                      isCompact: true,
                                      maxLines: 4,
                                      onChecklistToggle: (lineIndex) {
                                        HapticFeedback.selectionClick();
                                        noteProvider.toggleChecklistItem(
                                          note.id,
                                          lineIndex,
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteEditor(),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('New Note',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
      ),
    );
  }
}
