import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/app_localizations.dart';
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
import 'location_reminders_sheet.dart';
import 'before_you_go_sheet.dart';
import 'money/money_editor_dialogs.dart';

enum CaptureType {
  note,
  task,
  reminder,
  journal,
  wishlist,
}

class QuickCaptureSheet extends StatefulWidget {
  final CaptureType initialType;

  const QuickCaptureSheet({super.key, this.initialType = CaptureType.note});

  static void show(BuildContext context, {CaptureType initialType = CaptureType.note}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickCaptureSheet(initialType: initialType),
    );
  }

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  late CaptureType _selectedType;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  AlarmCategory _category = AlarmCategory.fromType(AlarmCategoryType.personal);
  ParsedDateResult? _parsedNlp;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

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
        content: Text(
          'Saved to ${_selectedType.name.toUpperCase()}',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.adaptive(
          context,
          dark: const Color(0xFF23252E),
          light: AppColors.lightTextPrimary,
        ),
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
            Builder(
              builder: (context) {
                final l10n = context.l10n;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTypeChip(l10n.tr('qc_note'), Icons.description_outlined, CaptureType.note),
                          _buildTypeChip(l10n.tr('qc_task'), Icons.check_circle_outline_rounded, CaptureType.task),
                          _buildTypeChip(l10n.tr('qc_reminder'), Icons.alarm_outlined, CaptureType.reminder),
                          _buildTypeChip(l10n.tr('qc_journal'), Icons.book_outlined, CaptureType.journal),
                          _buildTypeChip(l10n.tr('qc_wishlist'), Icons.card_giftcard_rounded, CaptureType.wishlist),
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.add_alarm_rounded, size: 14, color: AppColors.primary),
                              label: Text(l10n.tr('qc_alarm')),
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AlarmEditScreen()),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.account_balance_wallet_rounded, size: 14, color: kTwillAmber),
                              label: Text(l10n.tr('qc_money')),
                              onPressed: () {
                                Navigator.of(context).pop();
                                showMoneyTransactionSheet(context);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.door_front_door_outlined, size: 14, color: kScoutBlue),
                              label: Text(l10n.tr('qc_departure')),
                              onPressed: () {
                                Navigator.of(context).pop();
                                showDepartureEventEditorDialog(context);
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
                            ? l10n.tr('qc_headline_hint')
                            : (_selectedType == CaptureType.task ||
                                    _selectedType == CaptureType.reminder
                                ? l10n.tr('qc_task_hint')
                                : l10n.tr('qc_mind_hint')),
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
                      decoration: InputDecoration(
                        hintText: l10n.tr('qc_notes_hint'),
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
                              label: Text(l10n.categoryName(cat.type)),
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
                    const SizedBox(height: 16),

                    if (_selectedType == CaptureType.reminder) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          showLocationReminderEditorDialog(context);
                        },
                        icon: const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Color(0xFF3B82F6),
                        ),
                        label: Text(
                          l10n.tr('qc_geofence_btn'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6),
                          side: BorderSide(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        l10n.tr('qc_save_btn'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
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

