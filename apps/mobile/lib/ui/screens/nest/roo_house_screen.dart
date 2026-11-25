import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alarm.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/task_provider.dart';
import '../alarms/alarm_edit_screen.dart';
import '../alarms/alarms_list_screen.dart';
import '../discipline/digital_discipline_screen.dart';
import '../reminders/reminders_list_screen.dart';
import '../time/calendar_screen.dart';
import '../time/routines_screen.dart';
import '../time/tasks_screen.dart';
import '../timers/timers_screen.dart';
import 'bird_house_shared.dart';

/// Roo's House — Time, Planning, Habits & Digital Discipline (`#E04A3A`).
class RooHouseScreen extends StatelessWidget {
  static const Color rooColor = AppColors.rooCrimson;

  const RooHouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final alarmProvider = tryWatchProvider<AlarmProvider>(context);
    final taskProvider = tryWatchProvider<TaskProvider>(context);
    final routineProvider = tryWatchProvider<RoutineProvider>(context);
    final calendarProvider = tryWatchProvider<CalendarProvider>(context);
    final reminderProvider = tryWatchProvider<ReminderProvider>(context);
    final settingsProvider = tryWatchProvider<SettingsProvider>(context);

    final now = DateTime.now();
    final nextAlarm = alarmProvider?.nextUpcomingAlarm;
    final activeAlarms =
        alarmProvider?.alarms.where((a) => a.isEnabled).length ?? 0;
    final todayTasksCount = taskProvider?.tasksDueToday(now).length ?? 0;
    final routinesCount = routineProvider?.routines.length ?? 0;
    final todayEventsCount = calendarProvider?.eventsForDate(now).length ?? 0;
    final pendingRemindersCount =
        reminderProvider?.pendingReminders.length ?? 0;

    return Scaffold(
      key: const Key('roo_house_screen'),
      appBar: buildBirdHouseAppBar(
        context,
        title: l10n.tr('house_roo_title'),
        subtitle: l10n.tr('nest_roo_subtitle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildNextAlarmHero(
            context,
            l10n: l10n,
            alarm: nextAlarm,
            now: now,
            use24Hour: settingsProvider?.use24Hour ?? true,
            alarmProvider: alarmProvider,
          ),
          const SizedBox(height: 20),
          BirdSectionLabel(
            text: l10n.tr('house_tools_section'),
            accentColor: rooColor,
          ),
          BirdToolGrid(
            tiles: [
              BirdToolTile(
                tileKey: const Key('roo_tool_alarms'),
                title: l10n.tr('tab_alarms'),
                subtitle: l10n.tr(
                  'house_roo_alarms_sub',
                  {'count': activeAlarms},
                ),
                icon: Icons.alarm_rounded,
                accentColor: rooColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AlarmsListScreen(),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('roo_tool_tasks_routines'),
                title: l10n.tr('house_roo_tasks_routines'),
                subtitle: l10n.tr(
                  'house_roo_tasks_routines_sub',
                  {'tasks': todayTasksCount, 'routines': routinesCount},
                ),
                icon: Icons.checklist_rounded,
                accentColor: AppColors.orangeDark,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BirdTwoTabPageScaffold(
                      title: l10n.tr('house_roo_tasks_routines'),
                      accentColor: rooColor,
                      firstLabel: l10n.tr('tab_tasks'),
                      firstIcon: Icons.checklist_rounded,
                      firstChild: const TasksScreen(),
                      secondLabel: l10n.tr('tab_routines'),
                      secondIcon: Icons.repeat_rounded,
                      secondChild: const RoutinesScreen(),
                    ),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('roo_tool_calendar'),
                title: l10n.tr('tab_calendar'),
                subtitle: l10n.tr(
                  'house_roo_calendar_sub',
                  {'count': todayEventsCount},
                ),
                icon: Icons.calendar_month_rounded,
                accentColor: AppColors.catWork,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BirdToolPageScaffold(
                      title: l10n.tr('tab_calendar'),
                      child: const CalendarScreen(),
                    ),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('roo_tool_reminders'),
                title: l10n.tr('tab_reminders'),
                subtitle: l10n.tr(
                  'house_roo_reminders_sub',
                  {'count': pendingRemindersCount},
                ),
                icon: Icons.notifications_active_outlined,
                accentColor: AppColors.accent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RemindersListScreen(),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('roo_tool_timers'),
                title: l10n.tr('house_roo_timers_title'),
                subtitle: l10n.tr('house_roo_timers_sub'),
                icon: Icons.timer_outlined,
                accentColor: AppColors.orange,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TimersScreen(),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('roo_tool_discipline'),
                title: l10n.tr('house_roo_discipline_title'),
                subtitle: l10n.tr('house_roo_discipline_sub'),
                icon: Icons.phonelink_lock_rounded,
                accentColor: rooColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DigitalDisciplineScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextAlarmHero(
    BuildContext context, {
    required AppLocalizations l10n,
    required Alarm? alarm,
    required DateTime now,
    required bool use24Hour,
    required AlarmProvider? alarmProvider,
  }) {
    final isDark = AppColors.isDark(context);

    return Container(
      key: const Key('roo_house_hero_card'),
      padding: const EdgeInsets.all(18),
      decoration: birdHouseCardDecoration(
        context,
        heroTintColor: rooColor,
        radius: 22,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BirdStatusPill(
                      pillKey: const Key('roo_hero_next_alarm_pill'),
                      label: l10n.tr('house_roo_hero_label'),
                      dotColor: rooColor,
                    ),
                    if (alarm != null)
                      BirdStatusPill(
                        pillKey: const Key('roo_hero_category_pill'),
                        label: l10n.categoryName(alarm.category.type),
                        dotColor: alarm.category.color,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (alarm != null) ...[
                  Text(
                    alarm.formattedTime(use24Hour: use24Hour),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      color: AppColors.textPrimary(context),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${alarm.title} • ${alarm.timeUntilNext(now)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ] else ...[
                  Text(
                    l10n.tr('no_upcoming_alarms_set'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tr('set_an_alarm_to_keep_your'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('roo_hero_add_alarm_btn'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AlarmEditScreen(),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: rooColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.add_alarm_rounded, size: 16),
                      label: Text(
                        l10n.tr('add_alarm'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (alarm != null && alarmProvider != null)
                      TextButton.icon(
                        key: const Key('roo_hero_test_ring_btn'),
                        onPressed: () => alarmProvider.triggerAlarm(alarm),
                        style: TextButton.styleFrom(
                          backgroundColor: rooColor.withValues(
                            alpha: isDark ? 0.16 : 0.12,
                          ),
                          foregroundColor: AppColors.textPrimary(context),
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        icon: const Icon(
                          Icons.play_arrow_rounded,
                          size: 16,
                          color: rooColor,
                        ),
                        label: Text(
                          l10n.tr('test_ring'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          BirdHeroSpriteHalo(
            assetPath: alarm != null
                ? 'assets/mascots/sprites/roo/alarm.png'
                : 'assets/mascots/sprites/roo/quiet_day.png',
            accentColor: rooColor,
            fallbackIcon: Icons.alarm_rounded,
            size: 84,
          ),
        ],
      ),
    );
  }
}
