import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/routine_item.dart';
import '../../../providers/routine_provider.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  void _showAddRoutineDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final step1Controller = TextEditingController();
    final step2Controller = TextEditingController();
    final step3Controller = TextEditingController();
    RoutineType type = RoutineType.custom;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.sheetSurface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('New Habit Routine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Routine Name', prefixIcon: Icon(Icons.fitness_center_rounded)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Purpose / Description'),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Steps to complete daily:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(controller: step1Controller, decoration: const InputDecoration(hintText: 'Step 1')),
                    const SizedBox(height: 6),
                    TextField(controller: step2Controller, decoration: const InputDecoration(hintText: 'Step 2')),
                    const SizedBox(height: 6),
                    TextField(controller: step3Controller, decoration: const InputDecoration(hintText: 'Step 3')),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        final t = titleController.text.trim();
                        final steps = [
                          step1Controller.text.trim(),
                          step2Controller.text.trim(),
                          step3Controller.text.trim(),
                        ].where((s) => s.isNotEmpty).toList();

                        if (t.isNotEmpty && steps.isNotEmpty) {
                          Provider.of<RoutineProvider>(context, listen: false).addRoutine(
                            RoutineItem(
                              id: const Uuid().v4(),
                              title: t,
                              description: descController.text.trim(),
                              type: type,
                              steps: steps,
                              createdAt: DateTime.now(),
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Create Routine', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routineProvider = Provider.of<RoutineProvider>(context);
    final routines = routineProvider.routines;

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: routines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final r = routines[index];
          final isMorning = r.type == RoutineType.morning;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isMorning ? AppColors.accent : const Color(0xFF8338EC)).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isMorning ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
                          color: isMorning ? AppColors.accent : const Color(0xFF8338EC),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            if (r.description.isNotEmpty)
                              Text(
                                r.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (r.streakCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color: AppColors.adaptive(
                                  context,
                                  dark: AppColors.primaryLight,
                                  light: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${r.streakCount}d',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.adaptive(
                                    context,
                                    dark: AppColors.primaryLight,
                                    light: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: r.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.trackSurface(context),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        r.isCompletedToday ? AppColors.success : AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Checklist of steps
                  ...r.steps.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final stepText = entry.value;
                    final isChecked = r.completedStepIndices.contains(idx);

                    return InkWell(
                      onTap: () => routineProvider.toggleStep(r.id, idx),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isChecked
                                  ? AppColors.success
                                  : AppColors.textSecondary(context),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stepText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                  color: isChecked
                                      ? AppColors.textSecondary(context)
                                      : AppColors.textPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRoutineDialog(context),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('New Routine', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
      ),
    );
  }
}

