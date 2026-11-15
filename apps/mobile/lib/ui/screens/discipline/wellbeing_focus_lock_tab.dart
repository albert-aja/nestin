import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_restriction.dart';
import '../../../providers/device_control_provider.dart';
import '../../../providers/timer_provider.dart';
import 'wellbeing_app_picker_sheet.dart';
import 'wellbeing_intervention_dialog.dart';

/// Roo Digital Discipline -> Focus Lock tab owning distraction locks for both
/// Roo's Pomodoro timer and standalone focus sessions.
class WellbeingFocusLockTab extends StatelessWidget {
  const WellbeingFocusLockTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<DeviceControlProvider>();
    TimerProvider? timerProvider;
    try {
      timerProvider = Provider.of<TimerProvider>(context);
    } catch (_) {
      timerProvider = null;
    }

    final session = provider.activeFocusSession;
    final config = provider.focusLockConfig;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (session != null) _buildActiveSessionCard(context, provider, session, now),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: config.enabled
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.tr('focus_lock_roo_pomodoro_sync'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.tr('roo_evaluates_and_enforces_focus_lock'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
              if (timerProvider != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Roo Pomodoro: ${timerProvider.pomodoroTaskLabel} (${timerProvider.formattedPomodoroRemaining()} · ${timerProvider.isPomodoroRunning ? 'Running' : 'Idle'})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          if (!timerProvider!.isPomodoroRunning) {
                            timerProvider.startPomodoro();
                          } else {
                            timerProvider.resetPomodoro();
                          }
                        },
                        child: Text(
                          timerProvider.isPomodoroRunning
                              ? l10n.tr('stop')
                              : l10n.tr('start_focus'),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (session == null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => provider.activateFocusLockSession(
                    source: 'roo_manual',
                    taskLabel: 'Deep Focus Session',
                    duration: const Duration(minutes: 25),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    l10n.tr('start_25m_focus_lock'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: config.enabled,
                title: Text(
                  l10n.tr('auto_activate_on_roo_pomodoro'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  l10n.tr('automatically_locks_distracting_apps_during_work'),
                  style: const TextStyle(fontSize: 12),
                ),
                onChanged: (v) => provider.updateFocusLockConfig(
                  config.copyWith(enabled: v),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: config.restrictDuringBreaks,
                title: Text(
                  l10n.tr('keep_restrictions_during_breaks'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  l10n.tr('when_off_focus_lock_relaxes_during'),
                  style: const TextStyle(fontSize: 12),
                ),
                onChanged: (v) => provider.updateFocusLockConfig(
                  config.copyWith(restrictDuringBreaks: v),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: config.allowManualEnd,
                title: Text(
                  l10n.tr('allow_manual_early_end'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  l10n.tr('emergency_calls_and_essential_os_apps'),
                  style: const TextStyle(fontSize: 12),
                ),
                onChanged: (v) => provider.updateFocusLockConfig(
                  config.copyWith(allowManualEnd: v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('enforcement_level'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<RestrictionEnforcementMode>(
                  segments: const [
                    ButtonSegment(
                      value: RestrictionEnforcementMode.reminder,
                      label: Text('Reminder Mode'),
                    ),
                    ButtonSegment(
                      value: RestrictionEnforcementMode.strict,
                      label: Text('Strict Mode'),
                    ),
                  ],
                  selected: {config.enforcementMode},
                  onSelectionChanged: (sel) => provider.updateFocusLockConfig(
                    config.copyWith(enforcementMode: sel.first),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.tr('distracting_apps', {'config_length': config.restrictedPackages.length}),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    config.restrictedPackages
                        .map((p) => config.restrictedAppNames[p] ?? p)
                        .join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      final picked = await WellbeingAppPickerSheet.pickApps(
                        context,
                        initialSelected: config.restrictedPackages.toSet(),
                        initialNames: config.restrictedAppNames,
                        title: l10n.tr('apps_to_restrict_in_focus_lock'),
                      );
                      if (picked != null) {
                        await provider.updateFocusLockConfig(
                          config.copyWith(
                            restrictedPackages: picked.keys.toList(),
                            restrictedAppNames: picked,
                          ),
                        );
                      }
                    },
                    child: Text(l10n.tr('edit')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.tr('allowed_focus_exceptions', {'config_length': config.allowedPackages.length}),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    config.allowedPackages.isEmpty
                        ? l10n.tr('none_added_emergency_system_dialers_always')
                        : config.allowedPackages
                            .map(provider.displayNameForPackage)
                            .join(', '),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final picked = await WellbeingAppPickerSheet.pickApps(
                        context,
                        initialSelected: config.allowedPackages.toSet(),
                        title: l10n.tr('allow_during_focus_lock'),
                      );
                      if (picked != null) {
                        await provider.updateFocusLockConfig(
                          config.copyWith(
                            allowedPackages: picked.keys.toList(),
                          ),
                        );
                      }
                    },
                    child: Text(l10n.tr('pick')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionCard(
    BuildContext context,
    DeviceControlProvider provider,
    FocusLockSession session,
    DateTime now,
  ) {
    final l10n = context.l10n;
    final restrictingNow = session.isRestrictingPhaseNow(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${session.taskLabel} · ${session.phase.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                'Ends ${DateFormat.Hm().format(session.expectedEndAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            restrictingNow
                ? l10n.tr('active_apps_guarded', {'session_label': session.enforcementMode.label, 'session_length': session.restrictedPackages.length})
                : l10n.tr('break_relaxation_active_temporary_focus_lock', {'session_phase': session.phase}),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              if (session.restrictedPackages.isNotEmpty)
                OutlinedButton(
                  onPressed: () async {
                    final pkg = session.restrictedPackages.first;
                    final decision =
                        await provider.evaluateAndRecordLaunchAttempt(pkg);
                    if (!context.mounted) return;
                    await WellbeingInterventionDialog.show(
                      context,
                      provider,
                      decision,
                    );
                  },
                  child: Text(l10n.tr('inspect_test')),
                ),
              if (session.allowManualEnd)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () =>
                      provider.endFocusLockSession(reason: 'manual_end'),
                  child: Text(l10n.tr('end_focus_lock')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
