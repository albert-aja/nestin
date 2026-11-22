import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_restriction.dart';
import '../../../providers/device_control_provider.dart';
import 'wellbeing_app_picker_sheet.dart';
import 'wellbeing_intervention_dialog.dart';

/// Roo Digital Discipline -> App Fast tab for long-term intentional app avoidance.
class WellbeingAppFastTab extends StatelessWidget {
  const WellbeingAppFastTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<DeviceControlProvider>();
    final now = DateTime.now();

    final active = provider.appFastByStatus(AppFastStatus.active, now: now);
    final scheduled = provider.appFastByStatus(
      AppFastStatus.scheduled,
      now: now,
    );
    final history = [
      ...provider.appFastByStatus(AppFastStatus.completed, now: now),
      ...provider.appFastByStatus(AppFastStatus.cancelled, now: now),
      ...provider.appFastByStatus(AppFastStatus.failed, now: now),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.tr('app_fast_commitments'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('create_app_fast_btn'),
                    onPressed: () => _showCommitmentEditor(context, provider),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(l10n.tr('new_fast')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tr('step_away_from_selected_apps_for'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (active.isEmpty && scheduled.isEmpty && history.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.spa_outlined,
                    size: 36,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tr('no_app_fast_commitments_yet'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tr('tap_new_fast_to_avoid_distracting'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (active.isNotEmpty) ...[
          _sectionHeader(
            context,
            l10n.tr('active_3', {'active_length': active.length}),
          ),
          ...active.map(
            (c) => _buildCommitmentCard(
              context,
              provider,
              c,
              AppFastStatus.active,
              now,
            ),
          ),
        ],
        if (scheduled.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionHeader(
            context,
            l10n.tr('scheduled', {'scheduled_length': scheduled.length}),
          ),
          ...scheduled.map(
            (c) => _buildCommitmentCard(
              context,
              provider,
              c,
              AppFastStatus.scheduled,
              now,
            ),
          ),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionHeader(
            context,
            l10n.tr('completed_cancelled', {'history_length': history.length}),
          ),
          ...history.map(
            (c) => _buildCommitmentCard(
              context,
              provider,
              c,
              c.resolvedStatusAt(now),
              now,
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary(context),
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _buildCommitmentCard(
    BuildContext context,
    DeviceControlProvider provider,
    AppFastCommitment c,
    AppFastStatus status,
    DateTime now,
  ) {
    final l10n = context.l10n;
    final isStrict = c.mode == RestrictionEnforcementMode.strict;
    final accent = switch (status) {
      AppFastStatus.active => isStrict ? AppColors.primary : AppColors.accent,
      AppFastStatus.scheduled => AppColors.info,
      AppFastStatus.completed => AppColors.success,
      AppFastStatus.cancelled => AppColors.textMuted(context),
      AppFastStatus.failed => AppColors.error,
    };
    final remaining = c.remainingDurationAt(now);
    final remLabel = remaining.inDays > 0
        ? '${remaining.inDays}d ${remaining.inHours % 24}h left'
        : '${remaining.inHours}h ${remaining.inMinutes % 60}m left';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == AppFastStatus.active
                        ? c.mode.label
                        : status == AppFastStatus.failed
                            ? l10n.tr('status_failed').toUpperCase()
                            : status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${DateFormat.yMMMd().format(c.startAt)} → ${DateFormat.yMMMd().format(c.endAt)}'
              '${status == AppFastStatus.active ? ' · $remLabel' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            if (status == AppFastStatus.failed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.error.withValues(alpha: 0.28)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatFailureReason(l10n, c.failureReason),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == AppFastStatus.active) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: c.progressRatioAt(now),
                  minHeight: 6,
                  color: accent,
                  backgroundColor: AppColors.trackSurface(context),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: c.targetPackages.map((pkg) {
                final installed = provider.isPackageInstalled(pkg);
                final name = c.displayNameForPackage(pkg);
                return Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    installed ? name : '$name (not installed)',
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              }).toList(),
            ),
            if (c.motivation != null && c.motivation!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '“${c.motivation!}”',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (status == AppFastStatus.active &&
                    c.targetPackages.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: Text(
                      l10n.tr('test_intervention'),
                    ),
                    onPressed: () async {
                      final decision =
                          await provider.evaluateAndRecordLaunchAttempt(
                        c.targetPackages.first,
                        appName: c.displayNameForPackage(
                          c.targetPackages.first,
                        ),
                      );
                      if (!context.mounted) return;
                      await WellbeingInterventionDialog.show(
                        context,
                        provider,
                        decision,
                      );
                    },
                  ),
                if (status == AppFastStatus.active ||
                    status == AppFastStatus.scheduled) ...[
                  TextButton(
                    onPressed: () =>
                        _showCommitmentEditor(context, provider, existing: c),
                    child: Text(l10n.tr('edit')),
                  ),
                  TextButton(
                    onPressed: () => provider.cancelAppFastCommitment(c.id),
                    child: Text(
                      l10n.tr('end_fast'),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ] else
                  TextButton(
                    onPressed: () => provider.deleteAppFastCommitment(c.id),
                    child: Text(l10n.tr('remove_record')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFailureReason(AppLocalizations l10n, String? reason) {
    switch (reason) {
      case 'lock_bypassed_continue_anyway':
        return l10n.tr('app_fast_failed_bypassed_continue');
      case 'lock_bypassed_shield_grace':
        return l10n.tr('app_fast_failed_shield_grace');
      case 'usage_detected_during_fast':
        return l10n.tr('app_fast_failed_usage_detected');
      default:
        return l10n.tr('app_fast_failed_default');
    }
  }

  Future<void> _showCommitmentEditor(
    BuildContext context,
    DeviceControlProvider provider, {
    AppFastCommitment? existing,
  }) async {
    final l10n = context.l10n;
    final titleCtrl = TextEditingController(
      text: existing?.title ?? 'Social Media Detox',
    );
    final motivationCtrl = TextEditingController(
      text: existing?.motivation ?? '',
    );
    final messageCtrl = TextEditingController(
      text: existing?.interventionMessage ?? '',
    );

    var selectedApps = <String, String>{
      if (existing != null)
        for (final pkg in existing.targetPackages)
          pkg: existing.displayNameForPackage(pkg)
      else
        'com.instagram.android': 'Instagram',
    };
    var startAt = existing?.startAt ?? DateTime.now();
    var endAt =
        existing?.endAt ?? DateTime.now().add(const Duration(days: 30));
    var mode = existing?.mode ?? RestrictionEnforcementMode.reminder;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final strictSupport = provider.supportLevelForStrength(
            RestrictionStrength.strict,
          );
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        existing == null
                            ? l10n.tr('new_app_fast_commitment')
                            : l10n.tr('edit_commitment'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.tr('commitment_name'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.tr('apps_to_avoid'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ...selectedApps.entries.map(
                        (e) => InputChip(
                          label: Text(e.value),
                          onDeleted: () {
                            setModalState(() {
                              selectedApps.remove(e.key);
                            });
                          },
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: Text(l10n.tr('add_app')),
                        onPressed: () async {
                          final picked =
                              await WellbeingAppPickerSheet.pickApps(
                            context,
                            initialSelected: selectedApps.keys.toSet(),
                            initialNames: selectedApps,
                            title: l10n.tr('apps_for_app_fast'),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedApps = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.tr('commitment_duration'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [7, 14, 30, 90].map((days) {
                      return ChoiceChip(
                        label: Text('$days ${l10n.tr('days_d')}'),
                        selected: endAt.difference(startAt).inDays == days,
                        onSelected: (_) {
                          setModalState(() {
                            endAt = startAt.add(Duration(days: days));
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded,
                              size: 16),
                          label: Text(
                            'Start: ${DateFormat.yMMMd().format(startAt)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: startAt,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 1)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) {
                              setModalState(() {
                                startAt = DateTime(
                                  d.year,
                                  d.month,
                                  d.day,
                                  startAt.hour,
                                  startAt.minute,
                                );
                                if (!endAt.isAfter(startAt)) {
                                  endAt = startAt.add(const Duration(days: 7));
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon:
                              const Icon(Icons.event_busy_rounded, size: 16),
                          label: Text(
                            'End: ${DateFormat.yMMMd().format(endAt)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: endAt,
                              firstDate:
                                  startAt.add(const Duration(days: 1)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 730)),
                            );
                            if (d != null) {
                              setModalState(() {
                                endAt = DateTime(
                                  d.year,
                                  d.month,
                                  d.day,
                                  23,
                                  59,
                                  59,
                                );
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.tr('intervention_mode'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<RestrictionEnforcementMode>(
                    segments: [
                      ButtonSegment(
                        value: RestrictionEnforcementMode.reminder,
                        label: Text(l10n.tr('reminder')),
                        icon: const Icon(Icons.notifications_active_outlined),
                      ),
                      ButtonSegment(
                        value: RestrictionEnforcementMode.strict,
                        label: Text(l10n.tr('strict')),
                        icon: const Icon(Icons.shield_rounded),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) {
                      setModalState(() => mode = s.first);
                    },
                  ),
                  if (mode == RestrictionEnforcementMode.strict &&
                      strictSupport != PlatformSupportLevel.supported) ...[
                    const SizedBox(height: 6),
                    Text(
                      strictSupport ==
                              PlatformSupportLevel.supportedWithPermission
                          ? l10n.tr('strict_mode_requires_app_shield')
                          : l10n.tr('strict_mode_simulated_reminder'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: motivationCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.tr('personal_motivation_optional'),
                      hintText: l10n.tr('i_want_to_reclaim_my_evenings'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: messageCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.tr('custom_intervention_screen_message'),
                      hintText: l10n.tr('is_this_aligned_with_your_goals'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: selectedApps.isEmpty
                        ? null
                        : () async {
                            final title = titleCtrl.text.trim().isEmpty
                                ? 'App Fast'
                                : titleCtrl.text.trim();
                            final item = AppFastCommitment(
                              id: existing?.id,
                              title: title,
                              targetPackages: selectedApps.keys.toList(),
                              targetAppNames: selectedApps,
                              startAt: startAt,
                              endAt: endAt,
                              mode: mode,
                              motivation: motivationCtrl.text.trim().isEmpty
                                  ? null
                                  : motivationCtrl.text.trim(),
                              interventionMessage:
                                  messageCtrl.text.trim().isEmpty
                                      ? null
                                      : messageCtrl.text.trim(),
                            );
                            if (existing == null) {
                              await provider.createAppFastCommitment(item);
                            } else {
                              await provider.updateAppFastCommitment(item);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: Text(
                      l10n.tr('save_commitment'),
                    ),
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
