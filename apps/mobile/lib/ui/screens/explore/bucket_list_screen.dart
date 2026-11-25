import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/bucket_list_item.dart';
import '../../../data/models/entity_link.dart';
import '../../../data/models/saved_place.dart';
import '../../../providers/bucket_list_provider.dart';
import '../../../providers/cross_module_link_provider.dart';
import '../../../providers/geofence_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../widgets/linked_entities_section.dart';
import '../../widgets/mascot_milestone_stamp_overlay.dart';
import '../../widgets/swipe_action_card.dart';
import '../journal/memories_screen.dart';

enum _BucketStatusFilter { all, active, achieved, starred }

class BucketListScreen extends StatefulWidget {
  final String? highlightItemId;
  final BucketCategory? initialCategory;

  const BucketListScreen({
    super.key,
    this.highlightItemId,
    this.initialCategory,
  });

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  static const Color _pippinEmerald = AppColors.pippin;
  static const Color _echoAmber = AppColors.twill;
  static const Color _scoutBlue = AppColors.scout;

  final TextEditingController _searchController = TextEditingController();
  _BucketStatusFilter _statusFilter = _BucketStatusFilter.all;
  BucketCategory? _selectedCategory;
  int _quipIndex = 0;

  static const List<String> _quipsEn = [
    'Every great adventure starts with one dream pinned to the map!',
    'Link a dream spot to Scout\'s Saved Places so it\'s ready when you go.',
    'Check off a bucket-list goal and turn it into a lasting Echo memory in 1 tap!',
  ];

  static const List<String> _quipsId = [
    'Setiap petualangan besar dimulai dari satu impian di papan petamu!',
    'Tautkan tempat impian ke Tempat Tersimpan Scout agar siap dikunjungi.',
    'Selesaikan impian dan jadikan Kenangan Echo permanen dengan 1 ketukan!',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  T? _safeWatch<T>(BuildContext context) {
    try {
      return Provider.of<T>(context);
    } catch (_) {
      return null;
    }
  }

  T? _safeRead<T>(BuildContext context) {
    try {
      return Provider.of<T>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  SavedPlace? _resolvePlace(GeofenceProvider? geo, BucketListItem item) {
    if (geo == null || !item.hasSavedPlaceLink) return null;
    return geo.findPlaceById(item.savedPlaceId!);
  }

  List<BucketListItem> _applyFilters(
    List<BucketListItem> items,
    GeofenceProvider? geo,
    bool isId,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      switch (_statusFilter) {
        case _BucketStatusFilter.all:
          break;
        case _BucketStatusFilter.active:
          if (item.isCompleted) return false;
          break;
        case _BucketStatusFilter.achieved:
          if (!item.isCompleted) return false;
          break;
        case _BucketStatusFilter.starred:
          if (!item.isStarred) return false;
          break;
      }

      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }

      if (query.isEmpty) return true;
      final place = _resolvePlace(geo, item);
      final locationText = item.resolvedLocationLabel(
        livePlaceName: place?.name,
      );
      final targetWindow =
          item.targetWindowLabel(isIndonesian: isId) ?? '';
      return item.title.toLowerCase().contains(query) ||
          item.inspirationNote.toLowerCase().contains(query) ||
          locationText.toLowerCase().contains(query) ||
          item.category.labelEn.toLowerCase().contains(query) ||
          item.category.labelId.toLowerCase().contains(query) ||
          targetWindow.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> _handleToggleCompleted(
    BucketListProvider provider,
    BucketListItem item,
  ) async {
    final l10n = context.l10n;
    final justCompleted = await provider.toggleCompleted(item.id);
    if (!mounted) return;

    if (justCompleted) {
      HapticFeedback.mediumImpact();
      MascotMilestoneStampOverlay.showPippinStamped(
        context,
        title: l10n.tr('bucket_goal_achieved'),
        subtitle: item.title,
      );

      final journal = _safeRead<JournalProvider>(context);
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            l10n.tr('achieved_preserve_it_in_echo_s', {'item_title': item.title}),
          ),
          action: (journal != null && !item.isPromotedToMemory)
              ? SnackBarAction(
                  label: l10n.tr('promote'),
                  onPressed: () {
                    final latest = provider.findById(item.id) ?? item;
                    _handlePromoteToMemory(provider, latest);
                  },
                )
              : null,
        ),
      );
    } else {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _handlePromoteToMemory(
    BucketListProvider provider,
    BucketListItem item,
  ) async {
    final l10n = context.l10n;
    final journal = _safeRead<JournalProvider>(context);
    if (journal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.tr('journal_memories_provider_is_unavailable'),
          ),
        ),
      );
      return;
    }

