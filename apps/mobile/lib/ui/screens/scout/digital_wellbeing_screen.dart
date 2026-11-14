import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/device_capability.dart';
import '../../../data/models/digital_wellbeing.dart';
import '../../../data/models/phone_mode.dart';
import '../../../providers/device_control_provider.dart';
import '../settings/permission_center_screen.dart';

class DigitalWellbeingScreen extends StatefulWidget {
  final int initialTab;

  const DigitalWellbeingScreen({super.key, this.initialTab = 0});

  @override
  State<DigitalWellbeingScreen> createState() => _DigitalWellbeingScreenState();
}

class _DigitalWellbeingScreenState extends State<DigitalWellbeingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<DeviceControlProvider>();
    final activeMode = provider.activePhoneMode;
    final snapshot = provider.activeSnapshot;
    final lastSummary = provider.lastRestorationSummary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pick('Scout · Wellbeing & Phone Control',
              'Scout · Kesejahteraan & Kontrol Ponsel'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.pick('Permission Center', 'Pusat Izin'),
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
            tooltip: l10n.pick('Refresh Usage & Device Check', 'Segarkan'),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.pick('Usage & Limits', 'Penggunaan')),
            Tab(text: l10n.pick('Phone Modes', 'Mode Ponsel')),
            Tab(text: l10n.pick('Activity Log', 'Riwayat')),
          ],
        ),
      ),
      body: Column(
        children: [
          if (activeMode != null && snapshot != null && !snapshot.wasRestored)
            _buildActiveModeBanner(context, provider, activeMode, snapshot)
          else if (lastSummary != null && lastSummary.restorationNotes.isNotEmpty)
            _buildRestorationSummaryBanner(context, lastSummary),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsageAndLimitsTab(context, provider),
                _buildPhoneModesTab(context, provider),
                _buildLogsAndBoundariesTab(context, provider),
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
        ? 'Ends ${DateFormat.Hm().format(snapshot.expiresAt!)}'
        : l10n.pick('Manual session', 'Sesi manual');

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
                  '${mode.name} · Active',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$expiresLabel · Safe restore snapshot armed',
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
                    notes.isEmpty ? '${mode.name} ended.' : notes.join(' '),
                  ),
                ),
              );
            },
            child: Text(l10n.pick('End & Restore', 'Akhiri')),
          ),
        ],
      ),
    );
  }

  Widget _buildRestorationSummaryBanner(
    BuildContext context,
    StateRestorationSnapshot summary,
  ) {
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
              'Last State Restoration (${summary.modeName}): ${summary.restorationNotes.join(' ')}',
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

  Widget _buildUsageAndLimitsTab(
    BuildContext context,
    DeviceControlProvider provider,
  ) {
    final l10n = context.l10n;
    final snap = provider.usageSnapshot;
    final rules = provider.appRules;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!snap.permissionGranted)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.privacy_tip_outlined,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.pick(
                          'Usage Telemetry Boundary',
                          'Batas Telemetri Penggunaan',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  snap.honestBoundaryMessage.isNotEmpty
                      ? snap.honestBoundaryMessage
                      : l10n.pick(
                          'Grant Usage Access in Permission Center so Scout can read daily app screen time accurately.',
                          'Berikan Akses Penggunaan di Pusat Izin agar Scout membaca waktu layar secara akurat.',
                        ),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.verified_user_outlined, size: 16),
                      label: Text(l10n.pick('Open Permission Center', 'Pusat Izin')),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PermissionCenterScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

        Row(
          children: [
            _metricPill(
              context,
              label: l10n.pick('Tracked Today', 'Terpantau Hari Ini'),
              value: '${snap.totalTrackedMinutes} min',
              icon: Icons.hourglass_bottom_rounded,
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 10),
            _metricPill(
              context,
              label: l10n.pick('Active Limits', 'Batas Aktif'),
              value: '${rules.where((r) => r.isEnabled).length} apps',
              icon: Icons.rule_folder_outlined,
              color: AppColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.pick('App Restriction Manager', 'Pengelola Pembatasan Aplikasi'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.pick('Add App', 'Tambah')),
              onPressed: () => _showEditAppRuleSheet(context, provider),
            ),
          ],
        ),
        const SizedBox(height: 6),

        ...rules.map((rule) {
          final record = snap.recordForPackage(rule.packageName);
          final used = record?.usedMinutesToday ?? 0;
          final ratio = rule.dailyLimitMinutes > 0
              ? (used / rule.dailyLimitMinutes).clamp(0.0, 1.0)
              : 0.0;
          final isOver = used >= rule.dailyLimitMinutes;
          final isWarning = !isOver && used >= rule.warningMinutes;
          final barColor = isOver
              ? AppColors.error
              : (isWarning ? AppColors.warning : AppColors.info);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
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
                              rule.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              rule.packageName,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: rule.isEnabled,
                        activeThumbColor: AppColors.accent,
                        onChanged: (val) => provider.addOrUpdateAppRule(
                          rule.copyWith(isEnabled: val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: AppColors.trackSurface(context),
                    color: barColor,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$used / ${rule.dailyLimitMinutes} min · ${rule.interventionLevel.label}'
                          '${rule.blockedScheduleStart != null ? ' · ${rule.blockedScheduleStart}-${rule.blockedScheduleEnd}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                      if (rule.interventionLevel ==
                              WellbeingInterventionLevel.timedSoftPause ||
                          rule.interventionLevel ==
                              WellbeingInterventionLevel.blockingSchedule ||
                          rule.interventionLevel ==
                              WellbeingInterventionLevel.strictModeGuard)
                        TextButton(
                          onPressed: () =>
                              _showMindfulPauseDialog(context, provider, rule),
                          child: Text(l10n.pick('Pause Check', 'Jeda')),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showEditAppRuleSheet(
                          context,
                          provider,
                          existing: rule,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPhoneModesTab(
    BuildContext context,
    DeviceControlProvider provider,
  ) {
    final l10n = context.l10n;
    final modes = provider.phoneModes;
    final registry = provider.registry;
    final dndSupport = registry.supportFor(DeviceCapabilityRegistry.actionDndToggle);
    final brightSupport =
        registry.supportFor(DeviceCapabilityRegistry.actionBrightnessControl);
    final timeoutSupport =
        registry.supportFor(DeviceCapabilityRegistry.actionScreenTimeoutControl);

    return ListView(
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
                  ? l10n.pick('Open Samsung Modes & Routines',
                      'Buka Samsung Modes & Routines')
                  : l10n.pick('Open OS Focus / Digital Wellbeing Settings',
                      'Buka Pengaturan Fokus / Wellbeing OS'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              l10n.pick(
                'Hardware or OEM-only toggles can be delegated straight to native OS settings.',
                'Pengaturan khusus sistem atau OEM dapat diteruskan langsung ke pengaturan OS.',
              ),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
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
              l10n.pick('Phone Mode Orchestrator', 'Orkestrator Mode Ponsel'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.pick('Custom Mode', 'Mode Kustom')),
              onPressed: () => _showEditPhoneModeSheet(context, provider),
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
                        child: Icon(_iconForMode(mode.iconKey), color: color),
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
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (mode.preset == PhoneModePreset.custom)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
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
                          'Brightness ${mode.targetBrightnessPercent}%',
                          brightSupport,
                        ),
                      if (mode.targetScreenTimeoutSeconds != null)
                        _supportChip(
                          context,
                          'Timeout ${mode.targetScreenTimeoutSeconds}s',
                          timeoutSupport,
                        ),
                      if (mode.restrictedAppRuleIds.isNotEmpty)
                        _supportChip(
                          context,
                          '${mode.restrictedAppRuleIds.length} App Guards',
                          registry.supportFor(
                            DeviceCapabilityRegistry.actionAppBlockingShield,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isActive)
                        FilledButton.icon(
                          icon: const Icon(Icons.stop_circle_outlined, size: 18),
                          label: Text(l10n.pick('End & Restore Settings',
                              'Akhiri & Pulihkan')),
                          onPressed: () async {
                            final notes = await provider.endActivePhoneMode();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(notes.join(' '))),
                            );
                          },
                        )
                      else
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(l10n.pick('Activate Mode', 'Aktifkan Mode')),
                          onPressed: () async {
                            final outcomes =
                                await provider.activatePhoneMode(mode.id);
                            if (!context.mounted) return;
                            final msg = outcomes
                                .map((o) => o.message)
                                .where((m) => m.isNotEmpty)
                                .join(' ');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  msg.isEmpty ? '${mode.name} activated.' : msg,
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
    );
  }

  Widget _buildLogsAndBoundariesTab(
    BuildContext context,
    DeviceControlProvider provider,
  ) {
    final l10n = context.l10n;
    final logs = provider.interventionLogs;
    final registry = provider.registry;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pick('Honest Device Boundaries (${registry.platform.toUpperCase()})',
                      'Batas Perangkat Jujur (${registry.platform.toUpperCase()})'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manufacturer: ${registry.manufacturer} • Model: ${registry.model} • OS: ${registry.osVersion}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 10),
                ...registry.capabilities.values.map(
                  (cap) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cap.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              if (cap.oemNote.isNotEmpty)
                                Text(
                                  cap.oemNote,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _supportChip(context, '', cap.support),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.pick('Intervention History', 'Riwayat Intervensi'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                l10n.pick(
                  'No intervention events logged yet today.',
                  'Belum ada riwayat intervensi hari ini.',
                ),
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
          )
        else
          ...logs.map(
            (log) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.notifications_paused_rounded,
                    color: AppColors.accent),
                title: Text(
                  '${log.appName} · ${log.level.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${log.reason} -> ${log.outcome}\n${DateFormat.yMMMd().add_Hm().format(log.timestamp)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metricPill(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
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
        statusText = 'Needs Permission';
        break;
      case ActionExecutionSupport.delegatedToSystemSettings:
        color = AppColors.info;
        statusText = 'System Settings';
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

  void _showMindfulPauseDialog(
    BuildContext context,
    DeviceControlProvider provider,
    TrackedAppRule rule,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mindful Pause · ${rule.displayName}'),
        content: Text(
          'Take a 10-second breath before continuing ${rule.displayName}. '
          'Level: ${rule.interventionLevel.label}.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await provider.logManualInterventionOutcome(
                rule: rule,
                reason: 'mindful_pause_prompt',
                outcome: 'bypassed_by_user',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Continue Anyway'),
          ),
          FilledButton(
            onPressed: () async {
              await provider.logManualInterventionOutcome(
                rule: rule,
                reason: 'mindful_pause_prompt',
                outcome: 'paused_by_user',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Stay Focused'),
          ),
        ],
      ),
    );
  }

  void _showEditAppRuleSheet(
    BuildContext context,
    DeviceControlProvider provider, {
    TrackedAppRule? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final pkgCtrl = TextEditingController(text: existing?.packageName ?? '');
    final limitCtrl = TextEditingController(
        text: (existing?.dailyLimitMinutes ?? 45).toString());
    var level =
        existing?.interventionLevel ?? WellbeingInterventionLevel.preLimitWarning;
    final startCtrl =
        TextEditingController(text: existing?.blockedScheduleStart ?? '');
    final endCtrl =
        TextEditingController(text: existing?.blockedScheduleEnd ?? '');

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
                  existing == null ? 'Add Tracked App' : 'Edit ${existing.displayName}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'App Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pkgCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Package ID (e.g. com.instagram.android)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: limitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily Limit (minutes)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WellbeingInterventionLevel>(
                  initialValue: level,
                  decoration:
                      const InputDecoration(labelText: 'Intervention Level'),
                  items: WellbeingInterventionLevel.values
                      .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setSheetState(() => level = v);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Schedule Start (HH:mm)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Schedule End (HH:mm)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (existing != null && !existing.isPreset)
                      TextButton(
                        onPressed: () async {
                          await provider.deleteAppRule(existing.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final pkg = pkgCtrl.text.trim();
                        if (name.isEmpty || pkg.isEmpty) return;
                        final limit = int.tryParse(limitCtrl.text.trim()) ?? 45;
                        final s = startCtrl.text.trim();
                        final e = endCtrl.text.trim();
                        final rule = existing != null
                            ? existing.copyWith(
                                displayName: name,
                                packageName: pkg,
                                dailyLimitMinutes: limit.clamp(5, 720),
                                interventionLevel: level,
                                blockedScheduleStart: s.isEmpty ? null : s,
                                clearScheduleStart: s.isEmpty,
                                blockedScheduleEnd: e.isEmpty ? null : e,
                                clearScheduleEnd: e.isEmpty,
                              )
                            : TrackedAppRule(
                                displayName: name,
                                packageName: pkg,
                                dailyLimitMinutes: limit.clamp(5, 720),
                                interventionLevel: level,
                                blockedScheduleStart: s.isEmpty ? null : s,
                                blockedScheduleEnd: e.isEmpty ? null : e,
                              );
                        await provider.addOrUpdateAppRule(rule);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
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

  void _showEditPhoneModeSheet(
    BuildContext context,
    DeviceControlProvider provider, {
    PhoneModeProfile? existing,
  }) {
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
                  existing == null ? 'Create Custom Phone Mode' : 'Edit ${existing.name}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Mode Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Do Not Disturb'),
                  value: enableDnd,
                  onChanged: (v) => setSheetState(() => enableDnd = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Adjust Screen Brightness'),
                  value: manageBrightness,
                  onChanged: (v) => setSheetState(() => manageBrightness = v),
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
                  decoration: const InputDecoration(
                    labelText: 'Auto-Restore Duration',
                  ),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 minutes')),
                    DropdownMenuItem(value: 60, child: Text('1 hour')),
                    DropdownMenuItem(value: 120, child: Text('2 hours')),
                    DropdownMenuItem(value: 480, child: Text('8 hours (Overnight)')),
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
                                targetBrightnessPercent:
                                    manageBrightness ? brightness.round() : null,
                                clearBrightness: !manageBrightness,
                                durationMinutes: durationMinutes,
                              )
                            : PhoneModeProfile(
                                name: name,
                                preset: PhoneModePreset.custom,
                                description: descCtrl.text.trim(),
                                enableDnd: enableDnd,
                                targetBrightnessPercent:
                                    manageBrightness ? brightness.round() : null,
                                durationMinutes: durationMinutes,
                              );
                        await provider.addOrUpdatePhoneMode(profile);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Mode'),
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
