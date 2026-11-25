import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/mental_wellness_models.dart';
import '../../../providers/break_the_cycle_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/seren_relaxation_provider.dart';
import 'seren_relaxation_screen.dart';

const Color kSerenWellnessPurple = AppColors.seren;
const Color kSerenWellnessLavender = AppColors.serenLight;

T? _tryRead<T>(BuildContext context) {
  try {
    return Provider.of<T>(context, listen: false);
  } catch (_) {
    return null;
  }
}

Widget _serenSprite({
  required String assetPath,
  required IconData fallbackIcon,
  double size = 84,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: kSerenWellnessPurple.withValues(alpha: 0.14),
    ),
    padding: const EdgeInsets.all(8),
    child: Image.asset(
      assetPath,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        fallbackIcon,
        size: size * 0.5,
        color: kSerenWellnessPurple,
      ),
    ),
  );
}

void _showCalmToast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.adaptive(
        context,
        dark: AppColors.darkSurfaceSubtle,
        light: AppColors.lightTextPrimary,
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Tailored, non-linear guided response modal for `EFA-02` & `EFA-08`.
class EfaGuidedSupportSheet extends StatelessWidget {
  final FeltStateType feltState;
  final BreakTheCycleProvider btc;
  final JournalProvider? journal;
  final SerenRelaxationProvider? seren;
  final VoidCallback onOpenSmallSteps;

  const EfaGuidedSupportSheet({
    super.key,
    required this.feltState,
    required this.btc,
    required this.journal,
    required this.seren,
    required this.onOpenSmallSteps,
  });

  static Future<void> show(
    BuildContext context, {
    required FeltStateType feltState,
    required BreakTheCycleProvider btc,
    required VoidCallback onOpenSmallSteps,
  }) {
    final journal = _tryRead<JournalProvider>(context);
    final seren = _tryRead<SerenRelaxationProvider>(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EfaGuidedSupportSheet(
        feltState: feltState,
        btc: btc,
        journal: journal,
        seren: seren,
        onOpenSmallSteps: onOpenSmallSteps,
      ),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.scrimHandle(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _serenSprite(
                  assetPath: 'assets/mascots/sprites/seren/open_arms_welcome.png',
                  fallbackIcon: feltState.icon,
                  size: 64,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr(feltState.titleKey),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.tr(feltState.acknowledgementKey),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: kSerenWellnessPurple.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                l10n.tr(feltState.encouragementKey),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...EfaResponseBucket.values.map((bucket) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  key: Key('mw_bucket_${bucket.name}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.of(context).pop();
                    switch (bucket) {
                      case EfaResponseBucket.calmBody:
                        SensoryGroundingSheet.show(context, btc: btc);
                        break;
                      case EfaResponseBucket.quietSurroundings:
                        EmotionalResetSheet.show(
                          context,
                          btc: btc,
                          seren: seren,
                        );
                        break;
                      case EfaResponseBucket.outOfHead:
                        EphemeralWritingSheet.show(
                          context,
                          btc: btc,
                          journal: journal,
                        );
                        break;
                      case EfaResponseBucket.smallNextStep:
                        onOpenSmallSteps();
                        break;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kSerenWellnessPurple.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            bucket.icon,
                            size: 18,
                            color: AppColors.adaptive(
                              context,
                              dark: kSerenWellnessLavender,
                              light: kSerenWellnessPurple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.tr(bucket.titleKey),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              Text(
                                l10n.tr(bucket.subtitleKey),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary(context),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.tr('mw_guided_skip_anytime'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive 5-4-3-2-1 sensory grounding stepper (`EFA-03`).
class SensoryGroundingSheet extends StatefulWidget {
  final BreakTheCycleProvider btc;

  const SensoryGroundingSheet({super.key, required this.btc});

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SensoryGroundingSheet(btc: btc),
    );
  }

  @override
  State<SensoryGroundingSheet> createState() => _SensoryGroundingSheetState();
}

class _SensoryGroundingSheetState extends State<SensoryGroundingSheet> {
  int _stepIndex = 0;

  void _nextOrFinish() async {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    if (_stepIndex < GroundingStepSpec.steps54321.length - 1) {
      setState(() => _stepIndex += 1);
      return;
    }

    await widget.btc.recordGroundingCompleted();
    if (!mounted) return;
    Navigator.of(context).pop();
    _showCalmToast(context, context.l10n.tr('mw_grounding_completed_toast'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = GroundingStepSpec.steps54321[_stepIndex];
    final isLast = _stepIndex == GroundingStepSpec.steps54321.length - 1;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.tr('mw_grounding_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: _serenSprite(
              assetPath:
                  'assets/mascots/sprites/seren/grounding_pebble_feather.png',
              fallbackIcon: step.icon,
              size: 86,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.tr('mw_grounding_quip'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: kSerenWellnessPurple.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: kSerenWellnessPurple,
                      child: Text(
                        '${step.count}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.tr(step.titleKey),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    Text(
                      l10n.tr('mw_grounding_step_counter', {
                        'current': _stepIndex + 1,
                      }),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.tr(step.instructionKey),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.tr(step.examplesKey),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.tr('btc_common_skip')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: Key(
                    isLast
                        ? 'mw_grounding_complete_btn'
                        : 'mw_grounding_next_btn',
                  ),
                  onPressed: _nextOrFinish,
                  style: FilledButton.styleFrom(
                    backgroundColor: kSerenWellnessPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.tr(
                      isLast ? 'mw_grounding_complete' : 'mw_grounding_next',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
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

/// Optional non-medical breathing break modal (`EFA-04`).
class BreathingBreakSheet extends StatefulWidget {
  final BreakTheCycleProvider btc;

  const BreathingBreakSheet({super.key, required this.btc});

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BreathingBreakSheet(btc: btc),
    );
  }

  @override
  State<BreathingBreakSheet> createState() => _BreathingBreakSheetState();
}

class _BreathingBreakSheetState extends State<BreathingBreakSheet> {
  String _modeId = 'coherent'; // coherent, box, 478
  bool _running = false;
  int _phaseIndex = 0;
  int _secondsLeft = 5;
  Timer? _timer;

  List<(String, int)> get _phases {
    switch (_modeId) {
      case 'box':
        return [
          ('mw_breath_phase_inhale', 4),
          ('mw_breath_phase_hold', 4),
          ('mw_breath_phase_exhale', 4),
          ('mw_breath_phase_rest', 4),
        ];
      case '478':
        return [
          ('mw_breath_phase_inhale', 4),
          ('mw_breath_phase_hold', 7),
          ('mw_breath_phase_exhale', 8),
        ];
      case 'coherent':
      default:
        return [
          ('mw_breath_phase_inhale', 5),
          ('mw_breath_phase_exhale', 5),
        ];
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _running = true;
      _phaseIndex = 0;
      _secondsLeft = _phases.first.$2;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft -= 1);
      } else {
        try {
          HapticFeedback.selectionClick();
        } catch (_) {}
        setState(() {
          _phaseIndex = (_phaseIndex + 1) % _phases.length;
          _secondsLeft = _phases[_phaseIndex].$2;
        });
      }
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    if (_running) {
      await widget.btc.recordBreathingBreakCompleted();
    }
    if (mounted) {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentPhase = _phases[_phaseIndex % _phases.length];

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.tr('mw_breathing_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
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
          Text(
            l10n.tr('mw_breathing_subtitle'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                selected: _modeId == 'coherent',
                label: Text(l10n.tr('mw_breath_coherent_label')),
                onSelected: (_) {
                  _timer?.cancel();
                  setState(() {
                    _modeId = 'coherent';
                    _running = false;
                    _phaseIndex = 0;
                    _secondsLeft = _phases.first.$2;
                  });
                },
              ),
              ChoiceChip(
                selected: _modeId == 'box',
                label: Text(l10n.tr('mw_breath_box_label')),
                onSelected: (_) {
                  _timer?.cancel();
                  setState(() {
                    _modeId = 'box';
                    _running = false;
                    _phaseIndex = 0;
                    _secondsLeft = _phases.first.$2;
                  });
                },
              ),
              ChoiceChip(
                selected: _modeId == '478',
                label: Text(l10n.tr('mw_breath_478_label')),
                onSelected: (_) {
                  _timer?.cancel();
                  setState(() {
                    _modeId = '478';
                    _running = false;
                    _phaseIndex = 0;
                    _secondsLeft = _phases.first.$2;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: kSerenWellnessPurple.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _running
                      ? l10n.tr(currentPhase.$1)
                      : l10n.tr('ready_to_breathe'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_running ? _secondsLeft : _phases.first.$2}s',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.adaptive(
                      context,
                      dark: kSerenWellnessLavender,
                      light: kSerenWellnessPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.tr('mw_breath_comfort_notice'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _running ? _stop : _start,
            style: FilledButton.styleFrom(
              backgroundColor: kSerenWellnessPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              l10n.tr(_running ? 'mw_breath_stop' : 'mw_breath_start'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              _timer?.cancel();
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SerenRelaxationScreen(initialTabIndex: 1),
                ),
              );
            },
            child: Text(l10n.tr('mw_breath_open_studio')),
          ),
        ],
      ),
    );
  }
}

/// 2–5 minute Emotional Reset sheet (`EFA-05`).
class EmotionalResetSheet extends StatelessWidget {
  final BreakTheCycleProvider btc;
  final SerenRelaxationProvider? seren;

  const EmotionalResetSheet({
    super.key,
    required this.btc,
    required this.seren,
  });

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
    SerenRelaxationProvider? seren,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmotionalResetSheet(btc: btc, seren: seren),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cues = [
      'mw_reset_cue_shoulders',
      'mw_reset_cue_jaw',
      'mw_reset_cue_hands',
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.tr('mw_reset_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            l10n.tr('mw_reset_subtitle'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ...cues.map(
            (key) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.spa_outlined,
                      size: 16,
                      color: kSerenWellnessPurple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.tr(key),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (seren != null) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () async {
                if (seren!.isMixerPlaying) {
                  await seren!.pauseMixerPlayback();
                } else {
                  await seren!.playSingleSound('rain');
                }
              },
              icon: const Icon(Icons.water_drop_outlined, size: 18),
              label: Text(
                l10n.tr(
                  seren!.isMixerPlaying
                      ? 'mw_reset_stop_audio'
                      : 'mw_reset_play_rain',
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              await btc.recordEmotionalResetCompleted();
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: kSerenWellnessPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(l10n.tr('mw_reset_done')),
          ),
        ],
      ),
    );
  }
}

/// *Let It Out* (`SU-04`) and *Unsent Letters* (`SU-05`) private vs ephemeral writer.
class EphemeralWritingSheet extends StatefulWidget {
  final BreakTheCycleProvider btc;
  final JournalProvider? journal;
  final EphemeralWritingMode initialMode;

  const EphemeralWritingSheet({
    super.key,
    required this.btc,
    required this.journal,
    this.initialMode = EphemeralWritingMode.letItOut,
  });

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
    JournalProvider? journal,
    EphemeralWritingMode initialMode = EphemeralWritingMode.letItOut,
  }) {
    final resolvedJournal = journal ?? _tryRead<JournalProvider>(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EphemeralWritingSheet(
        btc: btc,
        journal: resolvedJournal,
        initialMode: initialMode,
      ),
    );
  }

  @override
  State<EphemeralWritingSheet> createState() => _EphemeralWritingSheetState();
}

class _EphemeralWritingSheetState extends State<EphemeralWritingSheet> {
  late EphemeralWritingMode _mode;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  bool _dissolving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveToEcho() async {
    final l10n = context.l10n;
    final text = _bodyCtrl.text.trim();
    if (text.isEmpty) {
      _showCalmToast(context, l10n.tr('mw_ephemeral_empty_hint'));
      return;
    }
    if (widget.journal == null) return;
    await widget.btc.saveEphemeralWritingToEcho(
      journalProvider: widget.journal!,
      mode: _mode,
      title: _titleCtrl.text,
      content: text,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    _showCalmToast(context, l10n.tr('mw_ephemeral_saved_echo_toast'));
  }

  Future<void> _letItGo() async {
    final l10n = context.l10n;
    if (_bodyCtrl.text.trim().isEmpty && _titleCtrl.text.trim().isEmpty) {
      _showCalmToast(context, l10n.tr('mw_ephemeral_empty_hint'));
      return;
    }
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    setState(() => _dissolving = true);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    widget.btc.letItGoWithoutSaving();
    _titleCtrl.clear();
    _bodyCtrl.clear();
    if (!mounted) return;
    Navigator.of(context).pop();
    _showCalmToast(context, l10n.tr('mw_ephemeral_released_toast'));
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
        child: AnimatedOpacity(
          opacity: _dissolving ? 0.15 : 1.0,
          duration: const Duration(milliseconds: 240),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _serenSprite(
                    assetPath:
                        'assets/mascots/sprites/duos/duo_seren_echo_unsent_letter.png',
                    fallbackIcon: Icons.edit_note_rounded,
                    size: 52,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr(_mode.titleKey),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          l10n.tr(_mode.subtitleKey),
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
              Wrap(
                spacing: 8,
                children: EphemeralWritingMode.values.map((m) {
                  return ChoiceChip(
                    selected: _mode == m,
                    label: Text(l10n.tr(m.titleKey)),
                    onSelected: (_) => setState(() => _mode = m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: l10n.tr('mw_ephemeral_title_hint'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('mw_ephemeral_text_field'),
                controller: _bodyCtrl,
                maxLines: 5,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.tr(_mode.hintKey),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('mw_ephemeral_save_to_echo_btn'),
                onPressed: widget.journal == null ? null : _saveToEcho,
                style: FilledButton.styleFrom(
                  backgroundColor: kSerenWellnessPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(l10n.tr('mw_ephemeral_save_to_echo_btn')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('mw_ephemeral_let_it_go_btn'),
                onPressed: _letItGo,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(l10n.tr('mw_ephemeral_let_it_go_btn')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 5-Step Guided Urge Surfing Sheet (`BTC-03`).
class UrgeSurfingSheet extends StatefulWidget {
  final BreakTheCycleProvider btc;

  const UrgeSurfingSheet({super.key, required this.btc});

  static Future<void> show(
    BuildContext context, {
    required BreakTheCycleProvider btc,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UrgeSurfingSheet(btc: btc),
    );
  }

  @override
  State<UrgeSurfingSheet> createState() => _UrgeSurfingSheetState();
}

class _UrgeSurfingSheetState extends State<UrgeSurfingSheet> {
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _elapsedSeconds += 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatElapsed(int total) {
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
                Text(
                  l10n.tr('btc_urge_surf_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              l10n.tr('btc_urge_surf_subtitle'),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _serenSprite(
                  assetPath:
                      'assets/mascots/sprites/seren/urge_wave_breath.png',
                  fallbackIcon: Icons.waves_rounded,
                  size: 68,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('btc_urge_surf_quip'),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kSerenWellnessPurple.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l10n.tr('btc_urge_surf_elapsed', {
                            'time': _formatElapsed(_elapsedSeconds),
                          }),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.adaptive(
                              context,
                              dark: kSerenWellnessLavender,
                              light: kSerenWellnessPurple,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...UrgeSurfingStepSpec.steps.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr(s.titleKey),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.tr(s.guidanceKey),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('mw_urge_surfing_complete_btn'),
              onPressed: () async {
                await widget.btc.recordUrgeSurfingCompleted();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _showCalmToast(context, l10n.tr('btc_urge_surf_done_toast'));
              },
              style: FilledButton.styleFrom(
                backgroundColor: kSerenWellnessPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.tr('btc_urge_surf_complete_btn'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialogs for Comfort Kit notes and Break the Cycle private planning/reflections.
Future<void> showAddEncouragementNoteDialog(
  BuildContext context,
  BreakTheCycleProvider btc,
) async {
  final l10n = context.l10n;
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.sheetSurface(ctx),
      title: Text(l10n.tr('mw_note_dialog_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('mw_note_title_input'),
            controller: titleCtrl,
            decoration: InputDecoration(labelText: l10n.tr('mw_note_title_label')),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('mw_note_body_input'),
            controller: bodyCtrl,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.tr('mw_note_body_label')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.tr('btc_common_cancel')),
        ),
        FilledButton(
          key: const Key('mw_note_save_confirm_btn'),
          onPressed: () async {
            if (titleCtrl.text.trim().isEmpty &&
                bodyCtrl.text.trim().isEmpty) {
              return;
            }
            await btc.addCustomEncouragementNote(
              title: titleCtrl.text,
              subtitle: bodyCtrl.text,
            );
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Text(l10n.tr('mw_note_save_btn')),
        ),
      ],
    ),
  );
  titleCtrl.dispose();
  bodyCtrl.dispose();
}

Future<void> showCommitmentEditorDialog(
  BuildContext context,
  BreakTheCycleProvider btc, {
  PersonalCommitmentGoal? existing,
}) async {
  final l10n = context.l10n;
  final behaviorCtrl =
      TextEditingController(text: existing?.behaviorTitle ?? '');
  final whyCtrl = TextEditingController(text: existing?.myWhy ?? '');
  var intention = existing?.intention ?? ChangeIntentionType.manage;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.sheetSurface(ctx),
        title: Text(l10n.tr('btc_commitments_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('btc_commitment_behavior_input'),
                controller: behaviorCtrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('btc_behavior_label'),
                  hintText: l10n.tr('btc_behavior_hint'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.tr('btc_intention_label'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ChangeIntentionType.values.map((t) {
                  return ChoiceChip(
                    selected: intention == t,
                    label: Text(l10n.tr(t.translationKey)),
                    onSelected: (_) => setDialogState(() => intention = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('btc_commitment_why_input'),
                controller: whyCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.tr('btc_my_why_label'),
                  hintText: l10n.tr('btc_my_why_hint'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.tr('btc_common_cancel')),
          ),
          FilledButton(
            key: const Key('btc_commitment_save_btn'),
            onPressed: () async {
              final title = behaviorCtrl.text.trim();
              if (title.isEmpty) return;
              final now = DateTime.now();
              await btc.saveCommitment(
                PersonalCommitmentGoal(
                  id: existing?.id ?? const Uuid().v4(),
                  behaviorTitle: title,
                  intention: intention,
                  myWhy: whyCtrl.text.trim(),
                  isActive: existing?.isActive ?? true,
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                ),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(l10n.tr('btc_common_save')),
          ),
        ],
      ),
    ),
  );
  behaviorCtrl.dispose();
  whyCtrl.dispose();
}

Future<void> showTriggerReflectionDialog(
  BuildContext context,
  BreakTheCycleProvider btc, {
  JournalProvider? journal,
}) async {
  final l10n = context.l10n;
  final locCtrl = TextEditingController();
  final actCtrl = TextEditingController();
  final feelCtrl = TextEditingController();
  final beforeCtrl = TextEditingController();
  final needCtrl = TextEditingController();
  final nextCtrl = TextEditingController();
  var saveToEcho = journal != null;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.sheetSurface(ctx),
        title: Text(l10n.tr('btc_trigger_journal_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: locCtrl,
                decoration: InputDecoration(labelText: l10n.tr('btc_trig_location')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: actCtrl,
                decoration: InputDecoration(labelText: l10n.tr('btc_trig_activity')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: feelCtrl,
                decoration: InputDecoration(labelText: l10n.tr('btc_trig_feeling')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: beforeCtrl,
                decoration: InputDecoration(labelText: l10n.tr('btc_trig_before')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: needCtrl,
                decoration: InputDecoration(labelText: l10n.tr('btc_trig_needed')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nextCtrl,
                decoration: InputDecoration(labelText: l10n.tr('btc_trig_next_time')),
              ),
              if (journal != null)
                CheckboxListTile(
                  value: saveToEcho,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.tr('btc_save_copy_echo_toggle'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) => setDialogState(() => saveToEcho = v ?? false),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.tr('btc_common_cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await btc.addTriggerReflection(
                TriggerReflectionEntry(
                  id: const Uuid().v4(),
                  createdAt: DateTime.now(),
                  locationLabel: locCtrl.text.trim(),
                  currentActivity: actCtrl.text.trim(),
                  emotionalState: feelCtrl.text.trim(),
                  whatHappenedBefore: beforeCtrl.text.trim(),
                  whatINeeded: needCtrl.text.trim(),
                  tryDifferentlyNextTime: nextCtrl.text.trim(),
                ),
                journalProvider: journal,
                saveToEcho: saveToEcho,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(l10n.tr('btc_common_save')),
          ),
        ],
      ),
    ),
  );
  locCtrl.dispose();
  actCtrl.dispose();
  feelCtrl.dispose();
  beforeCtrl.dispose();
  needCtrl.dispose();
  nextCtrl.dispose();
}

Future<void> showRecoveryReflectionDialog(
  BuildContext context,
  BreakTheCycleProvider btc, {
  JournalProvider? journal,
}) async {
  final l10n = context.l10n;
  final whatCtrl = TextEditingController();
  final needCtrl = TextEditingController();
  final compCtrl = TextEditingController();
  final nextCtrl = TextEditingController();
  var saveToEcho = journal != null;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.sheetSurface(ctx),
        title: Text(l10n.tr('btc_recovery_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _serenSprite(
                assetPath:
                    'assets/mascots/sprites/seren/compassionate_tea_reset.png',
                fallbackIcon: Icons.local_cafe_rounded,
                size: 68,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tr('btc_recovery_quip'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('btc_recovery_what_input'),
                controller: whatCtrl,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.tr('btc_rec_what_happened')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: needCtrl,
                decoration: InputDecoration(labelText: l10n.tr('btc_rec_need_or_feeling')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: compCtrl,
                decoration: InputDecoration(labelText: l10n.tr('btc_rec_compassion_note')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nextCtrl,
                decoration: InputDecoration(labelText: l10n.tr('btc_rec_next_adjustment')),
              ),
              if (journal != null)
                CheckboxListTile(
                  value: saveToEcho,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.tr('btc_save_copy_echo_toggle'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) => setDialogState(() => saveToEcho = v ?? false),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.tr('btc_common_cancel')),
          ),
          FilledButton(
            key: const Key('btc_recovery_save_btn'),
            onPressed: () async {
              await btc.addRecoveryReflection(
                RecoveryReflectionEntry(
                  id: const Uuid().v4(),
                  createdAt: DateTime.now(),
                  whatHappened: whatCtrl.text.trim(),
                  underlyingNeedOrFeeling: needCtrl.text.trim(),
                  selfCompassionNote: compCtrl.text.trim(),
                  nextSmallAdjustment: nextCtrl.text.trim(),
                ),
                journalProvider: journal,
                saveToEcho: saveToEcho,
              );
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              _showCalmToast(context, l10n.tr('btc_recovery_saved_toast'));
            },
            child: Text(l10n.tr('btc_common_save')),
          ),
        ],
      ),
    ),
  );
  whatCtrl.dispose();
  needCtrl.dispose();
  compCtrl.dispose();
  nextCtrl.dispose();
}

Future<void> showAddBoundaryDialog(
  BuildContext context,
  BreakTheCycleProvider btc,
) async {
  final l10n = context.l10n;
  final titleCtrl = TextEditingController();
  var linksToTwill = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppColors.sheetSurface(ctx),
        title: Text(l10n.tr('btc_boundaries_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: l10n.tr('btc_boundary_label')),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: linksToTwill,
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.tr('btc_boundary_twill_toggle'),
                style: const TextStyle(fontSize: 12),
              ),
              onChanged: (v) => setDialogState(() => linksToTwill = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.tr('btc_common_cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final text = titleCtrl.text.trim();
              if (text.isEmpty) return;
              await btc.addPersonalBoundary(
                PersonalBoundaryItem(
                  id: const Uuid().v4(),
                  title: text,
                  categoryKey: linksToTwill
                      ? 'btc_boundary_cat_spending'
                      : 'btc_boundary_cat_daily',
                  isActive: true,
                  linksToTwillBudget: linksToTwill,
                ),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(l10n.tr('btc_common_save')),
          ),
        ],
      ),
    ),
  );
  titleCtrl.dispose();
}

Future<void> showRelapsePreventionPlanDialog(
  BuildContext context,
  BreakTheCycleProvider btc,
) async {
  final l10n = context.l10n;
  final existing = btc.relapsePreventionPlan;
  final trigCtrl = TextEditingController(text: existing.knownTriggers);
  final sitCtrl = TextEditingController(text: existing.vulnerableSituations);
  final altCtrl = TextEditingController(text: existing.goToAlternatives);
  final boundCtrl =
      TextEditingController(text: existing.personalBoundariesSummary);
  final trustCtrl = TextEditingController(text: existing.trustedPersonNote);
  final postCtrl =
      TextEditingController(text: existing.compassionatePostSetbackNote);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.sheetSurface(ctx),
      title: Text(l10n.tr('btc_plan_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: trigCtrl,
              decoration: InputDecoration(labelText: l10n.tr('btc_plan_triggers')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sitCtrl,
              decoration: InputDecoration(labelText: l10n.tr('btc_plan_situations')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: altCtrl,
              decoration: InputDecoration(labelText: l10n.tr('btc_plan_alternatives')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: boundCtrl,
              decoration: InputDecoration(labelText: l10n.tr('btc_plan_boundaries')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: trustCtrl,
              decoration: InputDecoration(labelText: l10n.tr('btc_plan_trusted')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: postCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.tr('btc_plan_post_setback')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.tr('btc_common_cancel')),
        ),
        FilledButton(
          onPressed: () async {
            await btc.saveRelapsePreventionPlan(
              RelapsePreventionPlan(
                knownTriggers: trigCtrl.text.trim(),
                vulnerableSituations: sitCtrl.text.trim(),
                goToAlternatives: altCtrl.text.trim(),
                personalBoundariesSummary: boundCtrl.text.trim(),
                trustedPersonNote: trustCtrl.text.trim(),
                compassionatePostSetbackNote: postCtrl.text.trim(),
              ),
            );
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Text(l10n.tr('btc_common_save')),
        ),
      ],
    ),
  );

  trigCtrl.dispose();
  sitCtrl.dispose();
  altCtrl.dispose();
  boundCtrl.dispose();
  trustCtrl.dispose();
  postCtrl.dispose();
}
