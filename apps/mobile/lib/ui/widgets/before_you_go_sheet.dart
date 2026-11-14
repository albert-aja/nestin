import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/alarm_category.dart';
import '../../data/models/before_you_go.dart';
import '../../data/models/calendar_event.dart';
import '../../providers/before_you_go_provider.dart';
import '../../providers/calendar_provider.dart';

const Color kScoutBlue = Color(0xFF3B82F6);
const Color kScoutAmber = Color(0xFFF59E0B);

class BeforeYouGoSheet extends StatefulWidget {
  final String? initialPresetId;
  final String? initialEventId;
  final int initialTab;

  const BeforeYouGoSheet({
    super.key,
    this.initialPresetId,
    this.initialEventId,
    this.initialTab = 0,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialPresetId,
    String? initialEventId,
    int initialTab = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BeforeYouGoSheet(
        initialPresetId: initialPresetId,
        initialEventId: initialEventId,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<BeforeYouGoSheet> createState() => _BeforeYouGoSheetState();
}

class _BeforeYouGoSheetState extends State<BeforeYouGoSheet> {
  final TextEditingController _newItemCtrl = TextEditingController();
  bool _newItemEssential = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<BeforeYouGoProvider>(context, listen: false);
      if (widget.initialPresetId != null &&
          provider.findPresetById(widget.initialPresetId) != null) {
        provider.selectActivePreset(widget.initialPresetId!);
      } else if (widget.initialEventId != null) {
        final ev = provider.findEventById(widget.initialEventId);
        if (ev != null) {
          provider.selectActivePreset(ev.presetId);
        }
      }
    });
  }

