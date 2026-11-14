import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/sleep_log.dart';
import '../../data/models/vital_log.dart';
import '../../providers/health_wellness_provider.dart';
import '../../providers/hydration_provider.dart';
import '../../providers/wearable_provider.dart';
import 'sleep_cycle_sheet.dart';

class HealthWellnessSheet extends StatefulWidget {
  final int initialTabIndex;

  const HealthWellnessSheet({
    super.key,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HealthWellnessSheet(initialTabIndex: initialTabIndex),
    );
  }

  @override
  State<HealthWellnessSheet> createState() => _HealthWellnessSheetState();
}

class _HealthWellnessSheetState extends State<HealthWellnessSheet>
    with SingleTickerProviderStateMixin {
  static const Color _serenPurple = Color(0xFF8B5CF6);
  static const Color _serenLight = Color(0xFFA78BFA);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _skyBlue = Color(0xFF38BDF8);
  static const Color _amber = Color(0xFFF59E0B);

  late TabController _tabController;
  int? _selectedStepDayIndex;
  int? _selectedSleepDayIndex;

  // Guided breathing timer state
  Timer? _breathingTimer;
  bool _isBreathingActive = false;
  bool _useBoxBreathing = false; // false = 4-7-8, true = 4-4-4-4
  int _phaseIndex = 0; // 0: inhale, 1: hold1, 2: exhale, 3: hold2
  int _phaseSecondsRemaining = 4;
  int _totalBreathingSeconds = 0;
  int _completedCycles = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _breathingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<({String label, int seconds, double scale})> get _currentPattern {
    if (_useBoxBreathing) {
      return const [
        (label: 'Inhale Gently', seconds: 4, scale: 1.25),
        (label: 'Hold Softly', seconds: 4, scale: 1.25),
        (label: 'Exhale Slowly', seconds: 4, scale: 0.80),
        (label: 'Rest Calmly', seconds: 4, scale: 0.80),
      ];
    }
    return const [
      (label: 'Inhale Nose', seconds: 4, scale: 1.25),
      (label: 'Hold Breath', seconds: 7, scale: 1.25),
      (label: 'Exhale Mouth', seconds: 8, scale: 0.80),
    ];
  }

  void _startBreathingSession() {
    _breathingTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      _isBreathingActive = true;
      _phaseIndex = 0;
      _phaseSecondsRemaining = _currentPattern[0].seconds;
      _totalBreathingSeconds = 0;
      _completedCycles = 0;
    });

    _breathingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isBreathingActive) return;
      setState(() {
        _totalBreathingSeconds++;
        if (_phaseSecondsRemaining > 1) {
          _phaseSecondsRemaining--;
        } else {
          final pattern = _currentPattern;
          _phaseIndex = (_phaseIndex + 1) % pattern.length;
          if (_phaseIndex == 0) {
            _completedCycles++;
          }
          _phaseSecondsRemaining = pattern[_phaseIndex].seconds;
          HapticFeedback.lightImpact();
        }
      });
    });
  }

  Future<void> _stopBreathingSession(HealthWellnessProvider provider) async {
    _breathingTimer?.cancel();
    _breathingTimer = null;

    final elapsed = _totalBreathingSeconds;
    setState(() {
      _isBreathingActive = false;
      _phaseIndex = 0;
      _phaseSecondsRemaining = _currentPattern[0].seconds;
    });

    if (elapsed >= 20) {
      final loggedMinutes = max(1, (elapsed / 60.0).round());
      await provider.addMindfulMinutes(loggedMinutes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🌿 Seren logged $loggedMinutes mindful minute${loggedMinutes > 1 ? 's' : ''} ($_completedCycles cycles)!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _syncWearableIfAvailable(
      BuildContext context, HealthWellnessProvider healthProvider) async {
    WearableProvider? wearable;
    try {
      wearable = Provider.of<WearableProvider>(context, listen: false);
    } catch (_) {
      wearable = null;
    }

    if (wearable == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wearable sync unavailable in test view.')),
        );
      }
      return;
    }

    if (!wearable.isConnected) {
      await wearable.connect(wearable.config.selectedPlatform);
    } else {
      await wearable.syncNow();
    }

    final record = wearable.latestRecord;
    if (record != null) {
      await healthProvider.ingestWearableRecord(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⌚ Synced ${record.stepCount ?? 0} steps, ${record.sleepDurationFormatted} sleep & ${record.restingHeartRate ?? "--"} bpm HR!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  double _readHydrationFraction(BuildContext context) {
    try {
      return Provider.of<HydrationProvider>(context).progressFraction;
    } catch (_) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: const EdgeInsets.only(top: 16, left: 18, right: 18, bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer<HealthWellnessProvider>(
        builder: (context, provider, _) {
          final hydrationFrac = _readHydrationFraction(context);
          final wellnessScore = provider.computeDailyWellnessScore(
            hydrationFraction: hydrationFrac,
          );
          final serenAccent = AppColors.adaptive(
            context,
            dark: _serenLight,
            light: _serenPurple,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
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
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _serenPurple.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.spa_rounded,
                      color: serenAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Seren Health Sanctuary',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _serenPurple.withValues(
                                  alpha: AppColors.isDark(context) ? 0.2 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _serenPurple.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'Score $wellnessScore',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: serenAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Steps • Sleep Cycles • Vitals • Calm Breathing',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.watch_rounded,
                        color: serenAccent, size: 20),
                    tooltip: 'Sync Wearable',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _syncWearableIfAvailable(context, provider),
                  ),
                  IconButton(
                    icon: Icon(Icons.tune_rounded,
                        color: AppColors.textSecondary(context), size: 20),
                    tooltip: 'Health Goals',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showGoalsDialog(context, provider),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.textSecondary(context), size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4-Tab Bar
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: _serenPurple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary(context),
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Steps'),
                    Tab(text: 'Sleep'),
                    Tab(text: 'Vitals'),
                    Tab(text: 'Breathe'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStepsTab(context, provider),
                    _buildSleepTab(context, provider),
                    _buildVitalsTab(context, provider),
                    _buildBreatheTab(context, provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 1: DAILY STEPS & MOVEMENT
  // ===========================================================================

  Widget _buildStepsTab(BuildContext context, HealthWellnessProvider provider) {
    final today = provider.todayActivity;
    final goals = provider.goals;
    final weeklyActivities = provider.getWeeklyActivities();
    final weeklyDates = provider.getWeeklyDates();
    final streak = provider.stepStreakDays;

    final maxChartSteps = max(
      goals.dailyStepGoal,
      weeklyActivities.fold<int>(0, (m, a) => max(m, a.steps)),
    );
    final distanceKm = today.distanceKmWithStride(goals.strideLengthMeters);
    final serenAccent =
        AppColors.adaptive(context, dark: _serenLight, light: _serenPurple);
    final emeraldAccent = AppColors.adaptive(
        context, dark: _emerald, light: const Color(0xFF047857));
    final skyAccent = AppColors.adaptive(
        context, dark: _skyBlue, light: const Color(0xFF0284C7));
    final amberAccent = AppColors.adaptive(
        context, dark: _amber, light: const Color(0xFFB45309));

    return ListView(
      children: [
        // Hero Step Progress Ring Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: today.isStepGoalMet
                  ? _emerald.withValues(alpha: 0.45)
                  : _serenPurple.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              // Circular Progress Gauge
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 102,
                      height: 102,
                      child: CircularProgressIndicator(
                        value: today.stepProgress,
                        strokeWidth: 9,
                        backgroundColor: AppColors.trackSurface(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          today.isStepGoalMet ? emeraldAccent : _serenPurple,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_walk_rounded,
                          size: 18,
                          color: today.isStepGoalMet ? emeraldAccent : serenAccent,
                        ),
                        Text(
                          NumberFormat('#,###').format(today.steps),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          '/ ${NumberFormat('#,###').format(today.stepGoal)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right-hand Metrics Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          today.isStepGoalMet
                              ? 'Goal Reached! 🎉'
                              : '${(today.stepProgress * 100).round()}% of Daily Goal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: today.isStepGoalMet
                                ? emeraldAccent
                                : AppColors.textPrimary(context),
                          ),
                        ),
                        if (streak > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _amber.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '🔥 ${streak}d',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: amberAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _stepMetricRow(context, Icons.route_rounded, skyAccent,
                        'Distance', '${distanceKm.toStringAsFixed(2)} km'),
                    const SizedBox(height: 6),
                    _stepMetricRow(
                        context,
                        Icons.local_fire_department_rounded,
                        amberAccent,
                        'Active Burn',
                        '${today.estimatedActiveCalories} kcal'),
                    const SizedBox(height: 6),
                    _stepMetricRow(
                        context,
                        Icons.timer_outlined,
                        emeraldAccent,
                        'Active Time',
                        '${today.activeMinutes} / ${today.activeMinutesGoal}m'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick Step & Walk Logging Strip
        Text(
          'QUICK LOG STEPS & MOVEMENT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary(context),
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quickActionChip(context, '+500 Steps', Icons.add_rounded, () {
              provider.addSteps(500);
            }),
            _quickActionChip(context, '+1,000', Icons.directions_walk_rounded,
                () {
              provider.addSteps(1000);
            }),
            _quickActionChip(context, '+2,500', Icons.directions_run_rounded,
                () {
              provider.addSteps(2500);
            }),
            _quickActionChip(context, '+15m Walk', Icons.park_rounded, () {
              provider.addSteps(1650, activeMinutesDelta: 15);
            }),
            _quickActionChip(context, 'Custom Steps', Icons.edit_rounded, () {
              _showCustomStepsDialog(context, provider);
            }, highlight: true),
          ],
        ),
        const SizedBox(height: 16),

        // 7-Day Steps Sparkline Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '7-Day Step Trend',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    'Avg ${NumberFormat('#,###').format(provider.weeklyAverageSteps)} / day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: serenAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (idx) {
                    final act = weeklyActivities[idx];
                    final dt = weeklyDates[idx];
                    final isToday = idx == 6;
                    final frac = maxChartSteps > 0
                        ? (act.steps / maxChartSteps).clamp(0.0, 1.0)
                        : 0.0;
                    final barH = max(6.0, frac * 84.0);
                    final isSel = _selectedStepDayIndex == idx;

                    final barColor = act.isStepGoalMet
                        ? _emerald
                        : (act.steps > 0
                            ? _serenPurple
                            : AppColors.trackSurface(context));

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedStepDayIndex = isSel ? null : idx;
                        }),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              act.steps >= 1000
                                  ? '${(act.steps / 1000).toStringAsFixed(1)}k'
                                  : (act.steps > 0 ? '${act.steps}' : '0'),
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: isSel ? 22 : 18,
                              height: barH,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(6),
                                border: (isToday || isSel)
                                    ? Border.all(
                                        color: AppColors.textPrimary(context),
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isToday ? 'Today' : DateFormat('E').format(dt),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    isToday ? FontWeight.w800 : FontWeight.w500,
                                color: isToday
                                    ? serenAccent
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (_selectedStepDayIndex != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.recessedSurface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Builder(builder: (_) {
                    final sel = weeklyActivities[_selectedStepDayIndex!];
                    final selDate = weeklyDates[_selectedStepDayIndex!];
                    return Text(
                      '${DateFormat('EEE, MMM d').format(selDate)}: ${NumberFormat('#,###').format(sel.steps)} steps • ${sel.distanceKm.toStringAsFixed(2)} km • ${sel.isStepGoalMet ? "Goal Met ✓" : "${sel.remainingSteps} remaining"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Weekly Total: ${NumberFormat('#,###').format(provider.weeklyTotalSteps)} steps',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary(context)),
                  ),
                  Text(
                    'Goals Met: ${provider.weeklyStepGoalsMetCount}/7d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: emeraldAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _stepMetricRow(BuildContext context, IconData icon, Color color,
      String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary(context)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _quickActionChip(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool highlight = false,
  }) {
    final serenAccent =
        AppColors.adaptive(context, dark: _serenLight, light: _serenPurple);
    return ActionChip(
      avatar: Icon(
        icon,
        size: 15,
        color: highlight ? Colors.white : serenAccent,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: highlight ? Colors.white : AppColors.textPrimary(context),
        ),
      ),
      backgroundColor:
          highlight ? _serenPurple : AppColors.elevatedSurface(context),
      side: BorderSide(
        color: highlight ? _serenPurple : AppColors.border(context),
      ),
      onPressed: onTap,
    );
  }

  // ===========================================================================
  // TAB 2: SLEEP TRACKING & ARCHITECTURE
  // ===========================================================================

  Widget _buildSleepTab(BuildContext context, HealthWellnessProvider provider) {
    final latestSleep = provider.latestSleepLog;
    final goals = provider.goals;
    final weeklyLogs = provider.getWeeklySleepLogs();
    final weeklyDates = provider.getWeeklyDates();
    final avgMin = provider.weeklyAverageSleepMinutes;
    final avgHrsStr = avgMin > 0
        ? '${avgMin ~/ 60}h ${(avgMin % 60).toString().padLeft(2, '0')}m'
        : '--';
    final debtMin = provider.weeklySleepDebtMinutes;
    final serenAccent =
        AppColors.adaptive(context, dark: _serenLight, light: _serenPurple);
    final emeraldAccent = AppColors.adaptive(
        context, dark: _emerald, light: const Color(0xFF047857));
    final skyAccent = AppColors.adaptive(
        context, dark: _skyBlue, light: const Color(0xFF0284C7));
    final amberAccent = AppColors.adaptive(
        context, dark: _amber, light: const Color(0xFFB45309));

    return ListView(
      children: [
        // Top Action Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showLogSleepDialog(context, provider),
                icon: const Icon(Icons.nightlight_round, size: 17),
                label: const Text(
                  'Log Sleep',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _serenPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => SleepCycleSheet.show(context),
                icon: Icon(Icons.waves_rounded, size: 17, color: skyAccent),
                label: Text(
                  'Cycles & Audio',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.border(context)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Latest Sleep Breakdown Card
        if (latestSleep != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _serenPurple.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Recorded Night (${latestSleep.dateKey})',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              latestSleep.formattedDuration,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${latestSleep.completedCycles} REM cycles',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: serenAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: latestSleep.qualityScore >= 80
                            ? _emerald.withValues(alpha: 0.18)
                            : _amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${latestSleep.qualityScore}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: latestSleep.qualityScore >= 80
                                  ? emeraldAccent
                                  : amberAccent,
                            ),
                          ),
                          Text(
                            '${latestSleep.qualityRating.emoji} ${latestSleep.qualityRating.label}',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textPrimary(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Bed ${DateFormat('HH:mm').format(latestSleep.bedtime)} → Wake ${DateFormat('HH:mm').format(latestSleep.wakeTime)} • ${latestSleep.sleepEfficiencyPercent}% efficiency',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context)),
                ),
                const SizedBox(height: 12),

                // Sleep Stages Stacked Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        if (latestSleep.deepMinutes > 0)
                          Expanded(
                            flex: latestSleep.deepMinutes,
                            child: Container(color: const Color(0xFF6366F1)),
                          ),
                        if (latestSleep.remMinutes > 0)
                          Expanded(
                            flex: latestSleep.remMinutes,
                            child: Container(color: _serenPurple),
                          ),
                        if (latestSleep.lightMinutes > 0)
                          Expanded(
                            flex: latestSleep.lightMinutes,
                            child: Container(color: _skyBlue),
                          ),
                        if (latestSleep.awakeMinutes > 0)
                          Expanded(
                            flex: latestSleep.awakeMinutes,
                            child: Container(color: _amber),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _stageLegend(context, const Color(0xFF6366F1), 'Deep',
                        '${latestSleep.deepMinutes}m'),
                    _stageLegend(context, _serenPurple, 'REM',
                        '${latestSleep.remMinutes}m'),
                    _stageLegend(context, skyAccent, 'Light',
                        '${latestSleep.lightMinutes}m'),
                    if (latestSleep.awakeMinutes > 0)
                      _stageLegend(context, amberAccent, 'Awake',
                          '${latestSleep.awakeMinutes}m'),
                  ],
                ),
                if (latestSleep.factors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: latestSleep.factors
                        .map((f) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.trackSurface(context),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textPrimary(context)),
                              ),
                            ))
                        .toList(),
                  ),
                ],
                if (latestSleep.notes != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '“${latestSleep.notes}”',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              children: [
                const Text('🌙', style: TextStyle(fontSize: 34)),
                const SizedBox(height: 8),
                Text(
                  'No sleep sessions recorded yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Log Sleep" or sync a wearable to track REM & Deep cycles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),

        // 7-Day Sleep Consistency Chart
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '7-Day Sleep Duration',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    'Target ${goals.formattedSleepTarget} • Avg $avgHrsStr',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: serenAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 112,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (idx) {
                    final log = weeklyLogs[idx];
                    final dt = weeklyDates[idx];
                    final isToday = idx == 6;
                    final mins = log?.durationMinutes ?? 0;
                    final frac =
                        (mins / max(goals.sleepTargetMinutes, 480)).clamp(0.0, 1.0);
                    final barH = mins > 0 ? max(10.0, frac * 76.0) : 6.0;
                    final isSel = _selectedSleepDayIndex == idx;

                    final meetsTarget =
                        log != null && log.meetsTarget(goals.sleepTargetMinutes);
                    final color = mins == 0
                        ? AppColors.trackSurface(context)
                        : (meetsTarget ? _emerald : const Color(0xFF6366F1));

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedSleepDayIndex = isSel ? null : idx;
                        }),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              mins > 0
                                  ? '${(mins / 60).toStringAsFixed(1)}h'
                                  : '-',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary(context)),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: isSel ? 22 : 18,
                              height: barH,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                                border: (isToday || isSel)
                                    ? Border.all(
                                        color: AppColors.textPrimary(context),
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isToday ? 'Today' : DateFormat('E').format(dt),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    isToday ? FontWeight.w800 : FontWeight.w500,
                                color: isToday
                                    ? serenAccent
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Avg Score: ${provider.weeklyAverageSleepScore}/100',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary(context)),
                  ),
                  Text(
                    debtMin > 0
                        ? 'Weekly Sleep Debt: ${debtMin ~/ 60}h ${debtMin % 60}m'
                        : 'Zero Sleep Debt 🌿',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: debtMin > 60 ? amberAccent : emeraldAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Past Logs
        if (provider.sleepLogs.isNotEmpty) ...[
          Text(
            'SLEEP HISTORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          ...provider.sleepLogs.map((log) => Card(
                color: AppColors.elevatedSurface(context),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.border(context)),
                ),
                child: ListTile(
                  leading: Text(
                    log.qualityRating.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    '${log.formattedDuration} • Score ${log.qualityScore}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  subtitle: Text(
                    '${log.dateKey} (${DateFormat('HH:mm').format(log.bedtime)}–${DateFormat('HH:mm').format(log.wakeTime)})',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary(context)),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.textSecondary(context)),
                    onPressed: () => provider.deleteSleepLog(log.id),
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _stageLegend(
      BuildContext context, Color color, String name, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$name $value',
          style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: HEART RATE & BODY VITALS
  // ===========================================================================

  Widget _buildVitalsTab(
      BuildContext context, HealthWellnessProvider provider) {
    final today = provider.todayActivity;
    final hr = provider.latestVitalOfType(VitalType.heartRate);
    final spo2 = provider.latestVitalOfType(VitalType.bloodOxygen);
    final bp = provider.latestVitalOfType(VitalType.bloodPressure);
    final weight = provider.latestVitalOfType(VitalType.bodyWeight);
    final isDark = AppColors.isDark(context);
    final serenAccent =
        AppColors.adaptive(context, dark: _serenLight, light: _serenPurple);
    final emeraldAccent = AppColors.adaptive(
        context, dark: _emerald, light: const Color(0xFF047857));
    final skyAccent = AppColors.adaptive(
        context, dark: _skyBlue, light: const Color(0xFF0284C7));
    final hrAccent = AppColors.adaptive(
        context, dark: const Color(0xFFEF4444), light: const Color(0xFFDC2626));

    return ListView(
      children: [
        // Quick Vitals Grid
        Row(
          children: [
            Expanded(
              child: _vitalTile(
                context,
                VitalType.heartRate,
                hr?.formattedValue ??
                    (today.restingHeartRate != null
                        ? '${today.restingHeartRate} bpm'
                        : '-- bpm'),
                hr?.statusLabel ?? 'No reading',
                hrAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _vitalTile(
                context,
                VitalType.bloodOxygen,
                spo2?.formattedValue ?? '-- %',
                spo2?.statusLabel ?? 'No reading',
                skyAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _vitalTile(
                context,
                VitalType.bloodPressure,
                bp?.formattedValue ?? '--/-- mmHg',
                bp?.statusLabel ?? 'No reading',
                serenAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _vitalTile(
                context,
                VitalType.bodyWeight,
                weight?.formattedValue ?? '-- kg',
                weight?.statusLabel ?? 'Check-in',
                emeraldAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Subjective Energy Check-In
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAILY ENERGY LEVEL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  (1, '🪫 Low'),
                  (2, '🥱 Mild'),
                  (3, '🙂 Steady'),
                  (4, '⚡ Good'),
                  (5, '✨ Peak'),
                ].map((opt) {
                  final selected = today.energyScore == opt.$1;
                  return InkWell(
                    onTap: () => provider.setEnergyScore(opt.$1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? _serenPurple.withValues(alpha: isDark ? 0.25 : 0.14)
                            : AppColors.sheetSurface(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? _serenPurple
                              : AppColors.border(context),
                        ),
                      ),
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected
                              ? (isDark ? Colors.white : _serenPurple)
                              : AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Log Vital CTA
        ElevatedButton.icon(
          onPressed: () => _showLogVitalDialog(context, provider),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text(
            'Record Vital Reading',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _serenPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),

        // Vitals History
        if (provider.vitalLogs.isNotEmpty) ...[
          Text(
            'RECENT READINGS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          ...provider.vitalLogs.map((v) => Card(
                color: AppColors.elevatedSurface(context),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.border(context)),
                ),
                child: ListTile(
                  leading: Text(v.type.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    '${v.type.label}: ${v.formattedValue}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  subtitle: Text(
                    '${v.statusLabel} • ${DateFormat('MMM d, HH:mm').format(v.recordedAt)}${v.note != null ? ' • ${v.note}' : ''}',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary(context)),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.textSecondary(context)),
                    onPressed: () => provider.deleteVitalLog(v.id),
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _vitalTile(BuildContext context, VitalType type, String value,
      String status, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(type.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: TextStyle(
                fontSize: 10, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: SEREN GUIDED BREATHING & MINDFUL MINUTES
  // ===========================================================================

  Widget _buildBreatheTab(
      BuildContext context, HealthWellnessProvider provider) {
    final today = provider.todayActivity;
    final pattern = _currentPattern;
    final currentPhase = pattern[_phaseIndex % pattern.length];
    final isDark = AppColors.isDark(context);
    final serenAccent =
        AppColors.adaptive(context, dark: _serenLight, light: _serenPurple);
    final emeraldAccent = AppColors.adaptive(
      context,
      dark: _emerald,
      light: const Color(0xFF047857),
    );

    return ListView(
      children: [
        // Breathing Pattern Switcher
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('4-7-8 Calm Sleep'),
                selected: !_useBoxBreathing,
                selectedColor:
                    _serenPurple.withValues(alpha: isDark ? 0.3 : 0.14),
                backgroundColor: AppColors.elevatedSurface(context),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: !_useBoxBreathing
                      ? serenAccent
                      : AppColors.textSecondary(context),
                ),
                onSelected: _isBreathingActive
                    ? null
                    : (_) => setState(() {
                          _useBoxBreathing = false;
                          _phaseIndex = 0;
                          _phaseSecondsRemaining = 4;
                        }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Box Focus (4-4-4-4)'),
                selected: _useBoxBreathing,
                selectedColor:
                    _serenPurple.withValues(alpha: isDark ? 0.3 : 0.14),
                backgroundColor: AppColors.elevatedSurface(context),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _useBoxBreathing
                      ? serenAccent
                      : AppColors.textSecondary(context),
                ),
                onSelected: _isBreathingActive
                    ? null
                    : (_) => setState(() {
                          _useBoxBreathing = true;
                          _phaseIndex = 0;
                          _phaseSecondsRemaining = 4;
                        }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Animated Breathing Circle Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  _isBreathingActive ? _serenPurple : AppColors.border(context),
            ),
          ),
          child: Column(
            children: [
              AnimatedScale(
                scale: _isBreathingActive ? currentPhase.scale : 1.0,
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _serenPurple.withValues(alpha: isDark ? 0.55 : 0.25),
                        _serenPurple.withValues(alpha: isDark ? 0.15 : 0.08),
                      ],
                    ),
                    border: Border.all(
                      color: serenAccent,
                      width: 2.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isBreathingActive ? '$_phaseSecondsRemaining' : '🌿',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppColors.adaptive(
                            context,
                            dark: Colors.white,
                            light: const Color(0xFF4C1D95),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isBreathingActive
                            ? currentPhase.label
                            : 'Ready to Breathe',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.adaptive(
                            context,
                            dark: Colors.white,
                            light: const Color(0xFF4C1D95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (_isBreathingActive)
                Text(
                  'Cycle ${_completedCycles + 1} • ${_totalBreathingSeconds}s elapsed',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary(context)),
                )
              else
                Text(
                  _useBoxBreathing
                      ? 'Inhale 4s • Hold 4s • Exhale 4s • Rest 4s'
                      : 'Inhale 4s • Hold 7s • Exhale 8s for deep relaxation',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context)),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_isBreathingActive) {
                      _stopBreathingSession(provider);
                    } else {
                      _startBreathingSession();
                    }
                  },
                  icon: Icon(_isBreathingActive
                      ? Icons.stop_circle_rounded
                      : Icons.play_arrow_rounded),
                  label: Text(
                    _isBreathingActive
                        ? 'Stop & Save Mindful Minutes'
                        : 'Start Guided Breathing',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isBreathingActive ? const Color(0xFFEF4444) : _serenPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Mindful Minutes Progress Strip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mindful Minutes: ${today.mindfulMinutes} / ${today.mindfulMinutesGoal}m',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: today.mindfulProgress,
                        minHeight: 6,
                        backgroundColor: AppColors.trackSurface(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          today.isMindfulGoalMet ? emeraldAccent : _serenPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => provider.addMindfulMinutes(5),
                style: OutlinedButton.styleFrom(
                  foregroundColor: serenAccent,
                  side: BorderSide(color: _serenPurple.withValues(alpha: 0.5)),
                ),
                child: const Text('+5m Calm'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DIALOGS (CUSTOM STEPS, LOG SLEEP, LOG VITAL, HEALTH GOALS)
  // ===========================================================================

  void _showCustomStepsDialog(
      BuildContext context, HealthWellnessProvider provider) {
    final stepsCtrl = TextEditingController(
      text: '${provider.todayActivity.steps}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adaptive(
          ctx,
          dark: const Color(0xFF1E2028),
          light: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Update Today Steps',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(ctx))),
        content: TextField(
          controller: stepsCtrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: AppColors.textPrimary(ctx)),
          decoration: InputDecoration(
            labelText: 'Total Steps Today',
            filled: true,
            fillColor: AppColors.adaptive(
              ctx,
              dark: const Color(0xFF16171D),
              light: const Color(0xFFF1F4F8),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(stepsCtrl.text.trim());
              if (val != null && val >= 0) {
                provider.setStepsForDate(val);
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _serenPurple),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLogSleepDialog(
      BuildContext context, HealthWellnessProvider provider) {
    final now = DateTime.now();
    TimeOfDay bedtime = const TimeOfDay(hour: 23, minute: 0);
    TimeOfDay wakeTime = const TimeOfDay(hour: 6, minute: 30);
    SleepQualityRating selectedRating = SleepQualityRating.restorative;
    final selectedFactors = <String>{};
    final notesCtrl = TextEditingController();

    final availableFactors = [
      'Wind-Down Audio',
      'Low Screen',
      'No Late Caffeine',
      'Evening Walk',
      'Restless',
      'Stress',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final wakeDt =
              DateTime(now.year, now.month, now.day, wakeTime.hour, wakeTime.minute);
          var bedDt = DateTime(
              now.year, now.month, now.day, bedtime.hour, bedtime.minute);
          if (!bedDt.isBefore(wakeDt)) {
            bedDt = bedDt.subtract(const Duration(days: 1));
          }
          final mins = wakeDt.difference(bedDt).inMinutes.clamp(1, 1440);
          final previewDur = '${mins ~/ 60}h ${mins % 60}m';
          final isDark = AppColors.isDark(ctx);
          final fieldFill = AppColors.adaptive(
            ctx,
            dark: const Color(0xFF16171D),
            light: const Color(0xFFF1F4F8),
          );
          final serenAccent = AppColors.adaptive(
              ctx, dark: _serenLight, light: _serenPurple);

          return AlertDialog(
            backgroundColor: AppColors.adaptive(
              ctx,
              dark: const Color(0xFF1E2028),
              light: Colors.white,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Text('🌙', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text('Log Sleep Session',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(ctx))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: bedtime,
                            );
                            if (picked != null) {
                              setDialogState(() => bedtime = picked);
                            }
                          },
                          child: Text(
                            'Bed ${bedtime.format(ctx)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: wakeTime,
                            );
                            if (picked != null) {
                              setDialogState(() => wakeTime = picked);
                            }
                          },
                          child: Text(
                            'Wake ${wakeTime.format(ctx)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Total Sleep Duration: $previewDur',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: serenAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SLEEP QUALITY',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(ctx)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: SleepQualityRating.values.map((r) {
                      final isSel = selectedRating == r;
                      return ChoiceChip(
                        label: Text('${r.emoji} ${r.label}'),
                        selected: isSel,
                        selectedColor:
                            _serenPurple.withValues(alpha: isDark ? 0.3 : 0.16),
                        backgroundColor: fieldFill,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: isSel
                              ? (isDark ? Colors.white : _serenPurple)
                              : AppColors.textPrimary(ctx),
                        ),
                        onSelected: (v) {
                          if (v) setDialogState(() => selectedRating = r);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SLEEP FACTORS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(ctx)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: availableFactors.map((f) {
                      final isSel = selectedFactors.contains(f);
                      return FilterChip(
                        label: Text(
                          f,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSel
                                ? AppColors.adaptive(
                                    ctx,
                                    dark: Colors.white,
                                    light: const Color(0xFF065F46),
                                  )
                                : AppColors.textPrimary(ctx),
                          ),
                        ),
                        selected: isSel,
                        selectedColor:
                            _emerald.withValues(alpha: isDark ? 0.25 : 0.16),
                        backgroundColor: fieldFill,
                        onSelected: (v) => setDialogState(() {
                          if (v) {
                            selectedFactors.add(f);
                          } else {
                            selectedFactors.remove(f);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(
                        color: AppColors.textPrimary(ctx), fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Optional sleep or dream notes...',
                      hintStyle: TextStyle(color: AppColors.textMuted(ctx)),
                      filled: true,
                      fillColor: fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await provider.logSleepSession(
                    bedtime: bedDt,
                    wakeTime: wakeDt,
                    qualityRating: selectedRating,
                    factors: selectedFactors.toList(),
                    notes: notesCtrl.text,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: _serenPurple),
                child: const Text('Save Sleep',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLogVitalDialog(
      BuildContext context, HealthWellnessProvider provider) {
    VitalType selectedType = VitalType.heartRate;
    final primaryCtrl = TextEditingController(text: '64');
    final secondaryCtrl = TextEditingController(text: '78');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = AppColors.isDark(ctx);
          final fieldFill = AppColors.adaptive(
            ctx,
            dark: const Color(0xFF16171D),
            light: const Color(0xFFF1F4F8),
          );
          return AlertDialog(
            backgroundColor: AppColors.adaptive(
              ctx,
              dark: const Color(0xFF1E2028),
              light: Colors.white,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Record Body Vital',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(ctx))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: VitalType.values.map((t) {
                      final isSel = selectedType == t;
                      return ChoiceChip(
                        label: Text('${t.emoji} ${t.label}',
                            style: TextStyle(
                                fontSize: 11,
                                color: isSel
                                    ? (isDark ? Colors.white : _serenPurple)
                                    : AppColors.textPrimary(ctx))),
                        selected: isSel,
                        selectedColor:
                            _serenPurple.withValues(alpha: isDark ? 0.3 : 0.16),
                        backgroundColor: fieldFill,
                        onSelected: (val) {
                          if (!val) return;
                          setDialogState(() {
                            selectedType = t;
                            switch (t) {
                              case VitalType.heartRate:
                                primaryCtrl.text = '64';
                                break;
                              case VitalType.bloodOxygen:
                                primaryCtrl.text = '98';
                                break;
                              case VitalType.bloodPressure:
                                primaryCtrl.text = '118';
                                secondaryCtrl.text = '78';
                                break;
                              case VitalType.bodyWeight:
                                primaryCtrl.text = '68.0';
                                break;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: primaryCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppColors.textPrimary(ctx)),
                    decoration: InputDecoration(
                      labelText: selectedType == VitalType.bloodPressure
                          ? 'Systolic (mmHg)'
                          : '${selectedType.label} (${selectedType.unit})',
                      filled: true,
                      fillColor: fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (selectedType == VitalType.bloodPressure) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: secondaryCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.textPrimary(ctx)),
                      decoration: InputDecoration(
                        labelText: 'Diastolic (mmHg)',
                        filled: true,
                        fillColor: fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    style: TextStyle(
                        color: AppColors.textPrimary(ctx), fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Context note (e.g. Morning resting)',
                      hintStyle: TextStyle(color: AppColors.textMuted(ctx)),
                      filled: true,
                      fillColor: fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final primary = double.tryParse(primaryCtrl.text.trim());
                  final secondary = selectedType == VitalType.bloodPressure
                      ? double.tryParse(secondaryCtrl.text.trim())
                      : null;
                  if (primary != null && primary > 0) {
                    await provider.logVital(
                      type: selectedType,
                      primaryValue: primary,
                      secondaryValue: secondary,
                      note: noteCtrl.text,
                    );
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: _serenPurple),
                child:
                    const Text('Record', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGoalsDialog(
      BuildContext context, HealthWellnessProvider provider) {
    var draft = provider.goals;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.adaptive(
            ctx,
            dark: const Color(0xFF1E2028),
            light: Colors.white,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Seren Wellness Goals',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(ctx))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Step Goal: ${NumberFormat('#,###').format(draft.dailyStepGoal)} steps',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(ctx)),
                ),
                Slider(
                  value: draft.dailyStepGoal.toDouble(),
                  min: 3000,
                  max: 20000,
                  divisions: 17,
                  activeColor: _serenPurple,
                  onChanged: (v) => setDialogState(() {
                    draft = draft.copyWith(dailyStepGoal: v.round());
                  }),
                ),
                Text(
                  'Sleep Target: ${draft.formattedSleepTarget}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(ctx)),
                ),
                Slider(
                  value: draft.sleepTargetMinutes.toDouble(),
                  min: 360,
                  max: 570,
                  divisions: 7,
                  activeColor: _serenPurple,
                  onChanged: (v) => setDialogState(() {
                    draft = draft.copyWith(sleepTargetMinutes: v.round());
                  }),
                ),
                Text(
                  'Active Minutes Goal: ${draft.dailyActiveMinutesGoal} mins',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(ctx)),
                ),
                Slider(
                  value: draft.dailyActiveMinutesGoal.toDouble(),
                  min: 15,
                  max: 90,
                  divisions: 5,
                  activeColor: _emerald,
                  onChanged: (v) => setDialogState(() {
                    draft = draft.copyWith(dailyActiveMinutesGoal: v.round());
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Afternoon Move Nudge',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textPrimary(ctx))),
                  subtitle: Text('Gentle 15:00 movement reminder',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary(ctx))),
                  value: draft.moveReminderEnabled,
                  activeThumbColor: _serenPurple,
                  onChanged: (v) => setDialogState(() {
                    draft = draft.copyWith(moveReminderEnabled: v);
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await provider.updateGoals(draft);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _serenPurple),
              child: const Text('Apply Goals',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

