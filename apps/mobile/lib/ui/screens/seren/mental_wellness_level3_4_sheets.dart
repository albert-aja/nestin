import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/journal_entry.dart';
import '../../../data/models/mental_wellness_models.dart';
import '../../../providers/break_the_cycle_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../journal/timeline_screen.dart';
import 'mental_wellness_level2_sheets.dart';

const Color _kSerenPurple = AppColors.seren;
const Color _kCrisisRose = AppColors.rose;

void _showL34Toast(BuildContext context, String msg) {
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

/// Level 4 Immediate Human & Verified Crisis Support Sheet (`GS-04`, `GS-05`).
/// Always accessible without any PIN gate (Crisis-Safety Override).
class CrisisSupportBridgeSheet extends StatefulWidget {
  final BreakTheCycleProvider btc;
  final SupportRegionFilter initialRegion;

  const CrisisSupportBridgeSheet({
    super.key,
    required this.btc,
    this.initialRegion = SupportRegionFilter.id,
  });

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
    SupportRegionFilter? initialRegion,
  }) {
    final localeCountry = Localizations.maybeLocaleOf(context)?.countryCode;
    final defaultRegion = initialRegion ??
        (localeCountry == 'US'
            ? SupportRegionFilter.us
            : localeCountry == 'ID'
                ? SupportRegionFilter.id
                : AppLocalizations.currentLanguage.name == 'id'
                    ? SupportRegionFilter.id
                    : SupportRegionFilter.global);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrisisSupportBridgeSheet(
        btc: btc,
        initialRegion: defaultRegion,
      ),
    );
  }

  @override
  State<CrisisSupportBridgeSheet> createState() =>
      _CrisisSupportBridgeSheetState();
}

class _CrisisSupportBridgeSheetState extends State<CrisisSupportBridgeSheet> {
  late SupportRegionFilter _region;

