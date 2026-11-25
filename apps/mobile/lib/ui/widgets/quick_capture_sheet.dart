import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/alarm_category.dart';
import '../../data/models/journal_entry.dart';
import '../../data/models/note_item.dart';
import '../../data/models/reminder.dart';
import '../../data/models/task_item.dart';
import '../../data/models/wishlist_item.dart';
import '../../domain/nlp/natural_language_date_parser.dart';
import '../../providers/collection_provider.dart';
import '../../providers/hydration_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/wearable_provider.dart';
import '../screens/alarms/alarm_edit_screen.dart';
import '../screens/seren/mental_wellness_screen.dart';
import 'before_you_go_sheet.dart';
import 'location_reminders_sheet.dart';
import 'mascot_milestone_stamp_overlay.dart';
import 'money/money_editor_dialogs.dart';
import 'nlp_date_detector_chip.dart';

enum CaptureType {
  note,
  task,
  reminder,
  journal,
  wishlist,
}

/// Refined 3-Zone Quick Capture Sheet (`24dp` top radius, `AppColors.sheetSurface`):
/// - Zone 1 (Top): Smart Text Capture (borderless full-pill 5-type selector,
///   focused NLP input, compact borderless optional chips for Date/Time,
///   Priority, Category & Notes, bird-tinted Save button)
/// - Zone 2 (Middle): 4-Column Quick Actions (`+ Money`, `+ Alarm`,
///   `BeforeYouGo`, inline `+1 Glass` with 48dp+ touch targets)
/// - Zone 3 (Bottom): Calm Anchor full-width soft lavender pill for Seren's
///   "Need a Moment?" (Mental Aid), smoothly collapsing Zones 2 & 3 on focus/keyboard
class QuickCaptureSheet extends StatefulWidget {
  final CaptureType? initialType;

  const QuickCaptureSheet({super.key, this.initialType});

  // Session draft & last-used capture type memory
  static CaptureType _lastUsedType = CaptureType.task;
  static String _unsavedDraftTitle = '';
  static String _unsavedDraftNotes = '';

  @visibleForTesting
  static void resetSessionMemory() {
    _lastUsedType = CaptureType.task;
    _unsavedDraftTitle = '';
    _unsavedDraftNotes = '';
  }