  @override
  void dispose() {
    _newItemCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BeforeYouGoProvider>(context);
    final nextDeparture = provider.getNextScheduledDeparture();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.sheetSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DefaultTabController(
            length: 2,
            initialIndex: widget.initialTab.clamp(0, 1),
            child: Column(
              children: [
                const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 13,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Heads-up notifications support Android shade actions: Mark All Ready & Snooze 5m.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kScoutBlue.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'assets/mascots/sprites/scout/before_you_go.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.door_front_door_outlined,
                            color: kScoutBlue,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scout — BeforeYouGo',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              nextDeparture != null
                                  ? 'Next: ${nextDeparture.title} • ${nextDeparture.formattedDepartureTime} (${nextDeparture.leadLabel})'
                                  : 'Custom checklists & smart departure heads-up',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'New Departure Trip',
                        icon: const Icon(Icons.add_alarm_rounded,
                            color: kScoutBlue),
                        onPressed: () => showDepartureEventEditorDialog(
                          context,
                          initialPresetId: provider.activePresetId,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  indicatorColor: kScoutBlue,
                  labelColor: kScoutBlue,
                  unselectedLabelColor: AppColors.textSecondary(context),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: [
                    Tab(
                      text:
                          'Checklists (${provider.activePreset.checkedCount}/${provider.activePreset.totalCount})',
                    ),
                    Tab(
                      text: 'Schedules (${provider.events.length})',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildChecklistTab(context, provider),
                      _buildSchedulesTab(context, provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChecklistTab(BuildContext context, BeforeYouGoProvider provider) {
    final preset = provider.activePreset;

    return Column(
      children: [
        // Preset Chips Selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              ...provider.presets.map((p) {
                final selected = p.id == preset.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    selectedColor: p.color.withValues(alpha: 0.22),
                    avatar: Icon(
                      p.icon,
                      size: 15,
                      color: selected
                          ? p.color
                          : AppColors.textSecondary(context),
                    ),
                    label: Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? p.color
                            : AppColors.textPrimary(context),
                      ),
                    ),
                    onSelected: (_) => provider.selectActivePreset(p.id),
                  ),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 15, color: kScoutBlue),
                label: const Text('New Preset',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () => showDeparturePresetDialog(context),
              ),
            ],
          ),
        ),

        // Preset Status Bar + Edit/Reset Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(preset.icon, color: preset.color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${preset.name} • ${preset.checkedCount}/${preset.totalCount} packed',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (preset.items.isNotEmpty && !preset.allChecked)
                      TextButton.icon(
                        onPressed: () =>
                            provider.markPresetAllReady(preset.id),
                        icon: const Icon(
                          Icons.done_all_rounded,
                          size: 15,
                          color: AppColors.success,
                        ),
                        label: const Text(
                          'Mark All Ready',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => provider.resetPresetItems(preset.id),
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text('Reset',
                          style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit Preset',
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => showDeparturePresetDialog(
                        context,
                        existing: preset,
                      ),
                    ),
                    if (provider.presets.length > 1)
                      IconButton(
                        tooltip: 'Delete Preset',
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                          color: AppColors.textSecondary(context),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await provider.deletePreset(preset.id);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: preset.completionFraction,
                    minHeight: 6,
                    backgroundColor: AppColors.trackSurface(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      preset.allChecked ? AppColors.success : preset.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Inline Add Item Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItemCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitNewItem(provider, preset.id),
                  decoration: InputDecoration(
                    hintText: 'Add item to ${preset.name}...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.add_task_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Mark as essential (featured in heads-up push)',
                child: IconButton.filledTonal(
                  onPressed: () =>
                      setState(() => _newItemEssential = !_newItemEssential),
                  icon: Icon(
                    _newItemEssential
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: _newItemEssential ? kScoutAmber : null,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: () => _submitNewItem(provider, preset.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kScoutBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text('Add', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // Reorderable Persistent Checklist
        Expanded(
          child: preset.items.isEmpty
              ? Center(
                  child: Text(
                    'No items in "${preset.name}". Add items above.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: preset.items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    provider.reorderItems(
                      preset.id,
                      oldIndex,
                      newIndex,
                      adjustForRemoval: false,
                    );
                  },
                  itemBuilder: (context, index) {
                    final item = preset.items[index];
                    return Card(
                      key: ValueKey('${preset.id}_${item.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        onTap: () => provider.toggleItem(preset.id, item.id),
                        leading: Checkbox(
                          value: item.isChecked,
                          activeColor: AppColors.success,
                          onChanged: (_) =>
                              provider.toggleItem(preset.id, item.id),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: item.isEssential
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  decoration: item.isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: item.isChecked
                                      ? AppColors.textSecondary(context)
                                      : AppColors.textPrimary(context),
                                ),
                              ),
                            ),
                            if (item.isEssential)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 15,
                                  color: kScoutAmber,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit item',
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _showEditItemDialog(context, provider, preset.id, item),
                            ),
                            IconButton(
                              tooltip: 'Delete item',
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: AppColors.textSecondary(context),
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  provider.removeItem(preset.id, item.id),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _submitNewItem(BeforeYouGoProvider provider, String presetId) {
    final label = _newItemCtrl.text.trim();
    if (label.isEmpty) return;
    provider.addItem(presetId, label, isEssential: _newItemEssential);
    _newItemCtrl.clear();
    setState(() => _newItemEssential = false);
  }

  Future<void> _showEditItemDialog(
    BuildContext context,
    BeforeYouGoProvider provider,
    String presetId,
    DepartureChecklistItem item,
  ) async {
    final ctrl = TextEditingController(text: item.label);
    var essential = item.isEssential;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardSurface(ctx),
          title: const Text('Edit Checklist Item',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Item Label'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Essential Item',
                    style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                    'Prioritized in pre-departure notifications',
                    style: TextStyle(fontSize: 11)),
                value: essential,
                onChanged: (v) => setDialogState(() => essential = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final nextLabel = ctrl.text.trim();
                if (nextLabel.isNotEmpty) {
                  provider.updateItem(
                    presetId,
                    item.copyWith(label: nextLabel, isEssential: essential),
                  );
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesTab(
      BuildContext context, BeforeYouGoProvider provider) {
    final events = provider.upcomingEvents();
    CalendarProvider? calProvider;
    try {
      calProvider = Provider.of<CalendarProvider>(context);
    } catch (_) {}

    final now = DateTime.now();
    final unlinkedCalendarEvents = calProvider == null
        ? const <CalendarEvent>[]
        : calProvider.upcomingEvents(now, limit: 4).where((ce) {
            if (ce.startTime == null) return false;
            return provider.findEventByLinkedCalendarId(ce.id) == null;
          }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => showDepartureEventEditorDialog(
                  context,
                  initialPresetId: provider.activePresetId,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Departure Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kScoutBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 13,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Heads-up notifications support Android shade actions: Mark All Ready & Snooze 5m.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (events.isEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      size: 38, color: kScoutBlue),
                  const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 13,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Heads-up notifications support Android shade actions: Mark All Ready & Snooze 5m.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
                  const Text(
                    'No Smart Departure Heads-Up Yet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Schedule a recurring routine (e.g. Mon–Fri 07:10 Leaving for Work) or a one-time trip (e.g. Today 16:00 Going to Airport) with custom advance alert time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.work_outline_rounded,
                            size: 14, color: kScoutBlue),
                        label: const Text('Leaving for Work (Mon–Fri 07:10)'),
                        onPressed: () {
                          provider.addDepartureEvent(
                            title: 'Leaving for work',
                            presetId: DeparturePreset.workPresetId,
                            hour: 7,
                            minute: 10,
                            recurrence: DepartureRecurrenceType.weekdays,
                            selectedDays: const {1, 2, 3, 4, 5},
                            leadMinutes: 15,
                          );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.flight_takeoff_rounded,
                            size: 14, color: kScoutAmber),
                        label: const Text('Going to Airport (Today 16:00)'),
                        onPressed: () {
                          provider.addDepartureEvent(
                            title: 'Going to airport',
                            presetId: DeparturePreset.travelPresetId,
                            hour: 16,
                            minute: 0,
                            recurrence: DepartureRecurrenceType.oneTime,
                            oneTimeDate: DateTime.now(),
                            leadMinutes: 30,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ...events.map((ev) {
            final preset = provider.findPresetById(ev.presetId);
            final nextDep = ev.nextDepartureAfter(now);
            final nextNotif = ev.nextNotificationAfter(now);
            final activeSnooze = provider.snoozeForEvent(ev.id, now);
            final isSnoozed =
                activeSnooze != null && activeSnooze.isActiveAt(now);
            final isReadyToday = ev.isCompletedForDate(now);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (preset?.color ?? kScoutBlue)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            preset?.icon ?? Icons.departure_board_rounded,
                            color: preset?.color ?? kScoutBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ev.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${ev.recurrenceSummary} • ${ev.formattedDepartureTime}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: ev.isEnabled,
                          activeThumbColor: kScoutBlue,
                          onChanged: (_) =>
                              provider.toggleDepartureEventEnabled(ev.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _pillChip(
                          context,
                          Icons.notifications_active_outlined,
                          '${ev.leadLabel} (${ev.formattedNotificationTime})',
                          kScoutAmber,
                        ),
                        if (preset != null)
                          _pillChip(
                            context,
                            preset.icon,
                            '${preset.name} (${preset.checkedCount}/${preset.totalCount})',
                            preset.color,
                          ),
                        if (ev.linkedCalendarEventId != null)
                          _pillChip(
                            context,
                            Icons.event_rounded,
                            'Calendar Linked',
                            AppColors.primary,
                          ),
                        if (isSnoozed)
                          _pillChip(
                            context,
                            Icons.snooze_rounded,
                            'Snoozed +5m -> ${activeSnooze.formattedSnoozedUntil}${activeSnooze.snoozeCount > 1 ? ' (${activeSnooze.snoozeCount}x)' : ''}',
                            kScoutAmber,
                          ),
                        if (isReadyToday)
                          _pillChip(
                            context,
                            Icons.verified_rounded,
                            'Marked Ready Today',
                            AppColors.success,
                          ),
                      ],
                    ),
                    if (nextNotif != null && nextDep != null && ev.isEnabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Next heads-up: ${DateFormat('EEE, MMM d • HH:mm').format(nextNotif)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          if (ev.isEnabled)
                            TextButton.icon(
                              onPressed: () async {
                                final snoozed = await provider.snoozeDeparture(
                                  eventId: ev.id,
                                  presetId: ev.presetId,
                                );
                                if (!context.mounted || snoozed == null) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Snoozed "${ev.title}" 5m until ${snoozed.formattedSnoozedUntil}',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.snooze_rounded, size: 15),
                              label: const Text('Snooze 5m',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          TextButton.icon(
                            onPressed: () {
                              provider.triggerTestNotification(ev.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Sent Scout BeforeYouGo preview for "${ev.title}"'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.notifications_rounded, size: 15),
                            label: const Text('Test Alert',
                                style: TextStyle(fontSize: 12)),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              if (preset != null) {
                                provider.selectActivePreset(preset.id);
                              }
                              showDepartureEventEditorDialog(
                                context,
                                existing: ev,
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('Edit',
                                style: TextStyle(fontSize: 12)),
                          ),
                          IconButton(
                            tooltip: 'Delete Schedule',
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 17,
                                color: AppColors.textSecondary(context)),
                            onPressed: () => provider.deleteDepartureEvent(ev.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        if (unlinkedCalendarEvents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Upcoming Calendar Events',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          ...unlinkedCalendarEvents.map((ce) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(ce.category.icon, color: ce.category.color),
                  title: Text(ce.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${DateFormat('EEE, MMM d').format(ce.date)} • ${ce.formattedTime()}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => showDepartureEventEditorDialog(
                      context,
                      linkCalendarEvent: ce,
                      initialPresetId: provider.activePresetId,
                    ),
                    child: const Text('+ Heads-up',
                        style: TextStyle(fontSize: 11)),
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _pillChip(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

Future<DeparturePreset?> showDeparturePresetDialog(
  BuildContext context, {
  DeparturePreset? existing,
}) async {
  final provider = Provider.of<BeforeYouGoProvider>(context, listen: false);
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  var iconCode =
      existing?.iconCodePoint ?? Icons.backpack_outlined.codePoint;
  var colorVal = existing?.colorValue ?? 0xFF3B82F6;

  final colorOptions = const [
    0xFF3B82F6,
    0xFF6366F1,
    0xFFF59E0B,
    0xFF10B981,
    0xFFEC4899,
    0xFFEF4444,
  ];

  return showDialog<DeparturePreset?>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
        backgroundColor: AppColors.cardSurface(ctx),
        title: Text(
          existing == null ? 'New Checklist Preset' : 'Edit Preset',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Preset Name',
                  hintText: 'e.g. Work, Travel, Gym, Weekend Run',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Icon',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DeparturePreset.availableIcons.map((ic) {
                  final selected = ic.codePoint == iconCode;
                  return InkWell(
                    onTap: () =>
                        setStateDialog(() => iconCode = ic.codePoint),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Color(colorVal).withValues(alpha: 0.22)
                            : AppColors.recessedSurface(ctx),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? Color(colorVal)
                              : AppColors.border(ctx),
                        ),
                      ),
                      child: Icon(ic, size: 18, color: Color(colorVal)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text('Color',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: colorOptions.map((c) {
                  final selected = c == colorVal;
                  return InkWell(
                    onTap: () => setStateDialog(() => colorVal = c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(c),
                      child: selected
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              DeparturePreset saved;
              if (existing == null) {
                saved = await provider.createPreset(
                  name: name,
                  iconCodePoint: iconCode,
                  colorValue: colorVal,
                );
              } else {
                saved = existing.copyWith(
                  name: name,
                  iconCodePoint: iconCode,
                  colorValue: colorVal,
                );
                await provider.updatePreset(saved);
              }
              if (ctx.mounted) Navigator.of(ctx).pop(saved);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<DepartureEvent?> showDepartureEventEditorDialog(
  BuildContext context, {
  DepartureEvent? existing,
  CalendarEvent? linkCalendarEvent,
  String? initialPresetId,
}) async {
  final provider = Provider.of<BeforeYouGoProvider>(context, listen: false);
  CalendarProvider? calProvider;
  try {
    calProvider = Provider.of<CalendarProvider>(context, listen: false);
  } catch (_) {}

  final titleCtrl = TextEditingController(
    text: existing?.title ?? linkCalendarEvent?.title ?? '',
  );
  var recurrence = existing?.recurrence ?? DepartureRecurrenceType.weekdays;
  if (existing == null && linkCalendarEvent != null) {
    recurrence = DepartureRecurrenceType.oneTime;
  }
  var oneTimeDate =
      existing?.oneTimeDate ?? linkCalendarEvent?.date ?? DateTime.now();
  var selectedTime = existing?.departureTimeOfDay ??
      linkCalendarEvent?.startTime ??
      const TimeOfDay(hour: 7, minute: 10);
  var selectedDays = Set<int>.from(
    existing?.selectedDays.isNotEmpty == true
        ? existing!.selectedDays
        : const {1, 2, 3, 4, 5},
  );
  var leadMinutes = existing?.leadMinutes ??
      linkCalendarEvent?.departureLeadMinutes ??
      15;
  var customLeadMode =
      !DepartureEvent.quickLeadMinuteOptions.contains(leadMinutes);
  final customLeadCtrl =
      TextEditingController(text: leadMinutes.toString());

  var presetId = existing?.presetId ??
      linkCalendarEvent?.beforeYouGoPresetId ??
      initialPresetId ??
      provider.activePresetId;
  if (!provider.presets.any((p) => p.id == presetId)) {
    presetId = provider.presets.first.id;
  }

  var alsoAddToCalendar = false;

  return showDialog<DepartureEvent?>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) {
        final effectiveNotifyTime = DateTime(
          2026,
          1,
          2,
          selectedTime.hour,
          selectedTime.minute,
        ).subtract(Duration(minutes: leadMinutes));
        final notifyStr =
            '${effectiveNotifyTime.hour.toString().padLeft(2, '0')}:${effectiveNotifyTime.minute.toString().padLeft(2, '0')}';

        return AlertDialog(
          backgroundColor: AppColors.cardSurface(ctx),
          title: Text(
            existing == null
                ? 'Schedule Departure Heads-Up'
                : 'Edit Departure Schedule',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    autofocus: existing == null && linkCalendarEvent == null,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      hintText: 'e.g. Leaving for work / Going to airport',
                      prefixIcon: Icon(Icons.departure_board_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: presetId,
                    decoration: const InputDecoration(
                      labelText: 'BeforeYouGo Checklist Preset',
                      prefixIcon: Icon(Icons.checklist_rounded),
                    ),
                    items: provider.presets
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.name} (${p.totalCount} items)'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => presetId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Schedule Repeat',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: DepartureRecurrenceType.values.map((r) {
                      final selected = recurrence == r;
                      return ChoiceChip(
                        selected: selected,
                        selectedColor: kScoutBlue.withValues(alpha: 0.22),
                        label: Text(r.label,
                            style: const TextStyle(fontSize: 11)),
                        onSelected: (_) {
                          setStateDialog(() {
                            recurrence = r;
                            if (r == DepartureRecurrenceType.weekdays) {
                              selectedDays = {1, 2, 3, 4, 5};
                            } else if (r == DepartureRecurrenceType.weekends) {
                              selectedDays = {6, 7};
                            } else if (r == DepartureRecurrenceType.daily) {
                              selectedDays = {1, 2, 3, 4, 5, 6, 7};
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (recurrence == DepartureRecurrenceType.customDays) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final entry in const {
                          1: 'Mon',
                          2: 'Tue',
                          3: 'Wed',
                          4: 'Thu',
                          5: 'Fri',
                          6: 'Sat',
                          7: 'Sun',
                        }.entries)
                          FilterChip(
                            selected: selectedDays.contains(entry.key),
                            label: Text(entry.value,
                                style: const TextStyle(fontSize: 11)),
                            onSelected: (sel) {
                              setStateDialog(() {
                                if (sel) {
                                  selectedDays.add(entry.key);
                                } else if (selectedDays.length > 1) {
                                  selectedDays.remove(entry.key);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (recurrence == DepartureRecurrenceType.oneTime) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: oneTimeDate,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 1)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365 * 2)),
                              );
                              if (picked != null) {
                                setStateDialog(() => oneTimeDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_rounded,
                                size: 14),
                            label: Text(
                              DateFormat('EEE, MMM d').format(oneTimeDate),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setStateDialog(() => selectedTime = picked);
                            }
                          },
                          icon: const Icon(Icons.schedule_rounded, size: 15),
                          label: Text(
                            'Depart ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Reminder Notification Lead Time',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...DepartureEvent.quickLeadMinuteOptions.map((mins) {
                        final selected = !customLeadMode && leadMinutes == mins;
                        return ChoiceChip(
                          selected: selected,
                          selectedColor: kScoutAmber.withValues(alpha: 0.25),
                          label: Text(
                            mins == 0 ? 'At time' : '${mins}m before',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onSelected: (_) {
                            setStateDialog(() {
                              customLeadMode = false;
                              leadMinutes = mins;
                              customLeadCtrl.text = mins.toString();
                            });
                          },
                        );
                      }),
                      ChoiceChip(
                        selected: customLeadMode,
                        selectedColor: kScoutAmber.withValues(alpha: 0.25),
                        label: const Text('Custom',
                            style: TextStyle(fontSize: 11)),
                        onSelected: (_) =>
                            setStateDialog(() => customLeadMode = true),
                      ),
                    ],
                  ),
                  if (customLeadMode) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customLeadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutes before departure (0–180)',
                        isDense: true,
                      ),
                      onChanged: (txt) {
                        final parsed = int.tryParse(txt.trim());
                        if (parsed != null) {
                          setStateDialog(() {
                            leadMinutes = parsed.clamp(0, 180);
                          });
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kScoutBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded,
                            size: 16, color: kScoutBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            leadMinutes == 0
                                ? 'Scout notifies right at ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'
                                : 'Scout pushes heads-up at $notifyStr (${leadMinutes}m before)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (existing == null &&
                      linkCalendarEvent == null &&
                      calProvider != null &&
                      recurrence == DepartureRecurrenceType.oneTime) ...[
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Also add to Calendar Events',
                          style: TextStyle(fontSize: 12)),
                      value: alsoAddToCalendar,
                      onChanged: (v) => setStateDialog(
                          () => alsoAddToCalendar = v ?? false),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;

                var linkedCalId =
                    existing?.linkedCalendarEventId ?? linkCalendarEvent?.id;
                if (existing == null &&
                    linkCalendarEvent == null &&
                    alsoAddToCalendar &&
                    calProvider != null &&
                    recurrence == DepartureRecurrenceType.oneTime) {
                  linkedCalId = const Uuid().v4();
                  await calProvider.addEvent(
                    CalendarEvent(
                      id: linkedCalId,
                      title: title,
                      date: oneTimeDate,
                      startTime: selectedTime,
                      hasReminder: true,
                      beforeYouGoPresetId: presetId,
                      departureLeadMinutes: leadMinutes,
                      category:
                          AlarmCategory.fromType(AlarmCategoryType.personal),
                      createdAt: DateTime.now(),
                    ),
                  );
                } else if (linkCalendarEvent != null && calProvider != null) {
                  await calProvider.updateEvent(
                    linkCalendarEvent.copyWith(
                      beforeYouGoPresetId: presetId,
                      departureLeadMinutes: leadMinutes,
                      hasReminder: true,
                    ),
                  );
                }

                DepartureEvent saved;
                if (existing != null) {
                  saved = existing.copyWith(
                    title: title,
                    presetId: presetId,
                    hour: selectedTime.hour,
                    minute: selectedTime.minute,
                    recurrence: recurrence,
                    selectedDays: selectedDays,
                    oneTimeDate: recurrence == DepartureRecurrenceType.oneTime
                        ? oneTimeDate
                        : null,
                    clearOneTimeDate:
                        recurrence != DepartureRecurrenceType.oneTime,
                    leadMinutes: leadMinutes,
                  );
                  await provider.updateDepartureEvent(saved);
                } else {
                  saved = await provider.addDepartureEvent(
                    title: title,
                    presetId: presetId,
                    hour: selectedTime.hour,
                    minute: selectedTime.minute,
                    recurrence: recurrence,
                    selectedDays: selectedDays,
                    oneTimeDate: recurrence == DepartureRecurrenceType.oneTime
                        ? oneTimeDate
                        : null,
                    leadMinutes: leadMinutes,
                    linkedCalendarEventId: linkedCalId,
                  );
                }
                if (ctx.mounted) Navigator.of(ctx).pop(saved);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kScoutBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Schedule'),
            ),
          ],
        );
      },
    ),
  );
}
