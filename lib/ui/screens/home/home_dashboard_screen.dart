import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alarm.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../providers/timer_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/category_badge.dart';
import '../../widgets/roodoo_brand_header.dart';
import '../alarms/alarm_edit_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const HomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alarmProvider = Provider.of<AlarmProvider>(context);
    final reminderProvider = Provider.of<ReminderProvider>(context);
    final timerProvider = Provider.of<TimerProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final nextAlarm = alarmProvider.nextUpcomingAlarm;
    final activeAlarmsCount =
        alarmProvider.alarms.where((a) => a.isEnabled).length;
    final pendingReminders = reminderProvider.pendingReminders;
    final runningTimers = timerProvider.activeRunningTimers;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RooDooBrandHeader(
                subtitle: 'Every moment, right on time.',
              ),
              const SizedBox(height: 12),

              // Hero Next Alarm Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildNextAlarmHero(
                  context,
                  nextAlarm,
                  alarmProvider,
                  settingsProvider,
                ),
              ),
              const SizedBox(height: 20),

              // Overview Metric Pills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildMetricCard(
                      title: 'Alarms',
                      count: '$activeAlarmsCount Active',
                      icon: Icons.alarm_rounded,
                      color: AppColors.primary,
                      onTap: () => widget.onNavigateTab(1),
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      title: 'Reminders',
                      count: '${pendingReminders.length} Due',
                      icon: Icons.checklist_rounded,
                      color: AppColors.catWork,
                      onTap: () => widget.onNavigateTab(2),
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      title: 'Timers',
                      count: '${runningTimers.length} Running',
                      icon: Icons.timer_outlined,
                      color: AppColors.accent,
                      onTap: () => widget.onNavigateTab(3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionBtn(
                            label: '+ Alarm',
                            color: AppColors.primary,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AlarmEditScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionBtn(
                            label: '+ Reminder',
                            color: AppColors.catWork,
                            onTap: () => widget.onNavigateTab(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionBtn(
                            label: '+ Timer',
                            color: AppColors.accent,
                            onTap: () => widget.onNavigateTab(3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Upcoming Reminders Snippet
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upcoming Agenda',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigateTab(2),
                      child: const Text('View all'),
                    ),
                  ],
                ),
              ),
              if (pendingReminders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1B20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2C2F3A)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'No pending agenda items. You are all set!',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8E929E)),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount:
                        pendingReminders.length > 3 ? 3 : pendingReminders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = pendingReminders[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1B20),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2C2F3A)),
                        ),
                        child: Row(
                          children: [
                            CategoryBadge(category: item.category, compact: true),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              item.formattedDueTime(
                                use24Hour: settingsProvider.use24Hour,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8E929E),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextAlarmHero(
    BuildContext context,
    Alarm? alarm,
    AlarmProvider provider,
    SettingsProvider settingsProvider,
  ) {
    if (alarm == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1B20),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF2C2F3A)),
        ),
        child: Column(
          children: [
            const Icon(Icons.alarm_off_rounded,
                size: 38, color: Color(0xFF8E929E)),
            const SizedBox(height: 12),
            const Text(
              'No upcoming alarms set',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Set an alarm to keep your schedule punctual',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E929E)),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AlarmEditScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Add Alarm',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final challenge =
        alarm.effectiveChallenge(settingsProvider.globalChallengeProfile);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF261D22),
            Color(0xFF1B181E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBadge(category: alarm.category),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alarm.timeUntilNext(_now),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alarm.formattedTime(use24Hour: settingsProvider.use24Hour),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              color: Colors.white,
            ),
          ),
          Text(
            alarm.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE2E4E9),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (challenge.isEnabled)
                Row(
                  children: [
                    const Icon(Icons.psychology_rounded,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      '${challenge.typeLabel} Challenge Required',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'Standard dismissal',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8E929E)),
                ),
              FilledButton.tonalIcon(
                onPressed: () => provider.triggerAlarm(alarm),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Test Ring'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  foregroundColor: AppColors.primaryLight,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1B20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2C2F3A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E929E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

