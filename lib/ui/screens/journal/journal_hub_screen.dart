import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'diary_entries_screen.dart';
import 'timeline_screen.dart';
import 'memories_screen.dart';

class JournalHubScreen extends StatelessWidget {
  final int initialTabIndex;

  const JournalHubScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Journal & Memories'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: Color(0xFF8E929E),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.book_outlined, size: 18), text: 'Diary'),
              Tab(icon: Icon(Icons.timeline_rounded, size: 18), text: 'Timeline'),
              Tab(icon: Icon(Icons.star_outline_rounded, size: 18), text: 'Memories'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DiaryEntriesScreen(),
            TimelineScreen(),
            MemoriesScreen(),
          ],
        ),
      ),
    );
  }
}

