import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/automation_rule.dart';
import '../../../providers/automation_provider.dart';
import '../../../providers/device_control_provider.dart';

class AutomationHubScreen extends StatelessWidget {
  const AutomationHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final automation = context.watch<AutomationProvider>();
    final deviceControl = context.watch<DeviceControlProvider>();
    final pending = automation.pendingConfirmations;
    final ownership = automation.activeOwnership;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pick('Nestin Automation Engine', 'Mesin Otomasi Nestin'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.pick('New Automation', 'Otomasi Baru'),
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () =>
                _showComposeAutomationSheet(context, automation, deviceControl),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showComposeAutomationSheet(context, automation, deviceControl),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.pick('New Rule', 'Aturan Baru')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pending.isNotEmpty) ...[
            Text(
              l10n.pick('Pending Confirmations', 'Menunggu Konfirmasi'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 8),
            ...pending.map(
              (p) => Card(
                color: AppColors.warning.withValues(alpha: 0.10),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.rule.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.triggerReason,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                automation.dismissPendingExecution(p.id),
                            child: Text(l10n.pick('Skip', 'Lewati')),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () =>
                                automation.confirmPendingExecution(p.id),
                            child: Text(l10n.pick('Confirm & Run', 'Jalankan')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (ownership.isNotEmpty) ...[
            Text(
              l10n.pick('Shared Setting Ownership Locks',
                  'Kunci Kepemilikan Pengaturan Bersama'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: ownership.entries.map((entry) {
                    final lock = entry.value;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.info, size: 18),
                      title: Text(
                        '${lock.settingKey} <- ${lock.ownerName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      subtitle: Text('Priority ${lock.priority}'),
                      trailing: TextButton(
                        onPressed: () =>
                            automation.releaseOwnershipLock(entry.key),
                        child: Text(l10n.pick('Release', 'Lepas')),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          Text(
            l10n.pick('Automation Rules (${automation.rules.length})',
                'Aturan Otomasi (${automation.rules.length})'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),

          ...automation.rules.map(
            (rule) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${rule.familyOwner.toUpperCase()} · P${rule.priority}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rule.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Switch(
                          value: rule.isEnabled,
                          activeThumbColor: AppColors.accent,
                          onChanged: (val) =>
                              automation.toggleRule(rule.id, val),
                        ),
                      ],
                    ),
                    if (rule.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        rule.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _pill(context, rule.triggerType.label),
                        ...rule.conditions.map((c) => _pill(context, c.summary)),
                        ...rule.actions.map((a) => _pill(context, a.type.label)),
                        if (rule.requiresConfirmation)
                          _pill(context, 'Confirm First'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 17),
                          label: Text(l10n.pick('Run Now', 'Jalankan')),
                          onPressed: () async {
                            final log =
                                await automation.runRuleManually(rule.id);
                            if (!context.mounted || log == null) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(log.summary)),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: l10n.pick('Delete rule', 'Hapus'),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppColors.error),
                          onPressed: () => automation.deleteRule(rule.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            l10n.pick('Execution & Rollback History', 'Riwayat Eksekusi'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),

          if (automation.logs.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.pick('No automation executions logged yet.',
                      'Belum ada riwayat eksekusi otomasi.'),
                  style: TextStyle(color: AppColors.textSecondary(context)),
                ),
              ),
            )
          else
            ...automation.logs.take(30).map((log) {
              final color = _statusColor(log.status);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log.ruleName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              log.status.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${log.triggerReason} • ${DateFormat.yMMMd().add_Hm().format(log.timestamp)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.summary,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      if (log.canRollback && !log.rolledBack)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.undo_rounded, size: 16),
                            label: Text(l10n.pick('Rollback Mode', 'Batalkan')),
                            onPressed: () =>
                                automation.rollbackExecution(log.id),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.subtleFill(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary(context),
        ),
      ),
    );
  }

  Color _statusColor(AutomationExecutionStatus status) {
    switch (status) {
      case AutomationExecutionStatus.succeeded:
        return AppColors.success;
      case AutomationExecutionStatus.partiallySucceeded:
      case AutomationExecutionStatus.pendingConfirmation:
        return AppColors.warning;
      case AutomationExecutionStatus.blockedByConflict:
      case AutomationExecutionStatus.blockedByPermission:
      case AutomationExecutionStatus.failed:
        return AppColors.error;
      case AutomationExecutionStatus.skippedCondition:
      case AutomationExecutionStatus.unsupported:
      case AutomationExecutionStatus.rolledBack:
        return AppColors.info;
    }
  }

  void _showComposeAutomationSheet(
    BuildContext context,
    AutomationProvider automation,
    DeviceControlProvider deviceControl,
  ) {
    final nameCtrl = TextEditingController();
    final placeOrTimeCtrl = TextEditingController(text: '22:00');
    final taskOrNotifCtrl = TextEditingController();
    var familyOwner = 'scout';
    var trigger = AutomationTriggerType.timeSchedule;
    var condition = AutomationConditionType.always;
    var actionType = AutomationActionType.activatePhoneMode;
    var selectedModeId = deviceControl.phoneModes.isNotEmpty
        ? deviceControl.phoneModes.first.id
        : 'mode_work';
    var priority = 60.0;
    var requiresConfirmation = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Nestin Automation Rule',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Rule Name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: familyOwner,
                  decoration: const InputDecoration(labelText: 'Bird Family'),
                  items: const [
                    DropdownMenuItem(value: 'roo', child: Text('Roo (Time)')),
                    DropdownMenuItem(value: 'echo', child: Text('Echo (Journal)')),
                    DropdownMenuItem(value: 'seren', child: Text('Seren (Wellness)')),
                    DropdownMenuItem(value: 'pippin', child: Text('Pippin (Hobbies)')),
                    DropdownMenuItem(value: 'twill', child: Text('Twill (Organize)')),
                    DropdownMenuItem(value: 'scout', child: Text('Scout (Smart Context)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setSheetState(() => familyOwner = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AutomationTriggerType>(
                  initialValue: trigger,
                  decoration: const InputDecoration(labelText: 'Trigger'),
                  items: AutomationTriggerType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setSheetState(() => trigger = v);
                  },
                ),
                if (trigger == AutomationTriggerType.timeSchedule ||
                    trigger == AutomationTriggerType.geofenceEnter ||
                    trigger == AutomationTriggerType.geofenceExit) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: placeOrTimeCtrl,
                    decoration: InputDecoration(
                      labelText: trigger == AutomationTriggerType.timeSchedule
                          ? 'Schedule Time (HH:mm)'
                          : 'Saved Place Name (e.g. Home / Work)',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<AutomationConditionType>(
                  initialValue: condition,
                  decoration: const InputDecoration(labelText: 'Condition'),
                  items: const [
                    DropdownMenuItem(
                        value: AutomationConditionType.always,
                        child: Text('Always')),
                    DropdownMenuItem(
                        value: AutomationConditionType.weekdayOnly,
                        child: Text('Weekdays only')),
                    DropdownMenuItem(
                        value: AutomationConditionType.weekendOnly,
                        child: Text('Weekends only')),
                  ],
                  onChanged: (v) {
                    if (v != null) setSheetState(() => condition = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AutomationActionType>(
                  initialValue: actionType,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: AutomationActionType.values
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setSheetState(() => actionType = v);
                  },
                ),
                if (actionType == AutomationActionType.activatePhoneMode &&
                    deviceControl.phoneModes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedModeId,
                    decoration: const InputDecoration(labelText: 'Phone Mode'),
                    items: deviceControl.phoneModes
                        .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => selectedModeId = v);
                    },
                  ),
                ] else if (actionType == AutomationActionType.createTask ||
                    actionType == AutomationActionType.createReminder ||
                    actionType == AutomationActionType.sendNotification) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: taskOrNotifCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notification / Task Title',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text('Priority: ${priority.round()} (Higher overrides conflicts)'),
                Slider(
                  value: priority,
                  min: 10,
                  max: 100,
                  divisions: 9,
                  onChanged: (v) => setSheetState(() => priority = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require confirmation before sensitive changes'),
                  value: requiresConfirmation,
                  onChanged: (v) =>
                      setSheetState(() => requiresConfirmation = v),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;

                      final triggerCfg = <String, dynamic>{};
                      if (trigger == AutomationTriggerType.timeSchedule) {
                        triggerCfg['time'] = placeOrTimeCtrl.text.trim();
                      } else if (trigger == AutomationTriggerType.geofenceEnter ||
                          trigger == AutomationTriggerType.geofenceExit) {
                        triggerCfg['placeName'] = placeOrTimeCtrl.text.trim();
                      }

                      final actionParams = <String, dynamic>{};
                      if (actionType == AutomationActionType.activatePhoneMode) {
                        actionParams['modeId'] = selectedModeId;
                      } else if (taskOrNotifCtrl.text.trim().isNotEmpty) {
                        actionParams['title'] = taskOrNotifCtrl.text.trim();
                      }

                      final rule = AutomationRule(
                        name: name,
                        familyOwner: familyOwner,
                        priority: priority.round(),
                        requiresConfirmation: requiresConfirmation,
                        triggerType: trigger,
                        triggerConfig: triggerCfg,
                        conditions: [AutomationCondition(type: condition)],
                        actions: [
                          AutomationAction(
                            type: actionType,
                            params: actionParams,
                          ),
                        ],
                      );
                      await automation.addOrUpdateRule(rule);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save Automation'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
