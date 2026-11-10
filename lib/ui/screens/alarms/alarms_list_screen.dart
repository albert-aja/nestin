import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alarm.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/category_badge.dart';
import 'alarm_edit_screen.dart';

class AlarmsListScreen extends StatelessWidget {
  const AlarmsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alarmProvider = Provider.of<AlarmProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final alarms = alarmProvider.alarms;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlarmEditScreen()),
              );
            },
          ),
        ],
      ),
      body: alarms.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: alarms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final alarm = alarms[index];
                return _buildAlarmCard(
                  context,
                  alarm,
                  alarmProvider,
                  settingsProvider,
                  now,
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AlarmEditScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_alarm_rounded, color: Colors.white),
        label: const Text(
          'New Alarm',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAlarmCard(
    BuildContext context,
    Alarm alarm,
    AlarmProvider provider,
    SettingsProvider settingsProvider,
    DateTime now,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final challenge =
        alarm.effectiveChallenge(settingsProvider.globalChallengeProfile);

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AlarmEditScreen(initialAlarm: alarm),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Category, Challenge Badge & Switch
              Row(
                children: [
                  CategoryBadge(category: alarm.category, compact: true),
                  const SizedBox(width: 8),
                  if (challenge.isEnabled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.psychology_rounded,
                              size: 11, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            alarm.challengeInherited
                                ? '${challenge.typeLabel} (Default)'
                                : '${challenge.typeLabel} (Custom)',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: alarm.isEnabled,
                      onChanged: (val) {
                        provider.toggleAlarm(alarm.id, val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Time & Next Trigger
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    alarm.formattedTime(use24Hour: settingsProvider.use24Hour),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: alarm.isEnabled
                          ? (isDark ? Colors.white : const Color(0xFF1E2024))
                          : const Color(0xFF8E929E),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (alarm.isEnabled)
                    Text(
                      alarm.timeUntilNext(now),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Title and recurrence
              Row(
                children: [
                  Expanded(
                    child: Text(
                      alarm.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: alarm.isEnabled
                            ? (isDark
                                ? const Color(0xFFE2E4E9)
                                : const Color(0xFF2E323D))
                            : const Color(0xFF8E929E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    alarm.schedule.getDisplayText(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF8E929E) : const Color(0xFF6C757D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Action bar: Test Trigger, Duplicate, Delete
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      provider.triggerAlarm(alarm);
                    },
                    icon: const Icon(Icons.play_circle_outline_rounded,
                        size: 16, color: AppColors.primary),
                    label: const Text(
                      'Test Ring',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Duplicate',
                        onPressed: () => provider.duplicateAlarm(alarm.id),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.error),
                        tooltip: 'Delete',
                        onPressed: () => provider.deleteAlarm(alarm.id),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2028),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.alarm_off_rounded,
              size: 56,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Alarms Configured',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the button below to create your first alarm',
            style: TextStyle(fontSize: 13, color: Color(0xFF8E929E)),
          ),
        ],
      ),
    );
  }
}

