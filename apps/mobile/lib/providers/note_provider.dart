import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/note_item.dart';
import '../data/models/alarm_category.dart';
import '../data/services/storage_service.dart';
import '../domain/notes/markdown_checklist_helper.dart';

class NoteProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<NoteItem> _notes = [];

  NoteProvider(this._storageService) {
    _loadNotes();
  }

  List<NoteItem> get notes => List.unmodifiable(_notes);

  List<NoteItem> get activeNotes {
    final list = _notes.where((n) => !n.isArchived).toList();
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  List<NoteItem> get pinnedNotes =>
      _notes.where((n) => !n.isArchived && n.isPinned).toList();

  List<NoteItem> get archivedNotes =>
      _notes.where((n) => n.isArchived).toList();

  void _loadNotes() {
    _notes = _storageService.loadNotes();
    if (_notes.isEmpty) {
      final now = DateTime.now();
      _notes = [
        NoteItem(
          id: const Uuid().v4(),
          title: 'Ideas for Weekend Trip',
          content: 'Pack light jackets, hiking boots, camera, and trail snacks. Check weather forecast before leaving Friday afternoon!',
          category: AlarmCategory.fromType(AlarmCategoryType.personal),
          tags: const ['Travel', 'Weekend', 'Packing'],
          isPinned: true,
          colorValue: 0xFFFF9E1B,
          createdAt: now,
          updatedAt: now,
        ),
        NoteItem(
          id: const Uuid().v4(),
          title: 'Books & Articles to Read',
          content: '1. Atomic Habits by James Clear\n2. Deep Work by Cal Newport\n3. The Psychology of Money by Morgan Housel',
          category: AlarmCategory.fromType(AlarmCategoryType.activities),
          tags: const ['Reading', 'Self-improvement'],
          isPinned: false,
          colorValue: 0xFF3A86FF,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      _save();
    }
  }

  Future<void> _save() async {
    await _storageService.saveNotes(_notes);
    notifyListeners();
  }

  Future<void> addNote(NoteItem note) async {
    _notes.add(note);
    await _save();
  }

  Future<void> updateNote(NoteItem note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note.copyWith(updatedAt: DateTime.now());
      await _save();
    }
  }

  /// Toggles the markdown checklist box at [lineIndex] (`- [ ]` <-> `- [x]`)
  /// directly on the note matching [id] and persists the change.
  Future<bool> toggleChecklistItem(String id, int lineIndex) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return false;

    final current = _notes[index];
    final updatedContent = MarkdownChecklistHelper.toggleChecklistAtLine(
      current.content,
      lineIndex,
    );
    if (updatedContent == null || updatedContent == current.content) {
      return false;
    }

    _notes[index] = current.copyWith(
      content: updatedContent,
      updatedAt: DateTime.now(),
    );
    await _save();
    return true;
  }

  Future<void> togglePin(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        isPinned: !_notes[index].isPinned,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  Future<void> toggleArchive(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        isArchived: !_notes[index].isArchived,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  int indexOfNote(String id) => _notes.indexWhere((n) => n.id == id);

  /// Restores a deleted or previously modified [note] snapshot at [index].
  Future<void> restoreNote(NoteItem note, {int? index}) async {
    final existingIndex = _notes.indexWhere((n) => n.id == note.id);
    if (existingIndex != -1) {
      _notes[existingIndex] = note;
    } else {
      final insertAt = (index ?? _notes.length).clamp(0, _notes.length);
      _notes.insert(insertAt, note);
    }
    await _save();
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _save();
  }
}

