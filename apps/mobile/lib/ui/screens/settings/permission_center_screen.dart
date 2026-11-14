import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/device_capability.dart';
import '../../../providers/device_control_provider.dart';

class PermissionCenterScreen extends StatelessWidget {
  const PermissionCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<DeviceControlProvider>();
    final registry = provider.registry;
    final revoked = registry.revokedPermissions;

    final requiredPerms = registry.permissions
        .where((p) => p.tier == PermissionRequirementTier.required)
        .toList();
    final recommendedPerms = registry.permissions
        .where((p) => p.tier == PermissionRequirementTier.recommended)
        .toList();
    final optionalPerms = registry.permissions
        .where((p) => p.tier == PermissionRequirementTier.optional)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.pick('Permission & Capability Center', 'Pusat Izin & Kapabilitas'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.pick('Re-check OS Permissions', 'Periksa Ulang Izin'),
            icon: provider.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: provider.isRefreshing
                ? null
                : () => provider.refreshCapabilities(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeviceOverviewCard(context, registry),
          const SizedBox(height: 12),

          if (revoked.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.gpp_maybe_rounded,
                      color: AppColors.error, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.pick(
                        '${revoked.length} previously granted permission(s) were revoked: ${revoked.map((e) => e.title).join(', ')}. Features using them have safely degraded.',
                        '${revoked.length} izin yang sebelumnya diberikan telah dicabut: ${revoked.map((e) => e.title).join(', ')}.',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (requiredPerms.isNotEmpty) ...[
            _sectionHeader(
              context,
              l10n.pick('Required Core Permissions', 'Izin Inti Wajib'),
              AppColors.primary,
            ),
            ...requiredPerms.map((p) => _permissionCard(context, provider, p)),
            const SizedBox(height: 12),
          ],

          if (recommendedPerms.isNotEmpty) ...[
            _sectionHeader(
              context,
              l10n.pick('Recommended Reliability & Telemetry',
                  'Disarankan untuk Keandalan & Telemetri'),
              AppColors.accent,
            ),
            ...recommendedPerms
                .map((p) => _permissionCard(context, provider, p)),
            const SizedBox(height: 12),
          ],

          if (optionalPerms.isNotEmpty) ...[
            _sectionHeader(
              context,
              l10n.pick('Optional Device Control & Context',
                  'Izin Kontrol Perangkat Opsional'),
              AppColors.info,
            ),
            ...optionalPerms.map((p) => _permissionCard(context, provider, p)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeviceOverviewCard(
    BuildContext context,
    DeviceCapabilityRegistry registry,
  ) {
    final grantedCount = registry.permissions.where((p) => p.isGranted).length;
    final totalCount = registry.permissions.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phonelink_setup_rounded, color: AppColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${registry.manufacturer} · ${registry.model}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Platform: ${registry.platform.toUpperCase()} • OS: ${registry.osVersion}'
                        '${registry.isSamsungOneUi ? ' • Samsung One UI' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$grantedCount / $totalCount Ready',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _permissionCard(
    BuildContext context,
    DeviceControlProvider provider,
    PermissionEntry entry,
  ) {
    final Color statusColor;
    final String statusLabel;
    switch (entry.status) {
      case PermissionStatus.granted:
        statusColor = AppColors.success;
        statusLabel = 'Granted';
        break;
      case PermissionStatus.revoked:
        statusColor = AppColors.error;
        statusLabel = 'Revoked';
        break;
      case PermissionStatus.denied:
        statusColor = AppColors.warning;
        statusLabel = 'Not Granted';
        break;
      case PermissionStatus.restricted:
        statusColor = AppColors.error;
        statusLabel = 'Restricted';
        break;
      case PermissionStatus.unavailable:
        statusColor = AppColors.textMuted(context);
        statusLabel = 'Unavailable';
        break;
    }

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
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.rationale,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How to enable: ${entry.enableInstructions}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (entry.affectsFeatures.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: entry.affectsFeatures
                    .map(
                      (f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.subtleFill(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (!entry.isGranted && entry.canOpenSettings) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Open OS Settings'),
                  onPressed: () async {
                    await provider.openPermissionSettings(entry.kind);
                    await provider.refreshCapabilities();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
