import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../alarms/alarms_list_screen.dart';
import '../reminders/reminders_list_screen.dart';
import '../timers/timers_screen.dart';
import 'calendar_screen.dart';
import 'tasks_screen.dart';
import 'routines_screen.dart';

class TimeHubScreen extends StatelessWidget {
  final int initialTabIndex;

  const TimeHubScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Time & Planning'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: Color(0xFF8E929E),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.alarm_rounded, size: 18), text: 'Alarms'),
              Tab(icon: Icon(Icons.task_alt_rounded, size: 18), text: 'Reminders'),
              Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Calendar'),
              Tab(icon: Icon(Icons.checklist_rounded, size: 18), text: 'Tasks'),
              Tab(icon: Icon(Icons.repeat_rounded, size: 18), text: 'Routines'),
              Tab(icon: Icon(Icons.timer_outlined, size: 18), text: 'Timers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AlarmsListScreen(),
            RemindersListScreen(),
            CalendarScreen(),
            TasksScreen(),
            RoutinesScreen(),
            TimersScreen(),
          ],
        ),
      ),
    );
  }
}

