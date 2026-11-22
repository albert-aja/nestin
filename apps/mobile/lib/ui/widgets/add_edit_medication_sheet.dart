import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/medication_item.dart';
import '../../providers/medication_provider.dart';

class AddEditMedicationSheet extends StatefulWidget {
  final MedicationItem? initialItem;

  const AddEditMedicationSheet({super.key, this.initialItem});

  static Future<void> show(BuildContext context, {MedicationItem? item}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditMedicationSheet(initialItem: item),
    );
  }

  @override
  State<AddEditMedicationSheet> createState() => _AddEditMedicationSheetState();
}

class _AddEditMedicationSheetState extends State<AddEditMedicationSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _dosageAmountController;
  late TextEditingController _currentStockController;
  late TextEditingController _refillThresholdController;
  late TextEditingController _notesController;

  String _dosageUnit = 'pills';
  MealInstruction _mealInstruction = MealInstruction.anytime;
  List<String> _scheduleTimes = ['08:00'];
  List<int> _daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
  bool _enableInventory = true;
  String _colorHex = '#8B5CF6';

  final List<String> _commonUnits = ['pills', 'mg', 'ml', 'drops', 'mcg', 'puffs'];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _dosageAmountController = TextEditingController(
        text: item != null
            ? (item.dosageAmount % 1 == 0
                ? item.dosageAmount.toInt().toString()
                : item.dosageAmount.toString())
            : '1');
    _currentStockController =
        TextEditingController(text: item?.currentStock?.toString() ?? '30');
    _refillThresholdController =
        TextEditingController(text: item?.refillThreshold?.toString() ?? '5');
    _notesController = TextEditingController(text: item?.notes ?? '');

    if (item != null) {
      _dosageUnit = item.dosageUnit;
      _mealInstruction = item.mealInstruction;
      _scheduleTimes = List.from(item.scheduleTimes);
      _daysOfWeek = List.from(item.daysOfWeek);
      _enableInventory = item.currentStock != null;
      _colorHex = item.colorHex;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageAmountController.dispose();
    _currentStockController.dispose();
    _refillThresholdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduleTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      final formatted = '$hourStr:$minStr';

      if (!_scheduleTimes.contains(formatted)) {
        setState(() {
          _scheduleTimes.add(formatted);
          _scheduleTimes.sort();
        });
      }
    }
  }

  void _removeScheduleTime(String time) {
    final l10n = context.l10n;
    if (_scheduleTimes.length > 1) {
      setState(() {
        _scheduleTimes.remove(time);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.tr('at_least_one_schedule_time_is'),
          ),
        ),
      );
    }
  }

  void _saveMedication() {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_scheduleTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.tr('add_at_least_one_reminder_time'),
          ),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final dosageAmount = double.tryParse(_dosageAmountController.text) ?? 1.0;
    final currentStock = _enableInventory
        ? int.tryParse(_currentStockController.text)
        : null;
    final refillThreshold = _enableInventory
        ? int.tryParse(_refillThresholdController.text) ?? 5
        : 5;
    final notes = _notesController.text.trim().isNotEmpty
        ? _notesController.text.trim()
        : null;

    final provider = Provider.of<MedicationProvider>(context, listen: false);

    if (widget.initialItem == null) {
      final newItem = MedicationItem(
        id: const Uuid().v4(),
        name: name,
        dosageAmount: dosageAmount,
        dosageUnit: _dosageUnit,
        mealInstruction: _mealInstruction,
        scheduleTimes: _scheduleTimes,
        daysOfWeek: _daysOfWeek,
        currentStock: currentStock,
        refillThreshold: refillThreshold,
        refillWarningEnabled: _enableInventory,
        notes: notes,
        colorHex: _colorHex,
        createdAt: DateTime.now(),
      );
      provider.addMedication(newItem);
    } else {
      final updated = widget.initialItem!.copyWith(
        name: name,
        dosageAmount: dosageAmount,
        dosageUnit: _dosageUnit,
        mealInstruction: _mealInstruction,
        scheduleTimes: _scheduleTimes,
        daysOfWeek: _daysOfWeek,
        currentStock: currentStock,
        clearStock: !_enableInventory,
        refillThreshold: refillThreshold,
        refillWarningEnabled: _enableInventory,
        notes: notes,
        clearNotes: notes == null,
        colorHex: _colorHex,
      );
      provider.updateMedication(updated);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialItem != null;
    final dayInitials = l10n.isIndonesian
        ? const ['S', 'S', 'R', 'K', 'J', 'S', 'M']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final violetAccent = AppColors.adaptive(
      context,
      dark: const Color(0xFFA78BFA),
      light: const Color(0xFF7C3AED),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.medication_rounded,
                        color: violetAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing
                          ? l10n.tr('edit_medication')
                          : l10n.tr('add_medication'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
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
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: ListView(
                children: [
                  // Medication Name
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.tr('medication_or_supplement_name'),
                      labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                      hintText: l10n.tr('e_g_vitamin_d3_amoxicillin_omega'),
                      hintStyle: TextStyle(color: AppColors.textMuted(context)),
                      prefixIcon: Icon(Icons.vaccines_rounded, color: violetAccent),
                      filled: true,
                      fillColor: AppColors.elevatedSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.tr('please_enter_a_name')
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Dosage Amount & Unit Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _dosageAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.tr('dose_amount'),
                            labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                            filled: true,
                            fillColor: AppColors.elevatedSurface(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) => (v == null || double.tryParse(v) == null)
                              ? l10n.tr('invalid')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          initialValue: _dosageUnit,
                          dropdownColor: AppColors.sheetSurface(context),
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.tr('unit'),
                            labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                            filled: true,
                            fillColor: AppColors.elevatedSurface(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _commonUnits.map((u) {
                            return DropdownMenuItem(
                              value: u,
                              child: Text(MedicationItem.localizeUnit(u)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _dosageUnit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Meal Instruction
                  Text(
                    l10n.tr('meal_instruction'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MealInstruction.values.map((instruction) {
                      final isSelected = _mealInstruction == instruction;
                      return ChoiceChip(
                        label: Text('${instruction.iconEmoji} ${instruction.label}'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.24),
                        backgroundColor: AppColors.elevatedSurface(context),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? violetAccent
                              : AppColors.textSecondary(context),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF8B5CF6)
                              : AppColors.border(context),
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _mealInstruction = instruction);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Schedule Times
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.tr('dose_schedule_times'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary(context),
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickScheduleTime,
                        icon: Icon(Icons.add_alarm_rounded, size: 16, color: violetAccent),
                        label: Text(
                          l10n.tr('add_time'),
                          style: TextStyle(color: violetAccent, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _scheduleTimes.map((timeStr) {
                      return Chip(
                        avatar: Icon(Icons.access_time_rounded, size: 16, color: violetAccent),
                        label: Text(
                          timeStr,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: AppColors.elevatedSurface(context),
                        deleteIcon: Icon(
                          Icons.cancel_rounded,
                          size: 16,
                          color: AppColors.textSecondary(context),
                        ),
                        onDeleted: () => _removeScheduleTime(timeStr),
                        side: BorderSide(color: AppColors.border(context)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Days of the Week
                  Text(
                    l10n.tr('repeat_days'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (int day = 1; day <= 7; day++) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_daysOfWeek.contains(day)) {
                                if (_daysOfWeek.length > 1) _daysOfWeek.remove(day);
                              } else {
                                _daysOfWeek.add(day);
                                _daysOfWeek.sort();
                              }
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _daysOfWeek.contains(day)
                                  ? const Color(0xFF8B5CF6)
                                  : AppColors.elevatedSurface(context),
                              border: Border.all(
                                color: _daysOfWeek.contains(day)
                                    ? Colors.transparent
                                    : AppColors.border(context),
                              ),
                            ),
                            child: Text(
                              dayInitials[day - 1],
                              style: TextStyle(
                                color: _daysOfWeek.contains(day)
                                    ? Colors.white
                                    : AppColors.textSecondary(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Inventory & Refill Warnings Card
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
                            Row(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 18, color: violetAccent),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.tr('pill_inventory_refill_alert'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _enableInventory,
                              activeThumbColor: const Color(0xFF8B5CF6),
                              onChanged: (v) => setState(() => _enableInventory = v),
                            ),
                          ],
                        ),
                        if (_enableInventory) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _currentStockController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    color: AppColors.textPrimary(context),
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: l10n.tr('current_stock'),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.sheetSurface(context),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _refillThresholdController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    color: AppColors.textPrimary(context),
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: l10n.tr('refill_warning_at'),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.sheetSurface(context),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr('decrements_automatically_when_marked_taken_alerts'),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Optional Notes
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.tr('special_notes_instructions'),
                      labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                      hintText: l10n.tr('e_g_drink_full_glass_of'),
                      hintStyle: TextStyle(color: AppColors.textMuted(context)),
                      filled: true,
                      fillColor: AppColors.elevatedSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Save Button
            ElevatedButton(
              onPressed: _saveMedication,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isEditing
                    ? l10n.tr('save_changes')
                    : l10n.tr('add_medication'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

