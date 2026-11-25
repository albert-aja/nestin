import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/device_capability.dart';
import '../../../data/models/mental_wellness_models.dart';
import '../../../data/models/seren_relaxation_models.dart';
import '../../../data/services/storage_service.dart';
import '../../../providers/break_the_cycle_provider.dart';
import '../../../providers/bucket_list_provider.dart';
import '../../../providers/device_control_provider.dart';
import '../../../providers/health_wellness_provider.dart';
import '../../../providers/hydration_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/money_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/seren_relaxation_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/task_provider.dart';
import '../../widgets/health_wellness_sheet.dart';
import '../../widgets/security_pin_gate_sheet.dart';
import '../../widgets/seren/mindful_app_pause_dialog.dart';
import '../discipline/wellbeing_app_picker_sheet.dart';
import '../explore/bucket_list_screen.dart';
import '../organize/money/money_hub_screen.dart';
import '../scout/phone_modes_screen.dart';
import '../time/routines_screen.dart';
import '../time/tasks_screen.dart';
import 'mental_wellness_level2_sheets.dart';
import 'mental_wellness_level3_4_sheets.dart';
import 'mental_wellness_sheets.dart';
import 'seren_relaxation_screen.dart';

/// Unified 3-Layer **Seren — Mental Wellness Support** hub (`MentalWellnessScreen`).
///
/// Level 1 (Immediate Comfort MVP / 100% Local):
/// - **Layer 1 — Immediate Support:** Non-clinical felt-state triage (`EFA-01`),
///   tailored guided support (`EFA-02`), 5-4-3-2-1 sensory grounding (`EFA-03`),
///   paced breathing (`EFA-04`), emotional reset (`EFA-05`), small next steps
///   (`EFA-06`), and immediate Urge Support (`BTC-02`).
/// - **Layer 2 — My Comfort Kit & Ephemeral Release:** Pinned calming tools &
///   encouragement notes (`EFA-07`, `EFA-08`), Echo Gratitude Pebble draw, and
///   *Let It Out* / *Unsent Letters* (`SU-04`, `SU-05`).
/// - **Layer 3 — Break the Cycle:** Commitments + *My Why* (`BTC-01`), Mindful App
///   Pause (`BTC-02`), Urge Surfing (`BTC-03`), Environment Reset (`BTC-07`),
///   Healthy Alternatives (`BTC-06`), Personal Boundaries (`BTC-08`), Trigger &
///   Compassionate Recovery Reflections (`BTC-04`, `BTC-05`, `BTC-09`), Relapse
///   Prevention Plan (`BTC-11`), and Qualitative Snapshot (`BTC-10`).
class MentalWellnessScreen extends StatefulWidget {
  /// Optional initial layer filter (`0 = all`, `1`, `2`, `3`).
  final int initialLayer;

  /// When `true` (e.g. launched via native `NestinShieldActivity` Step Back),
  /// automatically opens the 5-step Guided Urge Surfing sheet after mount.
  final bool openUrgeSupportOnInit;

  const MentalWellnessScreen({
    super.key,
    this.initialLayer = 0,
    this.openUrgeSupportOnInit = false,
  });

  @override
  State<MentalWellnessScreen> createState() => _MentalWellnessScreenState();
}

class _MentalWellnessScreenState extends State<MentalWellnessScreen> {
  static const Color _serenPurple = AppColors.seren;
  static const Color _serenLavender = AppColors.serenLight;

  late int _selectedLayer;
  bool _calmMode = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _smallStepsKey = GlobalKey();
  final GlobalKey _breakTheCycleKey = GlobalKey();

  BreakTheCycleProvider? _ownedBtcProvider;

