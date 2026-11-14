import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/countdown_timer.dart';
import '../../../providers/timer_provider.dart';
import 'pomodoro_view.dart';

class TimersScreen extends StatefulWidget {
  final int initialSubTabIndex;

  const TimersScreen({super.key, this.initialSubTabIndex = 0});

  @override
  State<TimersScreen> createState() => _TimersScreenState();
}

class _TimersScreenState extends State<TimersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialSubTabIndex,
    );
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddTimerDialog(BuildContext context) {
    int minutes = 5;
    int seconds = 0;
    final labelController = TextEditingController(text: 'Focus Timer');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.sheetSurface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Set New Timer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      labelText: 'Timer Label',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNumberPicker(
                        label: 'MIN',
                        value: minutes,
                        min: 0,
                        max: 180,
                        onChanged: (val) => setState(() => minutes = val),
                      ),
                      const SizedBox(width: 24),
                      _buildNumberPicker(
                        label: 'SEC',
                        value: seconds,
                        min: 0,
                        max: 59,
                        onChanged: (val) => setState(() => seconds = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      final total = (minutes * 60) + seconds;
                      if (total > 0) {
                        Provider.of<TimerProvider>(context, listen: false)
                            .addTimer(labelController.text.trim(), total);
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Start Countdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNumberPicker({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.remove_rounded),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            Container(
              width: 56,
              alignment: Alignment.center,
              child: Text(
                value.toString().padLeft(2, '0'),
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add_rounded),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timers & Focus'),
        bottom: TabBar(
          controller: _tabController,
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
          tabs: const [
            Tab(
              icon: Icon(Icons.local_fire_department_rounded, size: 18),
              text: 'Pomodoro Focus',
            ),
            Tab(
              icon: Icon(Icons.hourglass_bottom_rounded, size: 18),
              text: 'Custom Timers',
            ),
          ],
        ),
        actions: [
          if (_tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 28),
              onPressed: () => _showAddTimerDialog(context),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Pomodoro Focus Engine
          const PomodoroView(),

          // Tab 1: Custom Timers List
          _buildCustomTimersView(context, timerProvider),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTimerDialog(context),
              backgroundColor: AppColors.accent,
              icon: const Icon(Icons.timer_outlined, color: Colors.black),
              label: const Text(
                'New Timer',
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
              ),
            )
          : null,
    );
  }

  Widget _buildCustomTimersView(
      BuildContext context, TimerProvider timerProvider) {
    final timers = timerProvider.timers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Presets
          const Text(
            'Quick Presets',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _presetChip(context, '1m Tea', 60),
                _presetChip(context, '3m Eggs', 180),
                _presetChip(context, '5m Rest', 300),
                _presetChip(context, '10m Break', 600),
                _presetChip(context, '25m Sprint', 1500),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Active Timers
          const Text(
            'Active Timers',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (timers.isEmpty)
            _buildEmptyState(context)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildTimerCard(context, timers[index], timerProvider);
              },
            ),
        ],
      ),
    );
  }

  Widget _presetChip(BuildContext context, String label, int seconds) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        avatar: const Icon(Icons.flash_on_rounded,
            size: 14, color: AppColors.accent),
        onPressed: () {
          Provider.of<TimerProvider>(context, listen: false)
              .addTimer(label, seconds);
        },
      ),
    );
  }

  Widget _buildTimerCard(
    BuildContext context,
    CountdownTimer timer,
    TimerProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Circular Progress Indicator
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: timer.progress,
                    strokeWidth: 5,
                    backgroundColor: AppColors.trackSurface(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      timer.isFinished
                          ? AppColors.success
                          : (timer.isRunning
                              ? AppColors.accent
                              : AppColors.textMuted(context)),
                    ),
                  ),
                  Center(
                    child: Icon(
                      timer.isFinished
                          ? Icons.check_rounded
                          : (timer.isRunning
                              ? (timer.isPaused
                                  ? Icons.pause_rounded
                                  : Icons.timer_rounded)
                              : Icons.play_arrow_rounded),
                      size: 24,
                      color: timer.isRunning
                          ? AppColors.accent
                          : AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Timer Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timer.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timer.formattedRemaining(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: timer.isRunning
                          ? AppColors.textPrimary(context)
                          : AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            // Controls
            Row(
              children: [
                if (!timer.isRunning || timer.isPaused)
                  IconButton.filled(
                    onPressed: () {
                      if (!timer.isRunning) {
                        provider.startTimer(timer.id);
                      } else {
                        provider.resumeTimer(timer.id);
                      }
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                    ),
                  )
                else
                  IconButton.filled(
                    onPressed: () => provider.pauseTimer(timer.id),
                    icon: const Icon(Icons.pause_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.elevatedSurface(context),
                      foregroundColor: AppColors.textPrimary(context),
                    ),
                  ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => provider.resetTimer(timer.id),
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  tooltip: 'Reset',
                ),
                IconButton(
                  onPressed: () => provider.deleteTimer(timer.id),
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.error),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.timer_off_outlined,
                size: 48, color: AppColors.textSecondary(context)),
            const SizedBox(height: 12),
            const Text(
              'No active timers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a preset above or tap New Timer',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}