  @override
  void initState() {
    super.initState();
    _region = widget.initialRegion;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxH = MediaQuery.of(context).size.height * 0.88;
    final lifelines = widget.btc.crisisResourcesForRegion(_region);
    final directories = widget.btc.supportDirectoryForRegion(_region);

    return Container(
      key: const Key('mw_l4_crisis_sheet'),
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kCrisisRose.withValues(alpha: 0.12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/mascots/sprites/duos/seren_scout_crisis_lighthouse.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.health_and_safety_rounded,
                      color: _kCrisisRose,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.tr('mw_l4_crisis_sheet_title'),
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
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kCrisisRose.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _kCrisisRose.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      l10n.tr('mw_l4_crisis_safety_banner'),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: SupportRegionFilter.values.map((r) {
                      return ChoiceChip(
                        key: Key('mw_l4_region_${r.name}'),
                        selected: _region == r,
                        label: Text(l10n.tr(r.translationKey)),
                        onSelected: (_) => setState(() => _region = r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.tr('mw_l4_lifelines_heading'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...lifelines.map((entry) => _buildCrisisCard(context, entry)),
                  if (widget.btc.trustedContacts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: widget.btc.trustedContacts.map((contact) {
                        return FilledButton.tonalIcon(
                          onPressed: () => QuickReachOutSheet.show(
                            context,
                            btc: widget.btc,
                            contact: contact,
                          ),
                          icon: const Icon(Icons.person_outline_rounded, size: 16),
                          label: Text(contact.name),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    l10n.tr('mw_l4_directory_heading'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...directories.map((dir) => _buildDirectoryCard(context, dir)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrisisCard(BuildContext context, CrisisResourceEntry entry) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.organizationName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              l10n.tr(entry.roleKey),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.tr(entry.hoursKey)} • ${l10n.tr('mw_l4_verified_badge', {
                    'source': entry.verifiedSource,
                    'date': entry.lastVerifiedDate,
                  })}',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (entry.phoneOrShortcode.isNotEmpty)
                  FilledButton.icon(
                    key: Key('mw_l4_call_${entry.id}'),
                    onPressed: () => launchExternalUriWithFallback(
                      context,
                      'tel:${entry.phoneOrShortcode}',
                      fallbackClipboardText: entry.phoneOrShortcode,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kCrisisRose,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                    label: Text(
                      l10n.tr('mw_l4_call_lifeline_btn', {
                        'phone': entry.phoneOrShortcode,
                      }),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (entry.websiteUrl.isNotEmpty)
                  OutlinedButton.icon(
                    key: Key('mw_l4_web_${entry.id}'),
                    onPressed: () => launchExternalUriWithFallback(
                      context,
                      entry.websiteUrl,
                      fallbackClipboardText: entry.websiteUrl,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: Text(
                      l10n.tr('mw_l4_visit_site_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryCard(BuildContext context, SupportDirectoryEntry dir) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${dir.organizationName} • ${l10n.tr(dir.serviceTypeKey)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              l10n.tr(dir.descriptionKey),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.tr('mw_l4_verified_badge', {
                'source': dir.verifiedSource,
                'date': dir.lastVerifiedDate,
              }),
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: Key('mw_l4_dir_open_${dir.id}'),
              onPressed: () => launchExternalUriWithFallback(
                context,
                dir.websiteUrl.isNotEmpty
                    ? dir.websiteUrl
                    : 'tel:${dir.phoneOrShortcode}',
                fallbackClipboardText: dir.websiteUrl.isNotEmpty
                    ? dir.websiteUrl
                    : dir.phoneOrShortcode,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: Text(
                l10n.tr('mw_l4_visit_site_btn'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Curated Offline Educational Library Sheet (`SU-08`, `GS-06`).
class EducationalLibrarySheet extends StatelessWidget {
  final BreakTheCycleProvider btc;
  final JournalProvider? journal;

  const EducationalLibrarySheet({
    super.key,
    required this.btc,
    this.journal,
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
      builder: (_) => EducationalLibrarySheet(btc: btc, journal: journal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxH = MediaQuery.of(context).size.height * 0.86;
    return ChangeNotifierProvider<BreakTheCycleProvider>.value(
      value: btc,
      child: Consumer<BreakTheCycleProvider>(
        builder: (context, provider, _) {
          final bookmarks = provider.bookmarkedGuideIds;
          return Container(
            key: const Key('mw_l3_edu_library_sheet'),
            constraints: BoxConstraints(maxHeight: maxH),
            decoration: BoxDecoration(
              color: AppColors.sheetSurface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kSerenPurple.withValues(alpha: 0.14),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          'assets/mascots/sprites/duos/seren_echo_library_lantern.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.menu_book_rounded,
                            color: _kSerenPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.tr('mw_l3_edu_library_title'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              l10n.tr('mw_l3_edu_library_sub'),
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
                ),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: EducationalGuideSpec.catalog.map((guide) {
                      final isBookmarked = bookmarks.contains(guide.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: AppColors.elevatedSurface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: AppColors.border(context)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            key: Key('mw_l3_guide_tile_${guide.id}'),
                            leading: Icon(guide.icon, color: _kSerenPurple),
                            title: Text(
                              l10n.tr(guide.titleKey),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${l10n.tr(guide.category.translationKey)} • ${l10n.tr(guide.summaryKey)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              key: Key('mw_l3_bookmark_${guide.id}'),
                              tooltip: l10n.tr(
                                isBookmarked
                                    ? 'mw_l3_bookmarked_badge'
                                    : 'mw_l3_bookmark_btn',
                              ),
                              icon: Icon(
                                isBookmarked
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: isBookmarked ? _kSerenPurple : null,
                              ),
                              onPressed: () =>
                                  provider.toggleGuideBookmark(guide.id),
                            ),
                            onTap: () => GuideReaderSheet.show(
                              context,
                              btc: provider,
                              guide: guide,
                              journal: journal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Interactive reader + optional Echo guided reflection (`SU-03`, `SU-07`, `SU-08`).
class GuideReaderSheet extends StatefulWidget {
  final BreakTheCycleProvider btc;
  final EducationalGuideSpec guide;
  final JournalProvider? journal;

  const GuideReaderSheet({
    super.key,
    required this.btc,
    required this.guide,
    this.journal,
  });

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
    required EducationalGuideSpec guide,
    JournalProvider? journal,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GuideReaderSheet(
        btc: btc,
        guide: guide,
        journal: journal,
      ),
    );
  }

  @override
  State<GuideReaderSheet> createState() => _GuideReaderSheetState();
}

class _GuideReaderSheetState extends State<GuideReaderSheet> {
  final TextEditingController _reflectionCtrl = TextEditingController();
  JournalMood _selectedMood = JournalMood.neutral;

  @override
  void dispose() {
    _reflectionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final guide = widget.guide;
    final maxH = MediaQuery.of(context).size.height * 0.88;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      key: Key('mw_l3_guide_reader_${guide.id}'),
      constraints: BoxConstraints(maxHeight: maxH),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kSerenPurple.withValues(alpha: 0.14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/mascots/sprites/duos/seren_echo_library_lantern.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      guide.icon,
                      color: _kSerenPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.tr(guide.titleKey),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kSerenPurple.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.tr(guide.nonClinicalNoteKey),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < guide.sectionHeadingKeys.length; i++) ...[
              Text(
                l10n.tr(guide.sectionHeadingKeys[i]),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tr(guide.sectionBodyKeys[i]),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('mw_l3_pin_guide_kit_btn'),
                  onPressed: () async {
                    final title = l10n.tr(guide.titleKey);
                    await widget.btc.addComfortKitItem(
                      ComfortKitItem(
                        id: 'kit_guide_${guide.id}',
                        kind: ComfortKitItemKind.encouragementNote,
                        title: title,
                        subtitle: l10n.tr(guide.summaryKey),
                        referenceId: guide.id,
                        isPinned: true,
                        isCustomNote: true,
                        createdAt: DateTime.now(),
                      ),
                    );
                    if (context.mounted) {
                      _showL34Toast(
                        context,
                        l10n.tr('mw_l3_guide_pinned_toast', {'title': title}),
                      );
                    }
                  },
                  icon: const Icon(Icons.push_pin_outlined, size: 16),
                  label: Text(l10n.tr('mw_l3_pin_guide_kit_btn')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tr('mw_l3_reflection_optional_title'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.tr(guide.reflectionPromptKey),
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tr('mw_l3_reflection_mood_label'),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: JournalMood.values.map((m) {
                return ChoiceChip(
                  selected: _selectedMood == m,
                  label: Text('${m.emoji} ${m.name}'),
                  onSelected: (_) => setState(() => _selectedMood = m),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('mw_l3_guide_reflection_input'),
              controller: _reflectionCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.tr('mw_l3_reflection_hint'),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('mw_l3_guide_reflection_save_btn'),
              onPressed: widget.journal == null
                  ? null
                  : () async {
                      final text = _reflectionCtrl.text.trim();
                      if (text.isEmpty) return;
                      final navigator = Navigator.of(context);
                      await widget.btc.saveGuidedReflectionToEcho(
                        journalProvider: widget.journal!,
                        promptTitle: l10n.tr(guide.titleKey),
                        reflectionText: text,
                        guideId: guide.id,
                        mood: _selectedMood,
                      );
                      if (context.mounted) {
                        _showL34Toast(
                          context,
                          l10n.tr('mw_l3_reflection_saved_toast'),
                        );
                        navigator.pop();
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _kSerenPurple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.lock_outline_rounded, size: 17),
              label: Text(l10n.tr('mw_l3_reflection_save_btn')),
            ),
          ],
        ),
      ),
    );
  }
}

/// User-authored Personal Insights & Echo Timeline bridge (`SU-09`).
class PersonalInsightsAndHistorySheet extends StatefulWidget {
  final BreakTheCycleProvider btc;
  final JournalProvider? journal;
  final SettingsProvider? settings;

  const PersonalInsightsAndHistorySheet({
    super.key,
    required this.btc,
    this.journal,
    this.settings,
  });

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
    JournalProvider? journal,
    SettingsProvider? settings,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PersonalInsightsAndHistorySheet(
        btc: btc,
        journal: journal,
        settings: settings,
      ),
    );
  }

  @override
  State<PersonalInsightsAndHistorySheet> createState() =>
      _PersonalInsightsAndHistorySheetState();
}

class _PersonalInsightsAndHistorySheetState
    extends State<PersonalInsightsAndHistorySheet> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _obsCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxH = MediaQuery.of(context).size.height * 0.86;
    final isLocked = widget.settings != null &&
        widget.settings!.isDiaryLockEnabled &&
        !widget.settings!.isDiaryUnlocked;
    final serenEchoEntries = widget.journal?.journalEntries
            .where((e) => e.tags.contains('Seren'))
            .take(5)
            .toList() ??
        const <JournalEntry>[];

    return ChangeNotifierProvider<BreakTheCycleProvider>.value(
      value: widget.btc,
      child: Consumer<BreakTheCycleProvider>(
        builder: (context, provider, _) {
          return Container(
            key: const Key('mw_l3_insights_sheet'),
            constraints: BoxConstraints(maxHeight: maxH),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.sheetSurface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kSerenPurple.withValues(alpha: 0.14),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          'assets/mascots/sprites/duos/seren_echo_library_lantern.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: _kSerenPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.tr('mw_l3_insights_title'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              l10n.tr('mw_l3_insights_sub'),
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
                  TextField(
                    key: const Key('mw_l3_insight_title_input'),
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.tr('mw_l3_insight_title_label'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('mw_l3_insight_obs_input'),
                    controller: _obsCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.tr('mw_l3_insight_obs_label'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    key: const Key('mw_l3_insight_save_btn'),
                    onPressed: () async {
                      final obs = _obsCtrl.text.trim();
                      if (obs.isEmpty) return;
                      final title = _titleCtrl.text.trim().isNotEmpty
                          ? _titleCtrl.text.trim()
                          : obs;
                      await provider.addPersonalInsightNote(
                        title: title,
                        observation: obs,
                      );
                      _titleCtrl.clear();
                      _obsCtrl.clear();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _kSerenPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.tr('mw_l3_insight_save_btn')),
                  ),
                  const SizedBox(height: 12),
                  if (provider.personalInsights.isEmpty)
                    Text(
                      l10n.tr('mw_l3_insight_empty'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    )
                  else
                    ...provider.personalInsights.map((note) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.elevatedSurface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppColors.border(context)),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              note.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              note.observation,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              key: Key('mw_l3_insight_del_${note.id}'),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () =>
                                  provider.deletePersonalInsightNote(note.id),
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  Text(
                    l10n.tr('mw_l3_echo_reflections_heading'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isLocked)
                    Text(
                      l10n.tr('mw_l3_echo_locked_hint'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    )
                  else
                    ...serenEchoEntries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.elevatedSurface(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.title} — ${entry.content}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      );
                    }),
                  if (widget.journal != null && widget.settings != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('mw_l3_open_echo_timeline_btn'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TimelineScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.timeline_rounded, size: 16),
                      label: Text(l10n.tr('mw_l3_open_echo_timeline_btn')),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sensitive Data Deletion & Passphrase-Encrypted Export/Import Sheet.
class SensitiveDataPrivacySheet extends StatefulWidget {
  final BreakTheCycleProvider btc;

  const SensitiveDataPrivacySheet({
    super.key,
    required this.btc,
  });

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SensitiveDataPrivacySheet(btc: btc),
    );
  }

  @override
  State<SensitiveDataPrivacySheet> createState() =>
      _SensitiveDataPrivacySheetState();
}

class _SensitiveDataPrivacySheetState extends State<SensitiveDataPrivacySheet> {
  final TextEditingController _passphraseCtrl = TextEditingController();
  final TextEditingController _importCtrl = TextEditingController();
  String? _lastExportedEnvelope;

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    _importCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxH = MediaQuery.of(context).size.height * 0.88;

    return ChangeNotifierProvider<BreakTheCycleProvider>.value(
      value: widget.btc,
      child: Consumer<BreakTheCycleProvider>(
        builder: (context, provider, _) {
          final triggers = provider.triggerReflections;
          final recoveries = provider.recoveryReflections;
          return Container(
            key: const Key('mw_l3_privacy_sheet'),
            constraints: BoxConstraints(maxHeight: maxH),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.sheetSurface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kSerenPurple.withValues(alpha: 0.14),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          'assets/mascots/sprites/duos/echo_seren_encrypted_vault_key.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.enhanced_encryption_outlined,
                            color: _kSerenPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.tr('mw_l3_privacy_sheet_title'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              l10n.tr('mw_l3_privacy_sheet_sub'),
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
                  const SizedBox(height: 12),
                  Text(
                    l10n.tr('mw_l3_granular_section'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (triggers.isEmpty && recoveries.isEmpty)
                    Text(
                      l10n.tr('mw_l3_granular_empty'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    )
                  else ...[
                    ...triggers.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: AppColors.elevatedSurface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              '${l10n.tr('mw_l3_trigger_prefix')} • ${t.emotionalState.isNotEmpty ? t.emotionalState : t.currentActivity}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              key: Key('mw_l3_del_trigger_${t.id}'),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () =>
                                  provider.deleteTriggerReflection(t.id),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...recoveries.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: AppColors.elevatedSurface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              '${l10n.tr('mw_l3_recovery_prefix')} • ${r.whatHappened}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              key: Key('mw_l3_del_recovery_${r.id}'),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () =>
                                  provider.deleteRecoveryReflection(r.id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (provider.personalSupportPlan.hasContent)
                        OutlinedButton(
                          key: const Key('mw_l3_clear_support_plan_btn'),
                          onPressed: () => provider.clearPersonalSupportPlan(),
                          child: Text(l10n.tr('mw_l3_clear_support_plan_btn')),
                        ),
                      if (provider.relapsePreventionPlan.hasContent)
                        OutlinedButton(
                          key: const Key('mw_l3_clear_relapse_plan_btn'),
                          onPressed: () => provider.clearRelapsePreventionPlan(),
                          child: Text(l10n.tr('mw_l3_clear_relapse_plan_btn')),
                        ),
                      OutlinedButton.icon(
                        key: const Key('mw_l3_reset_all_btn'),
                        onPressed: () async {
                          await provider.resetAllMentalWellnessData();
                          if (context.mounted) {
                            _showL34Toast(
                              context,
                              l10n.tr('mw_l3_reset_done_toast'),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                        label: Text(l10n.tr('mw_l3_reset_all_btn')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.tr('mw_l3_encrypt_section'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('mw_l3_encrypt_passphrase_input'),
                    controller: _passphraseCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.tr('mw_l3_encrypt_passphrase_label'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('mw_l3_export_encrypted_btn'),
                    onPressed: () async {
                      final pass = _passphraseCtrl.text.trim();
                      if (pass.isEmpty) return;
                      final envelope = provider.exportEncryptedBackup(pass);
                      setState(() => _lastExportedEnvelope = envelope);
                      try {
                        await Clipboard.setData(ClipboardData(text: envelope));
                      } catch (_) {}
                      if (!context.mounted) return;
                      _showL34Toast(
                        context,
                        l10n.tr('mw_l3_export_encrypted_toast'),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _kSerenPurple,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.vpn_key_outlined, size: 17),
                    label: Text(l10n.tr('mw_l3_export_encrypted_btn')),
                  ),
                  if (_lastExportedEnvelope != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      _lastExportedEnvelope!,
                      key: const Key('mw_l3_exported_envelope_preview'),
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('mw_l3_import_encrypted_input'),
                    controller: _importCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.tr('mw_l3_import_encrypted_label'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('mw_l3_import_encrypted_btn'),
                    onPressed: () async {
                      final pass = _passphraseCtrl.text.trim();
                      final raw = _importCtrl.text.trim();
                      if (pass.isEmpty || raw.isEmpty) return;
                      final ok = await provider.importEncryptedBackup(raw, pass);
                      if (context.mounted) {
                        _showL34Toast(
                          context,
                          l10n.tr(
                            ok
                                ? 'mw_l3_import_success_toast'
                                : 'mw_l3_import_fail_toast',
                          ),
                        );
                      }
                    },
                    child: Text(l10n.tr('mw_l3_import_encrypted_btn')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dialog for adding a flexible guilt-free Well-being Intention (`HL-07`).
Future<void> showAddWellbeingGoalDialog(
  BuildContext context,
  BreakTheCycleProvider btc,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AddWellbeingGoalDialog(btc: btc),
  );
}

class _AddWellbeingGoalDialog extends StatefulWidget {
  final BreakTheCycleProvider btc;

  const _AddWellbeingGoalDialog({required this.btc});

  @override
  State<_AddWellbeingGoalDialog> createState() =>
      _AddWellbeingGoalDialogState();
}

class _AddWellbeingGoalDialogState extends State<_AddWellbeingGoalDialog> {
  final TextEditingController _titleCtrl = TextEditingController();
  String _categoryKey = 'mw_l3_goal_cat_balance';

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const cats = [
      'mw_l3_goal_cat_balance',
      'mw_l3_goal_cat_movement',
      'mw_l3_goal_cat_rest',
    ];
    return AlertDialog(
      key: const Key('mw_hl_add_goal_dialog'),
      backgroundColor: AppColors.sheetSurface(context),
      title: Text(l10n.tr('mw_l3_add_goal_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('mw_hl_goal_title_input'),
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: l10n.tr('mw_l3_add_goal_hint'),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: cats.map((k) {
              return ChoiceChip(
                selected: _categoryKey == k,
                label: Text(l10n.tr(k)),
                onSelected: (_) => setState(() => _categoryKey = k),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.tr('btc_common_cancel')),
        ),
        FilledButton(
          key: const Key('mw_hl_goal_save_btn'),
          onPressed: () async {
            final title = _titleCtrl.text.trim();
            if (title.isEmpty) return;
            final navigator = Navigator.of(context);
            await widget.btc.addWellbeingGoal(
              title: title,
              categoryKey: _categoryKey,
            );
            if (mounted) navigator.pop();
          },
          child: Text(l10n.tr('btc_common_save')),
        ),
      ],
    );
  }
}
