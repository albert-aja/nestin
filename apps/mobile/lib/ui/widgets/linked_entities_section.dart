import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/entity_link.dart';
import '../../providers/automation_provider.dart';
import '../../providers/before_you_go_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/cross_module_link_provider.dart';
import '../../providers/hobby_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/medication_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/reading_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/task_provider.dart';

class _LinkCandidate {
  final LinkEntityType type;
  final String id;
  final String title;

  const _LinkCandidate({
    required this.type,
    required this.id,
    required this.title,
  });
}

/// Embeddable cross-module linking bar ("Link Everything") usable inside any
/// Task, Calendar Event, Note, Reminder, Journal Entry, Hobby, or Checklist sheet.
class LinkedEntitiesSection extends StatelessWidget {
  final LinkEntityType entityType;
  final String entityId;
  final String entityTitle;

  const LinkedEntitiesSection({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
  });

  @override
  Widget build(BuildContext context) {
    CrossModuleLinkProvider? linkProvider;
    try {
      linkProvider = Provider.of<CrossModuleLinkProvider>(context);
    } catch (_) {
      return const SizedBox.shrink();
    }

    final links = linkProvider.linksFor(entityType, entityId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, size: 16, color: AppColors.info),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Connected Nestin Items',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                icon: const Icon(Icons.add_link_rounded, size: 16),
                label: const Text('Link Item', style: TextStyle(fontSize: 12)),
                onPressed: () => _openLinkPicker(context, linkProvider!),
              ),
            ],
          ),
          if (links.isEmpty)
            Text(
              'Link notes, events, tasks, journal entries, hobbies, medications, or automations without duplicating them.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: links.map((ref) {
                return InputChip(
                  avatar: Icon(_iconForType(ref.entityType), size: 14),
                  label: Text(
                    '${ref.entityType.familyLabel} · ${ref.title}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onDeleted: () => linkProvider!.removeLink(ref.linkId),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _openLinkPicker(
    BuildContext context,
    CrossModuleLinkProvider linkProvider,
  ) {
    final candidates = _gatherCandidates(context);
    var filterType = LinkEntityType.task;
    LinkEntityType? selectedFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final visible = candidates.where((c) {
            if (c.type == entityType && c.id == entityId) return false;
            if (selectedFilter != null && c.type != selectedFilter) {
              return false;
            }
            return true;
          }).toList();

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.72,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Link "$entityTitle" to...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: selectedFilter == null,
                          onSelected: (_) =>
                              setSheetState(() => selectedFilter = null),
                        ),
                        const SizedBox(width: 6),
                        ...LinkEntityType.values.map((t) {
                          filterType = t;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(filterType.label),
                              selected: selectedFilter == t,
                              onSelected: (_) =>
                                  setSheetState(() => selectedFilter = t),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: visible.isEmpty
                        ? Center(
                            child: Text(
                              'No linkable items available yet in this category.',
                              style: TextStyle(
                                color: AppColors.textSecondary(ctx),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (_, index) {
                              final c = visible[index];
                              return ListTile(
                                leading: Icon(_iconForType(c.type)),
                                title: Text(c.title),
                                subtitle: Text(
                                  '${c.type.familyLabel} · ${c.type.label}',
                                ),
                                onTap: () async {
                                  await linkProvider.addLink(
                                    sourceType: entityType,
                                    sourceId: entityId,
                                    sourceTitle: entityTitle,
                                    targetType: c.type,
                                    targetId: c.id,
                                    targetTitle: c.title,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_LinkCandidate> _gatherCandidates(BuildContext context) {
    final out = <_LinkCandidate>[];

    T? safeRead<T>() {
      try {
        return Provider.of<T>(context, listen: false);
      } catch (_) {
        return null;
      }
    }

    final calendar = safeRead<CalendarProvider>();
    if (calendar != null) {
      for (final e in calendar.events) {
        out.add(_LinkCandidate(
          type: LinkEntityType.calendarEvent,
          id: e.id,
          title: e.title,
        ));
      }
    }

    final tasks = safeRead<TaskProvider>();
    if (tasks != null) {
      for (final t in tasks.tasks) {
        out.add(_LinkCandidate(
          type: LinkEntityType.task,
          id: t.id,
          title: t.title,
        ));
      }
    }

    final notes = safeRead<NoteProvider>();
    if (notes != null) {
      for (final n in notes.notes) {
        out.add(_LinkCandidate(
          type: LinkEntityType.note,
          id: n.id,
          title: n.title.isEmpty ? 'Untitled Note' : n.title,
        ));
      }
    }

    final reminders = safeRead<ReminderProvider>();
    if (reminders != null) {
      for (final r in reminders.reminders) {
        out.add(_LinkCandidate(
          type: LinkEntityType.reminder,
          id: r.id,
          title: r.title,
        ));
      }
    }

    final journal = safeRead<JournalProvider>();
    if (journal != null) {
      for (final j in journal.journalEntries) {
        out.add(_LinkCandidate(
          type: LinkEntityType.journalEntry,
          id: j.id,
          title: j.title.isEmpty ? 'Journal Entry' : j.title,
        ));
      }
      for (final m in journal.memories) {
        out.add(_LinkCandidate(
          type: LinkEntityType.memory,
          id: m.id,
          title: m.title,
        ));
      }
    }

    final meds = safeRead<MedicationProvider>();
    if (meds != null) {
      for (final m in meds.medications) {
        out.add(_LinkCandidate(
          type: LinkEntityType.medication,
          id: m.id,
          title: m.name,
        ));
      }
    }

    final hobbies = safeRead<HobbyProvider>();
    if (hobbies != null) {
      for (final h in hobbies.hobbies) {
        out.add(_LinkCandidate(
          type: LinkEntityType.hobby,
          id: h.id,
          title: h.name,
        ));
      }
    }

    final reading = safeRead<ReadingProvider>();
    if (reading != null) {
      for (final b in reading.items) {
        out.add(_LinkCandidate(
          type: LinkEntityType.readingBook,
          id: b.id,
          title: b.title,
        ));
      }
    }

    final byg = safeRead<BeforeYouGoProvider>();
    if (byg != null) {
      for (final p in byg.presets) {
        out.add(_LinkCandidate(
          type: LinkEntityType.beforeYouGoPreset,
          id: p.id,
          title: p.name,
        ));
      }
    }

    final auto = safeRead<AutomationProvider>();
    if (auto != null) {
      for (final r in auto.rules) {
        out.add(_LinkCandidate(
          type: LinkEntityType.automationRule,
          id: r.id,
          title: r.name,
        ));
      }
    }

    return out;
  }

  IconData _iconForType(LinkEntityType type) {
    switch (type) {
      case LinkEntityType.calendarEvent:
        return Icons.event_rounded;
      case LinkEntityType.task:
        return Icons.check_circle_outline_rounded;
      case LinkEntityType.note:
        return Icons.sticky_note_2_outlined;
      case LinkEntityType.reminder:
        return Icons.notifications_active_outlined;
      case LinkEntityType.journalEntry:
        return Icons.book_outlined;
      case LinkEntityType.memory:
        return Icons.photo_album_outlined;
      case LinkEntityType.hobby:
        return Icons.palette_outlined;
      case LinkEntityType.readingBook:
        return Icons.menu_book_rounded;
      case LinkEntityType.medication:
        return Icons.medication_outlined;
      case LinkEntityType.beforeYouGoPreset:
        return Icons.backpack_outlined;
      case LinkEntityType.automationRule:
        return Icons.auto_awesome_rounded;
    }
  }
}
