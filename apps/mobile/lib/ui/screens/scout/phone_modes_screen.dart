import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/device_capability.dart';
import '../../../data/models/phone_mode.dart';
import '../../../providers/device_control_provider.dart';
import '../settings/permission_center_screen.dart';

/// Scout Everyday Assistance -> Phone Modes & Device Controls.
///
/// Manages practical phone settings, Sleep/Work/Study/Relax/Custom Phone Modes,
/// Do Not Disturb / brightness / screen timeout orchestration, OS Focus/Modes
/// links, and non-destructive state restoration snapshots.
class PhoneModesScreen extends StatelessWidget {
  const PhoneModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<DeviceControlProvider>();
    final activeMode = provider.activePhoneMode;
    final snapshot = provider.activeSnapshot;
    final lastSummary = provider.lastRestorationSummary;
    final modes = provider.phoneModes;
    final registry = provider.registry;
    final dndSupport =
        registry.supportFor(DeviceCapabilityRegistry.actionDndToggle);
    final brightSupport =
        registry.supportFor(DeviceCapabilityRegistry.actionBrightnessControl);
    final timeoutSupport =
        registry.supportFor(DeviceCapabilityRegistry.actionScreenTimeoutControl);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.tr('scout_phone_modes_utilities'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.tr('permission_center'),
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PermissionCenterScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: l10n.tr('refresh_usage_device_check'),
            icon: provider.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: provider.isRefreshing ? null : () => provider.refreshAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (activeMode != null && snapshot != null && !snapshot.wasRestored)
            _buildActiveModeBanner(context, provider, activeMode, snapshot)
          else if (lastSummary != null && lastSummary.restorationNotes.isNotEmpty)
            _buildRestorationSummaryBanner(context, lastSummary),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      registry.isSamsungOneUi
                          ? Icons.auto_awesome_rounded
                          : Icons.settings_applications_rounded,
                      color: AppColors.info,
                    ),
                    title: Text(
                      registry.isSamsungOneUi
                          ? l10n.tr('open_samsung_modes_routines')
                          : l10n.tr('open_os_focus_digital_wellbeing_settings'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      l10n.tr('hardware_or_oem_only_toggles_can'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => provider.openSystemModesOrWellbeing(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.tr('phone_mode_orchestrator'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l10n.tr('custom_mode')),
                      onPressed: () =>
                          _showEditPhoneModeSheet(context, provider),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...modes.map((mode) {
                  final isActive = provider.activePhoneModeId == mode.id;
                  final color = Color(mode.colorValue);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isActive ? color : AppColors.border(context),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _iconForMode(mode.iconKey),
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mode.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (mode.description.isNotEmpty)
                                      Text(
                                        mode.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (mode.preset == PhoneModePreset.custom)
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _showEditPhoneModeSheet(
                                    context,
                                    provider,
                                    existing: mode,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (mode.enableDnd)
                                _supportChip(context, 'DND', dndSupport),
                              if (mode.targetBrightnessPercent != null)
                                _supportChip(
                                  context,
                                  '${mode.targetBrightnessPercent}%',
                                  brightSupport,
                                ),
                              if (mode.targetScreenTimeoutSeconds != null)
                                _supportChip(
                                  context,
                                  '${mode.targetScreenTimeoutSeconds}s',
                                  timeoutSupport,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isActive)
                                FilledButton.icon(
                                  icon: const Icon(
                                    Icons.stop_circle_outlined,
                                    size: 18,
                                  ),
                                  label:
                                      Text(l10n.tr('end_restore_settings')),
                                  onPressed: () async {
                                    final notes =
                                        await provider.endActivePhoneMode();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(notes.join(' '))),
                                    );
                                  },
                                )
                              else
                                FilledButton.tonalIcon(
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 18,
                                  ),
                                  label: Text(l10n.tr('activate_mode')),
                                  onPressed: () async {
                                    final outcomes = await provider
                                        .activatePhoneMode(mode.id);
                                    if (!context.mounted) return;
                                    final msg = outcomes
                                        .map((o) => o.message)
                                        .where((m) => m.isNotEmpty)
                                        .join(' ');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          msg.isEmpty
                                              ? l10n.tr('mode_active_label',
                                                  {'name': mode.name})
                                              : msg,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveModeBanner(
    BuildContext context,
    DeviceControlProvider provider,
    PhoneModeProfile mode,
    StateRestorationSnapshot snapshot,
  ) {
    final l10n = context.l10n;
    final color = Color(mode.colorValue);
    final expiresLabel = snapshot.expiresAt != null
        ? DateFormat.Hm().format(snapshot.expiresAt!)
        : l10n.tr('manual_session');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_moon_rounded, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('mode_active_label', {'name': mode.name}),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.tr('safe_restore_armed', {'expires': expiresLabel}),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              final notes = await provider.endActivePhoneMode();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    notes.isEmpty ? mode.name : notes.join(' '),
                  ),
                ),
              );
            },
            child: Text(l10n.tr('end_restore')),
          ),
        ],
      ),
    );
  }

  Widget _buildRestorationSummaryBanner(
    BuildContext context,
    StateRestorationSnapshot summary,
  ) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.restore_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.tr('last_state_restoration', {
                'mode': summary.modeName,
                'notes': summary.restorationNotes.join(' '),
              }),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportChip(
    BuildContext context,
    String prefix,
    ActionExecutionSupport support,
  ) {
    final Color color;
    final String statusText;
    switch (support) {
      case ActionExecutionSupport.directlySupported:
        color = AppColors.success;
        statusText = 'Direct';
        break;
      case ActionExecutionSupport.permissionRequired:
        color = AppColors.warning;
        statusText = 'Permission';
        break;
      case ActionExecutionSupport.delegatedToSystemSettings:
        color = AppColors.info;
        statusText = 'OS Settings';
        break;
      case ActionExecutionSupport.unsupported:
        color = AppColors.error;
        statusText = 'Unsupported';
        break;
    }
    final text = prefix.isEmpty ? statusText : '$prefix · $statusText';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  IconData _iconForMode(String key) {
    switch (key) {
      case 'bedtime':
        return Icons.bedtime_rounded;
      case 'work':
        return Icons.work_outline_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'self_improvement':
        return Icons.self_improvement_rounded;
      default:
        return Icons.tune_rounded;
    }
  }

  void _showEditPhoneModeSheet(
    BuildContext context,
    DeviceControlProvider provider, {
    PhoneModeProfile? existing,
  }) {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var enableDnd = existing?.enableDnd ?? true;
    var manageBrightness = existing?.targetBrightnessPercent != null;
    var brightness = (existing?.targetBrightnessPercent ?? 40).toDouble();
    var durationMinutes = existing?.durationMinutes ?? 60;

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
                Text(
                  existing == null
                      ? l10n.tr('create_custom_phone_mode')
                      : '${l10n.tr('edit')} ${existing.name}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.tr('mode_name')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.tr('mode_description_label'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tr('enable_dnd')),
                  value: enableDnd,
                  onChanged: (v) => setSheetState(() => enableDnd = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tr('adjust_screen_brightness')),
                  value: manageBrightness,
                  onChanged: (v) =>
                      setSheetState(() => manageBrightness = v),
                ),
                if (manageBrightness)
                  Slider(
                    value: brightness,
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: '${brightness.round()}%',
                    onChanged: (v) => setSheetState(() => brightness = v),
                  ),
                DropdownButtonFormField<int>(
                  initialValue: durationMinutes,
                  decoration: InputDecoration(
                    labelText: l10n.tr('auto_restore_duration'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 30,
                      child: Text(l10n.tr('duration_30m')),
                    ),
                    DropdownMenuItem(
                      value: 60,
                      child: Text(l10n.tr('duration_1h')),
                    ),
                    DropdownMenuItem(
                      value: 120,
                      child: Text(l10n.tr('duration_2h')),
                    ),
                    DropdownMenuItem(
                      value: 480,
                      child: Text(l10n.tr('duration_8h_overnight')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setSheetState(() => durationMinutes = v);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final profile = existing != null
                            ? existing.copyWith(
                                name: name,
                                description: descCtrl.text.trim(),
                                enableDnd: enableDnd,
                                targetBrightnessPercent: manageBrightness
                                    ? brightness.round()
                                    : null,
                                clearBrightness: !manageBrightness,
                                durationMinutes: durationMinutes,
                              )
                            : PhoneModeProfile(
                                name: name,
                                preset: PhoneModePreset.custom,
                                description: descCtrl.text.trim(),
                                enableDnd: enableDnd,
                                targetBrightnessPercent: manageBrightness
                                    ? brightness.round()
                                    : null,
                                durationMinutes: durationMinutes,
                              );
                        await provider.addOrUpdatePhoneMode(profile);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(l10n.tr('save_mode')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
