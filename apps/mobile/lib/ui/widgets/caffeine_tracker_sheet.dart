import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/caffeine_data.dart';
import '../../domain/sleep/caffeine_calculator.dart';
import '../../providers/alarm_provider.dart';
import '../../providers/caffeine_provider.dart';
import '../../providers/sleep_wellness_provider.dart';

import 'caffeine_summary_card.dart';

/// Full Seren Wellness bottom sheet for logging caffeine servings, inspecting
/// ~5-hour half-life decay to tonight's target bedtime, and setting curfew nudges.
class CaffeineTrackerSheet extends StatefulWidget {
  const CaffeineTrackerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CaffeineTrackerSheet(),
    );
  }

  @override
  State<CaffeineTrackerSheet> createState() => _CaffeineTrackerSheetState();
}

class _CaffeineTrackerSheetState extends State<CaffeineTrackerSheet> {
  int _selectedOffsetMinutes = 0; // 0 = Now, 60 = -1h, 120 = -2h, -1 = custom
  TimeOfDay? _customTime;

  static const Color _caffeineAmber = Color(0xFFD97706);

  T? _tryWatch<T>(BuildContext context) {
    try {
      return Provider.of<T>(context);
    } catch (_) {
      return null;
    }
  }

  DateTime _resolveTargetBedtime(
    BuildContext context,
    DateTime now,
    SleepWellnessProvider? sleepWellness,
    AlarmProvider? alarmProvider,
  ) {
    if (sleepWellness != null) {
      final nextAlarmTime = alarmProvider?.nextUpcomingAlarm?.nextOccurrence(now);
      return sleepWellness.getTargetBedtime(
        currentTime: now,
        nextAlarmTime: nextAlarmTime,
      );
    }
    var fallback = DateTime(now.year, now.month, now.day, 22, 30);
    if (fallback.isBefore(now)) {
      fallback = fallback.add(const Duration(days: 1));
    }
    return fallback;
  }

  DateTime _resolveSelectedConsumeTime(DateTime now) {
    if (_selectedOffsetMinutes == -1 && _customTime != null) {
      final candidate = DateTime(
        now.year,
        now.month,
        now.day,
        _customTime!.hour,
        _customTime!.minute,
      );
      return candidate.isAfter(now) ? now : candidate;
    }
    if (_selectedOffsetMinutes > 0) {
      return now.subtract(Duration(minutes: _selectedOffsetMinutes));
    }
    return now;
  }

