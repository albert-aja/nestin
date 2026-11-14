import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
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
    if (_scheduleTimes.length > 1) {
      setState(() {
        _scheduleTimes.remove(time);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one schedule time is required.')),
      );
    }
  }

  void _saveMedication() {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduleTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one reminder time.')),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialItem != null;

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
                      isEditing ? 'Edit Medication' : 'Add Medication',
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
                      labelText: 'Medication or Supplement Name',
                      labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                      hintText: 'e.g. Vitamin D3, Amoxicillin, Omega-3',
                      hintStyle: TextStyle(color: AppColors.textMuted(context)),
                      prefixIcon: Icon(Icons.vaccines_rounded, color: violetAccent),
                      filled: true,
                      fillColor: AppColors.elevatedSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
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
                            labelText: 'Dose Amount',
                            labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                            filled: true,
                            fillColor: AppColors.elevatedSurface(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) =>
                              (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: _dosageUnit,
                          dropdownColor: AppColors.sheetSurface(context),
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Unit',
                            labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                            filled: true,
                            fillColor: AppColors.elevatedSurface(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _commonUnits.map((u) {
                            return DropdownMenuItem(value: u, child: Text(u));
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
                    'MEAL INSTRUCTION',
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
                        'DOSE SCHEDULE TIMES',
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
                          '+ Add Time',
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
                    'REPEAT DAYS',
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
                              ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1],
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
                                  'Pill Inventory & Refill Alert',
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
                              activeColor: const Color(0xFF8B5CF6),
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
                                    labelText: 'Current Stock',
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
                                    labelText: 'Refill Warning At',
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
                            'Decrements automatically when marked Taken. Alerts when stock reaches threshold.',
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
                      labelText: 'Special Notes / Instructions',
                      labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                      hintText: 'e.g. Drink full glass of water, doctor prescribed for 7 days',
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
                isEditing ? 'Save Changes' : 'Add Medication',
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