  @override
  void initState() {
    super.initState();
    _selectedLayer = widget.initialLayer.clamp(0, 3);
    if (widget.openUrgeSupportOnInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final btc = _resolveBtc(context);
        if (btc != null) {
          _openImmediateUrgeSupport(btc);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ownedBtcProvider?.dispose();
    super.dispose();
  }

  T? _tryRead<T>(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<T>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  BreakTheCycleProvider? _resolveBtc(BuildContext context) {
    final fromTree = _tryRead<BreakTheCycleProvider>(context, listen: true);
    if (fromTree != null) return fromTree;
    if (_ownedBtcProvider != null) return _ownedBtcProvider;

    final storage = _tryRead<StorageService>(context, listen: false);
    if (storage != null) {
      _ownedBtcProvider = BreakTheCycleProvider(storage);
      return _ownedBtcProvider;
    }
    return null;
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final targetCtx = key.currentContext;
    if (targetCtx == null) return;
    await Scrollable.ensureVisible(
      targetCtx,
      duration: Duration(milliseconds: _calmMode ? 450 : 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
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

  Future<void> _handleSmallStepTap(
    SmallNextStepOption step,
    BreakTheCycleProvider btc,
  ) async {
    final l10n = context.l10n;
    if (step.id == 'write_one_concern') {
      await EphemeralWritingSheet.show(
        context,
        btc: btc,
        initialMode: EphemeralWritingMode.letItOut,
      );
      await btc.recordSmallNextStepChosen(step.id);
      return;
    }
    if (step.logsHydrationGlass) {
      try {
        await Provider.of<HydrationProvider>(context, listen: false).addGlass();
      } catch (_) {}
    }
    await btc.recordSmallNextStepChosen(step.id);
    if (!mounted) return;
    _showSnack(
      l10n.tr('mw_small_step_chosen_toast', {'step': l10n.tr(step.titleKey)}),
    );
  }

  Future<void> _pickAppsForMindfulPause(BreakTheCycleProvider btc) async {
    final cfg = btc.mindfulAppPauseConfig;
    final deviceControl = _tryRead<DeviceControlProvider>(context);
    Map<String, String>? picked;

    if (deviceControl != null) {
      picked = await WellbeingAppPickerSheet.pickApps(
        context,
        initialSelected: cfg.monitoredPackages.toSet(),
        initialNames: cfg.monitoredAppNames,
        title: context.l10n.tr('btc_mindful_pause_select_apps'),
      );
    } else {
      picked = await _showFallbackAppPickerDialog(cfg);
    }

    if (picked == null) return;
    await btc.updateMindfulAppPauseConfig(
      cfg.copyWith(
        monitoredPackages: picked.keys.toList(),
        monitoredAppNames: picked,
      ),
    );
  }

  Future<Map<String, String>?> _showFallbackAppPickerDialog(
    MindfulAppPauseConfig cfg,
  ) async {
    const fallbackApps = {
      'com.android.chrome': 'Chrome Browser',
      'com.instagram.android': 'Instagram',
      'com.zhiliaoapp.musically': 'TikTok',
      'com.google.android.youtube': 'YouTube',
    };
    final selected = Map<String, String>.from(cfg.monitoredAppNames);
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.sheetSurface(ctx),
          title: Text(ctx.l10n.tr('btc_mindful_pause_select_apps')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: fallbackApps.entries.map((entry) {
              final checked = selected.containsKey(entry.key);
              return CheckboxListTile(
                value: checked,
                title: Text(entry.value),
                subtitle: Text(entry.key, style: const TextStyle(fontSize: 11)),
                onChanged: (v) {
                  setDialogState(() {
                    if (v == true) {
                      selected[entry.key] = entry.value;
                    } else {
                      selected.remove(entry.key);
                    }
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.l10n.tr('btc_common_cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(selected),
              child: Text(ctx.l10n.tr('btc_common_save')),
            ),
          ],
        ),
      ),
    );
  }

  void _openImmediateUrgeSupport(BreakTheCycleProvider btc) {
    UrgeSurfingSheet.show(context, btc: btc);
  }

  @override
  Widget build(BuildContext context) {
    final btc = _resolveBtc(context);
    if (btc == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg(context),
        appBar: AppBar(title: Text(context.l10n.tr('mw_screen_title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider<BreakTheCycleProvider>.value(
      value: btc,
      child: Consumer<BreakTheCycleProvider>(
        builder: (context, provider, _) => _buildScaffold(context, provider),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, BreakTheCycleProvider btc) {
    final l10n = context.l10n;
    final settings = _tryRead<SettingsProvider>(context, listen: true);
    final isLockedPrivate =
        settings != null && settings.isDiaryLockEnabled && !settings.isDiaryUnlocked;

    final borderAlpha = _calmMode ? 0.16 : 0.34;
    final cardColor = _calmMode
        ? AppColors.recessedSurface(context)
        : AppColors.cardSurface(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tr('mw_screen_title'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              l10n.tr('mw_screen_subtitle'),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('mw_calm_mode_toggle'),
            tooltip: l10n.tr(
              _calmMode ? 'mw_calm_mode_on' : 'mw_calm_mode_off',
            ),
            onPressed: () => setState(() => _calmMode = !_calmMode),
            icon: Icon(
              _calmMode ? Icons.visibility_rounded : Icons.spa_outlined,
              color: _calmMode ? _serenPurple : null,
            ),
          ),
          TextButton.icon(
            key: const Key('mw_quick_exit_btn'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: Text(
              l10n.tr('mw_quick_exit'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: Duration(milliseconds: _calmMode ? 450 : 200),
        color: _calmMode
            ? AppColors.recessedSurface(context).withValues(alpha: 0.4)
            : Colors.transparent,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            // 3-Layer Filter Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _layerChip(0, l10n.tr('mw_layer_all'), 'mw_layer_chip_all'),
                _layerChip(1, l10n.tr('mw_layer_1'), 'mw_layer_chip_1'),
                _layerChip(2, l10n.tr('mw_layer_2'), 'mw_layer_chip_2'),
                _layerChip(3, l10n.tr('mw_layer_3'), 'mw_layer_chip_3'),
              ],
            ),
            const SizedBox(height: 12),

            if (_selectedLayer == 0 || _selectedLayer == 1) ...[
              _buildLayer1ImmediateSupport(
                context,
                btc,
                cardColor: cardColor,
                borderAlpha: borderAlpha,
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedLayer == 0 || _selectedLayer == 2) ...[
              _buildLayer2ComfortKitAndRelease(
                context,
                btc,
                cardColor: cardColor,
                borderAlpha: borderAlpha,
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedLayer == 0 || _selectedLayer == 3) ...[
              Container(
                key: _breakTheCycleKey,
                child: _buildLayer3BreakTheCycle(
                  context,
                  btc,
                  isLockedPrivate: isLockedPrivate,
                  cardColor: cardColor,
                  borderAlpha: borderAlpha,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _layerChip(int layer, String label, String keyName) {
    final selected = _selectedLayer == layer;
    return ChoiceChip(
      key: Key(keyName),
      selected: selected,
      selectedColor: _serenPurple,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textPrimary(context),
        ),
      ),
      onSelected: (_) => setState(() => _selectedLayer = layer),
    );
  }

  Widget _buildLayer1ImmediateSupport(
    BuildContext context,
    BreakTheCycleProvider btc, {
    required Color cardColor,
    required double borderAlpha,
  }) {
    final l10n = context.l10n;
    final seren = _tryRead<SerenRelaxationProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Seren Hero Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _serenPurple.withValues(alpha: borderAlpha),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _serenPurple.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/mascots/sprites/seren/open_arms_welcome.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.spa_rounded,
                        size: 36,
                        color: _serenPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('mw_hero_welcome_quip'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.tr('mw_hero_non_clinical_note'),
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('mw_immediate_urge_support_btn'),
                onPressed: () => _openImmediateUrgeSupport(btc),
                style: FilledButton.styleFrom(
                  backgroundColor: _serenPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.waves_rounded, size: 18),
                label: Text(
                  l10n.tr('mw_immediate_urge_support_btn'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('mw_l4_open_crisis_bridge_btn'),
                onPressed: () =>
                    CrisisSupportBridgeSheet.show(context, btc: btc),
                icon: const Icon(
                  Icons.health_and_safety_outlined,
                  size: 17,
                  color: AppColors.rose,
                ),
                label: Text(
                  l10n.tr('mw_l4_open_crisis_btn'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Direct Tool Bypass Links (`EFA-01`)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _bypassChip(
                icon: Icons.surround_sound_rounded,
                label: l10n.tr('mw_bypass_sounds'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SerenRelaxationScreen(),
                  ),
                ),
              ),
              _bypassChip(
                icon: Icons.air_rounded,
                label: l10n.tr('mw_bypass_breathing'),
                onTap: () => BreathingBreakSheet.show(context, btc: btc),
              ),
              _bypassChip(
                icon: Icons.filter_5_rounded,
                label: l10n.tr('mw_bypass_grounding'),
                onTap: () => SensoryGroundingSheet.show(context, btc: btc),
              ),
              _bypassChip(
                icon: Icons.edit_note_rounded,
                label: l10n.tr('mw_bypass_let_it_out'),
                onTap: () => EphemeralWritingSheet.show(context, btc: btc),
              ),
              _bypassChip(
                icon: Icons.autorenew_rounded,
                label: l10n.tr('mw_bypass_break_the_cycle'),
                onTap: () {
                  setState(() => _selectedLayer = 3);
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToKey(_breakTheCycleKey),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Felt-State Triage Doors (`EFA-01`)
        Text(
          l10n.tr('mw_what_would_help_title'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.tr('mw_no_pressure_hint'),
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FeltStateType.values.map((state) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 40) / 2,
              child: InkWell(
                key: Key('mw_felt_state_${state.name}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  btc.selectFeltState(state);
                  EfaGuidedSupportSheet.show(
                    context,
                    feltState: state,
                    btc: btc,
                    onOpenSmallSteps: () => _scrollToKey(_smallStepsKey),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: btc.activeFeltState == state
                          ? _serenPurple
                          : AppColors.border(context),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        state.icon,
                        size: 20,
                        color: AppColors.adaptive(
                          context,
                          dark: _serenLavender,
                          light: _serenPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.tr(state.titleKey),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.tr(state.subtitleKey),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Quick 2–5 min Reset & Small Next Step (`EFA-05`, `EFA-06`)
        Container(
          key: _smallStepsKey,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('mw_small_step_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr('mw_small_step_subtitle'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => EmotionalResetSheet.show(
                      context,
                      btc: btc,
                      seren: seren,
                    ),
                    child: Text(
                      l10n.tr('mw_reset_title'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SmallNextStepOption.catalog.map((step) {
                  return ActionChip(
                    key: Key('mw_small_step_${step.id}'),
                    avatar: Icon(step.icon, size: 15, color: _serenPurple),
                    label: Text(
                      l10n.tr(step.titleKey),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _handleSmallStepTap(step, btc),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bypassChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 15, color: _serenPurple),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildLayer2ComfortKitAndRelease(
    BuildContext context,
    BreakTheCycleProvider btc, {
    required Color cardColor,
    required double borderAlpha,
  }) {
    final l10n = context.l10n;
    final seren = _tryRead<SerenRelaxationProvider>(context);
    final journal = _tryRead<JournalProvider>(context);
    final routines = _tryRead<RoutineProvider>(context);
    final settings = _tryRead<SettingsProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Comfort Kit (`EFA-07` Level 2 Customized Shelf)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _serenPurple.withValues(alpha: borderAlpha),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _serenPurple.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/mascots/sprites/seren/comfort_kit_treasure_box.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.inventory_2_outlined,
                        color: _serenPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('mw_comfort_kit_title'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr('mw_comfort_kit_subtitle'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('mw_comfort_kit_add_item_btn'),
                    onPressed: () => showComfortKitAddSheet(
                      context,
                      btc,
                      journal: journal,
                    ),
                    child: Text(l10n.tr('mw_l2_comfort_add_btn')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...btc.pinnedComfortKitItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final titleText =
                    item.isCustomNote ? item.title : l10n.tr(item.title);
                final subText =
                    item.isCustomNote ? item.subtitle : l10n.tr(item.subtitle);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppColors.elevatedSurface(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.border(context)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      leading: Icon(
                        _iconForComfortKind(item.kind),
                        color: _serenPurple,
                      ),
                      title: Text(
                        titleText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: subText.isNotEmpty
                          ? Text(subText, style: const TextStyle(fontSize: 11))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (idx > 0)
                            IconButton(
                              key: Key('mw_kit_pin_top_${item.id}'),
                              tooltip: l10n.tr('mw_l2_pin_top_tooltip'),
                              icon: const Icon(Icons.push_pin_outlined, size: 17),
                              onPressed: () =>
                                  btc.promoteComfortKitItemToTop(item.id),
                            ),
                          if (item.isCustomNote || item.id.startsWith('kit_'))
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => btc.deleteComfortKitItem(item.id),
                            )
                          else
                            const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                      onTap: () async {
                        await _handleComfortItemTap(
                          context,
                          btc: btc,
                          item: item,
                          titleText: titleText,
                          seren: seren,
                        );
                      },
                    ),
                  ),
                );
              }),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('mw_add_encouragement_note_btn'),
                    onPressed: () => showAddEncouragementNoteDialog(context, btc),
                    child: Text(
                      l10n.tr('mw_add_encouragement_note_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('mw_draw_gratitude_pebble_btn'),
                    onPressed: () {
                      final pebble = journal?.pickRandomGratitudePebble();
                      if (pebble == null) {
                        _showSnack(l10n.tr('mw_no_pebbles_yet'));
                        return;
                      }
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.sheetSurface(ctx),
                          title: Text(pebble.entryTitle),
                          content: Text(pebble.note),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(l10n.tr('btc_common_close')),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      l10n.tr('mw_draw_gratitude_pebble_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Let It Out, Unsent Letters & Spoken Voice Reflection (`SU-02`, `SU-04`, `SU-05`)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _serenPurple.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/mascots/sprites/duos/duo_seren_echo_unsent_letter.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.edit_note_rounded,
                        color: _serenPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('mw_ephemeral_section_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr('mw_ephemeral_section_subtitle'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('mw_open_let_it_out_btn'),
                    onPressed: () => EphemeralWritingSheet.show(
                      context,
                      btc: btc,
                      initialMode: EphemeralWritingMode.letItOut,
                    ),
                    child: Text(
                      l10n.tr('mw_let_it_out_title'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton(
                    key: const Key('mw_open_unsent_letter_btn'),
                    onPressed: () => EphemeralWritingSheet.show(
                      context,
                      btc: btc,
                      initialMode: EphemeralWritingMode.unsentLetter,
                    ),
                    child: Text(
                      l10n.tr('mw_unsent_letter_title'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('mw_open_voice_journal_btn'),
                    onPressed: () => VoiceJournalSessionSheet.show(
                      context,
                      btc: btc,
                      journal: journal,
                    ),
                    icon: const Icon(Icons.mic_none_rounded, size: 16),
                    label: Text(
                      l10n.tr('mw_l2_voice_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Get Support: Trusted Contacts, Custom Templates & Optional Support Plan (`GS-01`–`GS-03`, `GS-06`, `GS-07`)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _serenPurple.withValues(alpha: borderAlpha),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _serenPurple.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/mascots/sprites/duos/scout_seren_trusted_messenger.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.send_rounded,
                        color: _serenPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('gs_section_title'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr('gs_section_subtitle'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('mw_gs_add_contact_btn'),
                    onPressed: () => showTrustedContactEditorDialog(context, btc),
                    child: Text(l10n.tr('gs_add_contact_btn')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (btc.trustedContacts.isEmpty)
                Text(
                  l10n.tr('gs_contacts_empty'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                )
              else
                ...btc.trustedContacts.map((contact) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: AppColors.elevatedSurface(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border(context)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          backgroundColor: _serenPurple,
                          radius: 16,
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          contact.relationshipLabel.isNotEmpty
                              ? '${contact.name} (${contact.relationshipLabel})'
                              : contact.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${l10n.tr(contact.preferredChannel.translationKey)} • ${contact.phoneOrHandle}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            FilledButton.tonal(
                              key: Key('mw_gs_reach_out_${contact.id}'),
                              onPressed: () => QuickReachOutSheet.show(
                                context,
                                btc: btc,
                                contact: contact,
                              ),
                              child: Text(
                                l10n.tr('gs_reach_out_btn'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () =>
                                  btc.deleteTrustedContact(contact.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('mw_gs_add_template_btn'),
                    onPressed: () =>
                        showMessageTemplateEditorDialog(context, btc),
                    child: Text(
                      l10n.tr('gs_add_template_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('mw_gs_prof_guidance_btn'),
                    onPressed: () => showProfessionalHelpGuidanceSheet(context),
                    icon: const Icon(Icons.info_outline_rounded, size: 16),
                    label: Text(
                      l10n.tr('gs_prof_guidance_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('mw_gs_support_plan_btn'),
                    onPressed: () async {
                      if (settings != null &&
                          settings.isDiaryLockEnabled &&
                          !settings.isDiaryUnlocked) {
                        final ok = await SecurityPinGateSheet.verifyOrPrompt(
                          context,
                        );
                        if (!ok || !context.mounted) return;
                      }
                      await showPersonalSupportPlanDialog(context, btc);
                    },
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: Text(
                      l10n.tr('gs_support_plan_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('mw_l4_gs_crisis_btn'),
                    onPressed: () =>
                        CrisisSupportBridgeSheet.show(context, btc: btc),
                    icon: const Icon(
                      Icons.health_and_safety_outlined,
                      size: 16,
                      color: AppColors.rose,
                    ),
                    label: Text(
                      l10n.tr('mw_l4_open_crisis_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Morning & Evening Calm Rituals (`HL-03` — Seren ↔ Roo Integration)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _serenPurple.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/mascots/sprites/duos/roo_seren_calm_ritual_tea.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.emoji_food_beverage_rounded,
                        color: _serenPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('mw_l2_rituals_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr('mw_l2_rituals_sub'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tr('mw_l2_ritual_quip'),
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('mw_start_morning_ritual_btn'),
                    onPressed: () async {
                      if (seren != null) {
                        seren.setTimeOfDayMode(RelaxationTimeOfDayMode.morning);
                        await seren.playSingleSound('morning_melody');
                      }
                      if (context.mounted) {
                        _showSnack(l10n.tr('mw_l2_ritual_morning_started'));
                      }
                    },
                    icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                    label: Text(
                      l10n.tr('mw_l2_morning_ritual_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('mw_start_evening_ritual_btn'),
                    onPressed: () async {
                      if (seren != null) {
                        seren.setTimeOfDayMode(RelaxationTimeOfDayMode.evening);
                        await seren.playSingleSound('rain');
                      }
                      if (context.mounted) {
                        _showSnack(l10n.tr('mw_l2_ritual_evening_started'));
                      }
                    },
                    icon: const Icon(Icons.nightlight_outlined, size: 16),
                    label: Text(
                      l10n.tr('mw_l2_evening_ritual_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (routines != null)
                    OutlinedButton.icon(
                      key: const Key('mw_add_seren_routine_to_roo_btn'),
                      onPressed: () async {
                        final isEvening = DateTime.now().hour >= 17;
                        final title = l10n.tr(
                          isEvening
                              ? 'mw_l2_roo_evening_title'
                              : 'mw_l2_roo_morning_title',
                        );
                        await btc.linkCalmRitualToRoo(
                          routineProvider: routines,
                          isMorning: !isEvening,
                          title: title,
                          description: l10n.tr(
                            isEvening
                                ? 'mw_l2_roo_evening_desc'
                                : 'mw_l2_roo_morning_desc',
                          ),
                          steps: isEvening
                              ? [
                                  l10n.tr('mw_l2_roo_step_sound'),
                                  l10n.tr('mw_l2_roo_step_dim'),
                                  l10n.tr('mw_l2_roo_step_let_out'),
                                ]
                              : [
                                  l10n.tr('mw_l2_roo_step_water'),
                                  l10n.tr('mw_l2_roo_step_breath'),
                                  l10n.tr('mw_l2_roo_step_intention'),
                                ],
                        );
                        if (context.mounted) {
                          _showSnack(
                            l10n.tr('mw_l2_ritual_linked_toast', {'title': title}),
                          );
                        }
                      },
                      icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                      label: Text(
                        l10n.tr('mw_l2_link_roo_btn'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconForComfortKind(ComfortKitItemKind kind) {
    switch (kind) {
      case ComfortKitItemKind.soundscape:
        return Icons.water_drop_rounded;
      case ComfortKitItemKind.breathing:
        return Icons.air_rounded;
      case ComfortKitItemKind.grounding:
        return Icons.filter_5_rounded;
      case ComfortKitItemKind.encouragementNote:
      case ComfortKitItemKind.gratitudePebble:
        return Icons.favorite_border_rounded;
      case ComfortKitItemKind.reading:
        return Icons.menu_book_rounded;
      case ComfortKitItemKind.echoMemory:
        return Icons.auto_awesome_rounded;
      case ComfortKitItemKind.comfortPhoto:
        return Icons.photo_outlined;
      case ComfortKitItemKind.externalBookmark:
        return Icons.bookmark_border_rounded;
    }
  }

  Future<void> _handleComfortItemTap(
    BuildContext context, {
    required BreakTheCycleProvider btc,
    required ComfortKitItem item,
    required String titleText,
    required SerenRelaxationProvider? seren,
  }) async {
    final l10n = context.l10n;
    switch (item.kind) {
      case ComfortKitItemKind.soundscape:
        if (seren != null) {
          await seren.playSingleSound(item.referenceId ?? 'rain');
        }
        if (context.mounted) {
          _showSnack(titleText);
        }
        break;
      case ComfortKitItemKind.breathing:
        await BreathingBreakSheet.show(context, btc: btc);
        break;
      case ComfortKitItemKind.grounding:
        await SensoryGroundingSheet.show(context, btc: btc);
        break;
      case ComfortKitItemKind.reading:
        if (seren != null && item.referenceId != null) {
          final match = SerenRelaxationCatalog.readings
              .where((r) => r.id == item.referenceId)
              .toList();
          if (match.isNotEmpty) {
            await seren.openReadingItem(match.first.id);
          }
        }
        if (!context.mounted) return;
        _showSnack(l10n.tr('mw_l2_open_story_toast', {'title': titleText}));
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SerenRelaxationScreen(initialTabIndex: 3),
          ),
        );
        break;
      case ComfortKitItemKind.echoMemory:
      case ComfortKitItemKind.comfortPhoto:
      case ComfortKitItemKind.externalBookmark:
      case ComfortKitItemKind.encouragementNote:
      case ComfortKitItemKind.gratitudePebble:
        await showComfortItemPreviewDialog(context, item);
        break;
    }
  }

  Widget _buildLayer3BreakTheCycle(
    BuildContext context,
    BreakTheCycleProvider btc, {
    required bool isLockedPrivate,
    required Color cardColor,
    required double borderAlpha,
  }) {
    final l10n = context.l10n;
    final journal = _tryRead<JournalProvider>(context);
    final settings = _tryRead<SettingsProvider>(context);
    final health = _tryRead<HealthWellnessProvider>(context);
    final routines = _tryRead<RoutineProvider>(context);
    final money = _tryRead<MoneyProvider>(context);
    final bucket = _tryRead<BucketListProvider>(context);
    final tasks = _tryRead<TaskProvider>(context);
    final devices = _tryRead<DeviceControlProvider>(context);
    final cfg = btc.mindfulAppPauseConfig;
    final progress = btc.qualitativeProgress;
    final snoozedNow = cfg.isSnoozedAt(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tr('btc_section_title'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        Text(
          l10n.tr('btc_section_subtitle'),
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),

        // Anti-guilt reassurance banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _serenPurple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _serenPurple.withValues(alpha: borderAlpha),
            ),
          ),
          child: Text(
            l10n.tr('btc_anti_guilt_banner'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Level 3: Offline Educational Library & Personal Insights (`SU-08`, `SU-09`)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _serenPurple.withValues(alpha: borderAlpha),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _serenPurple.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/mascots/sprites/duos/seren_echo_library_lantern.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.menu_book_rounded,
                        color: _serenPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('mw_l3_edu_section_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr('mw_l3_edu_section_sub'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: EducationalGuideSpec.catalog.map((guide) {
                  return ActionChip(
                    key: Key('mw_l3_quick_guide_${guide.id}'),
                    avatar: Icon(guide.icon, size: 15, color: _serenPurple),
                    label: Text(
                      l10n.tr(guide.titleKey),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () => GuideReaderSheet.show(
                      context,
                      btc: btc,
                      guide: guide,
                      journal: journal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('mw_l3_open_edu_library_btn'),
                    onPressed: () => EducationalLibrarySheet.show(
                      context,
                      btc: btc,
                      journal: journal,
                    ),
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: Text(
                      l10n.tr('mw_l3_open_edu_library_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('mw_l3_open_insights_btn'),
                    onPressed: () => PersonalInsightsAndHistorySheet.show(
                      context,
                      btc: btc,
                      journal: journal,
                      settings: settings,
                    ),
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                    label: Text(
                      l10n.tr('mw_l3_open_insights_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Mindful App Pause Configuration Card (`BTC-02` — acute & unlocked)
        Material(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                          l10n.tr('btc_mindful_pause_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr('btc_mindful_pause_subtitle'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('mw_btc_mindful_pause_switch'),
                    value: cfg.isEnabled,
                    onChanged: (v) async {
                      await btc.updateMindfulAppPauseConfig(
                        cfg.copyWith(isEnabled: v),
                      );
                      if (v && devices != null) {
                        await devices.refreshCapabilities();
                      }
                    },
                  ),
                ],
              ),
              if (cfg.monitoredPackages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cfg.monitoredPackages.map((pkg) {
                    final label = cfg.monitoredAppNames[pkg] ??
                        devices?.displayNameForPackage(pkg) ??
                        pkg;
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(
                        Icons.pause_circle_outline_rounded,
                        size: 15,
                        color: _serenPurple,
                      ),
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      onDeleted: () {
                        final nextPkgs = cfg.monitoredPackages
                            .where((p) => p != pkg)
                            .toList();
                        final nextNames =
                            Map<String, String>.from(cfg.monitoredAppNames)
                              ..remove(pkg);
                        btc.updateMindfulAppPauseConfig(
                          cfg.copyWith(
                            monitoredPackages: nextPkgs,
                            monitoredAppNames: nextNames,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ] else if (cfg.isEnabled) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.tr('btc_mindful_pause_no_apps_warning'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('mw_btc_select_apps_btn'),
                    onPressed: () => _pickAppsForMindfulPause(btc),
                    icon: const Icon(Icons.apps_rounded, size: 16),
                    label: Text(
                      cfg.monitoredPackages.isEmpty
                          ? l10n.tr('btc_mindful_pause_select_apps')
                          : '${l10n.tr('btc_mindful_pause_apps_label')} (${cfg.monitoredPackages.length})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (!cfg.strictBlockMode)
                    OutlinedButton.icon(
                      key: const Key('mw_btc_snooze_1h_btn'),
                      onPressed: () async {
                        if (snoozedNow) {
                          await btc.clearMindfulAppPauseSnooze();
                        } else {
                          await btc.snoozeMindfulAppPause(
                            const Duration(hours: 1),
                          );
                        }
                      },
                      icon: const Icon(Icons.snooze_rounded, size: 16),
                      label: Text(
                        snoozedNow
                            ? l10n.tr('btc_mindful_pause_clear_snooze')
                            : l10n.tr('btc_mindful_pause_snooze_1h'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  FilledButton.tonalIcon(
                    key: const Key('mw_btc_preview_mindful_pause_btn'),
                    onPressed: () {
                      final pkg = cfg.monitoredPackages.isNotEmpty
                          ? cfg.monitoredPackages.first
                          : 'com.android.chrome';
                      MindfulAppPauseDialog.show(
                        context,
                        packageName: pkg,
                        onStepBackToUrgeSupport: () =>
                            _openImmediateUrgeSupport(btc),
                      );
                    },
                    icon: const Icon(Icons.door_front_door_outlined, size: 16),
                    label: Text(
                      l10n.tr('btc_mindful_pause_preview_btn'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (cfg.isEnabled) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('mw_btc_strict_block_switch'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: cfg.strictBlockMode,
                  title: Text(
                    l10n.tr('btc_mindful_pause_strict_toggle'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    l10n.tr('btc_mindful_pause_strict_sub'),
                    style: const TextStyle(fontSize: 11),
                  ),
                  onChanged: (v) => btc.updateMindfulAppPauseConfig(
                    cfg.copyWith(strictBlockMode: v),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: cfg.vulnerableHoursOnly,
                  title: Text(
                    l10n.tr('btc_mindful_pause_vulnerable_toggle'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    l10n.tr('btc_mindful_pause_vulnerable_window', {
                      'start': cfg.vulnerableStartHour.toString().padLeft(2, '0'),
                      'end': cfg.vulnerableEndHour.toString().padLeft(2, '0'),
                    }),
                    style: const TextStyle(fontSize: 11),
                  ),
                  onChanged: (v) => btc.updateMindfulAppPauseConfig(
                    cfg.copyWith(vulnerableHoursOnly: v),
                  ),
                ),
                if (devices != null &&
                    devices.registry.platform == 'android') ...[
                  const SizedBox(height: 8),
                  _buildMindfulPauseAndroidPermissionBanner(
                    context,
                    devices,
                  ),
                ],
              ],
            ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Environment Reset (`BTC-07` — acute & unlocked)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tr('btc_env_reset_title'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Text(
                l10n.tr('btc_env_reset_subtitle'),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EnvironmentResetSpec.catalog.map((env) {
                  return ActionChip(
                    key: Key('btc_env_${env.id}'),
                    avatar: Icon(env.icon, size: 15, color: _serenPurple),
                    label: Text(
                      l10n.tr(env.titleKey),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      await btc.recordEnvironmentResetTried(env.id);
                      if (!context.mounted) return;
                      _showSnack(
                        l10n.tr('btc_action_tried_toast', {
                          'item': l10n.tr(env.titleKey),
                        }),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Healthy Alternatives (`BTC-06` — unlocked)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _serenPurple.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/mascots/sprites/duos/duo_seren_pippin_healthy_spark.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.explore_rounded,
                        color: _serenPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('btc_healthy_alt_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr('btc_healthy_alt_subtitle'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HealthyAlternativeSpec.catalog.map((alt) {
                  return ActionChip(
                    key: Key('btc_alt_${alt.id}'),
                    avatar: Icon(alt.icon, size: 15, color: _serenPurple),
                    label: Text(
                      '${alt.companionBird} • ${l10n.tr(alt.titleKey)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      await btc.recordHealthyAlternativeExplored(alt.id);
                      if (!context.mounted) return;
                      switch (alt.id) {
                        case 'alt_soundscape':
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SerenRelaxationScreen(),
                            ),
                          );
                          return;
                        case 'alt_short_walk':
                        case 'alt_stretch':
                          if (health != null) {
                            await HealthWellnessSheet.show(
                              context,
                              initialTabIndex: 0,
                            );
                          } else {
                            _showSnack(l10n.tr('mw_hl_alt_movement'));
                          }
                          return;
                        case 'alt_read_pages':
                        case 'alt_sketch_hobby':
                        case 'alt_puzzle_spark':
                          if (bucket != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BucketListScreen(),
                              ),
                            );
                          } else {
                            _showSnack(l10n.tr('mw_hl_alt_pippin_books'));
                          }
                          return;
                        case 'alt_small_task':
                          if (tasks != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const TasksScreen(),
                              ),
                            );
                          } else {
                            _showSnack(l10n.tr('mw_hl_alt_roo_task'));
                          }
                          return;
                        case 'alt_message_friend':
                          if (btc.trustedContacts.isNotEmpty) {
                            await QuickReachOutSheet.show(
                              context,
                              btc: btc,
                              contact: btc.trustedContacts.first,
                            );
                          } else {
                            await CrisisSupportBridgeSheet.show(
                              context,
                              btc: btc,
                            );
                          }
                          return;
                      }
                      _showSnack(
                        l10n.tr('btc_action_tried_toast', {
                          'item': l10n.tr(alt.titleKey),
                        }),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Healthy Living Cross-Bird Bridges & Flexible Well-being Intentions (`HL-03`–`HL-07`)
        Material(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _serenPurple.withValues(alpha: 0.14),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        'assets/mascots/sprites/ensembles/flock_healthy_living_compass.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.explore_outlined,
                          color: _serenPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tr('mw_hl_bridges_title'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            l10n.tr('mw_hl_bridges_sub'),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('mw_hl_open_sleep_hydration_btn'),
                      onPressed: () {
                        if (health != null) {
                          HealthWellnessSheet.show(context, initialTabIndex: 1);
                        } else {
                          _showSnack(
                            l10n.tr('mw_hl_provider_missing_toast', {
                              'tool': l10n.tr('mw_hl_open_sleep_hydration_btn'),
                            }),
                          );
                        }
                      },
                      icon: const Icon(Icons.bedtime_outlined, size: 15),
                      label: Text(
                        l10n.tr('mw_hl_open_sleep_hydration_btn'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('mw_hl_open_roo_routines_btn'),
                      onPressed: () {
                        if (routines != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RoutinesScreen(),
                            ),
                          );
                        } else {
                          _showSnack(
                            l10n.tr('mw_hl_provider_missing_toast', {
                              'tool': l10n.tr('mw_hl_open_roo_routines_btn'),
                            }),
                          );
                        }
                      },
                      icon: const Icon(Icons.view_agenda_outlined, size: 15),
                      label: Text(
                        l10n.tr('mw_hl_open_roo_routines_btn'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('mw_hl_open_twill_budget_btn'),
                      onPressed: () {
                        if (money != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MoneyHubScreen(standalone: true),
                            ),
                          );
                        } else {
                          _showSnack(
                            l10n.tr('mw_hl_provider_missing_toast', {
                              'tool': l10n.tr('mw_hl_open_twill_budget_btn'),
                            }),
                          );
                        }
                      },
                      icon: const Icon(Icons.savings_outlined, size: 15),
                      label: Text(
                        l10n.tr('mw_hl_open_twill_budget_btn'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('mw_hl_open_scout_modes_btn'),
                      onPressed: () {
                        if (devices != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PhoneModesScreen(),
                            ),
                          );
                        } else {
                          _showSnack(
                            l10n.tr('mw_hl_provider_missing_toast', {
                              'tool': l10n.tr('mw_hl_open_scout_modes_btn'),
                            }),
                          );
                        }
                      },
                      icon: const Icon(Icons.tune_rounded, size: 15),
                      label: Text(
                        l10n.tr('mw_hl_open_scout_modes_btn'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tr('mw_l3_goals_title'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            l10n.tr('mw_l3_goals_sub'),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const Key('mw_hl_add_wellbeing_goal_btn'),
                      onPressed: () => showAddWellbeingGoalDialog(context, btc),
                      child: Text(l10n.tr('mw_l3_add_goal_btn')),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...btc.wellbeingGoals.map((goal) {
                  final titleText = goal.title.startsWith('mw_')
                      ? l10n.tr(goal.title)
                      : goal.title;
                  return CheckboxListTile(
                    key: Key('mw_hl_goal_${goal.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: goal.isActive,
                    title: Text(titleText, style: const TextStyle(fontSize: 12)),
                    subtitle: Text(
                      l10n.tr(goal.categoryKey),
                      style: const TextStyle(fontSize: 10),
                    ),
                    secondary: goal.id.startsWith('hl_goal_')
                        ? null
                        : IconButton(
                            key: Key('mw_hl_del_goal_${goal.id}'),
                            icon: const Icon(Icons.delete_outline, size: 17),
                            onPressed: () => btc.deleteWellbeingGoal(goal.id),
                          ),
                    onChanged: (_) => btc.toggleWellbeingGoal(goal.id),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Personal Boundaries (`BTC-08`)
        Material(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('btc_boundaries_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr('btc_boundaries_subtitle'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('mw_btc_add_boundary_btn'),
                    onPressed: () => showAddBoundaryDialog(context, btc),
                    child: Text(l10n.tr('btc_add_boundary_btn')),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...btc.personalBoundaries.map((b) {
                final titleText = b.title.startsWith('btc_')
                    ? l10n.tr(b.title)
                    : b.title;
                return Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: b.isActive,
                        title: Text(
                          titleText,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          l10n.tr(b.categoryKey),
                          style: const TextStyle(fontSize: 10),
                        ),
                        onChanged: (_) => btc.togglePersonalBoundary(b.id),
                      ),
                    ),
                    if (!b.id.startsWith('bound_'))
                      IconButton(
                        key: Key('mw_btc_del_boundary_${b.id}'),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        onPressed: () => btc.deletePersonalBoundary(b.id),
                      ),
                  ],
                );
              }),
            ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Sensitive Personal Records (`BTC-01`, `BTC-04`, `BTC-05`, `BTC-09`, `BTC-11`)
        // Protected by Echo's `DiaryLockHelper` / `SecurityPinGateSheet` when enabled.
        if (isLockedPrivate)
          Container(
            key: const Key('mw_btc_private_locked_card'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _serenPurple.withValues(alpha: borderAlpha),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: _serenPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.tr('btc_private_records_title'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.tr('btc_private_records_locked_desc'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('mw_btc_unlock_private_records_btn'),
                  onPressed: () async {
                    await SecurityPinGateSheet.verifyOrPrompt(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _serenPurple,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(l10n.tr('btc_unlock_private_records_btn')),
                ),
              ],
            ),
          )
        else ...[
          // `BTC-01` Commitments + My Why
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tr('btc_commitments_title'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('mw_btc_add_commitment_btn'),
                      onPressed: () => showCommitmentEditorDialog(context, btc),
                      child: Text(l10n.tr('btc_add_commitment_btn')),
                    ),
                  ],
                ),
                if (btc.commitments.isEmpty)
                  Text(
                    l10n.tr('btc_commitments_empty'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  )
                else
                  ...btc.commitments.map(
                    (goal) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.elevatedSurface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l10n.tr(goal.intention.translationKey)} • ${goal.behaviorTitle}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (goal.myWhy.isNotEmpty)
                                    Text(
                                      goal.myWhy,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => showCommitmentEditorDialog(
                                context,
                                btc,
                                existing: goal,
                              ),
                            ),
                            IconButton(
                              key: Key('mw_btc_del_commitment_${goal.id}'),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => btc.deleteCommitment(goal.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // `BTC-04`/`BTC-05` Trigger Journal, `BTC-09` Recovery Reflection, `BTC-11` Plan
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.tr('btc_trigger_journal_title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  l10n.tr('btc_trigger_journal_sub'),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('mw_btc_add_trigger_btn'),
                      onPressed: () => showTriggerReflectionDialog(
                        context,
                        btc,
                        journal: journal,
                      ),
                      child: Text(l10n.tr('btc_add_trigger_btn')),
                    ),
                    OutlinedButton(
                      key: const Key('mw_btc_add_recovery_btn'),
                      onPressed: () => showRecoveryReflectionDialog(
                        context,
                        btc,
                        journal: journal,
                      ),
                      child: Text(l10n.tr('btc_add_recovery_btn')),
                    ),
                    OutlinedButton(
                      key: const Key('mw_btc_edit_plan_btn'),
                      onPressed: () =>
                          showRelapsePreventionPlanDialog(context, btc),
                      child: Text(l10n.tr('btc_plan_edit_btn')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // `BTC-10` Qualitative Change Progress (hidden numeric counts in Calm Mode)
          if (!_calmMode)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('btc_progress_title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    l10n.tr('btc_progress_subtitle'),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _qualitativePill(
                        l10n.tr('btc_progress_reflections'),
                        progress.reflectionsCompletedCount,
                      ),
                      _qualitativePill(
                        l10n.tr('btc_progress_strategies'),
                        progress.strategiesTriedCount,
                      ),
                      _qualitativePill(
                        l10n.tr('btc_progress_goals'),
                        progress.goalsShapedCount,
                      ),
                      _qualitativePill(
                        l10n.tr('btc_progress_alternatives'),
                        progress.alternativesExploredCount,
                      ),
                      _qualitativePill(
                        l10n.tr('btc_progress_grounding'),
                        progress.groundingSessionsCompletedCount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('mw_l3_open_privacy_controls_btn'),
          onPressed: () async {
            if (settings != null &&
                settings.isDiaryLockEnabled &&
                !settings.isDiaryUnlocked) {
              final ok = await SecurityPinGateSheet.verifyOrPrompt(context);
              if (!ok || !context.mounted) return;
            }
            await SensitiveDataPrivacySheet.show(context, btc: btc);
          },
          icon: const Icon(Icons.enhanced_encryption_outlined, size: 17),
          label: Text(l10n.tr('mw_l3_privacy_btn')),
        ),
      ],
    );
  }

  Widget _buildMindfulPauseAndroidPermissionBanner(
    BuildContext context,
    DeviceControlProvider devices,
  ) {
    final l10n = context.l10n;
    final reg = devices.registry;
    final hasAccessibility = reg.supportFor(
          DeviceCapabilityRegistry.actionAppBlockingShield,
        ) ==
        ActionExecutionSupport.directlySupported;
    final hasUsage = reg.isGranted(NestinPermissionKind.usageStats);
    final hasOverlay = reg.supportFor(
          DeviceCapabilityRegistry.actionAppOverlayBanner,
        ) ==
        ActionExecutionSupport.directlySupported;

    final isReady = hasAccessibility || (hasUsage && hasOverlay);
    if (isReady) {
      return Container(
        key: const Key('mw_btc_shield_ready_banner'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.14),
              ),
              padding: const EdgeInsets.all(3),
              child: Image.asset(
                'assets/mascots/sprites/duos/duo_seren_scout_shield_ready.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('btc_mindful_pause_shield_ready_title'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    l10n.tr('btc_mindful_pause_shield_ready_sub'),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('mw_btc_permission_needed_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.tr('btc_mindful_pause_perm_needed_title'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.tr('btc_mindful_pause_perm_needed_sub'),
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (!hasAccessibility)
                FilledButton.tonalIcon(
                  key: const Key('mw_btc_enable_accessibility_btn'),
                  onPressed: () async {
                    await devices.openPermissionSettings(
                      NestinPermissionKind.accessibilityService,
                    );
                    await devices.refreshCapabilities();
                  },
                  icon: const Icon(Icons.shield_outlined, size: 15),
                  label: Text(
                    l10n.tr('btc_mindful_pause_enable_accessibility_btn'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              if (!hasUsage)
                OutlinedButton.icon(
                  key: const Key('mw_btc_enable_usage_btn'),
                  onPressed: () async {
                    await devices.openPermissionSettings(
                      NestinPermissionKind.usageStats,
                    );
                    await devices.refreshCapabilities();
                  },
                  icon: const Icon(Icons.query_stats_rounded, size: 15),
                  label: Text(
                    l10n.tr('btc_mindful_pause_enable_usage_btn'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              if (!hasOverlay)
                OutlinedButton.icon(
                  key: const Key('mw_btc_enable_overlay_btn'),
                  onPressed: () async {
                    await devices.openPermissionSettings(
                      NestinPermissionKind.systemAlertWindow,
                    );
                    await devices.refreshCapabilities();
                  },
                  icon: const Icon(Icons.layers_outlined, size: 15),
                  label: Text(
                    l10n.tr('btc_mindful_pause_enable_overlay_btn'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qualitativePill(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }
}
