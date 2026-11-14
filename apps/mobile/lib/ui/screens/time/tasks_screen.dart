import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/models/task_item.dart';
import '../../../data/models/alarm_category.dart';
import '../../../data/models/entity_link.dart';
import '../../../domain/nlp/natural_language_date_parser.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/cross_module_link_provider.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/nlp_date_detector_chip.dart';
import '../../widgets/swipe_action_card.dart';
import '../../widgets/linked_entities_section.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _tabIndex = 0; // 0 = Pending, 1 = Completed

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    TaskPriority priority = TaskPriority.medium;
    AlarmCategory category = AlarmCategory.fromType(AlarmCategoryType.work);
    final List<String> subtaskTitles = [];
    final subtaskController = TextEditingController();
    DateTime dueDate = DateTime.now();
    TimeOfDay? dueTime;
    ParsedDateResult? parsedNlp;

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
                        const Text('New Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        hintText: 'e.g. Sync with team tomorrow at 3pm',
                        prefixIcon: Icon(Icons.task_alt_rounded),
                      ),
                      onChanged: (text) {
                        final res = NaturalLanguageDateParser.parse(text);
                        if (res.hasMatch) {
                          setSheetState(() {
                            parsedNlp = res;
                            if (res.date != null) dueDate = res.date!;
                            if (res.time != null) dueTime = res.time;
                          });
                        } else if (parsedNlp != null) {
                          setSheetState(() => parsedNlp = null);
                        }
                      },
                    ),
                    if (parsedNlp != null && parsedNlp!.hasMatch)
                      NlpDateDetectorChip(
                        result: parsedNlp!,
                        onCleanTitle: () {
                          setSheetState(() {
                            titleController.text = parsedNlp!.cleanTitle;
                            titleController.selection = TextSelection.collapsed(
                              offset: titleController.text.length,
                            );
                          });
                        },
                        onDismiss: () {
                          setSheetState(() => parsedNlp = null);
                        },
                      ),
                    const SizedBox(height: 10),

                    // Date & Time Selectors
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                              );
                              if (picked != null) setSheetState(() => dueDate = picked);
                            },
                            icon: const Icon(Icons.calendar_today_rounded, size: 14),
                            label: Text(
                              DateFormat('EEE, MMM d').format(dueDate),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: dueTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) setSheetState(() => dueTime = picked);
                            },
                            icon: const Icon(Icons.access_time_rounded, size: 14),
                            label: Text(
                              dueTime != null ? dueTime!.format(context) : 'No Time',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes / Context (Optional)'),
                    ),
                    const SizedBox(height: 14),

                    // Priority Selector
                    Text(
                      'Priority',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: TaskPriority.values.map((p) {
                        final isSelected = priority == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            selected: isSelected,
                            label: Text(
                              p.name.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                            backgroundColor: AppColors.elevatedSurface(context),
                            selectedColor: AppColors.primary,
                            onSelected: (val) {
                              if (val) setSheetState(() => priority = p);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Subtask Quick Add
                    Text(
                      'Subtasks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: subtaskController,
                            decoration: const InputDecoration(hintText: 'Add sub-step...'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent),
                          onPressed: () {
                            final subText = subtaskController.text.trim();
                            if (subText.isNotEmpty) {
                              setSheetState(() {
                                subtaskTitles.add(subText);
                                subtaskController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (subtaskTitles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...subtaskTitles.map((st) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.circle_outlined, size: 14, color: AppColors.accent),
                                const SizedBox(width: 8),
                                Expanded(child: Text(st, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          )),
                    ],
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () {
                        var t = titleController.text.trim();
                        if (t.isNotEmpty) {
                          if (parsedNlp != null &&
                              parsedNlp!.hasMatch &&
                              t == parsedNlp!.originalText) {
                            t = parsedNlp!.cleanTitle;
                          }
                          final subs = subtaskTitles
                              .map((title) => TaskSubItem(id: const Uuid().v4(), title: title))
                              .toList();

                          Provider.of<TaskProvider>(context, listen: false).addTask(
                            TaskItem(
                              id: const Uuid().v4(),
                              title: t,
                              notes: notesController.text.trim(),
                              priority: priority,
                              category: category,
                              subtasks: subs,
                              dueDate: dueDate,
                              dueTime: dueTime,
                              createdAt: DateTime.now(),
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.catWork,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save Task', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
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

  Future<void> _toggleTaskWithUndo(
    BuildContext context,
    TaskProvider provider,
    TaskItem task,
  ) async {
    final snapshot = task;
    final originalIndex = provider.indexOfTask(task.id);
    await provider.toggleTaskCompletion(task.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context: context,
      message: task.isCompleted
          ? 'Reopened "${task.title}"'
          : 'Completed "${task.title}"',
      color: task.isCompleted ? AppColors.info : AppColors.success,
      icon: task.isCompleted
          ? Icons.replay_rounded
          : Icons.check_circle_rounded,
      onUndo: () => provider.restoreTask(snapshot, index: originalIndex),
    );
  }

  Future<void> _deleteTaskWithUndo(
    BuildContext context,
    TaskProvider provider,
    TaskItem task,
  ) async {
    final snapshot = task;
    final originalIndex = provider.indexOfTask(task.id);
    await provider.deleteTask(task.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context: context,
      message: 'Deleted "${task.title}"',
      color: AppColors.error,
      icon: Icons.delete_outline_rounded,
      onUndo: () => provider.restoreTask(snapshot, index: originalIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final taskProvider = Provider.of<TaskProvider>(context);
    final displayedTasks = _tabIndex == 0 ? taskProvider.pendingTasks : taskProvider.completedTasks;
    final now = DateTime.now();

    return Scaffold(
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterTab(
                      l10n.pick(
                        'Pending (${taskProvider.pendingTasks.length})',
                        'Tertunda (${taskProvider.pendingTasks.length})',
                      ),
                      0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterTab(
                      l10n.pick(
                        'Completed (${taskProvider.completedTasks.length})',
                        'Selesai (${taskProvider.completedTasks.length})',
                      ),
                      1),
                ),
              ],
            ),
          ),

          // Tasks List
          Expanded(
            child: displayedTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 48, color: AppColors.textSecondary(context)),
                        const SizedBox(height: 12),
                        Text(
                          _tabIndex == 0
                              ? l10n.pick('No pending tasks!', 'Tidak ada tugas tertunda!')
                              : l10n.pick('No completed tasks yet', 'Belum ada tugas selesai'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: displayedTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = displayedTasks[index];
                      final isOverdue = task.isOverdue(now);

                      return SwipeActionCard(
                        key: ValueKey('task_swipe_${task.id}'),
                        dismissKey: ValueKey('task_${task.id}'),
                        swipeRightStyle: task.isCompleted
                            ? SwipeActionStyle(
                                label: l10n.pick('Reopen', 'Buka Lagi'),
                                icon: Icons.replay_rounded,
                                color: AppColors.info,
                              )
                            : SwipeActionStyle(
                                label: l10n.pick('Complete', 'Selesai'),
                                icon: Icons.check_circle_rounded,
                                color: AppColors.success,
                              ),
                        swipeLeftStyle: SwipeActionStyle(
                          label: l10n.tr('delete'),
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                        onSwipeRight: () =>
                            _toggleTaskWithUndo(context, taskProvider, task),
                        onSwipeLeft: () =>
                            _deleteTaskWithUndo(context, taskProvider, task),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: task.isCompleted,
                                      activeColor: AppColors.success,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      onChanged: (_) => taskProvider.toggleTaskCompletion(task.id),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: task.priorityColor.withOpacity(0.18),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  task.priorityLabel,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: task.priorityColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              CategoryBadge(category: task.category, compact: true),
                                              if (isOverdue) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                            task.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                              color: task.isCompleted
                                                  ? AppColors.textSecondary(context)
                                                  : AppColors.textPrimary(context),
                                            ),
                                          ),
                                          if (task.notes.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              task.notes,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary(context),
                                              ),
                                            ),
                                          ],
                                          if (task.dueDate != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.schedule_rounded,
                                                  size: 12,
                                                  color: isOverdue
                                                      ? AppColors.error
                                                      : AppColors.textSecondary(context),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  DateFormat('EEE, MMM d').format(task.dueDate!) +
                                                      (task.dueTime != null
                                                          ? ' • ${task.dueTime!.format(context)}'
                                                          : ''),
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
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Linked Items',
                                      icon: Icon(
                                        Icons.hub_outlined,
                                        size: 18,
                                        color: AppColors.info,
                                      ),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          backgroundColor:
                                              AppColors.sheetSurface(context),
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                          ),
                                          builder: (_) => SafeArea(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: LinkedEntitiesSection(
                                                entityType: LinkEntityType.task,
                                                entityId: task.id,
                                                entityTitle: task.title,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppColors.textSecondary(context),
                                      ),
                                      onPressed: () {
                                        try {
                                          Provider.of<CrossModuleLinkProvider>(
                                            context,
                                            listen: false,
                                          ).removeAllLinksFor(
                                            LinkEntityType.task,
                                            task.id,
                                          );
                                        } catch (_) {}
                                        _deleteTaskWithUndo(
                                            context, taskProvider, task);
                                      },
                                    ),
                                  ],
                                ),
                                // Subtasks checklist if present
                                if (task.subtasks.isNotEmpty) ...[
                                  const Divider(height: 14),
                                  ...task.subtasks.map((sub) => Padding(
                                        padding: const EdgeInsets.only(left: 36, bottom: 4),
                                        child: InkWell(
                                          onTap: () => taskProvider.toggleSubtask(task.id, sub.id),
                                          child: Row(
                                            children: [
                                              Icon(
                                                sub.isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                                size: 16,
                                                color: sub.isCompleted
                                                    ? AppColors.success
                                                    : AppColors.textSecondary(context),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  sub.title,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                                                    color: sub.isCompleted
                                                        ? AppColors.textSecondary(context)
                                                        : AppColors.adaptive(
                                                            context,
                                                            dark: const Color(0xFFD1D5DB),
                                                            light: AppColors.lightTextPrimary,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )),
                                ],
                              ],
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
        onPressed: _showAddTaskDialog,
        backgroundColor: AppColors.catWork,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Task', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _buildFilterTab(String label, int index) {
    final isSelected = _tabIndex == index;
    return InkWell(
      onTap: () => setState(() => _tabIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.catWork
              : AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.catWork : AppColors.border(context),
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
    );
  }
}

