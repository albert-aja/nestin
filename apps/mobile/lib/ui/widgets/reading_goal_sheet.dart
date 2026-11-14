import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/reading_goal_data.dart';
import '../../providers/reading_provider.dart';
import 'reading_sparkline_history.dart';

class ReadingGoalSettingsSheet extends StatelessWidget {
  const ReadingGoalSettingsSheet({super.key});

  static const Color _pippinEmerald = Color(0xFF10B981);
  static const Color _pippinGold = Color(0xFFF59E0B);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReadingGoalSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emeraldInk = AppColors.adaptive(
      context,
      dark: _pippinEmerald,
      light: const Color(0xFF047857),
    );
    final goldInk = AppColors.adaptive(
      context,
      dark: _pippinGold,
      light: const Color(0xFFB45309),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer<ReadingProvider>(
        builder: (context, provider, _) {
          final goal = provider.dailyPageGoal;
          final currentStreak = provider.currentStreak;
          final bestStreak = provider.bestStreak;
          final eveningEnabled = provider.eveningReminderEnabled;
          final nudgePreview =
              provider.buildEveningReminderBody(forDate: DateTime.now());

          const presetGoals = [10, 15, 25, 40];
          const eveningPresets = [
            (19, 0, '19:00'),
            (20, 0, '20:00'),
            (21, 0, '21:00'),
            (22, 0, '22:00'),
          ];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header with Pippin sprite & fallback
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 46,
                        height: 46,
                        color: _pippinEmerald.withValues(alpha: 0.16),
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/mascots/sprites/pippin/reading.png',
                          width: 42,
                          height: 42,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Text(
                            '🦜',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.pick(
                              'Daily Page Goal & Streak',
                              'Target Halaman & Streak',
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            l10n.pick(
                              'Pippin evening reading habit & history',
                              'Pengingat baca sore Pippin & riwayat',
                            ),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: emeraldInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary(context),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Streak & Weekly Summary Card
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCol(
                        context,
                        label: l10n.pick('Current Streak', 'Streak Kini'),
                        value: '🔥 ${currentStreak}d',
                        color: goldInk,
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: AppColors.border(context),
                      ),
                      _buildStatCol(
                        context,
                        label: l10n.pick('Best Streak', 'Streak Terbaik'),
                        value: '🏆 ${bestStreak}d',
                        color: emeraldInk,
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: AppColors.border(context),
                      ),
                      _buildStatCol(
                        context,
                        label: l10n.pick('7-Day Total', 'Total 7 Hari'),
                        value: '${provider.weeklyTotalPages} p',
                        color: AppColors.textPrimary(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Full Interactive 7-day Sparkline
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: const ReadingSparklineHistory(),
                ),
                const SizedBox(height: 16),

                // Daily Page Goal Configuration
                Text(
                  l10n.pick('DAILY PAGE TARGET', 'TARGET HALAMAN HARIAN'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: goal > ReadingGoalData.minDailyGoal
                                ? () => provider.setDailyPageGoal(goal - 5)
                                : null,
                            icon: const Icon(Icons.remove_rounded, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppColors.recessedSurface(context),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  l10n.pick(
                                    '$goal pages / day',
                                    '$goal halaman / hari',
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                Text(
                                  l10n.pick(
                                    'Pages logged on books today count automatically',
                                    'Halaman yang dicatat hari ini dihitung otomatis',
                                  ),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: goal < ReadingGoalData.maxDailyGoal
                                ? () => provider.setDailyPageGoal(goal + 5)
                                : null,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppColors.recessedSurface(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: presetGoals.map((preset) {
                          final selected = goal == preset;
                          return ChoiceChip(
                            label: Text('$preset p'),
                            selected: selected,
                            selectedColor:
                                _pippinEmerald.withValues(alpha: 0.24),
                            backgroundColor:
                                AppColors.recessedSurface(context),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? emeraldInk
                                  : AppColors.textPrimary(context),
                            ),
                            side: BorderSide(
                              color: selected
                                  ? _pippinEmerald
                                  : Colors.transparent,
                            ),
                            onSelected: (v) {
                              if (v) provider.setDailyPageGoal(preset);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Optional Evening Pippin Nudge Configuration
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: eveningEnabled
                          ? _pippinEmerald.withValues(alpha: 0.45)
                          : AppColors.border(context),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            eveningEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_outlined,
                            color: eveningEnabled
                                ? emeraldInk
                                : AppColors.textSecondary(context),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.pick(
                                    'Evening Pippin Nudge',
                                    'Pengingat Sore Pippin',
                                  ),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                Text(
                                  l10n.pick(
                                    'Optional reminder if today\'s goal is incomplete',
                                    'Pengingat opsional jika target hari ini belum tercapai',
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: eveningEnabled,
                            activeThumbColor: _pippinEmerald,
                            onChanged: (val) =>
                                provider.toggleEveningReminder(val),
                          ),
                        ],
                      ),

                      // Pippin live dialog preview bubble
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _pippinEmerald.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _pippinEmerald.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🦜', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '"$nudgePreview"',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (eveningEnabled) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.pick(
                                'Reminder time: ${provider.formattedReminderTime}',
                                'Waktu pengingat: ${provider.formattedReminderTime}',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: provider.reminderHour,
                                    minute: provider.reminderMinute,
                                  ),
                                );
                                if (picked != null) {
                                  await provider.setReminderTime(
                                    picked.hour,
                                    picked.minute,
                                  );
                                }
                              },
                              icon: const Icon(Icons.schedule_rounded, size: 15),
                              label: Text(
                                l10n.pick('Custom Time', 'Atur Jam'),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: eveningPresets.map((slot) {
                            final selected = provider.reminderHour == slot.$1 &&
                                provider.reminderMinute == slot.$2;
                            return ChoiceChip(
                              label: Text(slot.$3),
                              selected: selected,
                              selectedColor:
                                  _pippinEmerald.withValues(alpha: 0.24),
                              backgroundColor:
                                  AppColors.recessedSurface(context),
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? emeraldInk
                                    : AppColors.textPrimary(context),
                              ),
                              side: BorderSide(
                                color: selected
                                    ? _pippinEmerald
                                    : Colors.transparent,
                              ),
                              onSelected: (v) {
                                if (v) {
                                  provider.setReminderTime(slot.$1, slot.$2);
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await provider.testSendEveningNudgeNow();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.pick(
                                    'Sent Pippin reading nudge preview!',
                                    'Pratinjau pengingat Pippin terkirim!',
                                  ),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.notifications_rounded,
                            size: 16,
                            color: emeraldInk,
                          ),
                          label: Text(
                            l10n.pick(
                              'Send Test Nudge',
                              'Kirim Pratinjau Pengingat',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: emeraldInk,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _pippinEmerald.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCol(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
