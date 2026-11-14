import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/models/calendar_event.dart';
import '../../../data/models/alarm_category.dart';
import '../../../data/models/before_you_go.dart';
import '../../../data/models/entity_link.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/before_you_go_provider.dart';
import '../../../providers/cross_module_link_provider.dart';
import '../../../domain/nlp/natural_language_date_parser.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/nlp_date_detector_chip.dart';
import '../../widgets/before_you_go_sheet.dart';
import '../../widgets/linked_entities_section.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locController = TextEditingController();
    DateTime eventDate = _selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    AlarmCategory category = AlarmCategory.fromType(AlarmCategoryType.work);
    ParsedDateResult? parsedNlp;

    BeforeYouGoProvider? bygProvider;
    try {
      bygProvider = Provider.of<BeforeYouGoProvider>(context, listen: false);
    } catch (_) {}
    var attachBeforeYouGo = false;
    var selectedPresetId =
        bygProvider?.activePresetId ?? DeparturePreset.everydayPresetId;
    var selectedLeadMinutes = 15;
    var customLeadMode = false;
    final customLeadCtrl = TextEditingController(text: '15');

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
                        const Text(
                          'New Calendar Event',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'e.g. Sync with team tomorrow at 3pm',
                        prefixIcon: Icon(Icons.event_rounded),
                      ),
                      onChanged: (text) {
                        final res = NaturalLanguageDateParser.parse(text);
                        if (res.hasMatch) {
                          setSheetState(() {
                            parsedNlp = res;
                            if (res.date != null) eventDate = res.date!;
                            if (res.time != null) startTime = res.time!;
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: eventDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                              );
                              if (picked != null) {
                                setSheetState(() => eventDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_rounded, size: 14),
                            label: Text(
                              DateFormat('EEE, MMM d').format(eventDate),
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
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setSheetState(() => startTime = picked);
                              }
                            },
                            icon: const Icon(Icons.schedule_rounded, size: 14),
                            label: Text(
                              startTime.format(context),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description / Notes',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locController,
                      decoration: const InputDecoration(
                        labelText: 'Location / Link (Optional)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
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
                    if (bygProvider != null) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: AppColors.cardSurface(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: attachBeforeYouGo
                                ? kScoutBlue.withValues(alpha: 0.5)
                                : AppColors.border(context),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text(
                                'Scout BeforeYouGo Heads-Up',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                'Push notification before leaving with essentials checklist',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                              value: attachBeforeYouGo,
                              activeThumbColor: kScoutBlue,
                              onChanged: (v) =>
                                  setSheetState(() => attachBeforeYouGo = v),
                            ),
                            if (attachBeforeYouGo) ...[
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: selectedPresetId,
                                decoration: const InputDecoration(
                                  labelText: 'Checklist Preset',
                                  isDense: true,
                                ),
                                items: bygProvider.presets
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p.id,
                                        child: Text(
                                          '${p.name} (${p.totalCount} items)',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setSheetState(() => selectedPresetId = v);
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...[0, 10, 15, 30, 45, 60].map((m) {
                                    final isSel =
                                        !customLeadMode && selectedLeadMinutes == m;
                                    return ChoiceChip(
                                      selected: isSel,
                                      selectedColor:
                                          kScoutAmber.withValues(alpha: 0.25),
                                      label: Text(
                                        m == 0 ? 'At time' : '${m}m before',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onSelected: (_) {
                                        setSheetState(() {
                                          customLeadMode = false;
                                          selectedLeadMinutes = m;
                                          customLeadCtrl.text = m.toString();
                                        });
                                      },
                                    );
                                  }),
                                  ChoiceChip(
                                    selected: customLeadMode,
                                    selectedColor:
                                        kScoutAmber.withValues(alpha: 0.25),
                                    label: const Text('Custom',
                                        style: TextStyle(fontSize: 11)),
                                    onSelected: (_) =>
                                        setSheetState(() => customLeadMode = true),
                                  ),
                                ],
                              ),
                              if (customLeadMode) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: customLeadCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Minutes before event (0–180)',
                                    isDense: true,
                                  ),
                                  onChanged: (txt) {
                                    final parsed = int.tryParse(txt.trim());
                                    if (parsed != null) {
                                      setSheetState(() {
                                        selectedLeadMinutes =
                                            parsed.clamp(0, 180);
                                      });
                                    }
                                  },
                                ),
                              ],
                            ],
                          ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        var t = titleController.text.trim();
                        if (t.isNotEmpty) {
                          if (parsedNlp != null &&
                              parsedNlp!.hasMatch &&
                              t == parsedNlp!.originalText) {
                            t = parsedNlp!.cleanTitle;
                          }
                          final calEvent = CalendarEvent(
                            id: const Uuid().v4(),
                            title: t,
                            description: descController.text.trim(),
                            location: locController.text.trim().isNotEmpty
                                ? locController.text.trim()
                                : null,
                            date: eventDate,
                            startTime: startTime,
                            hasReminder: attachBeforeYouGo,
                            beforeYouGoPresetId:
                                attachBeforeYouGo ? selectedPresetId : null,
                            departureLeadMinutes:
                                attachBeforeYouGo ? selectedLeadMinutes : null,
                            category: category,
                            createdAt: DateTime.now(),
                          );
                          await Provider.of<CalendarProvider>(context,
                                  listen: false)
                              .addEvent(calEvent);
                          if (attachBeforeYouGo && bygProvider != null) {
                            await bygProvider.upsertFromCalendarEvent(
                              calEvent,
                              presetId: selectedPresetId,
                              leadMinutes: selectedLeadMinutes,
                            );
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Save Event',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
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
    final calendarProvider = Provider.of<CalendarProvider>(context);
    BeforeYouGoProvider? bygProvider;
    try {
      bygProvider = Provider.of<BeforeYouGoProvider>(context);
    } catch (_) {}
    final dayEvents = calendarProvider.eventsForDate(_selectedDate);

    return Scaffold(
      body: Column(
        children: [
          // Date Ribbon (Current 14 days horizontal scroll)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.recessedSurface(context),
            child: SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 14,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index - 2));
                  final isSelected = date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;
                  final dayEventsCount = calendarProvider.eventsForDate(date).length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => setState(() => _selectedDate = date),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 54,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.cardSurface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border(context),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.formatDate(date, 'EEE').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                            if (dayEventsCount > 0)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Selected Day Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.formatDate(_selectedDate, 'EEEE, MMMM d'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      context.l10n.pick(
                        '${dayEvents.length} scheduled ${dayEvents.length == 1 ? 'event' : 'events'}',
                        '${dayEvents.length} acara terjadwal',
                      ),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _showAddEventDialog,
                ),
              ],
            ),
          ),

          // Events List
          Expanded(
            child: dayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded, size: 48, color: AppColors.textSecondary(context)),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.pick(
                            'No events for this date',
                            'Tidak ada acara pada tanggal ini',
                          ),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.pick(
                            'Tap + to schedule a meeting, activity or plan',
                            'Ketuk + untuk menjadwalkan rapat, aktivitas, atau rencana',
                          ),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: dayEvents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = dayEvents[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: event.category.color.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(event.category.icon, color: event.category.color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CategoryBadge(category: event.category, compact: true),
                                        const SizedBox(width: 8),
                                        Text(
                                          event.formattedTime(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.adaptive(
                                              context,
                                              dark: AppColors.accent,
                                              light: const Color(0xFFC26A00),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      event.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (event.description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        event.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                    if (event.location != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary(context)),
                                          const SizedBox(width: 4),
                                          Text(
                                            event.location!,
                                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (event.hasDepartureHeadsUp) ...[
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: bygProvider == null
                                            ? null
                                            : () => BeforeYouGoSheet.show(
                                                  context,
                                                  initialPresetId:
                                                      event.beforeYouGoPresetId,
                                                ),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: kScoutBlue.withValues(
                                                alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.door_front_door_outlined,
                                                size: 12,
                                                color: kScoutBlue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'BeforeYouGo • ${event.departureLeadMinutes ?? 15}m heads-up',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: kScoutBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (bygProvider != null &&
                                  event.startTime != null)
                                IconButton(
                                  tooltip: event.hasDepartureHeadsUp
                                      ? 'Edit BeforeYouGo Heads-Up'
                                      : 'Add BeforeYouGo Heads-Up',
                                  icon: Icon(
                                    Icons.door_front_door_outlined,
                                    size: 18,
                                    color: event.hasDepartureHeadsUp
                                        ? kScoutBlue
                                        : AppColors.textSecondary(context),
                                  ),
                                  onPressed: () {
                                    final existingDep = bygProvider!
                                        .findEventByLinkedCalendarId(event.id);
                                    showDepartureEventEditorDialog(
                                      context,
                                      existing: existingDep,
                                      linkCalendarEvent: event,
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Linked Items',
                                  icon: const Icon(
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
                                            entityType:
                                                LinkEntityType.calendarEvent,
                                            entityId: event.id,
                                            entityTitle: event.title,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.textSecondary(context)),
                                onPressed: () {
                                  try {
                                    Provider.of<CrossModuleLinkProvider>(
                                      context,
                                      listen: false,
                                    ).removeAllLinksFor(
                                      LinkEntityType.calendarEvent,
                                      event.id,
                                    );
                                  } catch (_) {}
                                  bygProvider?.removeByLinkedCalendarEventId(
                                      event.id);
                                  calendarProvider.deleteEvent(event.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

