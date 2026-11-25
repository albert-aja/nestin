import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/interactive_experience_models.dart';
import '../../../data/models/journal_entry.dart';
import '../../../providers/interactive_experience_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../widgets/gratitude_jar_sheet.dart';
import '../explore/nestin_discover_screen.dart';
import '../explore/strengths_lab_section.dart';
import '../journal/diary_entries_screen.dart';
import '../journal/memories_screen.dart';
import '../journal/timeline_screen.dart';
import 'bird_house_shared.dart';

/// Echo's House — Mindful Diary, Mood, Gratitude Jar, Memories & Echo Labs (`#D97706`).
class EchoHouseScreen extends StatelessWidget {
  static const Color echoColor = AppColors.echo;

  const EchoHouseScreen({super.key});

  Future<void> _launchKnowledgeArena(BuildContext context) async {
    final exp = tryReadProvider<InteractiveExperienceProvider>(context);
    if (exp == null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NestinDiscoverScreen()),
      );
      return;
    }
    final hasDraft = exp.draftFor(ExperienceCatalog.knowledgeArenaId) != null;
    if (hasDraft) {
      await exp.startOrResumeKnowledgeArena(topic: KnowledgeArenaTopic.all);
    } else {
      await exp.startFreshKnowledgeArena(topic: KnowledgeArenaTopic.all);
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const KnowledgeArenaFlowSheet(),
    );
  }

  Future<void> _launchBrainPlayground(BuildContext context) async {
    final exp = tryReadProvider<InteractiveExperienceProvider>(context);
    if (exp == null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NestinDiscoverScreen()),
      );
      return;
    }
    final hasDraft = exp.draftFor(ExperienceCatalog.brainPlaygroundId) != null;
    if (hasDraft) {
      await exp.startOrResumeBrainPlayground(
        category: BrainPlaygroundCategory.all,
      );
    } else {
      await exp.startFreshBrainPlayground(
        category: BrainPlaygroundCategory.all,
      );
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BrainPlaygroundFlowSheet(),
    );
  }

  Future<void> _launchStrengthsLab(BuildContext context) async {
    final exp = tryReadProvider<InteractiveExperienceProvider>(context);
    if (exp == null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NestinDiscoverScreen()),
      );
      return;
    }
    await StrengthsLabWizardSheet.show(
      context,
      expProvider: exp,
      initialDraft: exp.draftFor(ExperienceCatalog.strengthsLifeSkillsId),
    );
  }

  void _openDiary(BuildContext context, AppLocalizations l10n) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BirdToolPageScaffold(
          title: l10n.tr('tab_diary'),
          trackDiaryLifecycle: true,
          child: const DiaryEntriesScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final journal = tryWatchProvider<JournalProvider>(context);
    final entries = journal?.journalEntries ?? const <JournalEntry>[];
    final memories = journal?.memories ?? const [];
    final pebbles = journal?.getGratitudePebbles() ?? const [];

    final now = DateTime.now();
    JournalEntry? todayEntry;
    for (final entry in entries) {
      if (entry.date.year == now.year &&
          entry.date.month == now.month &&
          entry.date.day == now.day) {
        todayEntry = entry;
        break;
      }
    }

    return Scaffold(
      key: const Key('echo_house_screen'),
      appBar: buildBirdHouseAppBar(
        context,
        title: l10n.tr('house_echo_title'),
        subtitle: l10n.tr('nest_echo_subtitle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildHeroCard(
            context,
            l10n: l10n,
            todayEntry: todayEntry,
            pebbleCount: pebbles.length,
          ),
          const SizedBox(height: 18),
          BirdSectionLabel(
            text: l10n.tr('house_tools_section'),
            accentColor: echoColor,
          ),
          BirdToolGrid(
            tiles: [
              BirdToolTile(
                tileKey: const Key('echo_tool_diary'),
                title: l10n.tr('tab_diary'),
                subtitle: l10n.tr(
                  'house_echo_diary_sub',
                  {'count': entries.length},
                ),
                icon: Icons.book_outlined,
                accentColor: echoColor,
                onTap: () => _openDiary(context, l10n),
              ),
              BirdToolTile(
                tileKey: const Key('echo_tool_memories_timeline'),
                title: l10n.tr('house_echo_memories_timeline'),
                subtitle: l10n.tr(
                  'house_echo_memories_sub',
                  {'count': memories.length},
                ),
                icon: Icons.photo_album_outlined,
                accentColor: AppColors.primary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BirdTwoTabPageScaffold(
                      title: l10n.tr('house_echo_memories_timeline'),
                      accentColor: echoColor,
                      firstLabel: l10n.tr('tab_memories'),
                      firstIcon: Icons.star_outline_rounded,
                      firstChild: const MemoriesScreen(),
                      secondLabel: l10n.tr('tab_timeline'),
                      secondIcon: Icons.timeline_rounded,
                      secondChild: const TimelineScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          BirdSectionLabel(
            text: l10n.tr('house_echo_labs_section'),
            accentColor: AppColors.indigo,
          ),
          BirdToolGrid(
            tiles: [
              BirdToolTile(
                tileKey: const Key('echo_tool_knowledge_arena'),
                title: l10n.tr('house_echo_arena_title'),
                subtitle: l10n.tr('house_echo_arena_sub'),
                icon: Icons.school_outlined,
                accentColor: AppColors.indigo,
                onTap: () => _launchKnowledgeArena(context),
              ),
              BirdToolTile(
                tileKey: const Key('echo_tool_brain_playground'),
                title: l10n.tr('house_echo_brain_title'),
                subtitle: l10n.tr('house_echo_brain_sub'),
                icon: Icons.extension_outlined,
                accentColor: AppColors.seren,
                onTap: () => _launchBrainPlayground(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BirdToolTile(
            tileKey: const Key('echo_tool_strengths_lab'),
            title: l10n.tr('house_echo_strengths_title'),
            subtitle: l10n.tr('house_echo_strengths_sub'),
            icon: Icons.psychology_alt_rounded,
            accentColor: echoColor,
            onTap: () => _launchStrengthsLab(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required AppLocalizations l10n,
    required JournalEntry? todayEntry,
    required int pebbleCount,
  }) {
    final isDark = AppColors.isDark(context);

    return Container(
      key: const Key('echo_house_hero_card'),
      padding: const EdgeInsets.all(18),
      decoration: birdHouseCardDecoration(
        context,
        heroTintColor: echoColor,
        radius: 22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('house_echo_hero_title'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      todayEntry != null
                          ? l10n.tr('house_echo_mood_logged', {
                              'emoji': todayEntry.mood.emoji,
                              'label': todayEntry.mood.label,
                            })
                          : l10n.tr('house_echo_mood_empty'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const BirdHeroSpriteHalo(
                assetPath: 'assets/mascots/sprites/echo/grateful.png',
                accentColor: echoColor,
                fallbackIcon: Icons.auto_stories_rounded,
                size: 80,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('echo_hero_open_diary_btn'),
                onPressed: () => _openDiary(context, l10n),
                style: FilledButton.styleFrom(
                  backgroundColor: echoColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 17),
                label: Text(
                  l10n.tr('house_echo_open_diary'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('echo_hero_gratitude_btn'),
                onPressed: () => GratitudeJarSheet.show(context),
                style: TextButton.styleFrom(
                  backgroundColor: echoColor.withValues(
                    alpha: isDark ? 0.16 : 0.12,
                  ),
                  foregroundColor: AppColors.textPrimary(context),
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: echoColor,
                ),
                label: Text(
                  l10n.tr('house_echo_gratitude_jar', {'count': pebbleCount}),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
