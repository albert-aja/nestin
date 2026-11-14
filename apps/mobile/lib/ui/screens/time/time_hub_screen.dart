import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
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
    final l10n = context.l10n;
    return DefaultTabController(
      length: 6,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tr('time_hub_title')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.adaptive(
              context,
              dark: AppColors.primaryLight,
              light: AppColors.primary,
            ),
            unselectedLabelColor: AppColors.textSecondary(context),
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(icon: const Icon(Icons.alarm_rounded, size: 18), text: l10n.tr('tab_alarms')),
              Tab(icon: const Icon(Icons.task_alt_rounded, size: 18), text: l10n.tr('tab_reminders')),
              Tab(icon: const Icon(Icons.calendar_month_rounded, size: 18), text: l10n.tr('tab_calendar')),
              Tab(icon: const Icon(Icons.checklist_rounded, size: 18), text: l10n.tr('tab_tasks')),
              Tab(icon: const Icon(Icons.repeat_rounded, size: 18), text: l10n.tr('tab_routines')),
              Tab(icon: const Icon(Icons.timer_outlined, size: 18), text: l10n.tr('tab_timers')),
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