    final geo = _safeRead<GeofenceProvider>(context);
    final linkProvider = _safeRead<CrossModuleLinkProvider>(context);
    final linkedPlace = _resolvePlace(geo, item);

    final memory = await provider.promoteToEchoMemory(
      item.id,
      journal,
      linkedPlace: linkedPlace,
      linkProvider: linkProvider,
    );
    if (!mounted || memory == null) return;

    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(
          l10n.tr('promoted_to_echo_s_memories', {'memory_title': memory.title}),
        ),
        action: SnackBarAction(
          label: l10n.tr('view'),
          onPressed: _openEchoMemories,
        ),
      ),
    );
  }

  void _openEchoMemories() {
    final l10n = context.l10n;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(l10n.tr('echo_s_memories')),
          ),
          body: const MemoriesScreen(),
        ),
      ),
    );
  }

  Future<void> _handleDeleteWithUndo(
    BucketListProvider provider,
    BucketListItem item,
  ) async {
    final l10n = context.l10n;
    final originalIndex = provider.indexOfItem(item.id);
    await provider.deleteItem(item.id);
    if (!mounted) return;

    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(
          l10n.tr('removed', {'item_title': item.title}),
        ),
        action: SnackBarAction(
          label: l10n.tr('undo'),
          onPressed: () {
            provider.restoreItem(item, atIndex: originalIndex);
          },
        ),
      ),
    );
  }

  void _openEditorSheet(
    BuildContext context,
    BucketListProvider provider, {
    BucketListItem? existingItem,
  }) {
    final geo = _safeRead<GeofenceProvider>(context);
    final hasLinks = _safeRead<CrossModuleLinkProvider>(context) != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BucketGoalEditorSheet(
        provider: provider,
        geofenceProvider: geo,
        existingItem: existingItem,
        showCrossLinks: hasLinks && existingItem != null,
      ),
    );
  }

  void _openQuickPlaceLinkSheet(
    BuildContext context,
    BucketListProvider provider,
    BucketListItem item,
  ) {
    final l10n = context.l10n;
    final geo = _safeRead<GeofenceProvider>(context);
    if (geo == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: AppColors.sheetSurface(ctx),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.place_rounded, color: _scoutBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tr('link_saved_place'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 12),
              if (geo.places.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.tr('no_saved_places_yet_create_one'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(ctx),
                    ),
                  ),
                )
              else
                ...geo.places.map((place) {
                  final selected = item.savedPlaceId == place.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor:
                          Color(place.category.colorValue).withValues(alpha: 0.16),
                      child: Text(place.category.emoji),
                    ),
                    title: Text(
                      place.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      place.address.isNotEmpty
                          ? '${place.address} • ${place.formattedCoordinates}'
                          : place.formattedCoordinates,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded,
                            color: _pippinEmerald)
                        : const Icon(Icons.link_rounded),
                    onTap: () async {
                      await provider.linkSavedPlace(item.id, place);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  );
                }),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.hasSavedPlaceLink)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await provider.unlinkSavedPlace(item.id);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.link_off_rounded, size: 16),
                      label: Text(l10n.tr('unlink_place')),
                    ),
                  FilledButton.icon(
                    onPressed: () async {
                      final created = await _showQuickCreateSavedPlaceDialog(
                        ctx,
                        geo,
                        initialName: item.locationLabel ?? item.title,
                      );
                      if (created != null) {
                        await provider.linkSavedPlace(item.id, created);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      }
                    },
                    icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                    label: Text(
                      l10n.tr('new_saved_place'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isId = l10n.isIndonesian;
    final provider = context.watch<BucketListProvider>();
    final geo = _safeWatch<GeofenceProvider>(context);
    final filtered = _applyFilters(provider.items, geo, isId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.tr('life_bucket_list_places'),
        ),
        actions: [
          if (provider.promotedCount > 0)
            IconButton(
              key: const Key('bucket_view_memories_action'),
              tooltip: l10n.tr('echo_s_memories'),
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: _openEchoMemories,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _buildHeroCard(context, provider, isId),
          const SizedBox(height: 14),
          _buildSearchField(context, l10n),
          const SizedBox(height: 12),
          _buildStatusFilters(context, provider, l10n),
          const SizedBox(height: 10),
          _buildCategoryChips(context, provider, isId),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _buildEmptyState(context, l10n)
          else
            ...filtered.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BucketGoalCard(
                  item: item,
                  linkedPlace: _resolvePlace(geo, item),
                  geofenceProvider: geo,
                  isHighlighted: item.id == widget.highlightItemId,
                  isIndonesian: isId,
                  onToggleCompleted: () =>
                      _handleToggleCompleted(provider, item),
                  onToggleStarred: () {
                    HapticFeedback.selectionClick();
                    provider.toggleStarred(item.id);
                  },
                  onEdit: () =>
                      _openEditorSheet(context, provider, existingItem: item),
                  onLinkPlace: geo == null
                      ? null
                      : () => _openQuickPlaceLinkSheet(context, provider, item),
                  onPromoteToMemory: () =>
                      _handlePromoteToMemory(provider, item),
                  onViewMemories: _openEchoMemories,
                  onDelete: () => _handleDeleteWithUndo(provider, item),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('bucket_add_dream_fab'),
        onPressed: () => _openEditorSheet(context, provider),
        backgroundColor: _pippinEmerald,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          l10n.tr('add_dream'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    BucketListProvider provider,
    bool isId,
  ) {
    final l10n = context.l10n;
    final quip = isId
        ? _quipsId[_quipIndex % _quipsId.length]
        : _quipsEn[_quipIndex % _quipsEn.length];
    final spritePath = _statusFilter == _BucketStatusFilter.achieved &&
            provider.completedCount > 0
        ? 'assets/mascots/sprites/pippin/summit.png'
        : 'assets/mascots/sprites/pippin/treasure_map.png';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _pippinEmerald.withValues(alpha: 0.42),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _pippinEmerald.withValues(alpha: 0.14),
            AppColors.cardSurface(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _quipIndex++);
                },
                child: Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _pippinEmerald.withValues(alpha: 0.16),
                    border: Border.all(
                      color: _pippinEmerald.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Image.asset(
                    spritePath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.explore_rounded,
                      size: 36,
                      color: _pippinEmerald,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l10n.tr('pippin_s_dream_board'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _pippinEmerald.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.tr('achieved', {'provider_completedCount': provider.completedCount, 'provider_totalCount': provider.totalCount}),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.adaptive(
                                context,
                                dark: _pippinEmerald,
                                light: AppColors.pippinDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _quipIndex++),
                      child: Text(
                        '“$quip”',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: provider.completionProgress,
              minHeight: 7,
              backgroundColor: AppColors.trackSurface(context),
              valueColor: const AlwaysStoppedAnimation<Color>(_pippinEmerald),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _statChip(
                context,
                emoji: '🧭',
                label: l10n.tr('to_explore', {'provider_pendingCount': provider.pendingCount}),
                accent: _pippinEmerald,
              ),
              _statChip(
                context,
                emoji: '⭐',
                label: l10n.tr('priority', {'provider_length': provider.starredPendingItems.length}),
                accent: _echoAmber,
              ),
              InkWell(
                onTap: _openEchoMemories,
                borderRadius: BorderRadius.circular(10),
                child: _statChip(
                  context,
                  emoji: '✨',
                  label: l10n.tr('in_echo_memories', {'provider_promotedCount': provider.promotedCount}),
                  accent: AppColors.echo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(
    BuildContext context, {
    required String emoji,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, AppLocalizations l10n) {
    return TextField(
      key: const Key('bucket_search_field'),
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: l10n.tr('search_dreams_places_notes_or_season'),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
        isDense: true,
      ),
    );
  }

  Widget _buildStatusFilters(
    BuildContext context,
    BucketListProvider provider,
    AppLocalizations l10n,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        ChoiceChip(
          selected: _statusFilter == _BucketStatusFilter.all,
          label: Text(l10n.tr('all_2', {'provider_totalCount': provider.totalCount})),
          onSelected: (_) =>
              setState(() => _statusFilter = _BucketStatusFilter.all),
        ),
        ChoiceChip(
          selected: _statusFilter == _BucketStatusFilter.active,
          label: Text(
            l10n.tr('to_explore_2', {'provider_pendingCount': provider.pendingCount}),
          ),
          onSelected: (_) =>
              setState(() => _statusFilter = _BucketStatusFilter.active),
        ),
        ChoiceChip(
          selected: _statusFilter == _BucketStatusFilter.achieved,
          label: Text(
            l10n.tr('achieved_2', {'provider_completedCount': provider.completedCount}),
          ),
          onSelected: (_) =>
              setState(() => _statusFilter = _BucketStatusFilter.achieved),
        ),
        ChoiceChip(
          selected: _statusFilter == _BucketStatusFilter.starred,
          avatar: const Icon(Icons.star_rounded, size: 15, color: _echoAmber),
          label: Text(l10n.tr('priority_2')),
          onSelected: (_) =>
              setState(() => _statusFilter = _BucketStatusFilter.starred),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(
    BuildContext context,
    BucketListProvider provider,
    bool isId,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: _selectedCategory == null,
              label: Text(isId ? 'Semua Kategori' : 'All Categories'),
              onSelected: (_) => setState(() => _selectedCategory = null),
            ),
          ),
          ...BucketCategory.values.map((cat) {
            final count = provider.countForCategory(cat);
            final selected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected,
                selectedColor: cat.color.withValues(alpha: 0.22),
                label: Text('${cat.emoji} ${cat.label(isId)} ($count)'),
                onSelected: (_) => setState(
                  () => _selectedCategory = selected ? null : cat,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Image.asset(
                'assets/mascots/sprites/pippin/curious.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.explore_outlined,
                  size: 46,
                  color: _pippinEmerald,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.tr('no_matching_bucket_list_dreams_yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tr('pin_a_place_to_visit_or'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketGoalCard extends StatelessWidget {
  final BucketListItem item;
  final SavedPlace? linkedPlace;
  final GeofenceProvider? geofenceProvider;
  final bool isHighlighted;
  final bool isIndonesian;
  final VoidCallback onToggleCompleted;
  final VoidCallback onToggleStarred;
  final VoidCallback onEdit;
  final VoidCallback? onLinkPlace;
  final VoidCallback onPromoteToMemory;
  final VoidCallback onViewMemories;
  final Future<void> Function() onDelete;

  const _BucketGoalCard({
    required this.item,
    required this.linkedPlace,
    required this.geofenceProvider,
    required this.isHighlighted,
    required this.isIndonesian,
    required this.onToggleCompleted,
    required this.onToggleStarred,
    required this.onEdit,
    required this.onLinkPlace,
    required this.onPromoteToMemory,
    required this.onViewMemories,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.category.color;
    final targetWindow = item.targetWindowLabel(isIndonesian: isIndonesian);
    final placeName = item.resolvedLocationLabel(
      livePlaceName: linkedPlace?.name,
    );
    final distanceMeters = (linkedPlace != null && geofenceProvider != null)
        ? geofenceProvider!.distanceToPlaceMeters(linkedPlace!)
        : null;

    return SwipeActionCard(
      dismissKey: ValueKey('bucket_swipe_${item.id}'),
      swipeRightStyle: SwipeActionStyle(
        label: item.isCompleted
            ? (isIndonesian ? 'Buka Lagi' : 'Reopen')
            : (isIndonesian ? 'Tercapai' : 'Achieve'),
        icon: item.isCompleted
            ? Icons.replay_rounded
            : Icons.check_circle_rounded,
        color: AppColors.pippin,
      ),
      swipeLeftStyle: SwipeActionStyle(
        label: isIndonesian ? 'Hapus' : 'Delete',
        icon: Icons.delete_outline_rounded,
        color: AppColors.error,
      ),
      onSwipeRight: onToggleCompleted,
      onSwipeLeft: onDelete,
      child: Container(
        key: Key('bucket_card_${item.id}'),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHighlighted
                ? AppColors.twill
                : (item.isCompleted
                    ? AppColors.pippin.withValues(alpha: 0.45)
                    : accent.withValues(alpha: 0.35)),
            width: isHighlighted ? 2 : 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent,
                      accent.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            key: Key('bucket_check_${item.id}'),
                            onTap: onToggleCompleted,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10, top: 2),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.isCompleted
                                      ? AppColors.pippin
                                      : accent.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: item.isCompleted
                                        ? AppColors.pippin
                                        : accent.withValues(alpha: 0.65),
                                    width: 1.8,
                                  ),
                                ),
                                child: item.isCompleted
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                decoration: item.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isCompleted
                                    ? AppColors.textSecondary(context)
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                          IconButton(
                            key: Key('bucket_star_${item.id}'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: onToggleStarred,
                            tooltip: isIndonesian ? 'Prioritas' : 'Priority',
                            icon: Icon(
                              item.isStarred
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: item.isStarred
                                  ? AppColors.twill
                                  : AppColors.textSecondary(context),
                              size: 20,
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit();
                              } else if (value == 'place' &&
                                  onLinkPlace != null) {
                                onLinkPlace!();
                              } else if (value == 'delete') {
                                onDelete();
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(
                                  isIndonesian ? 'Ubah Impian' : 'Edit Dream',
                                ),
                              ),
                              if (onLinkPlace != null)
                                PopupMenuItem(
                                  value: 'place',
                                  child: Text(
                                    isIndonesian
                                        ? 'Tautkan Tempat Tersimpan'
                                        : 'Link Saved Place',
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  isIndonesian ? 'Hapus' : 'Delete',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _pill(
                            context,
                            text:
                                '${item.category.emoji} ${item.category.label(isIndonesian)}',
                            color: accent,
                          ),
                          if (targetWindow != null)
                            _pill(
                              context,
                              text: targetWindow,
                              color: AppColors.twill,
                            ),
                          if (placeName.isNotEmpty)
                            InkWell(
                              onTap: onLinkPlace,
                              borderRadius: BorderRadius.circular(8),
                              child: _pill(
                                context,
                                text: item.hasSavedPlaceLink
                                    ? '${linkedPlace?.category.emoji ?? '📍'} $placeName${distanceMeters != null ? ' • ${_formatDistance(distanceMeters)}' : ''}'
                                    : '📌 $placeName',
                                color: item.hasSavedPlaceLink
                                    ? AppColors.scout
                                    : AppColors.textSecondary(context),
                              ),
                            )
                          else if (onLinkPlace != null)
                            InkWell(
                              key: Key('bucket_link_place_${item.id}'),
                              onTap: onLinkPlace,
                              borderRadius: BorderRadius.circular(8),
                              child: _pill(
                                context,
                                text: isIndonesian
                                    ? '+ Tautkan Tempat'
                                    : '+ Link SavedPlace',
                                color: AppColors.scout,
                              ),
                            ),
                          if (item.completedAt != null)
                            _pill(
                              context,
                              text:
                                  '✓ ${DateFormat.yMMMd().format(item.completedAt!)}',
                              color: AppColors.pippin,
                            ),
                        ],
                      ),
                      if (item.hasInspirationNote) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.recessedSurface(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: accent.withValues(alpha: 0.75),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            item.inspirationNote,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.38,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                      if (item.isCompleted) ...[
                        const SizedBox(height: 12),
                        _buildMemoryPromotionBanner(context),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemoryPromotionBanner(BuildContext context) {
    if (item.isPromotedToMemory) {
      return Container(
        key: Key('bucket_promoted_badge_${item.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.twill.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.twill.withValues(alpha: 0.40),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppColors.echo,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isIndonesian
                    ? 'Tersimpan di Kenangan Echo'
                    : 'Preserved in Echo\'s Memories',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.adaptive(
                    context,
                    dark: AppColors.twillLight,
                    light: AppColors.echoDark,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onViewMemories,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                isIndonesian ? 'Lihat' : 'View',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.pippin.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.twill.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Image.asset(
              'assets/mascots/sprites/pippin/snapshot.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.photo_album_rounded,
                size: 20,
                color: AppColors.echo,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              key: Key('bucket_promote_btn_${item.id}'),
              onPressed: onPromoteToMemory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.echo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: Text(
                isIndonesian
                    ? '1-Ketuk Simpan ke Kenangan Echo'
                    : 'Promote to Echo\'s Memories',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}

class _BucketGoalEditorSheet extends StatefulWidget {
  final BucketListProvider provider;
  final GeofenceProvider? geofenceProvider;
  final BucketListItem? existingItem;
  final bool showCrossLinks;

  const _BucketGoalEditorSheet({
    required this.provider,
    required this.geofenceProvider,
    required this.existingItem,
    required this.showCrossLinks,
  });

  @override
  State<_BucketGoalEditorSheet> createState() => _BucketGoalEditorSheetState();
}

class _BucketGoalEditorSheetState extends State<_BucketGoalEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _locationController;
  late BucketCategory _category;
  late BucketTargetSeason _season;
  int? _targetYear;
  String? _savedPlaceId;
  late bool _isStarred;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _noteController =
        TextEditingController(text: item?.inspirationNote ?? '');
    _locationController =
        TextEditingController(text: item?.locationLabel ?? '');
    _category = item?.category ?? BucketCategory.travelPlaces;
    _season = item?.targetSeason ?? BucketTargetSeason.anytime;
    _targetYear = item?.targetYear;
    _savedPlaceId = item?.savedPlaceId;
    _isStarred = item?.isStarred ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    SavedPlace? selectedPlace;
    if (_savedPlaceId != null && widget.geofenceProvider != null) {
      selectedPlace = widget.geofenceProvider!.findPlaceById(_savedPlaceId!);
    }

    final existing = widget.existingItem;
    final cleanLocation = _locationController.text.trim();

    if (existing == null) {
      await widget.provider.addItem(
        title: title,
        inspirationNote: _noteController.text.trim(),
        category: _category,
        targetSeason: _season,
        targetYear: _targetYear,
        locationLabel: cleanLocation,
        linkedPlace: selectedPlace,
        isStarred: _isStarred,
      );
    } else {
      await widget.provider.updateItem(
        existing.copyWith(
          title: title,
          inspirationNote: _noteController.text.trim(),
          category: _category,
          targetSeason: _season,
          targetYear: _targetYear,
          clearTargetYear: _targetYear == null,
          locationLabel: cleanLocation.isEmpty ? null : cleanLocation,
          clearLocationLabel: cleanLocation.isEmpty,
          savedPlaceId: selectedPlace?.id,
          savedPlaceName: selectedPlace?.name,
          clearSavedPlace: selectedPlace == null,
          isStarred: _isStarred,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isId = l10n.isIndonesian;
    final geo = widget.geofenceProvider;
    final currentYear = DateTime.now().year;
    final yearOptions = [currentYear, currentYear + 1, currentYear + 2, currentYear + 3];

    return Material(
      color: AppColors.sheetSurface(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existingItem == null
                        ? l10n.tr('new_bucket_list_dream')
                        : l10n.tr('edit_dream_goal'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('bucket_editor_title_field'),
              controller: _titleController,
              autofocus: widget.existingItem == null,
              decoration: InputDecoration(
                labelText: l10n.tr('dream_goal_or_place_to_visit'),
                prefixIcon: const Icon(Icons.explore_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.tr('category_tag'),
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
              children: BucketCategory.values.map((cat) {
                return ChoiceChip(
                  selected: _category == cat,
                  selectedColor: cat.color.withValues(alpha: 0.22),
                  label: Text('${cat.emoji} ${cat.label(isId)}'),
                  onSelected: (_) => setState(() => _category = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.tr('target_season_year'),
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
              children: BucketTargetSeason.values.map((season) {
                return ChoiceChip(
                  selected: _season == season,
                  label: Text('${season.emoji} ${season.label(isId)}'),
                  onSelected: (_) => setState(() => _season = season),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  selected: _targetYear == null,
                  label: Text(l10n.tr('any_year')),
                  onSelected: (_) => setState(() => _targetYear = null),
                ),
                ...yearOptions.map((y) {
                  return ChoiceChip(
                    selected: _targetYear == y,
                    label: Text('$y'),
                    onSelected: (_) => setState(() => _targetYear = y),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('bucket_editor_location_field'),
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.tr('destination_spot_label_optional'),
                prefixIcon: const Icon(Icons.pin_drop_outlined),
              ),
            ),
            if (geo != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tr('optional_savedplace_link_scout'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final created = await _showQuickCreateSavedPlaceDialog(
                        context,
                        geo,
                        initialName: _locationController.text.trim().isNotEmpty
                            ? _locationController.text.trim()
                            : _titleController.text.trim(),
                      );
                      if (created != null && mounted) {
                        setState(() => _savedPlaceId = created.id);
                      }
                    },
                    icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                    label: Text(l10n.tr('new_place')),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    selected: _savedPlaceId == null,
                    label: Text(l10n.tr('none')),
                    onSelected: (_) => setState(() => _savedPlaceId = null),
                  ),
                  ...geo.places.map((place) {
                    return ChoiceChip(
                      selected: _savedPlaceId == place.id,
                      label: Text('${place.category.emoji} ${place.name}'),
                      onSelected: (_) =>
                          setState(() => _savedPlaceId = place.id),
                    );
                  }),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('bucket_editor_note_field'),
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.tr('inspiration_notes_ideas'),
                hintText: l10n.tr('why_this_dream_excites_you_spots'),
                prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.tr('star_as_priority_dream'),
              ),
              value: _isStarred,
              onChanged: (v) => setState(() => _isStarred = v),
            ),
            if (widget.showCrossLinks && widget.existingItem != null) ...[
              const SizedBox(height: 8),
              LinkedEntitiesSection(
                entityType: LinkEntityType.bucketList,
                entityId: widget.existingItem!.id,
                entityTitle: widget.existingItem!.title,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('bucket_editor_save_btn'),
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pippin,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: Text(
                widget.existingItem == null
                    ? l10n.tr('pin_to_dream_board')
                    : l10n.tr('save_changes'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<SavedPlace?> _showQuickCreateSavedPlaceDialog(
  BuildContext context,
  GeofenceProvider geofenceProvider, {
  String initialName = '',
}) async {
  final l10n = context.l10n;
  final nameController = TextEditingController(text: initialName);
  final addressController = TextEditingController();
  final latController = TextEditingController(text: '-7.9425');
  final lonController = TextEditingController(text: '112.9530');
  var category = PlaceCategory.custom;

  final created = await showDialog<SavedPlace>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(
          l10n.tr('create_saved_place'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.tr('place_name'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: l10n.tr('address_city'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Lat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lonController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Lon'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: PlaceCategory.values.map((c) {
                  return ChoiceChip(
                    selected: category == c,
                    label: Text('${c.emoji} ${c.displayName}'),
                    onSelected: (_) => setDialogState(() => category = c),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.tr('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final cleanName = nameController.text.trim();
              if (cleanName.isEmpty) return;
              final lat = double.tryParse(latController.text.trim()) ?? 0.0;
              final lon = double.tryParse(lonController.text.trim()) ?? 0.0;
              final place = SavedPlace(
                id: const Uuid().v4(),
                name: cleanName,
                address: addressController.text.trim(),
                latitude: lat,
                longitude: lon,
                radiusMeters: category.defaultRadiusMeters,
                category: category,
                createdAt: DateTime.now(),
              );
              await geofenceProvider.addPlace(place);
              if (ctx.mounted) Navigator.of(ctx).pop(place);
            },
            child: Text(l10n.tr('save_link')),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  addressController.dispose();
  latController.dispose();
  lonController.dispose();
  return created;
}
