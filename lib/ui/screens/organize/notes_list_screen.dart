import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/note_item.dart';
import '../../../data/models/alarm_category.dart';
import '../../../providers/note_provider.dart';
import '../../widgets/category_badge.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  void _showNoteEditor({NoteItem? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController = TextEditingController(text: existing?.content ?? '');
    AlarmCategory category = existing?.category ?? AlarmCategory.fromType(AlarmCategoryType.personal);

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
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                          existing == null ? 'New Note' : 'Edit Note',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      autofocus: existing == null,
                      decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title_rounded)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Write your thoughts, references or details...'),
                    ),
                    const SizedBox(height: 14),
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
                              selectedColor: cat.color,
                              onSelected: (val) {
                                if (val) setSheetState(() => category = cat);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        final t = titleController.text.trim();
                        final c = contentController.text.trim();
                        if (t.isNotEmpty || c.isNotEmpty) {
                          final now = DateTime.now();
                          final noteProvider = Provider.of<NoteProvider>(context, listen: false);

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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save Note', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
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
    final noteProvider = Provider.of<NoteProvider>(context);
    final notes = noteProvider.activeNotes;

    return Scaffold(
      body: notes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notes_rounded, size: 48, color: Color(0xFF8E929E)),
                  SizedBox(height: 12),
                  Text('No notes yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Tap + to jot down thoughts, ideas, or references', style: TextStyle(fontSize: 12, color: Color(0xFF8E929E))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
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
                              CategoryBadge(category: note.category, compact: true),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                  size: 18,
                                  color: note.isPinned ? AppColors.accent : const Color(0xFF8E929E),
                                ),
                                onPressed: () => noteProvider.togglePin(note.id),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF8E929E)),
                                onPressed: () => noteProvider.deleteNote(note.id),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          if (note.title.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              note.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ],
                          if (note.content.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              note.content,
                              style: const TextStyle(fontSize: 13, color: Color(0xFFD1D5DB), height: 1.4),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteEditor(),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('New Note', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
      ),
    );
  }
}

