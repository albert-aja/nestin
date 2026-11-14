import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/medication_item.dart';
import '../../data/models/medication_log.dart';
import '../../providers/medication_provider.dart';
import 'add_edit_medication_sheet.dart';

class MedicationTrackerSheet extends StatefulWidget {
  const MedicationTrackerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MedicationTrackerSheet(),
    );
  }

  @override
  State<MedicationTrackerSheet> createState() => _MedicationTrackerSheetState();
}

class _MedicationTrackerSheetState extends State<MedicationTrackerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _promptRefillDialog(BuildContext context, MedicationItem med) {
    int refillAmount = 30;
    showDialog(
      context: context,
      builder: (ctx) {
        final violetAccent = AppColors.adaptive(
          ctx,
          dark: const Color(0xFFA78BFA),
          light: const Color(0xFF7C3AED),
        );
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.sheetSurface(ctx),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: violetAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Refill ${med.name}',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textPrimary(ctx),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current stock: ${med.currentStock ?? 0} ${med.dosageUnit}',
                    style: TextStyle(
                      color: AppColors.textSecondary(ctx),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select refill quantity:',
                    style: TextStyle(
                      color: AppColors.textPrimary(ctx),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [10, 30, 60, 90].map((qty) {
                      final isSel = refillAmount == qty;
                      return ChoiceChip(
                        label: Text('+$qty'),
                        selected: isSel,
                        selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        backgroundColor: AppColors.elevatedSurface(ctx),
                        labelStyle: TextStyle(
                          color: isSel ? violetAccent : AppColors.textPrimary(ctx),
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (val) {
                          if (val) setDialogState(() => refillAmount = qty);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary(ctx)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Provider.of<MedicationProvider>(context, listen: false)
                        .refillMedication(med.id, refillAmount);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Refilled +$refillAmount ${med.dosageUnit} of ${med.name}')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Confirm Refill', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final violetAccent = AppColors.adaptive(
      context,
      dark: const Color(0xFFA78BFA),
      light: const Color(0xFF7C3AED),
    );
    final emeraldText = AppColors.adaptive(
      context,
      dark: const Color(0xFF10B981),
      light: const Color(0xFF047857),
    );
    final amberText = AppColors.adaptive(
      context,
      dark: const Color(0xFFF59E0B),
      light: const Color(0xFFB45309),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer<MedicationProvider>(
        builder: (context, provider, _) {
          final todayDoses = provider.todayDoses;
          final streak = provider.adherenceStreakDays;
          final weeklyRate = (provider.weeklyAdherenceRate * 100).round();
          final lowStockMeds = provider.lowStockMedications;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.medication_rounded,
                          color: violetAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medication & Pill Tracker',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            'Seren Wellness Companion',
                            style: TextStyle(
                              fontSize: 11,
                              color: violetAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
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
              const SizedBox(height: 12),

              // Streak & Adherence Badge Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              streak > 0 ? '$streak-Day Streak' : 'Start Your Streak',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              streak > 0
                                  ? 'Consecutive perfect adherence days'
                                  : 'Take your doses consistently',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: weeklyRate >= 80
                            ? const Color(0xFF10B981).withValues(alpha: 0.18)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$weeklyRate% 7d Adherence',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: weeklyRate >= 80 ? emeraldText : amberText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Refill Alert Banner (if any active meds low)
              if (lowStockMeds.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: amberText, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Low Supply Warning',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: amberText,
                              ),
                            ),
                            Text(
                              '${lowStockMeds.first.name} has only ${lowStockMeds.first.currentStock} left!',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _promptRefillDialog(context, lowStockMeds.first),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: Text(
                          '+ Refill',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: amberText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Tab Bar (Today's Doses vs Cabinet)
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary(context),
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(text: "Today's Doses (${provider.todayDosesTakenCount}/${provider.todayDosesTotalCount})"),
                    Tab(text: "Cabinet (${provider.activeMedications.length})"),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Today's Doses
                    _buildTodayDosesTab(context, provider, todayDoses),

                    // Tab 2: Cabinet & Inventory
                    _buildCabinetTab(context, provider),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Add Medication Button
              ElevatedButton.icon(
                onPressed: () => AddEditMedicationSheet.show(context),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Add New Medication',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodayDosesTab(
    BuildContext context,
    MedicationProvider provider,
    List<TodayDoseSlot> doses,
  ) {
    final violetAccent = AppColors.adaptive(
      context,
      dark: const Color(0xFFA78BFA),
      light: const Color(0xFF7C3AED),
    );
    final emeraldText = AppColors.adaptive(
      context,
      dark: const Color(0xFF10B981),
      light: const Color(0xFF047857),
    );
    final amberText = AppColors.adaptive(
      context,
      dark: const Color(0xFFF59E0B),
      light: const Color(0xFFB45309),
    );

    if (doses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 44,
              color: AppColors.textMuted(context),
            ),
            const SizedBox(height: 12),
            Text(
              'No medications scheduled for today',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "+ Add New Medication" to create your dosage schedule.',
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final allTaken = doses.isNotEmpty && doses.every((d) => d.isTaken);

    return ListView(
      children: [
        if (allTaken) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.stars_rounded, color: emeraldText, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🌿 Wonderful! All doses taken for today. Keep up the restorative wellness rhythm.',
                    style: TextStyle(
                      fontSize: 12,
                      color: emeraldText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        ...doses.map((slot) {
          final med = slot.medication;
          final isTaken = slot.isTaken;
          final isSkipped = slot.isSkipped;
          final isPending = slot.isPending;

          return Card(
            color: isTaken
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : AppColors.elevatedSurface(context),
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isTaken
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : (isPending ? AppColors.border(context) : Colors.transparent),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Time Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sheetSurface(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: violetAccent),
                            const SizedBox(width: 4),
                            Text(
                              slot.timeString,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Meal Instruction Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${med.mealInstruction.iconEmoji} ${med.mealInstruction.shortLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: violetAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Medicine Name, Dose & Snooze Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              med.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              med.dosageString,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            if (slot.isSnoozed) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.snooze_rounded,
                                      size: 13,
                                      color: amberText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      slot.snooze!.snoozeCount > 1
                                          ? 'Snoozed until ${slot.snooze!.formattedSnoozedUntil} (${slot.snooze!.snoozeCount}x)'
                                          : 'Snoozed until ${slot.snooze!.formattedSnoozedUntil}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: amberText,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => provider.cancelSnooze(
                                        medicationId: med.id,
                                        timeString: slot.timeString,
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 13,
                                        color: amberText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isTaken) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 14, color: emeraldText),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Taken',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: emeraldText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.undo_rounded,
                                  size: 16, color: AppColors.textSecondary(context)),
                              tooltip: 'Undo',
                              onPressed: () {
                                if (slot.log != null) {
                                  provider.undoDose(slot.log!.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ] else if (isSkipped) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.trackSurface(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Skipped',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.undo_rounded,
                                  size: 16, color: AppColors.textSecondary(context)),
                              tooltip: 'Undo',
                              onPressed: () {
                                if (slot.log != null) {
                                  provider.undoDose(slot.log!.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        children: [
                          // 1-Tap Snooze 15m Button
                          OutlinedButton.icon(
                            onPressed: () async {
                              final snoozed = await provider.snoozeDose(
                                medicationId: med.id,
                                timeString: slot.timeString,
                              );
                              if (!context.mounted || snoozed == null) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '⏰ Snoozed ${med.name} 15m (next alert at ${snoozed.formattedSnoozedUntil})',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.snooze_rounded,
                              size: 14,
                              color: amberText,
                            ),
                            label: Text(
                              'Snooze 15m',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: amberText,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),

                          // 1-Tap Skip Button
                          OutlinedButton(
                            onPressed: () => provider.recordDose(
                              medicationId: med.id,
                              timeString: slot.timeString,
                              action: MedicationAction.skipped,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.border(context)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Skip',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context))),
                          ),

                          // 1-Tap Take Button
                          ElevatedButton.icon(
                            onPressed: () => provider.recordDose(
                              medicationId: med.id,
                              timeString: slot.timeString,
                              action: MedicationAction.taken,
                            ),
                            icon: const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white),
                            label: const Text('Take',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCabinetTab(BuildContext context, MedicationProvider provider) {
    final medications = provider.medications;
    final violetAccent = AppColors.adaptive(
      context,
      dark: const Color(0xFFA78BFA),
      light: const Color(0xFF7C3AED),
    );
    final amberText = AppColors.adaptive(
      context,
      dark: const Color(0xFFF59E0B),
      light: const Color(0xFFB45309),
    );

    if (medications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 44,
              color: AppColors.textMuted(context),
            ),
            const SizedBox(height: 12),
            Text(
              'Your medicine cabinet is empty',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your prescriptions, vitamins, or supplements below.',
              style: TextStyle(
                color: AppColors.textMuted(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: medications.map((med) {
        final isLow = med.isLowStock;

        return Card(
          color: AppColors.elevatedSurface(context),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isLow
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                  : AppColors.border(context),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: med.isActive
                                ? const Color(0xFF10B981)
                                : AppColors.textMuted(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          med.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: med.isActive
                                ? AppColors.textPrimary(context)
                                : AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: med.isActive,
                      activeColor: const Color(0xFF8B5CF6),
                      onChanged: (_) => provider.toggleActive(med.id),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${med.dosageString} • ${med.scheduleTimes.join(", ")}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${med.mealInstruction.shortLabel})',
                      style: TextStyle(fontSize: 11, color: violetAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Stock Badge
                    if (med.currentStock != null) ...[
                      Row(
                        children: [
                          Icon(
                            isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                            size: 14,
                            color: isLow
                                ? amberText
                                : AppColors.textSecondary(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stock: ${med.currentStock} ${med.dosageUnit}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isLow ? FontWeight.w700 : FontWeight.w500,
                              color: isLow
                                  ? amberText
                                  : AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Stock tracking disabled',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ],

                    // Action Icons
                    Row(
                      children: [
                        if (med.currentStock != null) ...[
                          IconButton(
                            icon: Icon(Icons.add_circle_outline_rounded,
                                size: 20, color: violetAccent),
                            tooltip: 'Refill Pills',
                            onPressed: () => _promptRefillDialog(context, med),
                          ),
                        ],
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.textSecondary(context),
                          ),
                          tooltip: 'Edit',
                          onPressed: () => AddEditMedicationSheet.show(context, item: med),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                          tooltip: 'Delete',
                          onPressed: () => provider.deleteMedication(med.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

