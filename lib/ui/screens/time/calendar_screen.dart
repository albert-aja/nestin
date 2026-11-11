import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/calendar_event.dart';
import '../../../data/models/alarm_category.dart';
import '../../../providers/calendar_provider.dart';
import '../../../domain/nlp/natural_language_date_parser.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/nlp_date_detector_chip.dart';

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
                          Provider.of<CalendarProvider>(context, listen: false).addEvent(
                            CalendarEvent(
                              id: const Uuid().v4(),
                              title: t,
                              description: descController.text.trim(),
                              location: locController.text.trim().isNotEmpty
                                  ? locController.text.trim()
                                  : null,
                              date: eventDate,
                              startTime: startTime,
                              category: category,
                              createdAt: DateTime.now(),
                            ),
                          );
                          Navigator.of(context).pop();
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
    final dayEvents = calendarProvider.eventsForDate(_selectedDate);

    return Scaffold(
      body: Column(
        children: [
          // Date Ribbon (Current 14 days horizontal scroll)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFF141519),
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
                          color: isSelected ? AppColors.primary : const Color(0xFF1E2028),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : const Color(0xFF2C2F3A),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('EEE').format(date).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF8E929E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : const Color(0xFFE2E4E9),
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
                      DateFormat('EEEE, MMMM d').format(_selectedDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${dayEvents.length} scheduled ${dayEvents.length == 1 ? 'event' : 'events'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8E929E)),
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded, size: 48, color: Color(0xFF8E929E)),
                        SizedBox(height: 12),
                        Text(
                          'No events for this date',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap + to schedule a meeting, activity or plan',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8E929E)),
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
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.accent,
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
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8E929E),
                                        ),
                                      ),
                                    ],
                                    if (event.location != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF8E929E)),
                                          const SizedBox(width: 4),
                                          Text(
                                            event.location!,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF8E929E)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF8E929E)),
                                onPressed: () => calendarProvider.deleteEvent(event.id),
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

