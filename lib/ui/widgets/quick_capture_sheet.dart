import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/alarm_category.dart';
import '../../data/models/note_item.dart';
import '../../data/models/task_item.dart';
import '../../data/models/reminder.dart';
import '../../data/models/journal_entry.dart';
import '../../data/models/wishlist_item.dart';
import '../../providers/note_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/collection_provider.dart';
import '../../domain/nlp/natural_language_date_parser.dart';
import '../screens/alarms/alarm_edit_screen.dart';
import 'nlp_date_detector_chip.dart';

enum CaptureType {
  note,
  task,
  reminder,
  journal,
  wishlist,
}

class QuickCaptureSheet extends StatefulWidget {
  const QuickCaptureSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickCaptureSheet(),
    );
  }

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  CaptureType _selectedType = CaptureType.note;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  AlarmCategory _category = AlarmCategory.fromType(AlarmCategoryType.personal);
  ParsedDateResult? _parsedNlp;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    var title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();

    if (_parsedNlp != null &&
        _parsedNlp!.hasMatch &&
        title == _parsedNlp!.originalText) {
      title = _parsedNlp!.cleanTitle;
    }

    switch (_selectedType) {
      case CaptureType.note:
        Provider.of<NoteProvider>(context, listen: false).addNote(
          NoteItem(
            id: const Uuid().v4(),
            title: title,
            content: content,
            category: _category,
            createdAt: now,
            updatedAt: now,
          ),
        );
        break;

      case CaptureType.task:
        Provider.of<TaskProvider>(context, listen: false).addTask(
          TaskItem(
            id: const Uuid().v4(),
            title: title,
            notes: content,
            category: _category,
            dueDate: _parsedNlp?.date ?? now,
            dueTime: _parsedNlp?.time,
            createdAt: now,
          ),
        );
        break;

      case CaptureType.reminder:
        DateTime reminderDate = now.add(const Duration(hours: 2));
        if (_parsedNlp != null && _parsedNlp!.hasMatch) {
          final d = _parsedNlp!.date ?? now;
          final t = _parsedNlp!.time ?? const TimeOfDay(hour: 9, minute: 0);
          reminderDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        }
        Provider.of<ReminderProvider>(context, listen: false).addReminder(
          Reminder(
            id: const Uuid().v4(),
            title: title,
            notes: content,
            dueDateTime: reminderDate,
            category: _category,
            createdAt: now,
          ),
        );
        break;

      case CaptureType.journal:
        Provider.of<JournalProvider>(context, listen: false).addJournalEntry(
          JournalEntry(
            id: const Uuid().v4(),
            title: title,
            content: content,
            date: now,
            mood: JournalMood.good,
            createdAt: now,
            updatedAt: now,
          ),
        );
        break;

      case CaptureType.wishlist:
        Provider.of<CollectionProvider>(context, listen: false).addWishlistItem(
          WishlistItem(
            id: const Uuid().v4(),
            title: title,
            description: content,
            category: _category,
            createdAt: now,
          ),
        );
        break;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved to ${_selectedType.name.toUpperCase()}'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF23252E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.accent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Quick Capture',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Type Segment Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip('Note', Icons.description_outlined, CaptureType.note),
                  _buildTypeChip('Task', Icons.check_circle_outline_rounded, CaptureType.task),
                  _buildTypeChip('Reminder', Icons.alarm_outlined, CaptureType.reminder),
                  _buildTypeChip('Journal', Icons.book_outlined, CaptureType.journal),
                  _buildTypeChip('Wishlist', Icons.card_giftcard_rounded, CaptureType.wishlist),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.add_alarm_rounded, size: 14, color: AppColors.primary),
                      label: const Text('Alarm'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AlarmEditScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title field
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _selectedType == CaptureType.journal
                    ? "Today's headline..."
                    : (_selectedType == CaptureType.task ||
                            _selectedType == CaptureType.reminder
                        ? 'e.g. Sync with team tomorrow at 3pm'
                        : 'What is on your mind?'),
                prefixIcon: const Icon(Icons.edit_rounded),
              ),
              onChanged: (text) {
                if (_selectedType == CaptureType.task ||
                    _selectedType == CaptureType.reminder) {
                  final res = NaturalLanguageDateParser.parse(text);
                  if (res.hasMatch) {
                    setState(() => _parsedNlp = res);
                  } else if (_parsedNlp != null) {
                    setState(() => _parsedNlp = null);
                  }
                }
              },
            ),
            if (_parsedNlp != null &&
                _parsedNlp!.hasMatch &&
                (_selectedType == CaptureType.task ||
                    _selectedType == CaptureType.reminder))
              NlpDateDetectorChip(
                result: _parsedNlp!,
                onCleanTitle: () {
                  setState(() {
                    _titleController.text = _parsedNlp!.cleanTitle;
                    _titleController.selection = TextSelection.collapsed(
                      offset: _titleController.text.length,
                    );
                  });
                },
                onDismiss: () {
                  setState(() => _parsedNlp = null);
                },
              ),
            const SizedBox(height: 10),

            // Details / Notes field
            TextField(
              controller: _contentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Additional notes, thoughts, or details (optional)...',
              ),
            ),
            const SizedBox(height: 16),

            // Category Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AlarmCategory.predefined.map((cat) {
                  final isSelected = _category.type == cat.type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(cat.name),
                      selectedColor: cat.color,
                      avatar: Icon(cat.icon, size: 12, color: isSelected ? Colors.white : cat.color),
                      onSelected: (selected) {
                        if (selected) setState(() => _category = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Save to Everyday Space',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon, CaptureType type) {
    final isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.accent),
        selectedColor: AppColors.accent,
        onSelected: (val) {
          if (val) setState(() => _selectedType = type);
        },
      ),
    );
  }
}

