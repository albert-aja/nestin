import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/wearable_source.dart';
import '../../providers/health_wellness_provider.dart';
import '../../providers/wearable_provider.dart';

class WearableSyncSheet extends StatelessWidget {
  const WearableSyncSheet({super.key});

  void _forwardRecordToHealth(BuildContext context, WearableProvider provider) {
    final rec = provider.latestRecord;
    if (rec == null || !context.mounted) return;
    try {
      Provider.of<HealthWellnessProvider>(context, listen: false)
          .ingestWearableRecord(rec);
    } catch (_) {}
  }

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WearableSyncSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WearableProvider>(
      builder: (context, provider, _) {
        final config = provider.config;
        final record = provider.latestRecord;

        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.watch_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wearable & Health Sync',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Apple Health • Google Fit • Health Connect',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Connection status card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: config.isConnected
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.border(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        config.isConnected
                            ? Icons.check_circle_rounded
                            : Icons.link_off_rounded,
                        color: config.isConnected
                            ? AppColors.success
                            : AppColors.textSecondary(context),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.isConnected
                                  ? 'Connected to ${config.selectedPlatform.shortName}'
                                  : 'Not Connected',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              config.isConnected && record != null
                                  ? 'Last sync: ${record.syncedAt.hour.toString().padLeft(2, '0')}:${record.syncedAt.minute.toString().padLeft(2, '0')}'
                                  : 'Connect a wearable platform to sync wellness metrics',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (config.isConnected)
                        provider.isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.sync_rounded),
                                tooltip: 'Sync Now',
                                color: AppColors.accent,
                                onPressed: () async {
                                  await provider.syncNow();
                                  if (context.mounted) {
                                    _forwardRecordToHealth(context, provider);
                                  }
                                },
                              ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Platform selection
                const Text(
                  'Select Health Platform',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...WearablePlatform.values.map((plat) {
                  final isSelected =
                      config.isConnected && config.selectedPlatform == plat;
                  return Card(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : AppColors.elevatedSurface(context),
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.accent
                            : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        plat == WearablePlatform.appleHealth
                            ? Icons.health_and_safety_rounded
                            : plat == WearablePlatform.googleFit
                                ? Icons.directions_run_rounded
                                : plat == WearablePlatform.healthConnect
                                    ? Icons.favorite_rounded
                                    : Icons.developer_mode_rounded,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textSecondary(context),
                      ),
                      title: Text(
                        plat.displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        plat.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.radio_button_checked_rounded,
                              color: AppColors.accent,
                              size: 20,
                            )
                          : Icon(
                              Icons.radio_button_unchecked_rounded,
                              color: AppColors.textSecondary(context),
                              size: 20,
                            ),
                      onTap: () async {
                        final ok = await provider.connect(plat);
                        if (ok && context.mounted) {
                          _forwardRecordToHealth(context, provider);
                        }
                      },
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // Synced Metrics Display (if connected and record exists)
                if (config.isConnected && record != null) ...[
                  const Text(
                    'Latest Synced Wellness Metrics',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                    children: [
                      _metricTile(
                        context: context,
                        icon: Icons.bedtime_rounded,
                        color: const Color(0xFF8338EC),
                        label: 'Sleep Duration',
                        value: record.sleepDurationFormatted,
                        subtext: record.sleepMinutes != null
                            ? '${record.sleepCyclesCount} REM cycles'
                            : '--',
                      ),
                      _metricTile(
                        context: context,
                        icon: Icons.water_drop_rounded,
                        color: const Color(0xFF3A86FF),
                        label: 'Hydration',
                        value: record.waterIntakeMl != null
                            ? '${record.waterIntakeMl} ml'
                            : '--',
                        subtext: 'Synced with intake',
                      ),
                      _metricTile(
                        context: context,
                        icon: Icons.directions_walk_rounded,
                        color: const Color(0xFF10B981),
                        label: 'Daily Steps',
                        value: record.stepCount != null
                            ? '${record.stepCount}'
                            : '--',
                        subtext: 'Activity log',
                      ),
                      _metricTile(
                        context: context,
                        icon: Icons.favorite_rounded,
                        color: const Color(0xFFEF4444),
                        label: 'Resting HR',
                        value: record.restingHeartRate != null
                            ? '${record.restingHeartRate} bpm'
                            : '--',
                        subtext: 'Morning wake baseline',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Sync Granular Toggles
                const Text(
                  'Data Sync Permissions',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        title: const Text('Sleep Analysis & Cycles',
                            style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                            'Compare actual sleep with 90m cycle targets',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                        value: config.syncSleep,
                        activeColor: AppColors.accent,
                        onChanged: (val) => provider.updateConfig(
                          config.copyWith(syncSleep: val),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Hydration Tracking',
                            style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                            'Bidirectional water sync with health app',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                        value: config.syncHydration,
                        activeColor: AppColors.accent,
                        onChanged: (val) => provider.updateConfig(
                          config.copyWith(syncHydration: val),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Daily Steps & Activity',
                            style: TextStyle(fontSize: 13)),
                        value: config.syncSteps,
                        activeColor: AppColors.accent,
                        onChanged: (val) => provider.updateConfig(
                          config.copyWith(syncSteps: val),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Resting Heart Rate',
                            style: TextStyle(fontSize: 13)),
                        value: config.syncHeartRate,
                        activeColor: AppColors.accent,
                        onChanged: (val) => provider.updateConfig(
                          config.copyWith(syncHeartRate: val),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Auto-Sync on Launch',
                            style: TextStyle(fontSize: 13)),
                        value: config.autoSyncOnLaunch,
                        activeColor: AppColors.accent,
                        onChanged: (val) => provider.updateConfig(
                          config.copyWith(autoSyncOnLaunch: val),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Disconnect or Re-sync button
                if (config.isConnected)
                  OutlinedButton.icon(
                    onPressed: () => provider.disconnect(),
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('Disconnect Health Platform'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: BorderSide(color: AppColors.border(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
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
}
