import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
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

/// Redesigned 3-Zone Quick Capture Sheet:
/// - Zone 1 (Top): Smart Text Capture (5 text types, NLP date detector,
///   compact optional chips, bird-tinted Save button)
/// - Zone 2 (Middle): 4-Column Quick Actions (+ Money, + Alarm, BeforeYouGo,
///   inline +1 Glass)
/// - Zone 3 (Bottom): Calm Anchor full-width soft lavender pill for Seren's
///   "Need a Moment?" / Mental Aid
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
  static const Color _rooCrimson = Color(0xFFE04A3A);
  static const Color _scoutBlue = Color(0xFF3B82F6);
  static const Color _serenLavender = Color(0xFF8B5CF6);
  static const Color _twillAmber = Color(0xFFF59E0B);
  static const Color _echoTawny = Color(0xFFD97706);

  late CaptureType _selectedType;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

  AlarmCategory _category = AlarmCategory.fromType(AlarmCategoryType.personal);
  ParsedDateResult? _parsedNlp;
  bool _showNotesField = false;
  bool _showCategoryPicker = false;
  bool _isInputFocused = false;
  bool _restoredDraft = false;
  bool _loggedWaterInline = false;
  bool _didSubmit = false;

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
            category: _category,
            dueDate: _parsedNlp?.date ?? now,
            dueTime: _parsedNlp?.time,
            createdAt: now,
          ),
        );
        break;

      case CaptureType.reminder:
        DateTime reminderDate = now.add(const Duration(hours: 2));
        if (_parsedNlp != null && _parsedNlp!.hasMatch) {
          final d = _parsedNlp!.date ?? now;
          final t = _parsedNlp!.time ?? const TimeOfDay(hour: 9, minute: 0);
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
          dark: const Color(0xFF23252E),
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
    final goalJustMet = await hydration.addGlass();
    if (!mounted) return;
    setState(() {
      _loggedWaterInline = true;
    });
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
    final collapseLowerZones = _isInputFocused || viewInsetsBottom > 0;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final activeAccent = _accentForType(_selectedType);

    HydrationProvider? hydration;
    try {
      hydration = Provider.of<HydrationProvider>(context);
    } on ProviderNotFoundException {
      hydration = null;
    }

    return Container(
      padding: EdgeInsets.only(
        top: 10,
        left: 18,
        right: 18,
        bottom: viewInsetsBottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.scrimHandle(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_restoredDraft)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: activeAccent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.tr('qc_draft_restored'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.adaptive(
                                context,
                                dark: activeAccent,
                                light: Color.lerp(
                                      activeAccent,
                                      Colors.black,
                                      0.2,
                                    ) ??
                                    activeAccent,
                              ),
                            ),
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
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      l10n.tr('qc_hide_keyboard'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // =================================================================
            // ZONE 1: SMART TEXT CAPTURE
            // =================================================================
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
            const SizedBox(height: 12),

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

            const SizedBox(height: 8),

            // Compact Optional Field Chips (Notes, Category, Place Reminder)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilterChip(
                  key: const Key('qc_toggle_notes_chip'),
                  selected: _showNotesField,
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    Icons.notes_rounded,
                    size: 14,
                    color: _showNotesField
                        ? activeAccent
                        : AppColors.textSecondary(context),
                  ),
                  label: Text(
                    l10n.tr('qc_add_notes_chip'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  onSelected: (v) => setState(() => _showNotesField = v),
                ),
                FilterChip(
                  key: const Key('qc_toggle_category_chip'),
                  selected: _showCategoryPicker,
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    _category.icon,
                    size: 14,
                    color: _category.color,
                  ),
                  label: Text(
                    l10n.categoryName(_category.type),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  onSelected: (v) => setState(() => _showCategoryPicker = v),
                ),
                if (_selectedType == CaptureType.reminder)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: _scoutBlue,
                    ),
                    label: Text(
                      l10n.tr('qc_geofence_btn'),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      showLocationReminderEditorDialog(context);
                    },
                  ),
              ],
            ),

            if (_showNotesField) ...[
              const SizedBox(height: 8),
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

            if (_showCategoryPicker) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AlarmCategory.predefined.map((cat) {
                    final isSelected = _category.type == cat.type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        selected: isSelected,
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          l10n.categoryName(cat.type),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        selectedColor: cat.color,
                        avatar: Icon(
                          cat.icon,
                          size: 13,
                          color: isSelected ? Colors.white : cat.color,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _category = cat;
                              _showCategoryPicker = false;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Primary Bird-Tinted Save Button
            ElevatedButton(
              key: const Key('qc_save_btn'),
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeAccent,
                foregroundColor: Colors.white,
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

            // =================================================================
            // ZONES 2 & 3: Smoothly collapse when text field is focused
            // =================================================================
            AnimatedSize(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: collapseLowerZones
                  ? const SizedBox.shrink(key: Key('qc_zones_collapsed'))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Divider(height: 1, color: AppColors.border(context)),
                        const SizedBox(height: 12),

                        // ZONE 2: High-Frequency 4-Column Quick Actions
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
                            const SizedBox(width: 8),
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
                            const SizedBox(width: 8),
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
                            const SizedBox(width: 8),
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
                                onTap: _logOneGlassInline,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ZONE 3: Calm Anchor — Full-Width Soft Lavender Seren Pill
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
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            key: const Key('qc_zone_calm_anchor'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _serenLavender.withValues(
                                alpha: isDark ? 0.16 : 0.10,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _serenLavender.withValues(
                                  alpha: isDark ? 0.36 : 0.28,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _serenLavender.withValues(
                                      alpha: isDark ? 0.24 : 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.spa_rounded,
                                    color: _serenLavender,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.tr('qc_calm_anchor_title'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.adaptive(
                                            context,
                                            dark: const Color(0xFFC4B5FD),
                                            light: const Color(0xFF5B21B6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        l10n.tr('qc_calm_anchor_subtitle'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppColors.adaptive(
                                    context,
                                    dark: const Color(0xFFC4B5FD),
                                    light: const Color(0xFF6D28D9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypePill({
    required String label,
    required IconData icon,
    required CaptureType type,
  }) {
    final isSelected = _selectedType == type;
    final tint = _accentForType(type);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        key: Key('qc_type_pill_${type.name}'),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary(context),
          ),
        ),
        avatar: Icon(
          icon,
          size: 14,
          color: isSelected ? Colors.white : tint,
        ),
        selectedColor: tint,
        onSelected: (val) {
          if (val) {
            setState(() {
              _selectedType = type;
              QuickCaptureSheet._lastUsedType = type;
              _reparseNlp(_titleController.text);
            });
          }
        },
      ),
    );
  }
}

class _QuickActionIconTile extends StatelessWidget {
  final Key tileKey;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionIconTile({
    required this.tileKey,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return InkWell(
      key: tileKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