  static void show(BuildContext context, {CaptureType? initialType}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickCaptureSheet(initialType: initialType),
    );
  }

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  static const Color _rooCrimson = AppColors.roo;
  static const Color _scoutBlue = AppColors.scout;
  static const Color _serenLavender = AppColors.seren;
  static const Color _twillAmber = AppColors.twill;
  static const Color _echoTawny = AppColors.echo;

  late CaptureType _selectedType;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

  AlarmCategory _category = AlarmCategory.fromType(AlarmCategoryType.personal);
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _manualDueDate;
  TimeOfDay? _manualDueTime;
  ParsedDateResult? _parsedNlp;

  bool _showDetails = false;
  bool _showDateTimePicker = false;
  bool _showPriorityPicker = false;
  bool _showNotesField = false;
  bool _showCategoryPicker = false;
  bool _isInputFocused = false;
  bool _restoredDraft = false;
  bool _loggedWaterInline = false;
  bool _didSubmit = false;
  double _previousViewInsetsBottom = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? QuickCaptureSheet._lastUsedType;
    QuickCaptureSheet._lastUsedType = _selectedType;

    if (QuickCaptureSheet._unsavedDraftTitle.isNotEmpty ||
        QuickCaptureSheet._unsavedDraftNotes.isNotEmpty) {
      _titleController.text = QuickCaptureSheet._unsavedDraftTitle;
      _contentController.text = QuickCaptureSheet._unsavedDraftNotes;
      _showNotesField = QuickCaptureSheet._unsavedDraftNotes.isNotEmpty;
      _restoredDraft = true;
      _reparseNlp(_titleController.text);
    }

    _titleFocusNode.addListener(_onFocusChanged);
    _notesFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    final focused = _titleFocusNode.hasFocus || _notesFocusNode.hasFocus;
    if (focused != _isInputFocused && mounted) {
      setState(() {
        _isInputFocused = focused;
      });
    }
  }

  void _reparseNlp(String text) {
    if (_selectedType == CaptureType.task ||
        _selectedType == CaptureType.reminder) {
      final res = NaturalLanguageDateParser.parse(text);
      _parsedNlp = res.hasMatch ? res : null;
    } else {
      _parsedNlp = null;
    }
  }

  Color _accentForType(CaptureType type) {
    switch (type) {
      case CaptureType.task:
      case CaptureType.reminder:
        return _rooCrimson;
      case CaptureType.note:
      case CaptureType.wishlist:
        return _twillAmber;
      case CaptureType.journal:
        return _echoTawny;
    }
  }

  String _labelForType(AppLocalizations l10n, CaptureType type) {
    switch (type) {
      case CaptureType.task:
        return l10n.tr('qc_task');
      case CaptureType.note:
        return l10n.tr('qc_note');
      case CaptureType.reminder:
        return l10n.tr('qc_reminder');
      case CaptureType.journal:
        return l10n.tr('qc_diary');
      case CaptureType.wishlist:
        return l10n.tr('qc_wishlist');
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return AppColors.error;
      case TaskPriority.high:
        return AppColors.orange;
      case TaskPriority.medium:
        return AppColors.scout;
      case TaskPriority.low:
        return AppColors.darkTextMuted;
    }
  }

  String _priorityLabel(AppLocalizations l10n, TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return l10n.tr('urgent');
      case TaskPriority.high:
        return l10n.tr('high');
      case TaskPriority.medium:
        return l10n.tr('medium');
      case TaskPriority.low:
        return l10n.tr('low');
    }
  }

  String _dateTimeChipLabel(AppLocalizations l10n) {
    final effectiveDate = _manualDueDate ?? _parsedNlp?.date;
    final effectiveTime = _manualDueTime ?? _parsedNlp?.time;
    if (effectiveDate == null && effectiveTime == null) {
      return l10n.tr('qc_datetime_chip');
    }
    final parts = <String>[];
    if (effectiveDate != null) {
      parts.add(l10n.formatDate(effectiveDate, 'MMM d'));
    }
    if (effectiveTime != null) {
      final hh = effectiveTime.hour.toString().padLeft(2, '0');
      final mm = effectiveTime.minute.toString().padLeft(2, '0');
      parts.add('$hh:$mm');
    }
    return parts.join(' • ');
  }

  Future<void> _pickManualDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _manualDueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() {
        _manualDueDate = picked;
      });
    }
  }

  Future<void> _pickManualTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _manualDueTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _manualDueTime = picked;
      });
    }
  }

  @override
  void dispose() {
    if (!_didSubmit) {
      QuickCaptureSheet._unsavedDraftTitle = _titleController.text;
      QuickCaptureSheet._unsavedDraftNotes = _contentController.text;
    }
    _titleFocusNode.removeListener(_onFocusChanged);
    _notesFocusNode.removeListener(_onFocusChanged);
    _titleFocusNode.dispose();
    _notesFocusNode.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    var title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();
    if (_parsedNlp != null &&
        _parsedNlp!.hasMatch &&
        title == _parsedNlp!.originalText) {
      title = _parsedNlp!.cleanTitle;
    }

    final resolvedDate = _manualDueDate ?? _parsedNlp?.date;
    final resolvedTime = _manualDueTime ?? _parsedNlp?.time;

    switch (_selectedType) {
      case CaptureType.note:
        Provider.of<NoteProvider>(context, listen: false).addNote(
          NoteItem(
            id: const Uuid().v4(),
            title: title,
            content: content,
            category: _category,
            createdAt: now,
            updatedAt: now,
          ),
        );
        break;

      case CaptureType.task:
        Provider.of<TaskProvider>(context, listen: false).addTask(
          TaskItem(
            id: const Uuid().v4(),
            title: title,
            notes: content,
            priority: _priority,
            category: _category,
            dueDate: resolvedDate ?? now,
            dueTime: resolvedTime,
            createdAt: now,
          ),
        );
        break;

      case CaptureType.reminder:
        DateTime reminderDate = now.add(const Duration(hours: 2));
        if (resolvedDate != null || resolvedTime != null) {
          final d = resolvedDate ?? now;
          final t = resolvedTime ?? const TimeOfDay(hour: 9, minute: 0);
          reminderDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        }
        Provider.of<ReminderProvider>(context, listen: false).addReminder(
          Reminder(
            id: const Uuid().v4(),
            title: title,
            notes: content,
            dueDateTime: reminderDate,
            category: _category,
            createdAt: now,
          ),
        );
        break;

      case CaptureType.journal:
        Provider.of<JournalProvider>(context, listen: false).addJournalEntry(
          JournalEntry(
            id: const Uuid().v4(),
            title: title,
            content: content,
            date: now,
            mood: JournalMood.good,
            createdAt: now,
            updatedAt: now,
          ),
        );
        break;

      case CaptureType.wishlist:
        Provider.of<CollectionProvider>(context, listen: false).addWishlistItem(
          WishlistItem(
            id: const Uuid().v4(),
            title: title,
            description: content,
            category: _category,
            createdAt: now,
          ),
        );
        break;
    }

    _didSubmit = true;
    QuickCaptureSheet._unsavedDraftTitle = '';
    QuickCaptureSheet._unsavedDraftNotes = '';
    QuickCaptureSheet._lastUsedType = _selectedType;

    final l10n = context.l10n;
    final targetLabel = _labelForType(l10n, _selectedType);
    Navigator.of(context).pop();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          l10n.tr('qc_saved_toast', {'target': targetLabel}),
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.adaptive(
          context,
          dark: AppColors.darkSurfaceSubtle,
          light: AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  Future<void> _logOneGlassInline() async {
    HapticFeedback.mediumImpact();
    HydrationProvider? hydration;
    try {
      hydration = Provider.of<HydrationProvider>(context, listen: false);
    } on ProviderNotFoundException {
      return;
    }
    final future = hydration.addGlass();
    if (mounted) {
      setState(() {
        _loggedWaterInline = true;
      });
    }
    final goalJustMet = await future;
    if (!mounted) return;
    try {
      Provider.of<WearableProvider>(context, listen: false)
          .syncHydrationToWearable(hydration.currentMilliliters);
    } catch (_) {}
    if (goalJustMet) {
      MascotMilestoneStampOverlay.showSerenRefreshed(
        context,
        currentMl: hydration.currentMilliliters,
        targetMl: hydration.targetMilliliters,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    if (_previousViewInsetsBottom > 0 && viewInsetsBottom == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_titleFocusNode.hasFocus || _notesFocusNode.hasFocus) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      });
    }
    _previousViewInsetsBottom = viewInsetsBottom;

    // Drive collapse/expand strictly from actual keyboard visibility
    final collapseLowerZones = viewInsetsBottom > 0;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final activeAccent = _accentForType(_selectedType);
    final hasText = _titleController.text.trim().isNotEmpty;
    final hasCustomDateTime =
        _manualDueDate != null || _manualDueTime != null || _parsedNlp != null;
    final showMetadataChips = _showDetails ||
        _isInputFocused ||
        hasText ||
        hasCustomDateTime ||
        _priority != TaskPriority.medium ||
        _showNotesField ||
        _showDateTimePicker ||
        _showPriorityPicker ||
        _showCategoryPicker;

    HydrationProvider? hydration;
    try {
      hydration = Provider.of<HydrationProvider>(context);
    } on ProviderNotFoundException {
      hydration = null;
    }

    return Container(
      key: const Key('quick_capture_sheet_container'),
      padding: EdgeInsets.only(
        top: 10,
        left: 16,
        right: 16,
        bottom: viewInsetsBottom + 20,
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
            // Drag Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.scrimHandle(context),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),

            // Header Row (48x48dp action targets + borderless full-pill restored badge)
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: activeAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.tr('quick_capture'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      if (_restoredDraft)
                        Container(
                          key: const Key('qc_draft_restored_pill'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: activeAccent.withValues(
                              alpha: isDark ? 0.16 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: activeAccent,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  l10n.tr('qc_draft_restored'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (collapseLowerZones)
                  TextButton(
                    key: const Key('qc_unfocus_btn'),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      l10n.tr('qc_hide_keyboard'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                IconButton(
                  key: const Key('qc_close_btn'),
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // =================================================================
            // ZONE 1: SMART TEXT CAPTURE
            // =================================================================
            // Horizontal borderless full-pill type selector (48dp touch height)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypePill(
                    label: l10n.tr('qc_task'),
                    icon: Icons.check_circle_outline_rounded,
                    type: CaptureType.task,
                  ),
                  _buildTypePill(
                    label: l10n.tr('qc_note'),
                    icon: Icons.description_outlined,
                    type: CaptureType.note,
                  ),
                  _buildTypePill(
                    label: l10n.tr('qc_reminder'),
                    icon: Icons.alarm_outlined,
                    type: CaptureType.reminder,
                  ),
                  _buildTypePill(
                    label: l10n.tr('qc_diary'),
                    icon: Icons.book_outlined,
                    type: CaptureType.journal,
                  ),
                  _buildTypePill(
                    label: l10n.tr('qc_wishlist'),
                    icon: Icons.card_giftcard_rounded,
                    type: CaptureType.wishlist,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Single Focused Text Input wired to NaturalLanguageDateParser
            TextField(
              key: const Key('qc_text_input'),
              controller: _titleController,
              focusNode: _titleFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: _selectedType == CaptureType.journal
                    ? l10n.tr('qc_headline_hint')
                    : (_selectedType == CaptureType.task ||
                            _selectedType == CaptureType.reminder
                        ? l10n.tr('qc_task_hint')
                        : l10n.tr('qc_mind_hint')),
                prefixIcon: Icon(Icons.edit_rounded, color: activeAccent),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: activeAccent, width: 1.6),
                ),
              ),
              onChanged: (text) {
                QuickCaptureSheet._unsavedDraftTitle = text;
                if (_restoredDraft && text.isEmpty) {
                  _restoredDraft = false;
                }
                setState(() {
                  _reparseNlp(text);
                });
              },
            ),

            // NLP Date Detector Chip
            if (_parsedNlp != null &&
                _parsedNlp!.hasMatch &&
                (_selectedType == CaptureType.task ||
                    _selectedType == CaptureType.reminder))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: NlpDateDetectorChip(
                  result: _parsedNlp!,
                  onCleanTitle: () {
                    setState(() {
                      _titleController.text = _parsedNlp!.cleanTitle;
                      _titleController.selection = TextSelection.collapsed(
                        offset: _titleController.text.length,
                      );
                      QuickCaptureSheet._unsavedDraftTitle =
                          _titleController.text;
                    });
                  },
                  onDismiss: () {
                    setState(() => _parsedNlp = null);
                  },
                ),
              ),

            const SizedBox(height: 4),

            // Progressive Disclosure: subtle "+ Details" pill until focused/typing/expanded
            AnimatedSize(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: AnimatedOpacity(
                duration: animDuration,
                curve: Curves.easeOutCubic,
                opacity: 1.0,
                child: showMetadataChips
                    ? SingleChildScrollView(
                        key: const Key('qc_metadata_chips_row'),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (_selectedType == CaptureType.task ||
                                _selectedType == CaptureType.reminder)
                              _buildOptionalPillChip(
                                key: const Key('qc_toggle_datetime_chip'),
                                icon: Icons.schedule_rounded,
                                accentColor: activeAccent,
                                label: _dateTimeChipLabel(l10n),
                                isActive:
                                    _showDateTimePicker || hasCustomDateTime,
                                tabular: true,
                                onTap: () => setState(() {
                                  _showDateTimePicker = !_showDateTimePicker;
                                  if (_showDateTimePicker) {
                                    _showPriorityPicker = false;
                                    _showCategoryPicker = false;
                                  }
                                }),
                              ),
                            if (_selectedType == CaptureType.task)
                              _buildOptionalPillChip(
                                key: const Key('qc_toggle_priority_chip'),
                                icon: Icons.flag_rounded,
                                accentColor: _priorityColor(_priority),
                                label: _priorityLabel(l10n, _priority),
                                isActive: _showPriorityPicker ||
                                    _priority != TaskPriority.medium,
                                onTap: () => setState(() {
                                  _showPriorityPicker = !_showPriorityPicker;
                                  if (_showPriorityPicker) {
                                    _showDateTimePicker = false;
                                    _showCategoryPicker = false;
                                  }
                                }),
                              ),
                            _buildOptionalPillChip(
                              key: const Key('qc_toggle_category_chip'),
                              icon: _category.icon,
                              accentColor: _category.color,
                              label: l10n.categoryName(_category.type),
                              isActive: _showCategoryPicker,
                              onTap: () => setState(() {
                                _showCategoryPicker = !_showCategoryPicker;
                                if (_showCategoryPicker) {
                                  _showDateTimePicker = false;
                                  _showPriorityPicker = false;
                                }
                              }),
                            ),
                            _buildOptionalPillChip(
                              key: const Key('qc_toggle_notes_chip'),
                              icon: Icons.notes_rounded,
                              accentColor: activeAccent,
                              label: l10n.tr('qc_add_notes_chip'),
                              isActive: _showNotesField,
                              onTap: () => setState(
                                () => _showNotesField = !_showNotesField,
                              ),
                            ),
                            if (_selectedType == CaptureType.reminder)
                              _buildOptionalPillChip(
                                key: const Key('qc_geofence_chip'),
                                icon: Icons.location_on_rounded,
                                accentColor: _scoutBlue,
                                label: l10n.tr('qc_geofence_btn'),
                                isActive: false,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  showLocationReminderEditorDialog(context);
                                },
                              ),
                          ],
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: _buildOptionalPillChip(
                          key: const Key('qc_toggle_details_chip'),
                          icon: Icons.add_rounded,
                          accentColor: activeAccent,
                          label: l10n.tr('qc_details_chip'),
                          isActive: false,
                          onTap: () => setState(() => _showDetails = true),
                        ),
                      ),
              ),
            ),

            // Inline Date/Time Quick Picker Row
            if (_showDateTimePicker &&
                (_selectedType == CaptureType.task ||
                    _selectedType == CaptureType.reminder))
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildOptionalPillChip(
                        key: const Key('qc_date_today_btn'),
                        icon: Icons.today_rounded,
                        accentColor: activeAccent,
                        label: l10n.tr('today'),
                        isActive: _manualDueDate != null &&
                            _manualDueDate!.day == DateTime.now().day,
                        onTap: () => setState(() {
                          final now = DateTime.now();
                          _manualDueDate =
                              DateTime(now.year, now.month, now.day);
                        }),
                      ),
                      _buildOptionalPillChip(
                        key: const Key('qc_date_tomorrow_btn'),
                        icon: Icons.wb_sunny_outlined,
                        accentColor: activeAccent,
                        label: l10n.tr('tomorrow'),
                        isActive: _manualDueDate != null &&
                            _manualDueDate!.day ==
                                DateTime.now()
                                    .add(const Duration(days: 1))
                                    .day,
                        onTap: () => setState(() {
                          final t = DateTime.now().add(const Duration(days: 1));
                          _manualDueDate = DateTime(t.year, t.month, t.day);
                        }),
                      ),
                      _buildOptionalPillChip(
                        key: const Key('qc_pick_date_btn'),
                        icon: Icons.calendar_month_rounded,
                        accentColor: activeAccent,
                        label: l10n.tr('qc_pick_date'),
                        isActive: false,
                        onTap: _pickManualDate,
                      ),
                      _buildOptionalPillChip(
                        key: const Key('qc_pick_time_btn'),
                        icon: Icons.access_time_rounded,
                        accentColor: activeAccent,
                        label: l10n.tr('qc_pick_time'),
                        isActive: _manualDueTime != null,
                        onTap: _pickManualTime,
                      ),
                      if (_manualDueDate != null || _manualDueTime != null)
                        _buildOptionalPillChip(
                          key: const Key('qc_clear_date_btn'),
                          icon: Icons.close_rounded,
                          accentColor: AppColors.textSecondary(context),
                          label: l10n.tr('qc_clear_date'),
                          isActive: false,
                          onTap: () => setState(() {
                            _manualDueDate = null;
                            _manualDueTime = null;
                          }),
                        ),
                    ],
                  ),
                ),
              ),

            // Inline Priority Picker Row
            if (_showPriorityPicker && _selectedType == CaptureType.task)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TaskPriority.values.map((prio) {
                      final color = _priorityColor(prio);
                      return _buildOptionalPillChip(
                        key: Key('qc_priority_${prio.name}'),
                        dotColor: color,
                        accentColor: color,
                        label: _priorityLabel(l10n, prio),
                        isActive: _priority == prio,
                        onTap: () => setState(() {
                          _priority = prio;
                          _showPriorityPicker = false;
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // Inline Category Picker Row
            if (_showCategoryPicker)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AlarmCategory.predefined.map((cat) {
                      final isSelected = _category.type == cat.type;
                      return _buildOptionalPillChip(
                        key: Key('qc_cat_${cat.type.name}'),
                        icon: cat.icon,
                        accentColor: cat.color,
                        label: l10n.categoryName(cat.type),
                        isActive: isSelected,
                        onTap: () => setState(() {
                          _category = cat;
                          _showCategoryPicker = false;
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),

            if (_showNotesField) ...[
              const SizedBox(height: 6),
              TextField(
                key: const Key('qc_notes_input'),
                controller: _contentController,
                focusNode: _notesFocusNode,
                maxLines: 2,
                onChanged: (text) {
                  QuickCaptureSheet._unsavedDraftNotes = text;
                },
                decoration: InputDecoration(
                  hintText: l10n.tr('qc_notes_hint'),
                ),
              ),
            ],

            // Primary Bird-Tinted Save Button — expands smoothly only once text is entered
            AnimatedSize(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                duration: animDuration,
                curve: Curves.easeOutCubic,
                opacity: hasText ? 1.0 : 0.0,
                child: hasText
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ElevatedButton(
                          key: const Key('qc_save_btn'),
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            l10n.tr('qc_save_btn'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // =================================================================
            // ZONES 2 & 3: Smoothly collapse/reappear in lockstep with keyboard
            // =================================================================
            AnimatedSize(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                duration: animDuration,
                curve: Curves.easeOutCubic,
                opacity: collapseLowerZones ? 0.0 : 1.0,
                child: collapseLowerZones
                    ? const SizedBox.shrink(key: Key('qc_zones_collapsed'))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          Divider(
                            height: 1,
                            color: AppColors.border(context)
                                .withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 10),

                          // ZONE 2: Light Borderless 4-Column Quick Action Strip (48dp+ tap targets)
                          Row(
                            key: const Key('qc_zone_quick_actions'),
                            children: [
                              Expanded(
                                child: _QuickActionIconTile(
                                  tileKey: const Key('qc_action_money'),
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: _twillAmber,
                                  label: l10n.tr('qc_action_money'),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    showMoneyTransactionSheet(context);
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _QuickActionIconTile(
                                  tileKey: const Key('qc_action_alarm'),
                                  icon: Icons.add_alarm_rounded,
                                  color: _rooCrimson,
                                  label: l10n.tr('qc_action_alarm'),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const AlarmEditScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _QuickActionIconTile(
                                  tileKey: const Key('qc_action_before_you_go'),
                                  icon: Icons.door_front_door_outlined,
                                  color: _scoutBlue,
                                  label: l10n.tr('qc_action_before_you_go'),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    BeforeYouGoSheet.show(context);
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _QuickActionIconTile(
                                  tileKey: const Key('qc_action_add_glass'),
                                  icon: _loggedWaterInline
                                      ? Icons.check_circle_rounded
                                      : Icons.water_drop_rounded,
                                  color: _loggedWaterInline
                                      ? AppColors.success
                                      : _serenLavender,
                                  label: _loggedWaterInline && hydration != null
                                      ? l10n.tr('qc_water_logged_inline', {
                                          'glasses': hydration.glassesConsumed,
                                          'goal': hydration.dailyGoalGlasses,
                                        })
                                      : l10n.tr('qc_action_add_glass'),
                                  tabular: _loggedWaterInline,
                                  onTap: _logOneGlassInline,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ZONE 3: Slim Single-Row Calm Anchor Lavender Pill
                          InkWell(
                            key: const Key('qc_mental_aid_chip'),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const MentalWellnessScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              key: const Key('qc_zone_calm_anchor'),
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _serenLavender.withValues(
                                  alpha: isDark ? 0.15 : 0.11,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: _serenLavender.withValues(
                                        alpha: isDark ? 0.24 : 0.16,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.spa_rounded,
                                      color: _serenLavender,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l10n.tr('qc_calm_anchor_title'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Borderless full-pill capture type chip with `>= 48dp` touch height.
  Widget _buildTypePill({
    required String label,
    required IconData icon,
    required CaptureType type,
  }) {
    final isSelected = _selectedType == type;
    final tint = _accentForType(type);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        key: Key('qc_type_pill_${type.name}'),
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedType = type;
            QuickCaptureSheet._lastUsedType = type;
            _showDateTimePicker = false;
            _showPriorityPicker = false;
            _reparseNlp(_titleController.text);
          });
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? tint : AppColors.subtleFill(context),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? Colors.white : tint,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compact borderless optional chip with `>= 48dp` hit target.
  Widget _buildOptionalPillChip({
    Key? key,
    IconData? icon,
    Color? dotColor,
    required Color accentColor,
    required String label,
    required bool isActive,
    bool tabular = false,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor.withValues(alpha: isDark ? 0.18 : 0.12)
                    : AppColors.subtleFill(context),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (icon != null) ...[
                    Icon(
                      icon,
                      size: 14,
                      color: isActive
                          ? accentColor
                          : AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary(context),
                      fontFeatures:
                          tabular ? const [FontFeature.tabularFigures()] : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionIconTile extends StatelessWidget {
  final Key tileKey;
  final IconData icon;
  final Color color;
  final String label;
  final bool tabular;
  final VoidCallback onTap;

  const _QuickActionIconTile({
    required this.tileKey,
    required this.icon,
    required this.color,
    required this.label,
    this.tabular = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return InkWell(
      key: tileKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                fontFeatures:
                    tabular ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
