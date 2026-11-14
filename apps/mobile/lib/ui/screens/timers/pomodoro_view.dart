import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/focus_session_log.dart';
import '../../../data/services/ambient_sound_service.dart';
import '../../../providers/timer_provider.dart';

class PomodoroView extends StatelessWidget {
  const PomodoroView({super.key});

  Color _getPhaseColor(FocusPhase phase) {
    switch (phase) {
      case FocusPhase.work:
        return AppColors.primary;
      case FocusPhase.shortBreak:
        return const Color(0xFF10B981); // Emerald
      case FocusPhase.longBreak:
        return const Color(0xFF06B6D4); // Cyan
    }
  }

  void _showTaskLabelDialog(BuildContext context, TimerProvider provider) {
    final controller = TextEditingController(text: provider.pomodoroTaskLabel);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Focus Task Label', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Deep Coding, Reading, Writing',
            prefixIcon: Icon(Icons.psychology_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.setPomodoroTaskLabel(controller.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDurationsDialog(BuildContext context, TimerProvider provider) {
    int work = provider.pomodoroTotalSeconds ~/ 60;
    if (provider.pomodoroPhase != FocusPhase.work) work = 25;
    int shortB = 5;
    int longB = 15;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.sheetSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Customize Pomodoro Intervals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Standard cycle is 25m work followed by 5m break.',
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 13),
              ),
              const SizedBox(height: 20),
              _buildDurationRow(
                'Work Sprint',
                work,
                (val) => setState(() => work = val),
                color: AppColors.primary,
              ),
              const SizedBox(height: 14),
              _buildDurationRow(
                'Short Break',
                shortB,
                (val) => setState(() => shortB = val),
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 14),
              _buildDurationRow(
                'Long Break',
                longB,
                (val) => setState(() => longB = val),
                color: const Color(0xFF06B6D4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  provider.setCustomPomodoroDurations(
                    workMinutes: work,
                    shortBreakMinutes: shortB,
                    longBreakMinutes: longB,
                  );
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Apply Intervals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationRow(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    required Color color,
  }) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(14),
        ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                onPressed: value > 1 ? () => onChanged(value - 5 > 0 ? value - 5 : 1) : null,
              ),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  '${value}m',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                onPressed: value < 90 ? () => onChanged(value + 5) : null,
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context);
    final phaseColor = _getPhaseColor(timerProvider.pomodoroPhase);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Pomodoro Timer Card
          _buildHeroCard(context, timerProvider, phaseColor),
          const SizedBox(height: 20),

          // 2. Ambient Noise Controls Bar
          _buildAmbientSoundBar(context, timerProvider),
          const SizedBox(height: 20),

          // 3. Today's Focus Metrics
          _buildMetricsStrip(timerProvider),
          const SizedBox(height: 20),

          // 4. Focus History Logs
          _buildHistoryLogs(context, timerProvider),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    TimerProvider provider,
    Color phaseColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: provider.isPomodoroRunning
              ? phaseColor.withValues(alpha: 0.4)
              : AppColors.border(context),
          width: 1.5,
        ),
        boxShadow: [
          if (provider.isPomodoroRunning)
            BoxShadow(
              color: phaseColor.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          // Top Bar: Phase Pill & Settings button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: phaseColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: phaseColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.pomodoroPhase == FocusPhase.work
                          ? Icons.local_fire_department_rounded
                          : Icons.coffee_rounded,
                      size: 16,
                      color: phaseColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider.pomodoroPhase.displayName.toUpperCase(),
                      style: TextStyle(
                        color: phaseColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20),
                tooltip: 'Customize Intervals',
                color: AppColors.textSecondary(context),
                onPressed: () => _showDurationsDialog(context, provider),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Large Circular Countdown Display
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: provider.pomodoroProgress,
                  strokeWidth: 8,
                  backgroundColor: AppColors.trackSurface(context),
                  valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider.formattedPomodoroRemaining(),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(4, (index) {
                          final cycleNumber = index + 1;
                          final isCompleted = cycleNumber < provider.pomodoroCycle;
                          final isCurrent = cycleNumber == provider.pomodoroCycle;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isCurrent ? 14 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? phaseColor
                                  : (isCurrent
                                      ? phaseColor
                                      : AppColors.trackSurface(context)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cycle ${provider.pomodoroCycle} of 4',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Task Label Tag with Quick Edit
          InkWell(
            onTap: () => _showTaskLabelDialog(context, provider),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded,
                      size: 18, color: AppColors.textSecondary(context)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      provider.pomodoroTaskLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.adaptive(
                          context,
                          dark: const Color(0xFFD1D5DB),
                          light: AppColors.lightTextPrimary,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_rounded,
                      size: 12, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Primary Controls Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reset Button
              IconButton.filledTonal(
                icon: const Icon(Icons.replay_rounded),
                tooltip: 'Reset Phase',
                onPressed: () => provider.resetPomodoro(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.elevatedSurface(context),
                  foregroundColor: AppColors.textPrimary(context),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(width: 16),

              // Play / Pause Hero Button
              ElevatedButton.icon(
                onPressed: () {
                  if (!provider.isPomodoroRunning) {
                    provider.startPomodoro();
                  } else if (provider.isPomodoroPaused) {
                    provider.resumePomodoro();
                  } else {
                    provider.pausePomodoro();
                  }
                },
                icon: Icon(
                  !provider.isPomodoroRunning || provider.isPomodoroPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: 26,
                  color: Colors.white,
                ),
                label: Text(
                  !provider.isPomodoroRunning
                      ? 'START FOCUS'
                      : (provider.isPomodoroPaused ? 'RESUME' : 'PAUSE'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: phaseColor,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 4,
                ),
              ),
              const SizedBox(width: 16),

              // Skip Phase Button
              IconButton.filledTonal(
                icon: const Icon(Icons.skip_next_rounded),
                tooltip: 'Skip to Next Phase',
                onPressed: () => provider.skipPomodoroPhase(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.elevatedSurface(context),
                  foregroundColor: AppColors.textPrimary(context),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientSoundBar(
    BuildContext context,
    TimerProvider provider,
  ) {
    final ambientAccent = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.graphic_eq_rounded,
                      size: 18, color: ambientAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Ambient White Noise',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              if (provider.selectedAmbientSound != AmbientSoundType.none)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: provider.isPomodoroRunning && !provider.isPomodoroPaused
                              ? ambientAccent
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        provider.selectedAmbientSound.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ambientAccent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Ambient Sound Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AmbientSoundType.values.map((type) {
                final isSelected = provider.selectedAmbientSound == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Icon(
                      type.icon,
                      size: 16,
                      color: isSelected
                          ? ambientAccent
                          : AppColors.textSecondary(context),
                    ),
                    label: Text(type.label),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.textPrimary(context)
                          : AppColors.textSecondary(context),
                    ),
                    backgroundColor: AppColors.elevatedSurface(context),
                    selectedColor: AppColors.trackSurface(context),
                    side: BorderSide(
                      color: isSelected
                          ? ambientAccent
                          : AppColors.border(context),
                      width: isSelected ? 1.5 : 1,
                    ),
                    onSelected: (_) => provider.setAmbientSound(type),
                  ),
                );
              }).toList(),
            ),
          ),

          // Volume Slider (only when noise is selected)
          if (provider.selectedAmbientSound != AmbientSoundType.none) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.volume_down_rounded,
                    size: 16, color: AppColors.textSecondary(context)),
                Expanded(
                  child: Slider(
                    value: provider.ambientVolume,
                    onChanged: (val) => provider.setAmbientVolume(val),
                    activeColor: AppColors.accent,
                    inactiveColor: AppColors.trackSurface(context),
                  ),
                ),
                Text(
                  '${(provider.ambientVolume * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsStrip(TimerProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            label: "Today's Focus",
            value: '${provider.todayFocusMinutes}m',
            icon: Icons.access_time_filled_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            label: "Pomodoros Done",
            value: '${provider.todayCompletedPomodoros}',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            label: "Total Minutes",
            value: '${provider.totalFocusMinutes}m',
            icon: Icons.insights_rounded,
            color: const Color(0xFF06B6D4),
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryLogs(BuildContext context, TimerProvider provider) {
    final logs = provider.focusLogs;
    final accent = AppColors.adaptive(
      context,
      dark: AppColors.accent,
      light: const Color(0xFFB45309),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 18, color: AppColors.textSecondary(context)),
                  const SizedBox(width: 8),
                  const Text(
                    'Focus Session Log',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              if (logs.isNotEmpty)
                TextButton(
                  onPressed: () => provider.clearFocusLogs(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.textSecondary(context),
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No completed focus sessions yet.\nStart a 25m sprint above!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 12),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length > 5 ? 5 : logs.length,
              separatorBuilder: (_, __) => Divider(
                color: AppColors.border(context),
                height: 12,
              ),
              itemBuilder: (context, index) {
                final log = logs[index];
                final timeFormatted =
                    DateFormat('h:mm a • MMM d').format(log.completedAt);
                return Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: log.phase == FocusPhase.work
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        log.phase == FocusPhase.work
                            ? Icons.check_circle_outline_rounded
                            : Icons.coffee_rounded,
                        size: 16,
                        color: log.phase == FocusPhase.work
                            ? AppColors.primary
                            : const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.taskLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeFormatted,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (log.ambientSoundUsed != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          log.ambientSoundUsed!,
                          style: TextStyle(
                            fontSize: 10,
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.trackSurface(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${log.durationMinutes}m',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
