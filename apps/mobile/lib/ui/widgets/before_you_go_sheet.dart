import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/alarm_category.dart';
import '../../data/models/before_you_go.dart';
import '../../data/models/calendar_event.dart';
import '../../providers/before_you_go_provider.dart';
import '../../providers/calendar_provider.dart';
import 'before_you_go_weather_banner.dart';

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
    final l10n = context.l10n;
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
                l10n.tr('heads_up_notifications_support_android_shade'),
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
                                  ? l10n.tr('next_3', {'nextDeparture_title': nextDeparture.title, 'nextDeparture_formattedDepartureTime': nextDeparture.formattedDepartureTime, 'nextDeparture_leadLabel': nextDeparture.leadLabel})
                                  : l10n.tr('custom_checklists_smart_departure_heads_up'),
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
                        tooltip: l10n.tr('new_departure_trip'),
                        icon: const Icon(Icons.add_alarm_rounded,
                            color: kScoutBlue),
                        onPressed: () => showDepartureEventEditorDialog(
                          context,
                          initialPresetId: provider.activePresetId,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.tr('close'),
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
                      text: l10n.tr('checklists', {'provider_checkedCount': provider.activePreset.checkedCount, 'provider_totalCount': provider.activePreset.totalCount}),
                    ),
                    Tab(
                      text: l10n.tr('schedules', {'provider_length': provider.events.length}),
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
    final l10n = context.l10n;
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
                label: Text(l10n.tr('new_preset'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
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
                        l10n.tr('packed', {'preset_name': preset.name, 'preset_checkedCount': preset.checkedCount, 'preset_totalCount': preset.totalCount}),
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
                        label: Text(
                          l10n.tr('mark_all_ready'),
                          style: const TextStyle(
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
                      label: Text(l10n.tr('reset_2'),
                          style: const TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.tr('edit_preset'),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => showDeparturePresetDialog(
                        context,
                        existing: preset,
                      ),
                    ),
                    if (provider.presets.length > 1)
                      IconButton(
                        tooltip: l10n.tr('delete_preset'),
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

        // Weather-Aware Checklist Item Prompts (LocalWeatherService)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
          child: BeforeYouGoWeatherBanner(
            provider: provider,
            compact: false,
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
                    hintText: l10n.tr('add_item_to', {'preset_name': preset.name}),
                    isDense: true,
                    prefixIcon: const Icon(Icons.add_task_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: l10n.tr('mark_as_essential_featured_in_heads'),
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
                child: Text(l10n.tr('add'),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // Reorderable Persistent Checklist
        Expanded(
          child: preset.items.isEmpty
              ? Center(
                  child: Text(
                    l10n.tr('no_items_in_add_items_above', {'preset_name': preset.name}),
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
                              tooltip: l10n.tr('edit_item'),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _showEditItemDialog(context, provider, preset.id, item),
                            ),
                            IconButton(
                              tooltip: l10n.tr('delete_item'),
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
        builder: (ctx, setDialogState) {
          final l10n = ctx.l10n;
          return AlertDialog(
            backgroundColor: AppColors.cardSurface(ctx),
            title: Text(
              l10n.tr('edit_checklist_item'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.tr('item_label'),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.tr('essential_item'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    l10n.tr('prioritized_in_pre_departure_notifications'),
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: essential,
                  onChanged: (v) => setDialogState(() => essential = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.tr('cancel')),
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
                child: Text(l10n.tr('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSchedulesTab(
      BuildContext context, BeforeYouGoProvider provider) {
    final l10n = context.l10n;
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
                label: Text(l10n.tr('add_departure_schedule')),
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
                l10n.tr('heads_up_notifications_support_android_shade'),
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
                l10n.tr('heads_up_notifications_support_android_shade'),
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
                  Text(
                    l10n.tr('no_smart_departure_heads_up_yet'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.tr('schedule_a_recurring_routine_e_g'),
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
                        label: Text(l10n.tr('leaving_for_work_mon_fri_07')),
                        onPressed: () {
                          provider.addDepartureEvent(
                            title: l10n.tr('leaving_for_work'),
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
                        label: Text(l10n.tr('going_to_airport_today_16_00')),
                        onPressed: () {
                          provider.addDepartureEvent(
                            title: l10n.tr('going_to_airport'),
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
                            l10n.tr('calendar_linked'),
                            AppColors.primary,
                          ),
                        if (isSnoozed)
                          _pillChip(
                            context,
                            Icons.snooze_rounded,
                            l10n.tr('snoozed_5m', {'activeSnooze_formattedSnoozedUntil': activeSnooze.formattedSnoozedUntil, 'activeSnooze_x': activeSnooze.snoozeCount > 1 ? ' (${activeSnooze.snoozeCount}x)' : ''}),
                            kScoutAmber,
                          ),
                        if (isReadyToday)
                          _pillChip(
                            context,
                            Icons.verified_rounded,
                            l10n.tr('marked_ready_today'),
                            AppColors.success,
                          ),
                      ],
                    ),
                    if (nextNotif != null && nextDep != null && ev.isEnabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.tr('next_heads_up', {'l10n_mm': l10n.formatDate(nextNotif, 'EEE, MMM d • HH:mm')}),
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
                                      l10n.tr('snoozed_5m_until_2', {'ev_title': ev.title, 'snoozed_formattedSnoozedUntil': snoozed.formattedSnoozedUntil}),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.snooze_rounded, size: 15),
                              label: Text(l10n.tr('notif_action_snooze_5m'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          TextButton.icon(
                            onPressed: () {
                              provider.triggerTestNotification(ev.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.tr('sent_scout_beforeyougo_preview_for', {'ev_title': ev.title}),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.notifications_rounded, size: 15),
                            label: Text(
                                l10n.tr('test_alert'),
                                style: const TextStyle(fontSize: 12)),
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
                            label: Text(l10n.tr('edit_2'),
                                style: const TextStyle(fontSize: 12)),
                          ),
                          IconButton(
                            tooltip:
                                l10n.tr('delete_schedule'),
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
            l10n.tr('upcoming_calendar_events'),
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
                    '${l10n.formatDate(ce.date, 'EEE, MMM d')} • ${ce.formattedTime()}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => showDepartureEventEditorDialog(
                      context,
                      linkCalendarEvent: ce,
                      initialPresetId: provider.activePresetId,
                    ),
                    child: Text(l10n.tr('heads_up'),
                        style: const TextStyle(fontSize: 11)),
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
      builder: (ctx, setStateDialog) {
        final l10n = ctx.l10n;
        return AlertDialog(
          backgroundColor: AppColors.cardSurface(ctx),
          title: Text(
            existing == null
                ? l10n.tr('new_checklist_preset')
                : l10n.tr('edit_preset'),
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
                  decoration: InputDecoration(
                    labelText: l10n.tr('preset_name'),
                    hintText: l10n.tr('e_g_work_travel_gym_weekend'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.tr('icon'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
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
                Text(l10n.tr('color'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
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
              child: Text(l10n.tr('cancel')),
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
              child: Text(l10n.tr('save')),
            ),
          ],
        );
      },
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
        final l10n = ctx.l10n;
        final effectiveNotifyTime = DateTime(
          2026,
          1,
          2,
          selectedTime.hour,
          selectedTime.minute,
        ).subtract(Duration(minutes: leadMinutes));
        final notifyStr =
            '${effectiveNotifyTime.hour.toString().padLeft(2, '0')}:${effectiveNotifyTime.minute.toString().padLeft(2, '0')}';
        final departStr =
            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

        return AlertDialog(
          backgroundColor: AppColors.cardSurface(ctx),
          title: Text(
            existing == null
                ? l10n.tr('schedule_departure_heads_up')
                : l10n.tr('edit_departure_schedule'),
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
                    decoration: InputDecoration(
                      labelText: l10n.tr('event_title'),
                      hintText: l10n.tr('e_g_leaving_for_work_going'),
                      prefixIcon: const Icon(Icons.departure_board_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: presetId,
                    decoration: InputDecoration(
                      labelText: l10n.tr('beforeyougo_checklist_preset'),
                      prefixIcon: const Icon(Icons.checklist_rounded),
                    ),
                    items: provider.presets
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(l10n.tr('items', {'p_name': p.name, 'p_totalCount': p.totalCount})),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => presetId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.tr('schedule_repeat'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
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
                        for (final entry in {
                          1: l10n.tr('mon'),
                          2: l10n.tr('tue'),
                          3: l10n.tr('wed'),
                          4: l10n.tr('thu'),
                          5: l10n.tr('fri'),
                          6: l10n.tr('sat'),
                          7: l10n.tr('sun'),
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
                              l10n.formatDate(oneTimeDate, 'EEE, MMM d'),
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
                            l10n.tr('depart', {'departStr': departStr}),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                      l10n.tr('reminder_notification_lead_time'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
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
                            mins == 0
                                ? l10n.tr('at_time')
                                : l10n.tr('m_before', {'mins': mins}),
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
                        label: Text(l10n.tr('custom_2'),
                            style: const TextStyle(fontSize: 11)),
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
                      decoration: InputDecoration(
                        labelText: l10n.tr('minutes_before_departure_0_180'),
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
                                ? l10n.tr('scout_notifies_right_at', {'departStr': departStr})
                                : l10n.tr('scout_pushes_heads_up_at_m', {'notifyStr': notifyStr, 'leadMinutes': leadMinutes}),
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
                      title: Text(
                          l10n.tr('also_add_to_calendar_events'),
                          style: const TextStyle(fontSize: 12)),
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
              child: Text(l10n.tr('cancel')),
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
              child: Text(l10n.tr('save_schedule')),
            ),
          ],
        );
      },
    ),
  );
}
