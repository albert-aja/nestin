import 'dart:async';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/memory_item.dart';
import '../../../data/models/mental_wellness_models.dart';
import '../../../data/models/seren_relaxation_models.dart';
import '../../../providers/break_the_cycle_provider.dart';
import '../../../providers/journal_provider.dart';

const Color _kSerenPurple = AppColors.seren;
const Color _kSerenLavender = AppColors.serenLight;
const MethodChannel _kWidgetsChannel = MethodChannel('com.nestin.app/widgets');

void _showL2Toast(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.adaptive(
        context,
        dark: AppColors.darkSurfaceSubtle,
        light: AppColors.lightTextPrimary,
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Opens [uri] natively via Android `MainActivity` `launchExternalUri`, falling
/// back cleanly to clipboard copy on unsupported hosts or missing handlers.
Future<bool> launchExternalUriWithFallback(
  BuildContext context,
  String uri, {
  String? fallbackClipboardText,
  String? toastOnFallback,
  String? toastOnLaunched,
}) async {
  bool launched = false;
  try {
    final res = await _kWidgetsChannel.invokeMethod<bool>(
      'launchExternalUri',
      {'uri': uri},
    );
    launched = res ?? false;
  } catch (_) {
    launched = false;
  }

  if (!launched) {
    try {
      await Clipboard.setData(
        ClipboardData(text: fallbackClipboardText ?? uri),
      );
    } catch (_) {}
    if (context.mounted && toastOnFallback != null) {
      _showL2Toast(context, toastOnFallback);
    }
  } else if (context.mounted && toastOnLaunched != null) {
    _showL2Toast(context, toastOnLaunched);
  }
  return launched;
}

/// Comfort Kit customization sheet (`EFA-07` Level 2): pin notes, Seren soundscapes,
/// calm stories, Echo memories, comfort photos, or external resource bookmarks.
Future<void> showComfortKitAddSheet(
  BuildContext context,
  BreakTheCycleProvider btc, {
  JournalProvider? journal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ComfortKitAddSheet(btc: btc, journal: journal),
  );
}

class _ComfortKitAddSheet extends StatefulWidget {
  final BreakTheCycleProvider btc;
  final JournalProvider? journal;

  const _ComfortKitAddSheet({
    required this.btc,
    required this.journal,
  });

  @override
  State<_ComfortKitAddSheet> createState() => _ComfortKitAddSheetState();
}

class _ComfortKitAddSheetState extends State<_ComfortKitAddSheet> {
  ComfortKitItemKind _selectedKind = ComfortKitItemKind.encouragementNote;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _subCtrl = TextEditingController();
  final TextEditingController _urlOrPathCtrl = TextEditingController();

  String _selectedSoundId = SerenRelaxationCatalog.sounds.first.id;
  String _selectedStoryId = SerenRelaxationCatalog.readings.first.id;
  String? _selectedMemoryId;
  String _selectedPhotoPreset = 'assets/banner.jpg';

  @override
  void initState() {
    super.initState();
    final memories = widget.journal?.memories ?? const <MemoryItem>[];
    if (memories.isNotEmpty) {
      _selectedMemoryId = memories.first.id;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subCtrl.dispose();
    _urlOrPathCtrl.dispose();
    super.dispose();
  }

  Future<void> _pinSelected() async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final id = const Uuid().v4();

    ComfortKitItem? item;
    switch (_selectedKind) {
      case ComfortKitItemKind.encouragementNote:
        final t = _titleCtrl.text.trim();
        final s = _subCtrl.text.trim();
        if (t.isEmpty && s.isEmpty) return;
        item = ComfortKitItem(
          id: id,
          kind: ComfortKitItemKind.encouragementNote,
          title: t.isNotEmpty ? t : s,
          subtitle: s,
          isCustomNote: true,
          createdAt: now,
        );
        break;
      case ComfortKitItemKind.soundscape:
        final sound = SerenRelaxationCatalog.sounds.firstWhere(
          (s) => s.id == _selectedSoundId,
          orElse: () => SerenRelaxationCatalog.sounds.first,
        );
        item = ComfortKitItem(
          id: 'kit_sound_${sound.id}',
          kind: ComfortKitItemKind.soundscape,
          title: sound.titleKey,
          subtitle: sound.descriptionKey,
          referenceId: sound.id,
          isCustomNote: false,
          createdAt: now,
        );
        break;
      case ComfortKitItemKind.reading:
        final story = SerenRelaxationCatalog.readings.firstWhere(
          (r) => r.id == _selectedStoryId,
          orElse: () => SerenRelaxationCatalog.readings.first,
        );
        item = ComfortKitItem(
          id: 'kit_story_${story.id}',
          kind: ComfortKitItemKind.reading,
          title: story.titleKey,
          subtitle: story.subtitleKey,
          referenceId: story.id,
          isCustomNote: false,
          createdAt: now,
        );
        break;
      case ComfortKitItemKind.echoMemory:
        final memories = widget.journal?.memories ?? const <MemoryItem>[];
        final match = memories.where((m) => m.id == _selectedMemoryId).toList();
        if (match.isEmpty) return;
        final mem = match.first;
        item = ComfortKitItem(
          id: 'kit_mem_${mem.id}',
          kind: ComfortKitItemKind.echoMemory,
          title: mem.title,
          subtitle: mem.description,
          referenceId: mem.id,
          isCustomNote: true,
          createdAt: now,
        );
        break;
      case ComfortKitItemKind.comfortPhoto:
        final path = _urlOrPathCtrl.text.trim().isNotEmpty
            ? _urlOrPathCtrl.text.trim()
            : _selectedPhotoPreset;
        final caption = _subCtrl.text.trim().isNotEmpty
            ? _subCtrl.text.trim()
            : l10n.tr('mw_l2_kind_photo');
        item = ComfortKitItem(
          id: id,
          kind: ComfortKitItemKind.comfortPhoto,
          title: _titleCtrl.text.trim().isNotEmpty
              ? _titleCtrl.text.trim()
              : caption,
          subtitle: caption,
          referenceId: path,
          isCustomNote: true,
          createdAt: now,
        );
        break;
      case ComfortKitItemKind.externalBookmark:
        final url = _urlOrPathCtrl.text.trim();
        final title = _titleCtrl.text.trim();
        if (url.isEmpty && title.isEmpty) return;
        item = ComfortKitItem(
          id: id,
          kind: ComfortKitItemKind.externalBookmark,
          title: title.isNotEmpty ? title : url,
          subtitle: _subCtrl.text.trim().isNotEmpty ? _subCtrl.text.trim() : url,
          referenceId: url,
          isCustomNote: true,
          createdAt: now,
        );
        break;
      case ComfortKitItemKind.breathing:
      case ComfortKitItemKind.grounding:
      case ComfortKitItemKind.gratitudePebble:
        return;
    }

    await widget.btc.addComfortKitItem(item);
    if (!mounted) return;
    Navigator.of(context).pop();
    _showL2Toast(context, l10n.tr('mw_l2_pinned_toast'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final memories = widget.journal?.memories ?? const <MemoryItem>[];

    final kindChoices = <(ComfortKitItemKind, String)>[
      (ComfortKitItemKind.encouragementNote, 'mw_l2_kind_note'),
      (ComfortKitItemKind.soundscape, 'mw_l2_kind_sound'),
      (ComfortKitItemKind.reading, 'mw_l2_kind_story'),
      (ComfortKitItemKind.echoMemory, 'mw_l2_kind_memory'),
      (ComfortKitItemKind.comfortPhoto, 'mw_l2_kind_photo'),
      (ComfortKitItemKind.externalBookmark, 'mw_l2_kind_bookmark'),
    ];

    final photoPresets = <(String, String)>[
      ('assets/banner.jpg', 'mw_l2_photo_preset_sunrise'),
      ('assets/mascots/sprites/seren/rainy_window.png', 'mw_l2_photo_preset_rain'),
      ('assets/mascots/sprites/seren/alpine_meadow_breeze.png', 'mw_l2_photo_preset_meadow'),
      ('assets/mascots/sprites/duos/duo_seren_echo_evening_sanctuary.png', 'mw_l2_photo_preset_candle'),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kSerenPurple.withValues(alpha: 0.14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/mascots/sprites/seren/comfort_kit_treasure_box.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.inventory_2_outlined,
                      color: _kSerenPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.tr('mw_l2_comfort_add_title'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kindChoices.map((pair) {
                return ChoiceChip(
                  key: Key('mw_l2_kit_kind_${pair.$1.name}'),
                  selected: _selectedKind == pair.$1,
                  label: Text(
                    l10n.tr(pair.$2),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onSelected: (_) => setState(() => _selectedKind = pair.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (_selectedKind == ComfortKitItemKind.encouragementNote) ...[
              TextField(
                key: const Key('mw_l2_note_title_input'),
                controller: _titleCtrl,
                decoration: InputDecoration(labelText: l10n.tr('mw_note_title_label')),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('mw_l2_note_body_input'),
                controller: _subCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.tr('mw_note_body_label')),
              ),
            ] else if (_selectedKind == ComfortKitItemKind.soundscape) ...[
              Text(
                l10n.tr('mw_l2_select_sound_label'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: SerenRelaxationCatalog.sounds.take(8).map((s) {
                  return ChoiceChip(
                    selected: _selectedSoundId == s.id,
                    label: Text(l10n.tr(s.titleKey)),
                    onSelected: (_) => setState(() => _selectedSoundId = s.id),
                  );
                }).toList(),
              ),
            ] else if (_selectedKind == ComfortKitItemKind.reading) ...[
              Text(
                l10n.tr('mw_l2_select_story_label'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: SerenRelaxationCatalog.readings.take(6).map((r) {
                  return ChoiceChip(
                    selected: _selectedStoryId == r.id,
                    label: Text(l10n.tr(r.titleKey)),
                    onSelected: (_) => setState(() => _selectedStoryId = r.id),
                  );
                }).toList(),
              ),
            ] else if (_selectedKind == ComfortKitItemKind.echoMemory) ...[
              Text(
                l10n.tr('mw_l2_select_memory_label'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              if (memories.isEmpty)
                Text(
                  l10n.tr('mw_l2_no_memories_hint'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: memories.map((m) {
                    return ChoiceChip(
                      selected: _selectedMemoryId == m.id,
                      label: Text(m.title),
                      onSelected: (_) => setState(() => _selectedMemoryId = m.id),
                    );
                  }).toList(),
                ),
            ] else if (_selectedKind == ComfortKitItemKind.comfortPhoto) ...[
              Text(
                l10n.tr('mw_l2_photo_preset_label'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: photoPresets.map((p) {
                  return ChoiceChip(
                    selected: _selectedPhotoPreset == p.$1,
                    label: Text(l10n.tr(p.$2)),
                    onSelected: (_) => setState(() => _selectedPhotoPreset = p.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('mw_l2_photo_caption_label'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlOrPathCtrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('mw_l2_photo_path_label'),
                ),
              ),
            ] else if (_selectedKind == ComfortKitItemKind.externalBookmark) ...[
              TextField(
                key: const Key('mw_l2_bookmark_title_input'),
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('mw_l2_bookmark_title_label'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('mw_l2_bookmark_url_input'),
                controller: _urlOrPathCtrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('mw_l2_bookmark_url_label'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subCtrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('mw_l2_bookmark_note_label'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('mw_l2_comfort_add_confirm_btn'),
              onPressed: _pinSelected,
              style: FilledButton.styleFrom(
                backgroundColor: _kSerenPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.tr('mw_note_save_btn'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preview dialog for pinned Echo Memories, Comfort Photos, or External Bookmarks (`EFA-07`).
Future<void> showComfortItemPreviewDialog(
  BuildContext context,
  ComfortKitItem item,
) {
  final l10n = context.l10n;
  final titleText = item.isCustomNote ? item.title : l10n.tr(item.title);
  final subText = item.isCustomNote ? item.subtitle : l10n.tr(item.subtitle);
  final ref = item.referenceId ?? '';

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.sheetSurface(ctx),
      title: Text(titleText),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (item.kind == ComfortKitItemKind.comfortPhoto && ref.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 150,
                  child: ref.startsWith('assets/')
                      ? Image.asset(
                          ref,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.photo_library_outlined,
                            size: 48,
                            color: _kSerenPurple,
                          ),
                        )
                      : Image.file(
                          File(ref),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.photo_library_outlined,
                            size: 48,
                            color: _kSerenPurple,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (subText.isNotEmpty)
              Text(
                subText,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary(ctx),
                ),
              ),
            if (item.kind == ComfortKitItemKind.externalBookmark && ref.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ref,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (item.kind == ComfortKitItemKind.externalBookmark && ref.isNotEmpty)
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              launchExternalUriWithFallback(
                context,
                ref,
                fallbackClipboardText: ref,
                toastOnFallback: l10n.tr('gs_copied_or_opened_toast'),
              );
            },
            child: Text(l10n.tr('mw_l2_open_bookmark_btn')),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.tr('btc_common_close')),
        ),
      ],
    ),
  );
}

/// Spoken Voice Reflection modal (`SU-02`) saving directly into Echo's `JournalProvider`.
class VoiceJournalSessionSheet extends StatefulWidget {
  final BreakTheCycleProvider btc;
  final JournalProvider? journal;

  const VoiceJournalSessionSheet({
    super.key,
    required this.btc,
    required this.journal,
  });

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
    JournalProvider? journal,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceJournalSessionSheet(btc: btc, journal: journal),
    );
  }

  @override
  State<VoiceJournalSessionSheet> createState() =>
      _VoiceJournalSessionSheetState();
}

class _VoiceJournalSessionSheetState extends State<VoiceJournalSessionSheet> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  bool _recording = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_recording) {
      _timer?.cancel();
      setState(() => _recording = false);
      return;
    }
    setState(() => _recording = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _elapsedSeconds += 1);
    });
  }

  String _formattedDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Future<void> _saveToEcho() async {
    if (widget.journal == null) return;
    _timer?.cancel();
    await widget.btc.saveVoiceReflectionToEcho(
      journalProvider: widget.journal!,
      title: _titleCtrl.text,
      transcriptOrNotes: _notesCtrl.text,
      durationSeconds: _elapsedSeconds,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    _showL2Toast(context, context.l10n.tr('mw_l2_voice_saved_toast'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
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
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kSerenPurple.withValues(alpha: 0.14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/mascots/sprites/duos/echo_seren_voice_memo_feather.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.mic_none_rounded,
                      color: _kSerenPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('mw_l2_voice_title'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        l10n.tr('mw_l2_voice_sub'),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _kSerenPurple.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 36,
                    color: _kSerenPurple,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formattedDuration(_elapsedSeconds),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tr('mw_l2_voice_quip'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        key: const Key('mw_voice_memo_toggle_btn'),
                        onPressed: _toggleTimer,
                        icon: Icon(
                          _recording
                              ? Icons.pause_rounded
                              : Icons.fiber_manual_record_rounded,
                          size: 16,
                        ),
                        label: Text(
                          l10n.tr(
                            _recording ? 'mw_l2_voice_pause' : 'mw_l2_voice_record',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _timer?.cancel();
                          setState(() {
                            _recording = false;
                            _elapsedSeconds = 0;
                          });
                        },
                        child: Text(l10n.tr('mw_l2_voice_reset')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: l10n.tr('mw_l2_voice_title_hint'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('mw_voice_memo_notes_input'),
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.tr('mw_l2_voice_notes_hint'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('mw_voice_memo_save_btn'),
              onPressed: widget.journal == null ? null : _saveToEcho,
              style: FilledButton.styleFrom(
                backgroundColor: _kSerenPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(l10n.tr('mw_ephemeral_save_to_echo_btn')),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              key: const Key('mw_voice_memo_let_go_btn'),
              onPressed: () {
                _timer?.cancel();
                widget.btc.letItGoWithoutSaving();
                Navigator.of(context).pop();
                _showL2Toast(context, l10n.tr('mw_ephemeral_released_toast'));
              },
              child: Text(l10n.tr('mw_ephemeral_let_it_go_btn')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trusted Contact editor dialog (`GS-01`).
Future<void> showTrustedContactEditorDialog(
  BuildContext context,
  BreakTheCycleProvider btc, {
  TrustedContact? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TrustedContactEditorDialog(btc: btc, existing: existing),
  );
}

class _TrustedContactEditorDialog extends StatefulWidget {
  final BreakTheCycleProvider btc;
  final TrustedContact? existing;

  const _TrustedContactEditorDialog({
    required this.btc,
    this.existing,
  });

  @override
  State<_TrustedContactEditorDialog> createState() =>
      _TrustedContactEditorDialogState();
}

class _TrustedContactEditorDialogState
    extends State<_TrustedContactEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _relCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _noteCtrl;
  late TrustedContactChannel _channel;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _relCtrl = TextEditingController(text: e?.relationshipLabel ?? '');
    _phoneCtrl = TextEditingController(text: e?.phoneOrHandle ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _channel = e?.preferredChannel ?? TrustedContactChannel.sms;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = widget.existing;
    return AlertDialog(
      backgroundColor: AppColors.sheetSurface(context),
      title: Text(l10n.tr('gs_add_contact_btn')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('mw_gs_contact_name_input'),
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.tr('gs_contact_name_label'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _relCtrl,
              decoration: InputDecoration(
                labelText: l10n.tr('gs_contact_rel_label'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('mw_gs_contact_phone_input'),
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.tr('gs_contact_phone_label'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.tr('gs_contact_channel_label'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: TrustedContactChannel.values.map((c) {
                return ChoiceChip(
                  selected: _channel == c,
                  label: Text(l10n.tr(c.translationKey)),
                  onSelected: (_) => setState(() => _channel = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: l10n.tr('gs_contact_note_label'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.tr('btc_common_cancel')),
        ),
        FilledButton(
          key: const Key('mw_gs_contact_save_btn'),
          onPressed: () async {
            final name = _nameCtrl.text.trim();
            final phone = _phoneCtrl.text.trim();
            if (name.isEmpty || phone.isEmpty) return;
            final navigator = Navigator.of(context);
            await widget.btc.saveTrustedContact(
              TrustedContact(
                id: e?.id ?? const Uuid().v4(),
                name: name,
                relationshipLabel: _relCtrl.text.trim(),
                phoneOrHandle: phone,
                preferredChannel: _channel,
                note: _noteCtrl.text.trim(),
                createdAt: e?.createdAt ?? DateTime.now(),
              ),
            );
            if (mounted) navigator.pop();
          },
          child: Text(l10n.tr('btc_common_save')),
        ),
      ],
    );
  }
}

/// Custom Message Template editor (`GS-03` — "+ Write My Own Template").
Future<void> showMessageTemplateEditorDialog(
  BuildContext context,
  BreakTheCycleProvider btc, {
  SupportMessageTemplate? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _MessageTemplateEditorDialog(btc: btc, existing: existing),
  );
}

class _MessageTemplateEditorDialog extends StatefulWidget {
  final BreakTheCycleProvider btc;
  final SupportMessageTemplate? existing;

  const _MessageTemplateEditorDialog({
    required this.btc,
    this.existing,
  });

  @override
  State<_MessageTemplateEditorDialog> createState() =>
      _MessageTemplateEditorDialogState();
}

class _MessageTemplateEditorDialogState
    extends State<_MessageTemplateEditorDialog> {
  TextEditingController? _titleCtrl;
  TextEditingController? _bodyCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_titleCtrl != null) return;
    final l10n = context.l10n;
    final e = widget.existing;
    _titleCtrl = TextEditingController(
      text: e == null ? '' : (e.isCustom ? e.title : l10n.tr(e.title)),
    );
    _bodyCtrl = TextEditingController(
      text:
          e == null ? '' : (e.isCustom ? e.messageBody : l10n.tr(e.messageBody)),
    );
  }

  @override
  void dispose() {
    _titleCtrl?.dispose();
    _bodyCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = widget.existing;
    return AlertDialog(
      backgroundColor: AppColors.sheetSurface(context),
      title: Text(l10n.tr('gs_add_template_btn')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('mw_gs_template_title_input'),
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: l10n.tr('gs_template_title_label'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('mw_gs_template_body_input'),
            controller: _bodyCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.tr('gs_template_body_label'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.tr('btc_common_cancel')),
        ),
        FilledButton(
          key: const Key('mw_gs_template_save_btn'),
          onPressed: () async {
            final body = (_bodyCtrl?.text ?? '').trim();
            if (body.isEmpty) return;
            final titleText = (_titleCtrl?.text ?? '').trim();
            final title = titleText.isNotEmpty ? titleText : body;
            final navigator = Navigator.of(context);
            await widget.btc.saveMessageTemplate(
              SupportMessageTemplate(
                id: e?.id ?? const Uuid().v4(),
                title: title,
                messageBody: body,
                isCustom: true,
                createdAt: e?.createdAt ?? DateTime.now(),
              ),
            );
            if (mounted) navigator.pop();
          },
          child: Text(l10n.tr('btc_common_save')),
        ),
      ],
    );
  }
}

/// 1-Tap Quick Reach Out sheet (`GS-02`, `GS-03`) for Trusted Contacts.
class QuickReachOutSheet extends StatefulWidget {
  final BreakTheCycleProvider btc;
  final TrustedContact contact;

  const QuickReachOutSheet({
    super.key,
    required this.btc,
    required this.contact,
  });

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
    required TrustedContact contact,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickReachOutSheet(btc: btc, contact: contact),
    );
  }

  @override
  State<QuickReachOutSheet> createState() => _QuickReachOutSheetState();
}

class _QuickReachOutSheetState extends State<QuickReachOutSheet> {
  final TextEditingController _msgCtrl = TextEditingController();
  bool _initializedText = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedText) {
      _initializedText = true;
      final l10n = context.l10n;
      final templates = widget.btc.messageTemplates;
      if (templates.isNotEmpty) {
        final first = templates.first;
        _msgCtrl.text =
            first.isCustom ? first.messageBody : l10n.tr(first.messageBody);
      }
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(TrustedContactChannel channel) async {
    final l10n = context.l10n;
    final body = _msgCtrl.text.trim();
    final uri = widget.btc.composeContactUri(
      contact: widget.contact,
      messageBody: body,
      channelOverride: channel,
    );
    await launchExternalUriWithFallback(
      context,
      uri,
      fallbackClipboardText: body.isNotEmpty ? body : widget.contact.phoneOrHandle,
      toastOnFallback: l10n.tr('gs_copied_or_opened_toast'),
      toastOnLaunched: l10n.tr('gs_opened_external_toast', {
        'name': widget.contact.name,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
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
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kSerenPurple.withValues(alpha: 0.14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/mascots/sprites/duos/scout_seren_trusted_messenger.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.send_rounded,
                      color: _kSerenPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('gs_reach_out_title', {
                          'name': widget.contact.name,
                        }),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        l10n.tr('gs_reach_out_quip'),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.tr('gs_pick_template_label'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.btc.messageTemplates.map((t) {
                final title = t.isCustom ? t.title : l10n.tr(t.title);
                final body =
                    t.isCustom ? t.messageBody : l10n.tr(t.messageBody);
                return ActionChip(
                  label: Text(title, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _msgCtrl.text = body),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('mw_gs_reach_out_message_input'),
              controller: _msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.tr('gs_message_preview_label'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('mw_gs_send_sms_btn'),
                  onPressed: () => _send(TrustedContactChannel.sms),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kSerenPurple,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.sms_outlined, size: 16),
                  label: Text(l10n.tr('gs_send_sms_btn')),
                ),
                FilledButton.tonalIcon(
                  key: const Key('mw_gs_send_wa_btn'),
                  onPressed: () => _send(TrustedContactChannel.whatsapp),
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: Text(l10n.tr('gs_send_whatsapp_btn')),
                ),
                OutlinedButton.icon(
                  key: const Key('mw_gs_call_btn'),
                  onPressed: () => _send(TrustedContactChannel.call),
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: Text(l10n.tr('gs_call_btn')),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _msgCtrl.text));
                    if (context.mounted) {
                      _showL2Toast(context, l10n.tr('gs_copied_or_opened_toast'));
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(l10n.tr('gs_copy_message_btn')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-stigmatizing Professional Help Guidance modal (`GS-06`).
Future<void> showProfessionalHelpGuidanceSheet(BuildContext context) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(ctx),
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
                Expanded(
                  child: Text(
                    l10n.tr('gs_prof_guidance_title'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(ctx),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              l10n.tr('gs_prof_guidance_intro'),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary(ctx),
              ),
            ),
            const SizedBox(height: 12),
            _guidanceCard(
              ctx,
              title: l10n.tr('gs_prof_when_title'),
              body: l10n.tr('gs_prof_when_body'),
            ),
            const SizedBox(height: 8),
            _guidanceCard(
              ctx,
              title: l10n.tr('gs_prof_expect_title'),
              body: l10n.tr('gs_prof_expect_body'),
            ),
            const SizedBox(height: 8),
            _guidanceCard(
              ctx,
              title: l10n.tr('gs_prof_note_title'),
              body: l10n.tr('gs_prof_note_body'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _guidanceCard(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.elevatedSurface(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kSerenLavender.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    ),
  );
}

/// Private local Personal Support Plan editor (`GS-07`).
Future<void> showPersonalSupportPlanDialog(
  BuildContext context,
  BreakTheCycleProvider btc,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PersonalSupportPlanDialog(btc: btc),
  );
}

class _PersonalSupportPlanDialog extends StatefulWidget {
  final BreakTheCycleProvider btc;

  const _PersonalSupportPlanDialog({required this.btc});

  @override
  State<_PersonalSupportPlanDialog> createState() =>
      _PersonalSupportPlanDialogState();
}

class _PersonalSupportPlanDialogState
    extends State<_PersonalSupportPlanDialog> {
  late final TextEditingController _waysCtrl;
  late final TextEditingController _copingCtrl;
  late final TextEditingController _resCtrl;
  late final TextEditingController _emergCtrl;
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    final plan = widget.btc.personalSupportPlan;
    _waysCtrl = TextEditingController(text: plan.preferredWaysToAskForHelp);
    _copingCtrl = TextEditingController(text: plan.personalCopingStrategies);
    _resCtrl = TextEditingController(text: plan.helpfulResources);
    _emergCtrl = TextEditingController(text: plan.postSetbackOrEmergencySteps);
    _selectedIds = Set<String>.from(plan.trustedContactIds);
  }

  @override
  void dispose() {
    _waysCtrl.dispose();
    _copingCtrl.dispose();
    _resCtrl.dispose();
    _emergCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: AppColors.sheetSurface(context),
      title: Text(l10n.tr('gs_support_plan_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tr('gs_support_plan_sub'),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
            if (widget.btc.trustedContacts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.btc.trustedContacts.map((c) {
                  final checked = _selectedIds.contains(c.id);
                  return FilterChip(
                    selected: checked,
                    label: Text(c.name, style: const TextStyle(fontSize: 12)),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedIds.add(c.id);
                        } else {
                          _selectedIds.remove(c.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              key: const Key('mw_gs_plan_ways_input'),
              controller: _waysCtrl,
              maxLines: 2,
              decoration:
                  InputDecoration(labelText: l10n.tr('gs_plan_ways_label')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _copingCtrl,
              maxLines: 2,
              decoration:
                  InputDecoration(labelText: l10n.tr('gs_plan_coping_label')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _resCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: l10n.tr('gs_plan_resources_label')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emergCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: l10n.tr('gs_plan_emergency_label')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.tr('btc_common_cancel')),
        ),
        FilledButton(
          key: const Key('mw_gs_plan_save_btn'),
          onPressed: () async {
            final navigator = Navigator.of(context);
            await widget.btc.savePersonalSupportPlan(
              PersonalSupportPlan(
                trustedContactIds: _selectedIds.toList(),
                preferredWaysToAskForHelp: _waysCtrl.text.trim(),
                personalCopingStrategies: _copingCtrl.text.trim(),
                helpfulResources: _resCtrl.text.trim(),
                postSetbackOrEmergencySteps: _emergCtrl.text.trim(),
              ),
            );
            if (mounted) navigator.pop();
          },
          child: Text(l10n.tr('btc_common_save')),
        ),
      ],
    );
  }
}
