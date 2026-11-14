import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/sleep/sleep_cycle_calculator.dart';
import '../../data/services/ambient_sound_service.dart';
import '../../providers/sleep_wellness_provider.dart';
import '../../providers/alarm_provider.dart';
import 'caffeine_summary_card.dart';

class SleepCycleSheet extends StatefulWidget {
  const SleepCycleSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SleepCycleSheet(),
    );
  }

  @override
  State<SleepCycleSheet> createState() => _SleepCycleSheetState();
}

class _SleepCycleSheetState extends State<SleepCycleSheet> {
  int _selectedTab = 0; // 0: Wind-Down & Bedtimes, 1: Wake-Up from Now

  @override
  Widget build(BuildContext context) {
    return Consumer2<SleepWellnessProvider, AlarmProvider>(
      builder: (context, sleepWellness, alarmProvider, _) {
        final now = DateTime.now();
        final nextAlarm = alarmProvider.nextUpcomingAlarm;
        final nextAlarmTime = nextAlarm?.nextOccurrence(now);

        final effectiveWakeUp = sleepWellness.getEffectiveWakeUpTime(
          currentTime: now,
          nextAlarmTime: nextAlarmTime,
        );

        final targetBedtime = sleepWellness.getTargetBedtime(
          currentTime: now,
          nextAlarmTime: nextAlarmTime,
        );

        final windDownTime = sleepWellness.getWindDownAlertTime(
          currentTime: now,
          nextAlarmTime: nextAlarmTime,
        );

        final bedtimes = SleepCycleCalculator.calculateBedtimes(effectiveWakeUp);
        final wakeOptions = SleepCycleCalculator.calculateWakeUpTimes(now);

        final bedHourStr = targetBedtime.hour.toString().padLeft(2, '0');
        final bedMinStr = targetBedtime.minute.toString().padLeft(2, '0');
        final alertHourStr = windDownTime.hour.toString().padLeft(2, '0');
        final alertMinStr = windDownTime.minute.toString().padLeft(2, '0');
        final wakeHourStr = effectiveWakeUp.hour.toString().padLeft(2, '0');
        final wakeMinStr = effectiveWakeUp.minute.toString().padLeft(2, '0');

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
          child: SingleChildScrollView(
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

                // Seren Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.nightlight_round,
                          color: Color(0xFF8B5CF6), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seren Sleep & Wind-Down',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            'Restorative 90-minute REM cycles & alerts',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
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
                const SizedBox(height: 16),

                // Wind-Down Alert Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sleepWellness.isEnabled
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                          : AppColors.border(context),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bedtime Wind-Down Alert',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Push notification 30m before target bedtime',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: sleepWellness.isEnabled,
                            activeColor: const Color(0xFF8B5CF6),
                            onChanged: (val) {
                              sleepWellness.toggleEnabled(
                                val,
                                nextAlarmTime: nextAlarmTime,
                              );
                            },
                          ),
                        ],
                      ),
                      if (sleepWellness.isEnabled) ...[
                        Divider(color: AppColors.border(context), height: 20),
                        // Schedule Timing Details
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.recessedSurface(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.notifications_active_rounded,
                                      color: Color(0xFF8B5CF6), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Alert at $alertHourStr:$alertMinStr',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${sleepWellness.windDownLeadMinutes}m lead time',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.bedtime_rounded,
                                    color: AppColors.adaptive(
                                      context,
                                      dark: const Color(0xFF10B981),
                                      light: const Color(0xFF047857),
                                    ),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Target bedtime: $bedHourStr:$bedMinStr',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Wake up: $wakeHourStr:$wakeMinStr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Wake Target Mode
                        Row(
                          children: [
                            Text(
                              'Wake Source:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(
                                nextAlarm != null
                                    ? 'Next Alarm ($wakeHourStr:$wakeMinStr)'
                                    : 'Next Alarm (None)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: sleepWellness.syncWithNextAlarm
                                      ? Colors.white
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                              selected: sleepWellness.syncWithNextAlarm,
                              selectedColor: const Color(0xFF8B5CF6),
                              backgroundColor: AppColors.trackSurface(context),
                              onSelected: (selected) {
                                sleepWellness.updateConfig(
                                  sleepWellness.config.copyWith(
                                      syncWithNextAlarm: selected),
                                  nextAlarmTime: nextAlarmTime,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: Text(
                                'Fixed 07:00',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: !sleepWellness.syncWithNextAlarm
                                      ? Colors.white
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                              selected: !sleepWellness.syncWithNextAlarm,
                              selectedColor: const Color(0xFF8B5CF6),
                              backgroundColor: AppColors.trackSurface(context),
                              onSelected: (selected) {
                                sleepWellness.updateConfig(
                                  sleepWellness.config.copyWith(
                                      syncWithNextAlarm: !selected),
                                  nextAlarmTime: nextAlarmTime,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Cycles Choice
                        Row(
                          children: [
                            Text(
                              'Sleep Cycles:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...[4, 5, 6].map((cycles) {
                              final isSel =
                                  sleepWellness.targetSleepCycles == cycles;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(
                                    '$cycles (${cycles * 1.5}h)${cycles == 5 ? ' ★' : ''}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: isSel
                                          ? Colors.white
                                          : AppColors.textSecondary(context),
                                    ),
                                  ),
                                  selected: isSel,
                                  selectedColor: const Color(0xFF8B5CF6),
                                  backgroundColor: AppColors.trackSurface(context),
                                  onSelected: (_) {
                                    sleepWellness.updateConfig(
                                      sleepWellness.config
                                          .copyWith(targetSleepCycles: cycles),
                                      nextAlarmTime: nextAlarmTime,
                                    );
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 1-Tap Wind-Down Ambient Audio Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sleepWellness.isWindDownAudioPlaying
                          ? const Color(0xFF8B5CF6)
                          : AppColors.border(context),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.headphones_rounded,
                                color: Color(0xFF8B5CF6), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Wind-Down Ambient Audio',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (sleepWellness.isWindDownAudioPlaying)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Playing • ${sleepWellness.formattedRemainingTime}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.adaptive(
                                              context,
                                              dark: const Color(0xFF10B981),
                                              light: const Color(0xFF047857),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '1-tap soothing audio for 30 minutes to relax into sleep',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Sound Type Selector (Rain vs Forest Breeze)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => sleepWellness.switchAmbientSound(AmbientSoundType.rain),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: sleepWellness.activeAmbientSound == AmbientSoundType.rain
                                      ? const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.18)
                                      : AppColors.trackSurface(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: sleepWellness.activeAmbientSound == AmbientSoundType.rain
                                        ? const Color(0xFF8B5CF6)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.water_drop_rounded,
                                      size: 16,
                                      color: AppColors.adaptive(
                                        context,
                                        dark: const Color(0xFF38BDF8),
                                        light: const Color(0xFF0284C7),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Rainfall',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: sleepWellness.activeAmbientSound == AmbientSoundType.rain
                                            ? AppColors.textPrimary(context)
                                            : AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => sleepWellness.switchAmbientSound(AmbientSoundType.forest),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: sleepWellness.activeAmbientSound == AmbientSoundType.forest
                                      ? const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.18)
                                      : AppColors.trackSurface(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: sleepWellness.activeAmbientSound == AmbientSoundType.forest
                                        ? const Color(0xFF8B5CF6)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.park_rounded,
                                      size: 16,
                                      color: AppColors.adaptive(
                                        context,
                                        dark: const Color(0xFF34D399),
                                        light: const Color(0xFF047857),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Forest Breeze',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: sleepWellness.activeAmbientSound == AmbientSoundType.forest
                                            ? AppColors.textPrimary(context)
                                            : AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // If playing, show timer progress & volume slider
                      if (sleepWellness.isWindDownAudioPlaying) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: sleepWellness.audioProgress,
                            minHeight: 5,
                            backgroundColor: AppColors.trackSurface(context),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.volume_down_rounded, size: 16, color: AppColors.textSecondary(context)),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: const Color(0xFF8B5CF6),
                                  inactiveTrackColor: AppColors.trackSurface(context),
                                  thumbColor: AppColors.isDark(context)
                                      ? Colors.white
                                      : const Color(0xFF8B5CF6),
                                ),
                                child: Slider(
                                  value: sleepWellness.ambientVolume,
                                  onChanged: (val) => sleepWellness.setAmbientVolume(val),
                                ),
                              ),
                            ),
                            Icon(Icons.volume_up_rounded, size: 16, color: AppColors.textSecondary(context)),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // 1-Tap Start / Stop Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            sleepWellness.toggleWindDownAudio(
                              soundType: sleepWellness.activeAmbientSound,
                              durationMinutes: 30,
                            );
                          },
                          icon: Icon(
                            sleepWellness.isWindDownAudioPlaying
                                ? Icons.stop_circle_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            sleepWellness.isWindDownAudioPlaying
                                ? 'Stop Wind-Down Audio (${sleepWellness.formattedRemainingTime})'
                                : '1-Tap: Start 30m ${sleepWellness.activeAmbientSound == AmbientSoundType.rain ? 'Rainfall' : 'Forest Breeze'}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sleepWellness.isWindDownAudioPlaying
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CaffeineBedtimeBanner(targetBedtime: targetBedtime),
                const SizedBox(height: 16),

                // Tab Switcher for Cycles
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0
                                  ? AppColors.cardSurface(context)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Bedtimes for $wakeHourStr:$wakeMinStr Wake',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _selectedTab == 0
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: _selectedTab == 0
                                      ? AppColors.textPrimary(context)
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1
                                  ? AppColors.cardSurface(context)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'If You Sleep Right Now',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _selectedTab == 1
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: _selectedTab == 1
                                      ? AppColors.textPrimary(context)
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Options List
                if (_selectedTab == 0) ...[
                  ...bedtimes.map((opt) {
                    final h = opt.targetTime.hour.toString().padLeft(2, '0');
                    final m = opt.targetTime.minute.toString().padLeft(2, '0');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: opt.isRecommended
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                            : AppColors.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: opt.isRecommended
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                              : AppColors.border(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            opt.isRecommended
                                ? Icons.stars_rounded
                                : Icons.bedtime_outlined,
                            color: opt.isRecommended
                                ? const Color(0xFF8B5CF6)
                                : AppColors.textSecondary(context),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$h:$m',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (opt.isRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Recommended',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.adaptive(
                                    context,
                                    dark: const Color(0xFF8B5CF6),
                                    light: const Color(0xFF6D28D9),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  ...wakeOptions.map((opt) {
                    final h = opt.targetTime.hour.toString().padLeft(2, '0');
                    final m = opt.targetTime.minute.toString().padLeft(2, '0');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: opt.isRecommended
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                            : AppColors.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: opt.isRecommended
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                              : AppColors.border(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            opt.isRecommended
                                ? Icons.alarm_on_rounded
                                : Icons.alarm_outlined,
                            color: opt.isRecommended
                                ? const Color(0xFF8B5CF6)
                                : AppColors.textSecondary(context),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$h:$m',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (opt.isRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Sweet Spot',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.adaptive(
                                    context,
                                    dark: const Color(0xFF8B5CF6),
                                    light: const Color(0xFF6D28D9),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),

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
                          'Test Wind-Down Nudge',
                          style: TextStyle(
                              color: Color(0xFF8B5CF6), fontSize: 13),
                        ),
                        onPressed: () async {
                          await sleepWellness.testSendAlertNow(
                              nextAlarmTime: nextAlarmTime);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '🌙 Seren wind-down alert triggered!'),
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
                        child: const Text('Done',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
