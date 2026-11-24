import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/hobby_item.dart';
import '../../data/models/hobby_milestone.dart';
import '../../providers/hobby_provider.dart';

class HobbyPracticeSheet extends StatefulWidget {
  const HobbyPracticeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HobbyPracticeSheet(),
    );
  }

  @override
  State<HobbyPracticeSheet> createState() => _HobbyPracticeSheetState();
}

class _HobbyPracticeSheetState extends State<HobbyPracticeSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _localizeCategory(BuildContext context, String category) {
    final l10n = context.l10n;
    switch (category) {
      case 'Music':
        return l10n.tr('music');
      case 'Art':
        return l10n.tr('art');
      case 'Language':
        return l10n.tr('language');
      case 'Tech':
        return l10n.tr('tech');
      case 'Writing':
        return l10n.tr('writing');
      case 'Craft':
        return l10n.tr('craft');
      case 'Fitness':
        return l10n.tr('fitness');
      default:
        return category;
    }
  }

  String _localizeFocusTag(BuildContext context, String tag) {
    final l10n = context.l10n;
    switch (tag) {
      case 'Technique':
        return l10n.tr('technique');
      case 'Repertoire':
        return l10n.tr('repertoire');
      case 'Theory':
        return l10n.tr('theory');
      case 'Drills':
        return l10n.tr('drills');
      case 'Creative Play':
        return l10n.tr('creative_play');
      case 'Practice':
        return l10n.tr('practice');
      default:
        return tag;
    }
  }

  void _showMilestoneCelebrationDialog(
      BuildContext context, List<HobbyMilestone> unlocked, String hobbyName) {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        final emeraldText = AppColors.adaptive(
          ctx,
          dark: const Color(0xFF10B981),
          light: const Color(0xFF047857),
        );
        return AlertDialog(
          backgroundColor: AppColors.sheetSurface(ctx),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                l10n.tr('milestone_unlocked'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tr('dedication_in_reached_new_heights', {'hobbyName': hobbyName}),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 16),
              ...unlocked.map((m) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Text(m.iconEmoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${m.displayTitle} (${l10n.tr('hours', {'m_requiredHours': m.requiredHours})})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: emeraldText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.displayDescription,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                l10n.tr('keep_exploring'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogSessionDialog(BuildContext context, HobbyItem hobby) {
    int durationMinutes = 45;
    String focusTag = 'Technique';
    int rating = 5;
    final notesController = TextEditingController();
    final customMinController = TextEditingController();

    final tags = ['Technique', 'Repertoire', 'Theory', 'Drills', 'Creative Play'];

    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final emeraldText = AppColors.adaptive(
              ctx,
              dark: const Color(0xFF10B981),
              light: const Color(0xFF047857),
            );
            return AlertDialog(
              backgroundColor: AppColors.sheetSurface(ctx),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Text(hobby.iconEmoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tr('log_2', {'hobby_name': hobby.name}),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(ctx)),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Duration Section
                    Text(
                      l10n.tr('duration'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(ctx),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [15, 30, 45, 60, 90, 120].map((mins) {
                        final isSel = durationMinutes == mins;
                        return ChoiceChip(
                          label: Text('${mins}m'),
                          selected: isSel,
                          selectedColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                          backgroundColor: AppColors.elevatedSurface(ctx),
                          labelStyle: TextStyle(
                            color: isSel ? emeraldText : AppColors.textPrimary(ctx),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                durationMinutes = mins;
                                customMinController.clear();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: customMinController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: AppColors.textPrimary(ctx),
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.tr('custom_minutes_e_g_75'),
                        hintStyle: TextStyle(
                          color: AppColors.textMuted(ctx),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: AppColors.elevatedSurface(ctx),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null && parsed > 0) {
                          setDialogState(() => durationMinutes = parsed);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Focus Tag
                    Text(
                      l10n.tr('focus_area'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(ctx),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((t) {
                        final isSel = focusTag == t;
                        return ChoiceChip(
                          label: Text(_localizeFocusTag(ctx, t)),
                          selected: isSel,
                          selectedColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                          backgroundColor: AppColors.elevatedSurface(ctx),
                          labelStyle: TextStyle(
                            color: isSel ? emeraldText : AppColors.textPrimary(ctx),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setDialogState(() => focusTag = t);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Session Rating
                    Text(
                      l10n.tr('session_quality'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(ctx),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (int star = 1; star <= 5; star++) ...[
                          IconButton(
                            icon: Icon(
                              star <= rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: star <= rating
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.textMuted(ctx),
                              size: 26,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setDialogState(() => rating = star),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      style: TextStyle(
                        color: AppColors.textPrimary(ctx),
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.tr('notes_e_g_practiced_fingerpicking_patterns'),
                        hintStyle: TextStyle(
                          color: AppColors.textMuted(ctx),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: AppColors.elevatedSurface(ctx),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    l10n.tr('cancel'),
                    style: TextStyle(color: AppColors.textSecondary(ctx)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final provider =
                        Provider.of<HobbyProvider>(context, listen: false);
                    final newlyUnlocked = await provider.logPracticeSession(
                      hobbyId: hobby.id,
                      durationMinutes: durationMinutes,
                      focusTag: focusTag,
                      notes: notesController.text.trim().isNotEmpty
                          ? notesController.text.trim()
                          : null,
                      rating: rating,
                    );

                    if (newlyUnlocked.isNotEmpty && context.mounted) {
                      _showMilestoneCelebrationDialog(
                          context, newlyUnlocked, hobby.name);
                    } else if (context.mounted) {
                      final totalFormatted = provider.hobbies
                          .firstWhere((h) => h.id == hobby.id)
                          .formattedHours;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.tr('logged_m_of_total', {'durationMinutes': durationMinutes, 'hobby_name': hobby.name, 'totalFormatted': totalFormatted}),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    l10n.tr('log_practice'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddHobbyDialog(BuildContext context) {
    final nameController = TextEditingController();
    final targetController = TextEditingController(text: '50');
    final notesController = TextEditingController();
    String category = 'Music';
    String emoji = '🎸';

    final categories = [
      {'name': 'Music', 'emoji': '🎸'},
      {'name': 'Art', 'emoji': '🎨'},
      {'name': 'Language', 'emoji': '🗣️'},
      {'name': 'Tech', 'emoji': '💻'},
      {'name': 'Writing', 'emoji': '✍️'},
      {'name': 'Craft', 'emoji': '🧵'},
      {'name': 'Fitness', 'emoji': '🏃'},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final emeraldText = AppColors.adaptive(
              ctx,
              dark: const Color(0xFF10B981),
              light: const Color(0xFF047857),
            );
            return AlertDialog(
              backgroundColor: AppColors.sheetSurface(ctx),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Text('🦜', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tr('add_new_hobby_skill'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(ctx),
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(
                        color: AppColors.textPrimary(ctx),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.tr('hobby_name'),
                        labelStyle: TextStyle(
                          color: AppColors.textSecondary(ctx),
                          fontSize: 13,
                        ),
                        hintText: l10n.tr('e_g_classical_piano_rust_programming'),
                        hintStyle: TextStyle(color: AppColors.textMuted(ctx)),
                        filled: true,
                        fillColor: AppColors.elevatedSurface(ctx),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category & Emoji chips
                    Text(
                      l10n.tr('category_3'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(ctx),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: categories.map((cat) {
                        final isSel = category == cat['name'];
                        return ChoiceChip(
                          label: Text(
                            '${cat['emoji']} ${_localizeCategory(ctx, cat['name']!)}',
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                          backgroundColor: AppColors.elevatedSurface(ctx),
                          labelStyle: TextStyle(
                            color: isSel ? emeraldText : AppColors.textPrimary(ctx),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                category = cat['name']!;
                                emoji = cat['emoji']!;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Target Hours
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: AppColors.textPrimary(ctx),
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.tr('target_goal_hours'),
                        labelStyle: TextStyle(
                          color: AppColors.textSecondary(ctx),
                          fontSize: 12,
                        ),
                        hintText: l10n.tr('e_g_50_half_century_or'),
                        hintStyle: TextStyle(color: AppColors.textMuted(ctx)),
                        filled: true,
                        fillColor: AppColors.elevatedSurface(ctx),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      style: TextStyle(
                        color: AppColors.textPrimary(ctx),
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.tr('notes_intentions'),
                        labelStyle: TextStyle(
                          color: AppColors.textSecondary(ctx),
                          fontSize: 12,
                        ),
                        hintText: l10n.tr('e_g_30_mins_every_evening'),
                        hintStyle: TextStyle(color: AppColors.textMuted(ctx)),
                        filled: true,
                        fillColor: AppColors.elevatedSurface(ctx),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    l10n.tr('cancel'),
                    style: TextStyle(color: AppColors.textSecondary(ctx)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      final now = DateTime.now();
                      final target = int.tryParse(targetController.text) ?? 50;
                      final newHobby = HobbyItem(
                        id: const Uuid().v4(),
                        name: name,
                        category: category,
                        iconEmoji: emoji,
                        colorHex: '#10B981',
                        targetHours: target,
                        totalMinutesPracticed: 0,
                        notes: notesController.text.trim().isNotEmpty
                            ? notesController.text.trim()
                            : null,
                        createdAt: now,
                        updatedAt: now,
                      );
                      Provider.of<HobbyProvider>(context, listen: false)
                          .addHobby(newHobby);
                      Navigator.of(ctx).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    l10n.tr('add_hobby'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emeraldText = AppColors.adaptive(
      context,
      dark: const Color(0xFF10B981),
      light: const Color(0xFF047857),
    );
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer<HobbyProvider>(
        builder: (context, provider, _) {
          final hobbies = provider.activeHobbies;
          final totalHours = provider.totalCumulativeHours.toStringAsFixed(1);
          final totalSessions = provider.totalSessionsCount;
          final badgesUnlocked = provider.totalBadgesUnlocked;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('🦜', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tr('hobby_practice_space'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            l10n.tr('pippin_curiosity_mastery'),
                            style: TextStyle(
                              fontSize: 11,
                              color: emeraldText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(context)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Metrics Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      context,
                      l10n.tr('total_practiced'),
                      l10n.tr('hrs_2', {'totalHours': totalHours}),
                      emeraldText,
                    ),
                    Container(height: 28, width: 1, color: AppColors.border(context)),
                    _buildStatColumn(
                      context,
                      l10n.tr('sessions'),
                      '$totalSessions',
                      AppColors.textPrimary(context),
                    ),
                    Container(height: 28, width: 1, color: AppColors.border(context)),
                    _buildStatColumn(
                      context,
                      l10n.tr('badges_2'),
                      '🏆 $badgesUnlocked',
                      AppColors.adaptive(
                        context,
                        dark: const Color(0xFFF59E0B),
                        light: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tab Bar (Hobbies vs Practice History)
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary(context),
                  labelStyle:
                      const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(
                      text: l10n.tr('hobbies_milestones', {'hobbies_length': hobbies.length}),
                    ),
                    Tab(
                      text: l10n.tr('session_logs', {'totalSessions': totalSessions}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Hobbies & Milestones
                    _buildHobbiesTab(context, provider, hobbies),

                    // Tab 2: Session Logs
                    _buildSessionsTab(context, provider),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Add Hobby Button
              ElevatedButton.icon(
                onPressed: () => _showAddHobbyDialog(context),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                label: Text(
                  l10n.tr('add_new_hobby_skill'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(
      BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary(context))),
      ],
    );
  }

  Widget _buildHobbiesTab(
      BuildContext context, HobbyProvider provider, List<HobbyItem> hobbies) {
    final l10n = context.l10n;
    final emeraldText = AppColors.adaptive(
      context,
      dark: const Color(0xFF10B981),
      light: const Color(0xFF047857),
    );
    final amberText = AppColors.adaptive(
      context,
      dark: const Color(0xFFF59E0B),
      light: const Color(0xFFB45309),
    );

    if (hobbies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🦜', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(
              l10n.tr('no_hobbies_registered_yet'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.tr('tap_add_new_hobby_skill_to'),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: hobbies.map((hobby) {
        final nextMilestone = hobby.nextMilestone;
        final progress = hobby.progressToNextMilestone;
        final unlocked = hobby.unlockedMilestones;
        final hourUnitShort = l10n.tr('h');

        return Card(
          color: AppColors.elevatedSurface(context),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border(context)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Emoji + Name + Category + Total Hours
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(hobby.iconEmoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hobby.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _localizeCategory(context, hobby.category),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: emeraldText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hobby.formattedHours,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: emeraldText,
                          ),
                        ),
                        if (hobby.targetHours != null)
                          Text(
                            l10n.tr('target_h', {'hobby_targetHours': hobby.targetHours}),
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context)),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Next Milestone Progress Bar
                if (nextMilestone != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.tr('next_h', {'nextMilestone_iconEmoji': nextMilestone.iconEmoji, 'nextMilestone_displayTitle': nextMilestone.displayTitle, 'nextMilestone_requiredHours': nextMilestone.requiredHours}),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context)),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: emeraldText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.trackSurface(context),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        l10n.tr('virtuoso_reached_all_major_milestones_unlocked'),
                        style: TextStyle(
                            fontSize: 11,
                            color: amberText,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Milestone Badges Carousel
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: HobbyMilestone.standardMilestones.map((milestone) {
                      final isUnlocked = unlocked.any((m) => m.id == milestone.id);

                      return Tooltip(
                        message: '${milestone.displayTitle}: ${milestone.displayDescription}',
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                : AppColors.sheetSurface(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isUnlocked
                                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                  : AppColors.border(context),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(milestone.iconEmoji,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isUnlocked
                                        ? AppColors.textPrimary(context)
                                        : AppColors.textMuted(context)
                                            .withValues(alpha: 0.5),
                                  )),
                              const SizedBox(width: 4),
                              Text(
                                '${milestone.requiredHours}$hourUnitShort',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isUnlocked
                                      ? AppColors.textPrimary(context)
                                      : AppColors.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Action Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Quick +30m button
                        OutlinedButton(
                          onPressed: () async {
                            final newly = await provider.logPracticeSession(
                              hobbyId: hobby.id,
                              durationMinutes: 30,
                              focusTag: 'Practice',
                            );
                            if (newly.isNotEmpty && context.mounted) {
                              _showMilestoneCelebrationDialog(
                                  context, newly, hobby.name);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.border(context)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('+30m',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: emeraldText)),
                        ),
                        const SizedBox(width: 6),
                        // Quick +60m button
                        OutlinedButton(
                          onPressed: () async {
                            final newly = await provider.logPracticeSession(
                              hobbyId: hobby.id,
                              durationMinutes: 60,
                              focusTag: 'Practice',
                            );
                            if (newly.isNotEmpty && context.mounted) {
                              _showMilestoneCelebrationDialog(
                                  context, newly, hobby.name);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.border(context)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('+60m',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: emeraldText)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showLogSessionDialog(context, hobby),
                      icon: const Icon(Icons.add_task_rounded,
                          size: 15, color: Colors.white),
                      label: Text(
                        l10n.tr('log_session'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionsTab(BuildContext context, HobbyProvider provider) {
    final l10n = context.l10n;
    final sessions = provider.sessions;
    final emeraldText = AppColors.adaptive(
      context,
      dark: const Color(0xFF10B981),
      light: const Color(0xFF047857),
    );

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 44, color: AppColors.textMuted(context)),
            const SizedBox(height: 10),
            Text(
              l10n.tr('no_practice_sessions_logged_yet'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.tr('practice_sessions_you_log_will_appear'),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: sessions.map((session) {
        final dateStr = l10n.formatDate(session.sessionDate, 'y-MM-dd');

        return Card(
          color: AppColors.elevatedSurface(context),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.border(context)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.timer_outlined,
                  color: emeraldText, size: 18),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  session.hobbyName,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context)),
                ),
                Text(
                  session.formattedDuration,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: emeraldText),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(dateStr,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context))),
                    if (session.focusTag != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.trackSurface(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _localizeFocusTag(context, session.focusTag!),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (session.notes != null && session.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    session.notes!,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.textSecondary(context)),
              onPressed: () => provider.deleteSession(session.id),
            ),
          ),
        );
      }).toList(),
    );
  }
}

