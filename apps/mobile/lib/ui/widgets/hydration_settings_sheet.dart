import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/hydration_provider.dart';

class HydrationSettingsSheet extends StatelessWidget {
  const HydrationSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const HydrationSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, hydration, _) {
        final upcomingSlots = hydration.getUpcomingReminderSlots();
        final allSlots = hydration.calculateReminderSlots();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.sheetSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.scrimHandle(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header with Seren Mascot Identity
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.water_drop_rounded,
                        color: Color(0xFF8B5CF6), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seren Hydration Companion',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          'Gentle wellness reminders for your day',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Reminders Toggle Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Periodic Hydration Reminders',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Gentle alerts until daily goal is reached',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: hydration.remindersEnabled,
                          activeColor: const Color(0xFF8B5CF6),
                          onChanged: (val) {
                            hydration.toggleReminders(val);
                          },
                        ),
                      ],
                    ),
                    if (hydration.remindersEnabled) ...[
                      Divider(color: AppColors.border(context), height: 24),
                      Row(
                        children: [
                          Icon(
                            hydration.isGoalMet
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            size: 16,
                            color: hydration.isGoalMet
                                ? const Color(0xFF10B981)
                                : const Color(0xFF8B5CF6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hydration.isGoalMet
                                  ? 'Daily goal met! Reminders paused until tomorrow.'
                                  : '${upcomingSlots.length} of ${allSlots.length} slots left today (8 AM – 9 PM)',
                              style: TextStyle(
                                fontSize: 12,
                                color: hydration.isGoalMet
                                    ? const Color(0xFF10B981)
                                    : AppColors.textPrimary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Daily Goal Config
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Hydration Target',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          '${hydration.targetMilliliters}ml (${hydration.dailyGoalGlasses} glasses)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: AppColors.textSecondary(context)),
                          onPressed: hydration.dailyGoalGlasses > 4
                              ? () => hydration.setDailyGoal(hydration.dailyGoalGlasses - 1)
                              : null,
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF8B5CF6),
                              inactiveTrackColor: AppColors.trackSurface(context),
                              thumbColor: const Color(0xFF8B5CF6),
                            ),
                            child: Slider(
                              value: hydration.dailyGoalGlasses.toDouble(),
                              min: 4,
                              max: 16,
                              divisions: 12,
                              onChanged: (val) {
                                hydration.setDailyGoal(val.toInt());
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline,
                              color: AppColors.textSecondary(context)),
                          onPressed: hydration.dailyGoalGlasses < 16
                              ? () => hydration.setDailyGoal(hydration.dailyGoalGlasses + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Interval Selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminder Cadence (8 AM – 9 PM)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [60, 90, 120].map((interval) {
                        final isSelected = hydration.reminderIntervalMinutes == interval;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  '$interval min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF8B5CF6),
                              backgroundColor: AppColors.trackSurface(context),
                              onSelected: (_) {
                                hydration.updateSchedule(intervalMinutes: interval);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.notifications_active_rounded,
                          color: Color(0xFF8B5CF6), size: 18),
                      label: const Text(
                        'Test Seren Nudge',
                        style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 13),
                      ),
                      onPressed: () async {
                        await hydration.testSendReminderNow();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('💧 Seren hydration notification triggered!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

