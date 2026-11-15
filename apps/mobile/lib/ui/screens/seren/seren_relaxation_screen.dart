import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/models/seren_relaxation_models.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/seren_relaxation_provider.dart';
import '../../widgets/seren_visual_canvas.dart';

class SerenRelaxationScreen extends StatefulWidget {
  final RelaxationTimeOfDayMode? initialTimeOfDayMode;
  final int initialTabIndex;

  const SerenRelaxationScreen({
    super.key,
    this.initialTimeOfDayMode,
    this.initialTabIndex = 0,
  });

  @override
  State<SerenRelaxationScreen> createState() => _SerenRelaxationScreenState();
}

class _SerenRelaxationScreenState extends State<SerenRelaxationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AmbientSoundCategory? _selectedSoundCategory;
  VisualEnvironmentCategory? _selectedVisualCategory;
  String _readingFilter = 'all'; // all, morning, evening, bookmarked, favorites, history

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    if (widget.initialTimeOfDayMode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<SerenRelaxationProvider>()
            .setTimeOfDayMode(widget.initialTimeOfDayMode!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seren = context.watch<SerenRelaxationProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tr('seren_screen_title'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            Text(
              l10n.tr('seren_screen_subtitle'),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.tr('seren_timer_title'),
            onPressed: () => _showSleepTimerSheet(context),
            icon: Badge(
              isLabelVisible: seren.isTimerActive,
              label: Text(seren.formattedTimerRemaining),
              child: Icon(
                seren.isTimerActive
                    ? Icons.timer_rounded
                    : Icons.timer_outlined,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.tr('seren_reminders_title'),
            onPressed: () => _showRemindersSheet(context),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              icon: const Icon(Icons.tune_rounded, size: 18),
              text: l10n.tr('seren_tab_sounds_mixer'),
            ),
            Tab(
              icon: const Icon(Icons.air_rounded, size: 18),
              text: l10n.tr('seren_tab_guided_calm'),
            ),
            Tab(
              icon: const Icon(Icons.landscape_rounded, size: 18),
              text: l10n.tr('seren_tab_visuals'),
            ),
            Tab(
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              text: l10n.tr('seren_tab_stories_tts'),
            ),
            Tab(
              icon: const Icon(Icons.spa_rounded, size: 18),
              text: l10n.tr('seren_tab_mindful'),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTopModeAndHeroBanner(context, seren, l10n),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSoundsAndMixerTab(context, seren, l10n),
                _buildGuidedCalmTab(context, seren, l10n),
                _buildVisualsTab(context, seren, l10n),
                _buildStoriesAndTtsTab(context, seren, l10n),
                _buildMindfulTab(context, seren, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TOP MODE BAR & HERO VISUAL / AUDIO SANCTUARY BANNER
  // ===========================================================================

  Widget _buildTopModeAndHeroBanner(
    BuildContext context,
    SerenRelaxationProvider seren,
    AppLocalizations l10n,
  ) {
    final scene = seren.activeVisualScene;
    final showVisual = seren.playbackMode != RelaxationPlaybackMode.audioOnly;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...RelaxationTimeOfDayMode.values.map((mode) {
                  final selected = seren.timeOfDayMode == mode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      avatar: Icon(mode.icon, size: 16),
                      label: Text(mode.label),
                      onSelected: (_) => seren.setTimeOfDayMode(mode),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                PopupMenuButton<RelaxationPlaybackMode>(
                  tooltip: l10n.tr('seren_playback_mode_label'),
                  onSelected: seren.setPlaybackMode,
                  itemBuilder: (_) => RelaxationPlaybackMode.values
                      .map(
                        (m) => CheckedPopupMenuItem<RelaxationPlaybackMode>(
                          value: m,
                          checked: seren.playbackMode == m,
                          child: Text(m.label),
                        ),
                      )
                      .toList(),
                  child: Chip(
                    avatar: Icon(seren.playbackMode.icon, size: 16),
                    label: Text(seren.playbackMode.label),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (showVisual)
            SerenVisualCanvas(
              scene: scene,
              lowMotion: seren.lowMotionVisuals,
              height: 118,
              borderRadius: BorderRadius.circular(18),
              overlayChild: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.58),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            scene.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _buildActiveMixSummaryText(seren, l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (seren.isTimerActive)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          seren.formattedTimerRemaining,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: l10n.tr('seren_fullscreen_visual'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SerenFullscreenVisualPlayer(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('seren_hero_play_toggle'),
                      onPressed: seren.toggleMixerPlayback,
                      icon: Icon(
                        seren.isMixerPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.headphones_rounded),
                title: Text(l10n.tr('seren_mode_audio_only')),
                subtitle: Text(_buildActiveMixSummaryText(seren, l10n)),
                trailing: IconButton.filled(
                  key: const Key('seren_hero_play_toggle'),
                  onPressed: seren.toggleMixerPlayback,
                  icon: Icon(
                    seren.isMixerPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _buildActiveMixSummaryText(
    SerenRelaxationProvider seren,
    AppLocalizations l10n,
  ) {
    if (seren.activeTracks.isEmpty) {
      return l10n.tr('seren_mixer_empty_hint');
    }
    final names = seren.activeTracks
        .map((t) => SerenRelaxationCatalog.soundById(t.soundId).title)
        .join(' + ');
    return names;
  }

  // ===========================================================================
  // TAB 1: AMBIENT SOUND LIBRARY & MULTI-TRACK MIXER (FEATURES A & B)
  // ===========================================================================

  Widget _buildSoundsAndMixerTab(
    BuildContext context,
    SerenRelaxationProvider seren,
    AppLocalizations l10n,
  ) {
    final filteredSounds = seren.soundsForCategory(_selectedSoundCategory);
    final favorites = seren.favoriteSounds;
    final recents = seren.recentSounds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _buildMultiTrackMixerCard(context, seren, l10n),
        const SizedBox(height: 16),
        _buildPresetsAndSavedMixesSection(context, seren, l10n),
        if (favorites.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.tr('seren_section_favorites'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: favorites
                .map(
                  (sound) => ActionChip(
                    avatar: Icon(sound.icon, size: 16, color: sound.accentColor),
                    label: Text(sound.title),
                    onPressed: () => seren.playSingleSound(sound.id),
                  ),
                )
                .toList(),
          ),
        ],
        if (recents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.tr('seren_section_recently_played'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recents
                .map(
                  (sound) => ActionChip(
                    avatar: Icon(sound.icon, size: 16, color: sound.accentColor),
                    label: Text(sound.title),
                    onPressed: () => seren.playSingleSound(sound.id),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          l10n.tr('seren_section_sound_library'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: _selectedSoundCategory == null,
                  label: Text(l10n.tr('seren_filter_all')),
                  onSelected: (_) =>
                      setState(() => _selectedSoundCategory = null),
                ),
              ),
              ...AmbientSoundCategory.values.map((cat) {
                final selected = _selectedSoundCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    avatar: Icon(cat.icon, size: 16),
                    label: Text(cat.label),
                    onSelected: (_) =>
                        setState(() => _selectedSoundCategory = cat),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...filteredSounds.map((sound) {
          final inMix = seren.isSoundInMix(sound.id);
          final isFav = seren.isSoundFavorite(sound.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: inMix
                  ? BorderSide(color: sound.accentColor, width: 1.5)
                  : BorderSide.none,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: sound.accentColor.withValues(alpha: 0.16),
                child: Icon(sound.icon, color: sound.accentColor),
              ),
              title: Text(
                sound.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                sound.subtitle,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.tr('seren_action_favorite'),
                    onPressed: () => seren.toggleFavoriteSound(sound.id),
                    icon: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav ? Colors.pinkAccent : null,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    key: Key('seren_mix_toggle_${sound.id}'),
                    tooltip: inMix
                        ? l10n.tr('seren_action_remove_from_mix')
                        : l10n.tr('seren_action_add_to_mix'),
                    onPressed: () => seren.toggleTrackInMix(sound.id),
                    icon: Icon(
                      inMix
                          ? Icons.remove_circle_outline_rounded
                          : Icons.add_circle_outline_rounded,
                      color: inMix ? sound.accentColor : null,
                    ),
                  ),
                  IconButton.filledTonal(
                    key: Key('seren_play_single_${sound.id}'),
                    tooltip: l10n.tr('seren_action_quick_play'),
                    onPressed: () => seren.playSingleSound(sound.id),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMultiTrackMixerCard(
    BuildContext context,
    SerenRelaxationProvider seren,
    AppLocalizations l10n,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('seren_mixer_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.all_inclusive_rounded,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              l10n.tr('seren_loop_seamless_badge'),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const Key('seren_save_mix_button'),
                  onPressed: seren.activeTracks.isEmpty
                      ? null
                      : () => _showSaveSoundscapeDialog(context),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(l10n.tr('seren_action_save_mix')),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.volume_up_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  l10n.tr('seren_master_volume'),
                  style: const TextStyle(fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    key: const Key('seren_master_volume_slider'),
                    value: seren.masterVolume,
                    onChanged: seren.setMasterVolume,
                  ),
                ),
                Text('${(seren.masterVolume * 100).round()}%'),
              ],
            ),
            const Divider(),
            if (seren.activeTracks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.tr('seren_mixer_empty_hint')),
              )
            else
              ...seren.activeTracks.map((track) {
                final sound = SerenRelaxationCatalog.soundById(track.soundId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(sound.icon, color: sound.accentColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sound.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            key: Key('seren_mute_${track.soundId}'),
                            tooltip: l10n.tr('seren_action_mute_track'),
                            onPressed: () =>
                                seren.toggleTrackMute(track.soundId),
                            icon: Icon(
                              track.isMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.tr('seren_action_remove_from_mix'),
                            onPressed: () =>
                                seren.toggleTrackInMix(track.soundId),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                      Slider(
                        key: Key('seren_track_volume_${track.soundId}'),
                        value: track.isMuted ? 0.0 : track.volume,
                        onChanged: (v) =>
                            seren.setTrackVolume(track.soundId, v),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l10n.tr('seren_label_distance'),
                            style: const TextStyle(fontSize: 11),
                          ),
                          ...SoundDistance.values.map((dist) {
                            return ChoiceChip(
                              key: Key(
                                'seren_distance_${track.soundId}_${dist.name}',
                              ),
                              selected: track.distance == dist,
                              label: Text(
                                dist.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => seren.setTrackDistance(
                                track.soundId,
                                dist,
                              ),
                            );
                          }),
                          const SizedBox(width: 6),
                          Text(
                            l10n.tr('seren_label_stereo'),
                            style: const TextStyle(fontSize: 11),
                          ),
                          ...StereoPosition.values.map((pos) {
                            return ChoiceChip(
                              key: Key(
                                'seren_stereo_${track.soundId}_${pos.name}',
                              ),
                              selected: track.stereoPosition == pos,
                              label: Text(
                                pos.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => seren.setTrackStereoPosition(
                                track.soundId,
                                pos,
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildTrackWarmthEqRow(context, seren, track, l10n),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackWarmthEqRow(
    BuildContext context,
    SerenRelaxationProvider seren,
    SoundMixerTrackConfig track,
    AppLocalizations l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = track.toneWarmth <= -0.18
        ? Colors.amber.shade700
        : (track.toneWarmth >= 0.18 ? Colors.lightBlue.shade600 : colorScheme.secondary);

    return Row(
      children: [
        Icon(
          track.toneWarmth <= -0.18
              ? Icons.nights_stay_rounded
              : (track.toneWarmth >= 0.18
                  ? Icons.wb_sunny_outlined
                  : Icons.tune_rounded),
          size: 15,
          color: badgeColor,
        ),
        const SizedBox(width: 4),
        Text(
          l10n.tr('seren_label_tone_warmth'),
          style: const TextStyle(fontSize: 11),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              key: Key('seren_track_warmth_${track.soundId}'),
              min: -1.0,
              max: 1.0,
              divisions: 20,
              activeColor: badgeColor,
              value: track.toneWarmth,
              onChanged: (v) =>
                  seren.setTrackToneWarmth(track.soundId, v, commitAudio: false),
              onChangeEnd: (v) =>
                  seren.setTrackToneWarmth(track.soundId, v, commitAudio: true),
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: track.toneWarmth.abs() >= 0.05
              ? () => seren.setTrackToneWarmth(track.soundId, 0.0)
              : null,
          child: Container(
            key: Key('seren_track_warmth_badge_${track.soundId}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              track.toneLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetsAndSavedMixesSection(
    BuildContext context,
    SerenRelaxationProvider seren,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tr('seren_section_curated_presets'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: seren.curatedPresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final preset = seren.curatedPresets[index];
              final isSelected = seren.activeSoundscapeId == preset.id;
              return SizedBox(
                width: 215,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isSelected
                        ? BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          )
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => seren.loadSoundscape(preset),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(preset.recommendedFor.icon, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  preset.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: l10n.tr('seren_action_duplicate_mix'),
                                onPressed: () =>
                                    seren.duplicateSoundscape(preset),
                                icon: const Icon(Icons.copy_rounded, size: 15),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            preset.tracks
                                .map((t) =>
                                    SerenRelaxationCatalog.soundById(t.soundId)
                                        .title)
                                .join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (seren.customSoundscapes.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            l10n.tr('seren_section_saved_soundscapes'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...seren.customSoundscapes.map((custom) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                onTap: () => seren.loadSoundscape(custom),
                leading: const Icon(Icons.auto_awesome_rounded, size: 20),
                title: Text(
                  custom.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  custom.tracks
                      .map((t) =>
                          SerenRelaxationCatalog.soundById(t.soundId).title)
                      .join(' + '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'rename') {
                      _showRenameSoundscapeDialog(context, custom);
                    } else if (action == 'update') {
                      seren.updateCustomSoundscapeFromCurrentMix(custom.id);
                    } else if (action == 'duplicate') {
                      seren.duplicateSoundscape(custom);
                    } else if (action == 'delete') {
                      seren.deleteCustomSoundscape(custom.id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(l10n.tr('seren_action_rename_mix')),
                    ),
                    PopupMenuItem(
                      value: 'update',
                      child: Text(l10n.tr('seren_action_update_mix')),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text(l10n.tr('seren_action_duplicate_mix')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.tr('seren_action_delete_mix')),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ===========================================================================
  // TAB 2: GUIDED RELAXATION & BREATHING SESSIONS (FEATURE C)
  // ===========================================================================

  Widget _buildGuidedCalmTab(
    BuildContext context,
    SerenRelaxationProvider seren,
    AppLocalizations l10n,
  ) {
    final active = seren.activeGuidedSession ??
        SerenRelaxationCatalog.guidedSessions.first;
    final step = seren.currentBreathingStep;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.favorite_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.tr('seren_prompt_stop_if_uncomfortable'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  active.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  active.subtitle,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Container(
                  width: 150,
                  height: 150,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        active.accentColor.withValues(alpha: 0.45),
                        active.accentColor.withValues(alpha: 0.10),
                      ],
                    ),
                    border: Border.all(
                      color: active.accentColor.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        seren.isGuidedSessionRunning && step != null
                            ? step.label
                            : active.category.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (seren.isGuidedSessionRunning) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${seren.guidedPhaseSecondsRemaining}s',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: active.availableDurationsMinutes.map((mins) {
                    return ChoiceChip(
                      selected: seren.guidedDurationMinutes == mins,
                      label: Text('$mins ${l10n.tr('seren_unit_min')}'),
                      onSelected: (_) {
                        seren.startGuidedSession(
                          active,
                          durationMinutes: mins,
                        );
                      },
                    );
                  }).toList(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.tr('seren_guided_voice_narration'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: seren.guidedNarrationEnabled,
                  onChanged: seren.setGuidedNarrationEnabled,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!seren.isGuidedSessionRunning)
                      FilledButton.icon(
                        key: const Key('seren_start_guided_btn'),
                        onPressed: () => seren.startGuidedSession(active),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(l10n.tr('seren_action_begin_session')),
                      )
                    else ...[
                      FilledButton.tonalIcon(
                        onPressed: seren.isGuidedSessionPaused
                            ? seren.resumeGuidedSession
                            : seren.pauseGuidedSession,
                        icon: Icon(
                          seren.isGuidedSessionPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(
                          seren.isGuidedSessionPaused
                              ? l10n.tr('seren_action_resume')
                              : l10n.tr('seren_action_pause'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const Key('seren_stop_guided_btn'),
                        onPressed: seren.stopGuidedSession,
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(l10n.tr('seren_action_end_session')),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                ...active.localizedPrompts.map(
                  (prompt) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '• $prompt',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.tr('seren_section_guided_catalog'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...SerenRelaxationCatalog.guidedSessions.map((session) {
          final isSelected = active.id == session.id;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isSelected
                  ? BorderSide(color: session.accentColor, width: 1.5)
                  : BorderSide.none,
            ),
            child: ListTile(
              onTap: () => seren.startGuidedSession(session),
              leading: CircleAvatar(
                backgroundColor: session.accentColor.withValues(alpha: 0.16),
                child: Icon(session.icon, color: session.accentColor),
              ),
              title: Text(
                session.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(session.subtitle),
              trailing: Text(
                '${session.defaultDurationMinutes} ${l10n.tr('seren_unit_min')}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: CALMING VISUAL EXPERIENCES & PAIRING (FEATURES E & F)
  // ===========================================================================

  Widget _buildVisualsTab(
    BuildContext context,
    SerenRelaxationProvider seren,
    AppLocalizations l10n,
  ) {
    final scenes = _selectedVisualCategory == null
        ? SerenRelaxationCatalog.visuals
        : SerenRelaxationCatalog.visuals
            .where((v) => v.category == _selectedVisualCategory)
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            secondary: const Icon(Icons.motion_photos_paused_rounded),
            title: Text(l10n.tr('seren_low_motion_mode')),
            subtitle: Text(l10n.tr('seren_low_motion_subtitle')),
            value: seren.lowMotionVisuals,
            onChanged: seren.setLowMotionVisuals,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: _selectedVisualCategory == null,
                  label: Text(l10n.tr('seren_filter_all')),
                  onSelected: (_) =>
                      setState(() => _selectedVisualCategory = null),
                ),
              ),
              ...VisualEnvironmentCategory.values.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _selectedVisualCategory == cat,
                    label: Text(cat.label),
                    onSelected: (_) =>
                        setState(() => _selectedVisualCategory = cat),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...scenes.map((scene) {
          final isSelected = seren.activeVisualId == scene.id;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: isSelected
                  ? BorderSide(color: scene.accentParticleColor, width: 2)
                  : BorderSide.none,
            ),
            child: Column(
              children: [
                SerenVisualCanvas(
                  scene: scene,
                  lowMotion: seren.lowMotionVisuals,
                  height: 96,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                ListTile(
                  title: Text(
                    scene.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(scene.subtitle),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () => seren.selectVisualScene(
                          scene.id,
                          pairSuggestedAudio: false,
                        ),
                        child: Text(l10n.tr('seren_action_visual_only')),
                      ),
                      FilledButton.tonal(
                        key: Key('seren_pair_visual_${scene.id}'),
                        onPressed: () => seren.selectVisualScene(
                          scene.id,
                          pairSuggestedAudio: true,
                        ),
                        child: Text(l10n.tr('seren_action_pair_audio_visual')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: BEDTIME STORIES, RELAXATION READING & NATIVE TTS (FEATURE G)
  // ===========================================================================

  Widget _buildStoriesAndTtsTab(
    BuildContext context,
    SerenRelaxationProvider seren,
    AppLocalizations l10n,
  ) {
    final activeReading =
        seren.activeReading ?? SerenRelaxationCatalog.readings.first;
    final paragraphs = activeReading.paragraphs;
    final filteredReadings = _filterReadings(seren);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(activeReading.category.icon, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeReading.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('seren_bookmark_${activeReading.id}'),
                      tooltip: l10n.tr('seren_action_bookmark'),
                      onPressed: () =>
                          seren.toggleBookmarkReading(activeReading.id),
                      icon: Icon(
                        seren.isReadingBookmarked(activeReading.id)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.tr('seren_action_favorite'),
                      onPressed: () =>
                          seren.toggleFavoriteReading(activeReading.id),
                      icon: Icon(
                        seren.isReadingFavorite(activeReading.id)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: seren.isReadingFavorite(activeReading.id)
                            ? Colors.pinkAccent
                            : null,
                      ),
                    ),
                  ],
                ),
                Text(
                  activeReading.subtitle,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.schedule_rounded, size: 15),
                      label: Text(
                        l10n.tr('seren_reading_minutes_read', {
                          'minutes': activeReading.estimatedMinutes,
                        }),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    if (activeReading.isMultiChapter)
                      Chip(
                        key: const Key('seren_active_chapter_badge'),
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.menu_book_rounded, size: 15),
                        label: Text(
                          l10n.tr('seren_reading_chapter_badge', {
                            'current': seren.activeReadingChapterIndex + 1,
                            'total': activeReading.chapterCount,
                          }),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    if (activeReading.seasonTag != null)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          activeReading.seasonTag!.icon,
                          size: 15,
                        ),
                        label: Text(
                          activeReading.seasonTag!.label,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
                if (activeReading.isMultiChapter) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        l10n.tr('seren_reading_chapters_label'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('seren_prev_chapter_btn'),
                        tooltip: l10n.tr('seren_reading_prev_chapter'),
                        visualDensity: VisualDensity.compact,
                        onPressed: seren.activeReadingChapterIndex > 0
                            ? seren.previousReadingChapter
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        key: const Key('seren_next_chapter_btn'),
                        tooltip: l10n.tr('seren_reading_next_chapter'),
                        visualDensity: VisualDensity.compact,
                        onPressed: seren.activeReadingChapterIndex <
                                activeReading.chapterCount - 1
                            ? seren.nextReadingChapter
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        activeReading.chapters.length,
                        (cIdx) {
                          final chapter = activeReading.chapters[cIdx];
                          final isSelected =
                              seren.activeReadingChapterIndex == cIdx;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: Key(
                                'seren_chapter_pill_${activeReading.id}_$cIdx',
                              ),
                              selected: isSelected,
                              label: Text(
                                '${l10n.tr('seren_reading_chapter_short', {'num': cIdx + 1})}: ${chapter.title}',
                              ),
                              onSelected: (_) =>
                                  seren.jumpToReadingChapter(cIdx),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!seren.isTtsPlaying && !seren.isTtsPaused)
                      FilledButton.icon(
                        key: const Key('seren_tts_play_btn'),
                        onPressed: () =>
                            seren.startReadingTts(item: activeReading),
                        icon: const Icon(Icons.record_voice_over_rounded),
                        label: Text(l10n.tr('seren_tts_read_aloud')),
                      )
                    else ...[
                      FilledButton.tonalIcon(
                        key: const Key('seren_tts_pause_resume_btn'),
                        onPressed: seren.isTtsPaused
                            ? seren.resumeReadingTts
                            : seren.pauseReadingTts,
                        icon: Icon(
                          seren.isTtsPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(
                          seren.isTtsPaused
                              ? l10n.tr('seren_action_resume')
                              : l10n.tr('seren_action_pause'),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('seren_tts_stop_btn'),
                        onPressed: seren.stopReadingTts,
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(l10n.tr('seren_action_stop')),
                      ),
                    ],
                    IconButton(
                      key: const Key('seren_tts_prev_paragraph_btn'),
                      tooltip: l10n.tr('seren_tts_prev_paragraph'),
                      onPressed: seren.previousReadingParagraph,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    IconButton(
                      key: const Key('seren_tts_next_paragraph_btn'),
                      tooltip: l10n.tr('seren_tts_next_paragraph'),
                      onPressed: seren.nextReadingParagraph,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.music_note_rounded, size: 16),
                      label: Text(l10n.tr('seren_tts_pair_ambient')),
                      onPressed: () =>
                          seren.playSingleSound(activeReading.pairedSoundId),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.tr('seren_tts_speed_label'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    ...[0.75, 0.9, 1.0, 1.15].map((spd) {
                      return ChoiceChip(
                        selected: (seren.ttsSpeechRate - spd).abs() < 0.03,
                        label: Text('${spd}x'),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => seren.setTtsSpeechRate(spd),
                      );
                    }),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      l10n.tr('seren_tts_narration_volume'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: seren.narrationVolume,
                        onChanged: seren.setNarrationVolume,
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    l10n.tr('seren_tts_duck_ambient'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: seren.duckAmbientDuringNarration,
                  onChanged: seren.setDuckAmbientDuringNarration,
                ),
                const Divider(),
                ...List.generate(paragraphs.length, (idx) {
                  final isCurrent = seren.activeReadingParagraphIndex == idx;
                  final chapterIndex = activeReading.chapterIndexForParagraph(idx);
                  final isChapterStart = activeReading.isMultiChapter &&
                      activeReading.startParagraphIndexForChapter(
                            chapterIndex,
                          ) ==
                          idx;
                  final chapter = isChapterStart
                      ? activeReading.chapters[chapterIndex]
                      : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chapter != null)
                        Padding(
                          key: Key(
                            'seren_chapter_heading_${activeReading.id}_$chapterIndex',
                          ),
                          padding: EdgeInsets.only(
                            top: chapterIndex == 0 ? 4 : 12,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  l10n.tr('seren_reading_chapter_short', {
                                    'num': chapterIndex + 1,
                                  }),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  chapter.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => seren.startReadingTts(
                          item: activeReading,
                          startParagraph: idx,
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            paragraphs[idx],
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildReadingFilterChip('all', l10n.tr('seren_filter_all')),
              _buildReadingFilterChip(
                'morning',
                l10n.tr('seren_mode_morning_peace'),
              ),
              _buildReadingFilterChip(
                'evening',
                l10n.tr('seren_mode_evening_unwind'),
              ),
              _buildReadingFilterChip(
                'travelogues',
                l10n.tr('seren_filter_travelogues'),
              ),
              _buildReadingFilterChip(
                'seasonal',
                l10n.tr('seren_filter_seasonal'),
              ),
              _buildReadingFilterChip(
                'bookmarked',
                l10n.tr('seren_filter_bookmarked'),
              ),
              _buildReadingFilterChip(
                'favorites',
                l10n.tr('seren_section_favorites'),
              ),
              _buildReadingFilterChip(
                'history',
                l10n.tr('seren_filter_reading_history'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...filteredReadings.map((item) {
          final isSelected = activeReading.id == item.id;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isSelected
                  ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    )
                  : BorderSide.none,
            ),
            child: ListTile(
              key: Key('seren_reading_tile_${item.id}'),
              onTap: () => seren.openReadingItem(item.id),
              leading: Icon(item.category.icon),
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.subtitle),
                  if (item.isMultiChapter || item.seasonTag != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.isMultiChapter)
                          Text(
                            '${item.chapterCount} ${l10n.tr('seren_reading_chapters_label')}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        if (item.seasonTag != null)
                          Text(
                            '• ${item.seasonTag!.label}',
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: IconButton.filledTonal(
                tooltip: l10n.tr('seren_tts_read_aloud'),
                onPressed: () => seren.openReadingItem(
                  item.id,
                  startTts: true,
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 18),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReadingFilterChip(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: Key('seren_reading_filter_$key'),
        selected: _readingFilter == key,
        label: Text(label),
        onSelected: (_) => setState(() => _readingFilter = key),
      ),
    );
  }

  List<RelaxationReadingItem> _filterReadings(SerenRelaxationProvider seren) {
    final all = SerenRelaxationCatalog.readings;
    switch (_readingFilter) {
      case 'morning':
        return all
            .where((r) => r.recommendedFor == RelaxationTimeOfDayMode.morning)
            .toList();
      case 'evening':
        return all
            .where((r) => r.recommendedFor == RelaxationTimeOfDayMode.evening)
            .toList();
      case 'travelogues':
        return all
            .where(
              (r) =>
                  r.category == RelaxationReadingCategory.slowTravelogues ||
                  r.category == RelaxationReadingCategory.fictionalJourneys,
            )
            .toList();
      case 'seasonal':
        return all
            .where(
              (r) =>
                  r.category == RelaxationReadingCategory.seasonalEssays ||
                  r.category == RelaxationReadingCategory.natureFacts ||
                  r.seasonTag != null,
            )
            .toList();
      case 'bookmarked':
        return all
            .where((r) => seren.isReadingBookmarked(r.id))
            .toList();
      case 'favorites':
        return all
            .where((r) => seren.isReadingFavorite(r.id))
            .toList();
      case 'history':
        return seren.prefs.readingHistoryIds
            .map(SerenRelaxationCatalog.readingById)
            .toList();
      default:
        return all;
    }
  }

  // ===========================================================================
  // TAB 5: MINDFUL ACTIVITIES & ECHO JOURNAL INTEGRATION (FEATURE H)
  // ===========================================================================

  Widget _buildMindfulTab(
    BuildContext context,
    SerenRelaxationProvider seren,
    AppLocalizations l10n,
  ) {
    final journalProvider = context.watch<JournalProvider>();
    final visiblePrompts = SerenRelaxationCatalog.mindfulPrompts
        .where((p) => !seren.skippedMindfulPromptIds.contains(p.id))
        .toList();
    final serenEntries = journalProvider.journalEntries
        .where((e) => e.tags.contains('Seren'))
        .take(5)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.self_improvement_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.tr('seren_mindful_zero_pressure_note'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (seren.skippedMindfulPromptIds.isNotEmpty)
                TextButton(
                  onPressed: seren.resetSkippedMindfulPrompts,
                  child: Text(l10n.tr('seren_action_restore_prompts')),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...visiblePrompts.map((prompt) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(prompt.icon, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          prompt.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(prompt.promptText),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: Key('seren_skip_prompt_${prompt.id}'),
                        onPressed: () => seren.skipMindfulPrompt(prompt.id),
                        child: Text(l10n.tr('seren_action_skip_prompt')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        key: Key('seren_reflect_prompt_${prompt.id}'),
                        onPressed: () =>
                            _showMindfulReflectionDialog(context, prompt),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: Text(l10n.tr('seren_action_save_to_echo')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (serenEntries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.tr('seren_section_recent_echo_reflections'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...serenEntries.map(
            (entry) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.book_outlined),
                title: Text(entry.title),
                subtitle: Text(
                  entry.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // DIALOGS & BOTTOM SHEETS
  // ===========================================================================

  Future<void> _showSleepTimerSheet(BuildContext context) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<SerenRelaxationProvider>(
          builder: (context, seren, _) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('seren_timer_title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.tr('seren_timer_subtitle'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [15, 30, 45, 60, 90].map((mins) {
                      return ActionChip(
                        key: Key('seren_timer_preset_$mins'),
                        label: Text('$mins ${l10n.tr('seren_unit_min')}'),
                        onPressed: () {
                          seren.startPlaybackTimer(mins);
                          Navigator.of(ctx).pop();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.tr('seren_timer_auto_fade_out')),
                    subtitle: Text(l10n.tr('seren_timer_auto_fade_subtitle')),
                    value: seren.autoFadeOut,
                    onChanged: seren.setAutoFadeOut,
                  ),
                  if (seren.isTimerActive)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('seren_cancel_timer_btn'),
                        onPressed: () {
                          seren.cancelPlaybackTimer();
                          Navigator.of(ctx).pop();
                        },
                        icon: const Icon(Icons.timer_off_outlined),
                        label: Text(l10n.tr('seren_action_cancel_timer')),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRemindersSheet(BuildContext context) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<SerenRelaxationProvider>(
          builder: (context, seren, _) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('seren_reminders_title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.tr('seren_reminder_morning_label')),
                    subtitle: Text(l10n.tr('seren_reminder_morning_sub')),
                    value: seren.prefs.morningGentleReminderEnabled,
                    onChanged: seren.setMorningGentleReminder,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.tr('seren_reminder_evening_label')),
                    subtitle: Text(l10n.tr('seren_reminder_evening_sub')),
                    value: seren.prefs.eveningUnwindReminderEnabled,
                    onChanged: seren.setEveningUnwindReminder,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSaveSoundscapeDialog(BuildContext context) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.tr('seren_dialog_save_mix_title')),
          content: TextField(
            key: const Key('seren_save_mix_name_input'),
            controller: controller,
            decoration: InputDecoration(
              hintText: l10n.tr('seren_dialog_save_mix_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.tr('common_cancel')),
            ),
            FilledButton(
              key: const Key('seren_confirm_save_mix_btn'),
              onPressed: () {
                context
                    .read<SerenRelaxationProvider>()
                    .saveCurrentMixAsSoundscape(controller.text);
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.tr('common_save')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenameSoundscapeDialog(
    BuildContext context,
    SavedSoundscape soundscape,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: soundscape.displayName);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.tr('seren_action_rename_mix')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: l10n.tr('seren_dialog_save_mix_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.tr('common_cancel')),
            ),
            FilledButton(
              onPressed: () {
                context
                    .read<SerenRelaxationProvider>()
                    .renameCustomSoundscape(soundscape.id, controller.text);
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.tr('common_save')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMindfulReflectionDialog(
    BuildContext context,
    MindfulActivityPrompt prompt,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(prompt.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prompt.promptText, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                key: const Key('seren_mindful_reflection_input'),
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.tr('seren_mindful_input_hint'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.tr('common_cancel')),
            ),
            FilledButton(
              key: const Key('seren_confirm_save_reflection_btn'),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  final journalProvider = context.read<JournalProvider>();
                  context
                      .read<SerenRelaxationProvider>()
                      .saveMindfulReflectionToJournal(
                        prompt: prompt,
                        responseText: text,
                        journalProvider: journalProvider,
                      );
                }
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.tr('common_save')),
            ),
          ],
        );
      },
    );
  }
}
