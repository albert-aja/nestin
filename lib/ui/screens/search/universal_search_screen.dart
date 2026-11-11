import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/note_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/collection_provider.dart';
import '../../../providers/alarm_provider.dart';

class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final calendarProvider = Provider.of<CalendarProvider>(context);
    final journalProvider = Provider.of<JournalProvider>(context);
    final collectionProvider = Provider.of<CollectionProvider>(context);
    final alarmProvider = Provider.of<AlarmProvider>(context);

    final q = _query.toLowerCase().trim();

    final matchingNotes = q.isEmpty
        ? []
        : noteProvider.notes
            .where((n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q))
            .toList();

    final matchingTasks = q.isEmpty
        ? []
        : taskProvider.tasks
            .where((t) => t.title.toLowerCase().contains(q) || t.notes.toLowerCase().contains(q))
            .toList();

    final matchingEvents = q.isEmpty
        ? []
        : calendarProvider.events
            .where((e) => e.title.toLowerCase().contains(q) || e.description.toLowerCase().contains(q))
            .toList();

    final matchingJournal = q.isEmpty
        ? []
        : journalProvider.journalEntries
            .where((j) => j.title.toLowerCase().contains(q) || j.content.toLowerCase().contains(q))
            .toList();

    final matchingWishlist = q.isEmpty
        ? []
        : collectionProvider.wishlist
            .where((w) => w.title.toLowerCase().contains(q) || w.description.toLowerCase().contains(q))
            .toList();

    final matchingAlarms = q.isEmpty
        ? []
        : alarmProvider.alarms
            .where((a) => a.title.toLowerCase().contains(q) || a.description.toLowerCase().contains(q))
            .toList();

    final totalCount = matchingNotes.length +
        matchingTasks.length +
        matchingEvents.length +
        matchingJournal.length +
        matchingWishlist.length +
        matchingAlarms.length;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search notes, tasks, events, journal...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (val) => setState(() => _query = val),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: q.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 56, color: Color(0xFF8E929E)),
                  SizedBox(height: 12),
                  Text(
                    'Universal Search',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Search across notes, tasks, events, journal & alarms',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8E929E)),
                  ),
                ],
              ),
            )
          : totalCount == 0
              ? const Center(
                  child: Text(
                    'No matching records found',
                    style: TextStyle(color: Color(0xFF8E929E)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (matchingNotes.isNotEmpty) ...[
                      _buildHeader('Notes', matchingNotes.length, AppColors.accent),
                      ...matchingNotes.map((n) => _buildResultTile(
                            title: n.title.isEmpty ? 'Untitled Note' : n.title,
                            subtitle: n.content,
                            icon: Icons.description_outlined,
                            color: AppColors.accent,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingTasks.isNotEmpty) ...[
                      _buildHeader('Tasks', matchingTasks.length, AppColors.catWork),
                      ...matchingTasks.map((t) => _buildResultTile(
                            title: t.title,
                            subtitle: t.isCompleted ? 'Completed' : 'Pending',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.catWork,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingEvents.isNotEmpty) ...[
                      _buildHeader('Calendar Events', matchingEvents.length, AppColors.primaryLight),
                      ...matchingEvents.map((e) => _buildResultTile(
                            title: e.title,
                            subtitle: e.formattedTime(),
                            icon: Icons.event_rounded,
                            color: AppColors.primaryLight,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingJournal.isNotEmpty) ...[
                      _buildHeader('Journal Entries', matchingJournal.length, AppColors.catPersonal),
                      ...matchingJournal.map((j) => _buildResultTile(
                            title: j.title.isEmpty ? 'Journal Entry' : j.title,
                            subtitle: j.content,
                            icon: Icons.book_outlined,
                            color: AppColors.catPersonal,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingWishlist.isNotEmpty) ...[
                      _buildHeader('Wishlist', matchingWishlist.length, AppColors.catHealth),
                      ...matchingWishlist.map((w) => _buildResultTile(
                            title: w.title,
                            subtitle: w.formattedPrice(),
                            icon: Icons.card_giftcard_rounded,
                            color: AppColors.catHealth,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (matchingAlarms.isNotEmpty) ...[
                      _buildHeader('Alarms', matchingAlarms.length, AppColors.primary),
                      ...matchingAlarms.map((a) => _buildResultTile(
                            title: a.title,
                            subtitle: a.formattedTime(),
                            icon: Icons.alarm_rounded,
                            color: AppColors.primary,
                          )),
                    ],
                  ],
                ),
    );
  }

  Widget _buildHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8E929E)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

