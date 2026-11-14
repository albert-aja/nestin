import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alarm_category.dart';
import '../../../data/models/reminder.dart';
import '../../../data/models/location_reminder.dart';
import '../../../providers/geofence_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/location_reminders_sheet.dart';
import '../../widgets/swipe_action_card.dart';

class RemindersListScreen extends StatefulWidget {
  const RemindersListScreen({super.key});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  int _tabFilter = 0; // 0 = All, 1 = Pending, 2 = Completed

  void _showReminderDialog({Reminder? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderEditorSheet(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminderProvider = Provider.of<ReminderProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    GeofenceProvider? geofenceProvider;
    try {
      geofenceProvider = Provider.of<GeofenceProvider>(context);
    } catch (_) {}
    final now = DateTime.now();

    List<Reminder> filtered = reminderProvider.reminders;
    if (_tabFilter == 1) {
      filtered = reminderProvider.pendingReminders;
    } else if (_tabFilter == 2) {
      filtered = reminderProvider.completedReminders;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          if (geofenceProvider != null)
            IconButton(
              icon: const Icon(Icons.location_on_outlined, size: 22),
              tooltip: 'Location Geofence Reminders',
              onPressed: () => LocationRemindersSheet.show(context),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28),
            onPressed: () => _showReminderDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (geofenceProvider != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: InkWell(
                onTap: () => LocationRemindersSheet.show(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.explore_rounded,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scout Location Triggers',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              '${geofenceProvider.armedCount} armed across ${geofenceProvider.places.length} places • ${geofenceProvider.permissionState.label}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
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
            ),
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterTab('All (${reminderProvider.reminders.length})', 0),
                const SizedBox(width: 8),
                _buildFilterTab(
                    'Pending (${reminderProvider.pendingReminders.length})', 1),
                const SizedBox(width: 8),
                _buildFilterTab(
                    'Done (${reminderProvider.completedReminders.length})', 2),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildReminderCard(
                        context,
                        item,
                        reminderProvider,
                        settingsProvider,
                        now,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReminderDialog(),
        backgroundColor: AppColors.catWork,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: const Text(
          'New Reminder',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, int index) {
    final isSelected = _tabFilter == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabFilter = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.catWork
                : AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? AppColors.catWork : AppColors.border(context),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Colors.white
                  : AppColors.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReminderWithUndo(
    BuildContext context,
    ReminderProvider provider,
    Reminder item,
  ) async {
    final snapshot = item;
    final originalIndex = provider.indexOfReminder(item.id);
    await provider.toggleCompletion(item.id);
    if (!context.mounted) return;

    final isRecurringAdvance =
        !item.isCompleted && item.recurrence != ReminderRecurrence.none;
    final message = item.isCompleted
        ? 'Reopened "${item.title}"'
        : (isRecurringAdvance
            ? 'Advanced "${item.title}" to next schedule'
            : 'Completed "${item.title}"');

    showUndoSnackBar(
      context: context,
      message: message,
      color: item.isCompleted ? AppColors.info : AppColors.success,
      icon: item.isCompleted
          ? Icons.replay_rounded
          : (isRecurringAdvance
              ? Icons.event_repeat_rounded
              : Icons.check_circle_rounded),
      onUndo: () => provider.restoreReminder(snapshot, index: originalIndex),
    );
  }

  Future<void> _deleteReminderWithUndo(
    BuildContext context,
    ReminderProvider provider,
    Reminder item,
  ) async {
    final snapshot = item;
    final originalIndex = provider.indexOfReminder(item.id);
    await provider.deleteReminder(item.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context: context,
      message: 'Deleted "${item.title}"',
      color: AppColors.error,
      icon: Icons.delete_outline_rounded,
      onUndo: () => provider.restoreReminder(snapshot, index: originalIndex),
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    Reminder item,
    ReminderProvider provider,
    SettingsProvider settingsProvider,
    DateTime now,
  ) {
    final isOverdue = item.isOverdue(now);
    final isRecurringAdvance =
        !item.isCompleted && item.recurrence != ReminderRecurrence.none;

    return SwipeActionCard(
      key: ValueKey('reminder_swipe_${item.id}'),
      dismissKey: ValueKey('reminder_${item.id}'),
      swipeRightStyle: item.isCompleted
          ? const SwipeActionStyle(
              label: 'Reopen',
              icon: Icons.replay_rounded,
              color: AppColors.info,
            )
          : SwipeActionStyle(
              label: isRecurringAdvance ? 'Next Due' : 'Complete',
              icon: isRecurringAdvance
                  ? Icons.event_repeat_rounded
                  : Icons.check_circle_rounded,
              color: AppColors.success,
            ),
      swipeLeftStyle: const SwipeActionStyle(
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        color: AppColors.error,
      ),
      onSwipeRight: () => _toggleReminderWithUndo(context, provider, item),
      onSwipeLeft: () => _deleteReminderWithUndo(context, provider, item),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item.isCompleted,
                activeColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (_) => provider.toggleCompletion(item.id),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoryBadge(category: item.category, compact: true),
                        const SizedBox(width: 8),
                        if (item.recurrence != ReminderRecurrence.none)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.subtleFill(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.recurrenceLabel(),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        if (isOverdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OVERDUE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isCompleted
                            ? AppColors.textSecondary(context)
                            : AppColors.textPrimary(context),
                      ),
                    ),
                    if (item.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 13, color: AppColors.textSecondary(context)),
                        const SizedBox(width: 4),
                        Text(
                          '${item.formattedDueDate()} at ${item.formattedDueTime(use24Hour: settingsProvider.use24Hour)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOverdue
                                ? AppColors.error
                                : AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.textSecondary(context)),
                onPressed: () =>
                    _deleteReminderWithUndo(context, provider, item),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all_rounded,
                size: 52, color: AppColors.catWork),
            const SizedBox(height: 16),
            const Text(
              'All caught up!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'No reminders to display in this view.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderEditorSheet extends StatefulWidget {
  final Reminder? existing;

  const _ReminderEditorSheet({this.existing});

  @override
  State<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<_ReminderEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  late AlarmCategory _category;
  late ReminderRecurrence _recurrence;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    final now = DateTime.now();
    _titleController = TextEditingController(text: r?.title ?? '');
    _notesController = TextEditingController(text: r?.notes ?? '');
    _dueDate = r?.dueDateTime ?? now;
    _dueTime = r != null
        ? TimeOfDay(hour: r.dueDateTime.hour, minute: r.dueDateTime.minute)
        : TimeOfDay(hour: now.hour + 1, minute: 0);
    _category = r?.category ?? AlarmCategory.fromType(AlarmCategoryType.work);
    _recurrence = r?.recurrence ?? ReminderRecurrence.none;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  void _save() {
    final text = _titleController.text.trim();
    if (text.isEmpty) return;

    final combinedDateTime = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );

    final provider = Provider.of<ReminderProvider>(context, listen: false);
    final now = DateTime.now();

    final reminder = Reminder(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: text,
      notes: _notesController.text.trim(),
      dueDateTime: combinedDateTime,
      recurrence: _recurrence,
      category: _category,
      isCompleted: widget.existing?.isCompleted ?? false,
      createdAt: widget.existing?.createdAt ?? now,
    );

    if (widget.existing == null) {
      provider.addReminder(reminder);
    } else {
      provider.updateReminder(reminder);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
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
                  widget.existing == null ? 'New Reminder' : 'Edit Reminder',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reminder Title',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // Date and Time Pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_rounded, size: 16),
                    label: Text(
                      '${_dueTime.hour.toString().padLeft(2, '0')}:${_dueTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recurrence
            DropdownButtonFormField<ReminderRecurrence>(
              value: _recurrence,
              decoration: const InputDecoration(
                labelText: 'Repeat Frequency',
                prefixIcon: Icon(Icons.repeat_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: ReminderRecurrence.none,
                  child: Text('Does not repeat'),
                ),
                DropdownMenuItem(
                  value: ReminderRecurrence.daily,
                  child: Text('Repeats Daily'),
                ),
                DropdownMenuItem(
                  value: ReminderRecurrence.weekdays,
                  child: Text('Repeats Weekdays'),
                ),
                DropdownMenuItem(
                  value: ReminderRecurrence.weekly,
                  child: Text('Repeats Weekly'),
                ),
                DropdownMenuItem(
                  value: ReminderRecurrence.monthly,
                  child: Text('Repeats Monthly'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _recurrence = val);
              },
            ),
            const SizedBox(height: 16),

            // Category Chips
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
                      avatar: Icon(
                        cat.icon,
                        size: 14,
                        color: isSelected ? Colors.white : cat.color,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _category = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catWork,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save Reminder',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

