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
  static const Color echoColor = Color(0xFFD97706);

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
        spriteAsset: 'assets/mascots/sprites/echo/reflect.png',
        accentColor: echoColor,
        fallbackIcon: Icons.auto_stories_rounded,
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
            accentColor: const Color(0xFF6366F1),
          ),
          BirdToolGrid(
            tiles: [
              BirdToolTile(
                tileKey: const Key('echo_tool_knowledge_arena'),
                title: l10n.tr('house_echo_arena_title'),
                subtitle: l10n.tr('house_echo_arena_sub'),
                icon: Icons.school_outlined,
                accentColor: const Color(0xFF6366F1),
                onTap: () => _launchKnowledgeArena(context),
              ),
              BirdToolTile(
                tileKey: const Key('echo_tool_brain_playground'),
                title: l10n.tr('house_echo_brain_title'),
                subtitle: l10n.tr('house_echo_brain_sub'),
                icon: Icons.extension_outlined,
                accentColor: const Color(0xFF8B5CF6),
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
    final amberInk = AppColors.adaptive(
      context,
      dark: const Color(0xFFFBBF24),
      light: const Color(0xFF92400E),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF282015), Color(0xFF1A1B20)]
              : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: echoColor.withValues(alpha: isDark ? 0.38 : 0.28),
        ),
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
              SizedBox(
                width: 72,
                height: 72,
                child: Image.asset(
                  'assets/mascots/sprites/echo/grateful.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.auto_stories_rounded,
                    size: 44,
                    color: echoColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _openDiary(context, l10n),
                style: FilledButton.styleFrom(
                  backgroundColor: echoColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 17),
                label: Text(
                  l10n.tr('house_echo_open_diary'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('echo_hero_gratitude_btn'),
                onPressed: () => GratitudeJarSheet.show(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: amberInk,
                  side: BorderSide(color: echoColor.withValues(alpha: 0.45)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(
                  l10n.tr('house_echo_gratitude_jar', {'count': pebbleCount}),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
