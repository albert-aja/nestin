import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/break_the_cycle_provider.dart';

/// Calm, non-judgmental 3–5 second intention check (`BTC-02`) for ambiguous apps.
///
/// Displays the user's own written *"Why"* without URL/content inspection,
/// failure logging, or punitive streak resets.
class MindfulAppPauseDialog extends StatefulWidget {
  final String packageName;
  final String appDisplayName;
  final VoidCallback? onStepBackToUrgeSupport;

  const MindfulAppPauseDialog({
    super.key,
    required this.packageName,
    required this.appDisplayName,
    this.onStepBackToUrgeSupport,
  });

  static Future<String?> show(
    BuildContext context, {
    required String packageName,
    String? appDisplayName,
    VoidCallback? onStepBackToUrgeSupport,
  }) {
    final resolvedName = appDisplayName ??
        _resolveAppDisplayName(context, packageName);
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => MindfulAppPauseDialog(
        packageName: packageName,
        appDisplayName: resolvedName,
        onStepBackToUrgeSupport: onStepBackToUrgeSupport,
      ),
    );
  }

  static String _resolveAppDisplayName(BuildContext context, String pkg) {
    try {
      final btc = Provider.of<BreakTheCycleProvider>(context, listen: false);
      final name = btc.mindfulAppPauseConfig.monitoredAppNames[pkg];
      if (name != null && name.trim().isNotEmpty) return name;
    } catch (_) {}
    return pkg;
  }

  @override
  State<MindfulAppPauseDialog> createState() => _MindfulAppPauseDialogState();
}

class _MindfulAppPauseDialogState extends State<MindfulAppPauseDialog> {
  static const Color _serenPurple = AppColors.seren;
  late int _secondsLeft;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    var initialSeconds = 4;
    try {
      initialSeconds = Provider.of<BreakTheCycleProvider>(
        context,
        listen: false,
      ).mindfulAppPauseConfig.pauseDurationSeconds;
    } catch (_) {}
    _secondsLeft = initialSeconds.clamp(3, 5);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  BreakTheCycleProvider? _tryBtc(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<BreakTheCycleProvider>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final btc = _tryBtc(context, listen: true);
    final strictBlockMode =
        btc?.mindfulAppPauseConfig.strictBlockMode ?? false;
    final activeWhys = btc?.activeCommitments
            .map((c) => c.myWhy.trim())
            .where((w) => w.isNotEmpty)
            .toList() ??
        const <String>[];
    final displayedWhy = activeWhys.isNotEmpty
        ? activeWhys.first
        : l10n.tr('btc_mindful_pause_default_why');

    return AlertDialog(
      backgroundColor: AppColors.sheetSurface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _serenPurple.withValues(alpha: 0.14),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  strictBlockMode
                      ? 'assets/mascots/sprites/seren/strict_sanctuary_gate.png'
                      : 'assets/mascots/sprites/seren/mindful_doorway_hourglass.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.nights_stay_rounded,
                    size: 48,
                    color: _serenPurple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.tr('btc_mindful_pause_dialog_title')} • ${widget.appDisplayName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tr('btc_mindful_pause_dialog_quip'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _serenPurple.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('btc_mindful_pause_why_prefix'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.adaptive(
                        context,
                        dark: AppColors.serenLight,
                        light: _serenPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayedWhy,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (strictBlockMode) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _serenPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.tr('btc_mindful_pause_strict_blocked_note'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              OutlinedButton(
                key: const Key('btc_mindful_pause_continue_btn'),
                onPressed: _secondsLeft > 0
                    ? null
                    : () {
                        btc?.grantMindfulPauseClearPurposeContinue(
                          widget.packageName,
                        );
                        Navigator.of(context).pop('continue');
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _secondsLeft > 0
                      ? '${l10n.tr('btc_mindful_pause_continue_btn')} ($_secondsLeft)'
                      : l10n.tr('btc_mindful_pause_continue_btn'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              key: const Key('btc_mindful_pause_step_back_btn'),
              onPressed: () async {
                await btc?.recordMindfulPauseStepBack(widget.packageName);
                if (!context.mounted) return;
                Navigator.of(context).pop('step_back');
                widget.onStepBackToUrgeSupport?.call();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _serenPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.spa_rounded, size: 18),
              label: Text(
                l10n.tr('btc_mindful_pause_step_back_btn'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            if (strictBlockMode)
              TextButton(
                key: const Key('btc_mindful_pause_close_btn'),
                onPressed: () => Navigator.of(context).pop('close'),
                child: Text(
                  l10n.tr('btc_mindful_pause_close_btn'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              )
            else
              TextButton(
                key: const Key('btc_mindful_pause_snooze_btn'),
                onPressed: () async {
                  await btc?.snoozeMindfulAppPause(const Duration(hours: 1));
                  if (!context.mounted) return;
                  Navigator.of(context).pop('snooze_1h');
                },
                child: Text(
                  l10n.tr('btc_mindful_pause_snooze_btn'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              l10n.tr('btc_mindful_pause_zero_inspection_note'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