  String _formatHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _logPreset(
    BuildContext context,
    CaffeineProvider caffeine,
    StimulantType type,
    DateTime targetBedtime,
  ) async {
    final l10n = context.l10n;
    final consumedAt = _resolveSelectedConsumeTime(DateTime.now());
    final entry = await caffeine.logDrink(
      type: type,
      consumedAt: consumedAt,
      isIndonesian: l10n.isIndonesian,
    );
    await caffeine.syncCurfewNotification(targetBedtime: targetBedtime);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.pick(
            '${entry.type.emoji} Logged ${entry.label} (~${entry.caffeineMg}mg)',
            '${entry.type.emoji} Mencatat ${entry.label} (~${entry.caffeineMg}mg)',
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openCustomDrinkDialog(
    BuildContext context,
    CaffeineProvider caffeine,
    DateTime targetBedtime,
  ) async {
    final l10n = context.l10n;
    final labelController = TextEditingController(
      text: l10n.pick('Iced Latte', 'Es Kopi Susu'),
    );
    final mgController = TextEditingController(text: '85');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.elevatedSurface(dialogCtx),
        title: Text(
          l10n.pick('Log Custom Stimulant', 'Catat Minuman Kustom'),
          style: TextStyle(color: AppColors.textPrimary(dialogCtx)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: InputDecoration(
                labelText: l10n.pick('Drink name', 'Nama minuman'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mgController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.pick('Caffeine (mg)', 'Kafein (mg)'),
                suffixText: 'mg',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.pick('Cancel', 'Batal')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _caffeineAmber),
            child: Text(
              l10n.pick('Log', 'Catat'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final parsedMg = int.tryParse(mgController.text.trim()) ?? 80;
    final consumedAt = _resolveSelectedConsumeTime(DateTime.now());
    await caffeine.logDrink(
      type: StimulantType.custom,
      caffeineMg: parsedMg.clamp(1, 1000),
      label: labelController.text.trim(),
      consumedAt: consumedAt,
      isIndonesian: l10n.isIndonesian,
    );
    await caffeine.syncCurfewNotification(targetBedtime: targetBedtime);
  }

  Future<void> _pickDrinkTime(BuildContext context) async {
    final now = DateTime.now();
    final initial = _customTime ?? TimeOfDay.fromDateTime(now);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() {
        _customTime = picked;
        _selectedOffsetMinutes = -1;
      });
    }
  }

  Future<void> _pickCurfewTime(
    BuildContext context,
    CaffeineProvider caffeine,
    DateTime targetBedtime,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: caffeine.config.curfewHour,
        minute: caffeine.config.curfewMinute,
      ),
    );
    if (picked != null && context.mounted) {
      await caffeine.updateConfig(
        caffeine.config.copyWith(
          curfewHour: picked.hour,
          curfewMinute: picked.minute,
          syncCurfewWithBedtime: false,
        ),
        targetBedtime: targetBedtime,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final caffeine = context.watch<CaffeineProvider>();
    final sleepWellness = _tryWatch<SleepWellnessProvider>(context);
    final alarmProvider = _tryWatch<AlarmProvider>(context);

    final now = DateTime.now();
    final targetBedtime = _resolveTargetBedtime(
      context,
      now,
      sleepWellness,
      alarmProvider,
    );

    final activeNowMg = caffeine.residualNow(now: now);
    final bedtimeResidualMg = caffeine.residualAt(targetBedtime);
    final impact = caffeine.impactAt(targetBedtime);
    final impactColor = CaffeineSummaryCard.impactColor(context, impact);
    final clearTime = caffeine.estimatedClearTime(fromTime: now);
    final todayTotalMg = caffeine.todayTotalMg;
    final limitMg = caffeine.dailyLimitMg;
    final curfewTime = caffeine.resolvedCurfewTime(
      referenceDate: now,
      targetBedtime: targetBedtime,
    );
    final pastCurfew = caffeine.isPastCurfew(
      now: now,
      targetBedtime: targetBedtime,
    );

    // 10-hour projection sampled every 2 hours starting from now (or covering bedtime).
    final horizonEnd = targetBedtime.isAfter(now.add(const Duration(hours: 8)))
        ? targetBedtime.add(const Duration(hours: 2))
        : now.add(const Duration(hours: 10));
    final curve = caffeine.buildDecayCurve(
      startTime: now,
      endTime: horizonEnd,
      step: const Duration(hours: 2),
    );
    final peakCurveMg = curve.fold<double>(
      caffeine.bedtimeSafeThresholdMg.toDouble(),
      (prev, pt) => pt.residualMg > prev ? pt.residualMg : prev,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _caffeineAmber.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.coffee_rounded,
                    color: _caffeineAmber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pick(
                          'Caffeine & Cutoff Tracker',
                          'Pelacak Kafein & Batas Sore',
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        l10n.pick(
                          'Seren ~${caffeine.halfLifeHours.toStringAsFixed(1)}h half-life decay to bedtime',
                          'Seren peluruhan paruh ~${caffeine.halfLifeHours.toStringAsFixed(1)} jam menuju jam tidur',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hero: Bedtime Residual & Active Caffeine
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: impactColor.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.pick(
                                'AT TONIGHT\'S BEDTIME (${_formatHm(targetBedtime)})',
                                'SAAT JAM TIDUR MALAM (${_formatHm(targetBedtime)})',
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.9,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${bedtimeResidualMg.round()} mg',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: impactColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.pick('residual est.', 'estimasi sisa'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: impactColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          CaffeineSummaryCard.impactLabel(l10n, impact),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: impactColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Secondary metric strip
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: l10n.pick('Active Now', 'Aktif Kini'),
                          value: '${activeNowMg.round()} mg',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          label: l10n.pick('Today Intake', 'Asupan Hari Ini'),
                          value: '$todayTotalMg / $limitMg mg',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          label: l10n.pick('Clears <25mg', 'Turun <25mg'),
                          value: clearTime != null
                              ? _formatHm(clearTime)
                              : l10n.pick('Clear', 'Bersih'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (todayTotalMg / limitMg).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.trackSurface(context),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        todayTotalMg > limitMg
                            ? const Color(0xFFEF4444)
                            : _caffeineAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Hourly Half-Life Decay Projection
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.pick(
                          'Half-Life Decay Curve',
                          'Kurva Peluruhan Kafein',
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        l10n.pick(
                          'Goal ≤${caffeine.bedtimeSafeThresholdMg}mg at ${_formatHm(targetBedtime)}',
                          'Target ≤${caffeine.bedtimeSafeThresholdMg}mg jam ${_formatHm(targetBedtime)}',
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 96,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: curve.map((point) {
                        final ratio = peakCurveMg > 0
                            ? (point.residualMg / peakCurveMg).clamp(0.05, 1.0)
                            : 0.05;
                        final isNearBedtime =
                            (point.time.difference(targetBedtime).inMinutes)
                                    .abs() <=
                                60;
                        final ptImpact = CaffeineCalculator.evaluateImpact(
                          point.residualMg,
                          safeThresholdMg: caffeine.bedtimeSafeThresholdMg,
                        );
                        final barColor = CaffeineSummaryCard.impactColor(
                          context,
                          ptImpact,
                        );

                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${point.residualMg.round()}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isNearBedtime
                                      ? barColor
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 42 * ratio,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                decoration: BoxDecoration(
                                  color: barColor.withValues(
                                    alpha: isNearBedtime ? 0.95 : 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: isNearBedtime
                                      ? Border.all(
                                          color: AppColors.textPrimary(context),
                                          width: 1.4,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatHm(point.time),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isNearBedtime
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isNearBedtime
                                      ? AppColors.textPrimary(context)
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick-Log Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.pick('Quick Log Serving', 'Catat Cepat Minuman'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                if (pastCurfew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.pick('Past Curfew', 'Lewat Batas Sore'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Consumed-at time selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TimeOffsetChip(
                    label: l10n.pick('Now', 'Sekarang'),
                    selected: _selectedOffsetMinutes == 0,
                    onTap: () => setState(() => _selectedOffsetMinutes = 0),
                  ),
                  const SizedBox(width: 6),
                  _TimeOffsetChip(
                    label: '-1h',
                    selected: _selectedOffsetMinutes == 60,
                    onTap: () => setState(() => _selectedOffsetMinutes = 60),
                  ),
                  const SizedBox(width: 6),
                  _TimeOffsetChip(
                    label: '-2h',
                    selected: _selectedOffsetMinutes == 120,
                    onTap: () => setState(() => _selectedOffsetMinutes = 120),
                  ),
                  const SizedBox(width: 6),
                  _TimeOffsetChip(
                    label: '-3h',
                    selected: _selectedOffsetMinutes == 180,
                    onTap: () => setState(() => _selectedOffsetMinutes = 180),
                  ),
                  const SizedBox(width: 6),
                  _TimeOffsetChip(
                    label: _selectedOffsetMinutes == -1 && _customTime != null
                        ? '${_customTime!.hour.toString().padLeft(2, '0')}:${_customTime!.minute.toString().padLeft(2, '0')}'
                        : l10n.pick('Pick Time', 'Pilih Jam'),
                    selected: _selectedOffsetMinutes == -1,
                    onTap: () => _pickDrinkTime(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...StimulantType.values
                    .where((t) => t != StimulantType.custom)
                    .map(
                      (type) => ActionChip(
                        avatar: Text(type.emoji),
                        label: Text(
                          '${type.localizedName(isIndonesian: l10n.isIndonesian)} • ${type.defaultMg}mg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        backgroundColor: AppColors.elevatedSurface(context),
                        side: BorderSide(
                          color: type.color.withValues(alpha: 0.45),
                        ),
                        onPressed: () => _logPreset(
                          context,
                          caffeine,
                          type,
                          targetBedtime,
                        ),
                      ),
                    ),
                ActionChip(
                  avatar: const Text('⚡'),
                  label: Text(
                    l10n.pick('Custom mg...', 'Kustom mg...'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  backgroundColor: AppColors.elevatedSurface(context),
                  side: BorderSide(color: AppColors.border(context)),
                  onPressed: () =>
                      _openCustomDrinkDialog(context, caffeine, targetBedtime),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Afternoon Curfew Nudge Configuration
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: caffeine.curfewEnabled
                      ? _caffeineAmber.withValues(alpha: 0.45)
                      : AppColors.border(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_paused_rounded,
                        color: _caffeineAmber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.pick(
                                'Afternoon Curfew Nudge',
                                'Pengingat Batas Kafein Sore',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              l10n.pick(
                                'Cutoff at ${_formatHm(curfewTime)} (${caffeine.config.syncCurfewWithBedtime ? '${caffeine.config.bedtimeCutOffLeadHours}h before bed' : 'fixed'})',
                                'Batas pukul ${_formatHm(curfewTime)} (${caffeine.config.syncCurfewWithBedtime ? '${caffeine.config.bedtimeCutOffLeadHours}j sebelum tidur' : 'jam tetap'})',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: caffeine.curfewEnabled,
                        activeThumbColor: _caffeineAmber,
                        onChanged: (val) => caffeine.toggleCurfewEnabled(
                          val,
                          targetBedtime: targetBedtime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final hour in const [12, 14, 16])
                        ChoiceChip(
                          label: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 11,
                              color: !caffeine.config.syncCurfewWithBedtime &&
                                      caffeine.config.curfewHour == hour &&
                                      caffeine.config.curfewMinute == 0
                                  ? Colors.white
                                  : AppColors.textSecondary(context),
                            ),
                          ),
                          selected: !caffeine.config.syncCurfewWithBedtime &&
                              caffeine.config.curfewHour == hour &&
                              caffeine.config.curfewMinute == 0,
                          selectedColor: _caffeineAmber,
                          backgroundColor: AppColors.trackSurface(context),
                          onSelected: (_) => caffeine.updateConfig(
                            caffeine.config.copyWith(
                              curfewHour: hour,
                              curfewMinute: 0,
                              syncCurfewWithBedtime: false,
                            ),
                            targetBedtime: targetBedtime,
                          ),
                        ),
                      ChoiceChip(
                        label: Text(
                          l10n.pick('8h Before Bed', '8j Sebelum Tidur'),
                          style: TextStyle(
                            fontSize: 11,
                            color: caffeine.config.syncCurfewWithBedtime
                                ? Colors.white
                                : AppColors.textSecondary(context),
                          ),
                        ),
                        selected: caffeine.config.syncCurfewWithBedtime,
                        selectedColor: const Color(0xFF8B5CF6),
                        backgroundColor: AppColors.trackSurface(context),
                        onSelected: (selected) => caffeine.updateConfig(
                          caffeine.config.copyWith(
                            syncCurfewWithBedtime: selected,
                          ),
                          targetBedtime: targetBedtime,
                        ),
                      ),
                      ActionChip(
                        label: Text(
                          l10n.pick('Custom Time', 'Atur Jam'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        backgroundColor: AppColors.recessedSurface(context),
                        onPressed: () =>
                            _pickCurfewTime(context, caffeine, targetBedtime),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        l10n.pick('Half-Life:', 'Waktu Paruh:'),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      for (final hl in const [4.0, 5.0, 6.0]) ...[
                        ChoiceChip(
                          label: Text(
                            '${hl.toStringAsFixed(0)}h',
                            style: TextStyle(
                              fontSize: 11,
                              color: (caffeine.halfLifeHours - hl).abs() < 0.01
                                  ? Colors.white
                                  : AppColors.textSecondary(context),
                            ),
                          ),
                          selected: (caffeine.halfLifeHours - hl).abs() < 0.01,
                          selectedColor: const Color(0xFF8B5CF6),
                          backgroundColor: AppColors.trackSurface(context),
                          onSelected: (_) => caffeine.updateConfig(
                            caffeine.config.copyWith(halfLifeHours: hl),
                            targetBedtime: targetBedtime,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await caffeine.testCurfewNudge(
                            targetBedtime: targetBedtime,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.pick(
                                  'Seren sent a test caffeine curfew nudge!',
                                  'Seren mengirim pengingat uji batas kafein!',
                                ),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text(
                          l10n.pick('Test Nudge', 'Uji Notif'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _caffeineAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Today's Intake History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.pick(
                    'Today\'s Drinks (${caffeine.todayEntries.length})',
                    'Minuman Hari Ini (${caffeine.todayEntries.length})',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                if (caffeine.todayEntries.isNotEmpty)
                  TextButton(
                    onPressed: () => caffeine.clearDayEntries(now),
                    child: Text(
                      l10n.pick('Clear Today', 'Hapus Hari Ini'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (caffeine.todayEntries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Text(
                  l10n.pick(
                    'No caffeine logged today. Tap Espresso, Coffee, Matcha, Tea, or Soda above to track bedtime clearance.',
                    'Belum ada kafein hari ini. Ketuk Espresso, Kopi, Matcha, Teh, atau Soda di atas untuk melacak sisa saat jam tidur.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              )
            else
              ...caffeine.todayEntries.map((entry) {
                final remainingFromDrink = CaffeineCalculator.residualFromEntryAt(
                  entry: entry,
                  targetTime: now,
                  halfLifeHours: caffeine.halfLifeHours,
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        entry.type.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              l10n.pick(
                                '${_formatHm(entry.consumedAt)} • ${entry.caffeineMg}mg dose (~${remainingFromDrink.round()}mg active)',
                                '${_formatHm(entry.consumedAt)} • dosis ${entry.caffeineMg}mg (~${remainingFromDrink.round()}mg aktif)',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.pick('Delete', 'Hapus'),
                        onPressed: () => caffeine.deleteEntry(entry.id),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.recessedSurface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeOffsetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeOffsetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textSecondary(context),
        ),
      ),
      selected: selected,
      selectedColor: const Color(0xFFD97706),
      backgroundColor: AppColors.trackSurface(context),
      onSelected: (_) => onTap(),
    );
  }
}
