import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/oem_hardening_data.dart';
import '../../providers/oem_hardening_provider.dart';

class OemHardeningSheet extends StatelessWidget {
  const OemHardeningSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OemHardeningSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OemHardeningProvider>(
      builder: (context, provider, _) {
        final status = provider.status;
        final config = provider.config;
        final isProtected = provider.isProtected;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.sheetSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sheet Title & Close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isProtected
                                  ? AppColors.success.withValues(alpha: 0.18)
                                  : const Color(0xFFE04A3A).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isProtected
                                  ? Icons.verified_user_rounded
                                  : Icons.shield_rounded,
                              color: isProtected
                                  ? AppColors.success
                                  : const Color(0xFFE04A3A),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status.brandDisplayName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  status.model.isNotEmpty
                                      ? '${status.model} • Android ${status.sdkInt >= 34 ? '14+' : status.sdkInt}'
                                      : 'Background Killer Hardening',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.textSecondary(context)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Risk & Status Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isProtected
                        ? AppColors.success.withValues(alpha: 0.12)
                        : const Color(0xFFE04A3A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isProtected
                          ? AppColors.success.withValues(alpha: 0.3)
                          : const Color(0xFFE04A3A).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isProtected
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        color: isProtected
                            ? AppColors.success
                            : const Color(0xFFE04A3A),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isProtected
                                  ? '100% Protected Against Sleep Kill'
                                  : status.riskLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isProtected
                                    ? AppColors.success
                                    : const Color(0xFFE04A3A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isProtected
                                  ? 'Battery optimizations disabled or keep-alive active. Alarms will fire on time.'
                                  : 'Aggressive battery management may freeze Nestin when phone sleeps.',
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
                const SizedBox(height: 18),

                // Step-by-step guidance
                Text(
                  'Recommended Protection Steps',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),

                ...status.guidanceSteps.map((step) {
                  return _buildStepCard(
                    context: context,
                    provider: provider,
                    step: step,
                    isBatteryIgnored: status.isIgnoringBatteryOptimizations,
                    isKeepAliveEnabled: config.keepAliveEnabledByUser,
                  );
                }),

                const SizedBox(height: 10),

                // OEM Specific Checklist
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates_outlined,
                              size: 16,
                              color: AppColors.adaptive(
                                context,
                                dark: AppColors.accent,
                                light: const Color(0xFFC26A00),
                              )),
                          const SizedBox(width: 8),
                          Text(
                            '${status.brandDisplayName} Pro-Tips',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.adaptive(
                                context,
                                dark: AppColors.accent,
                                light: const Color(0xFFC26A00),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getBrandProTips(status.oemBrand),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Done / Dismiss Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      provider.refreshStatus();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done & Verify Protection',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  Widget _buildStepCard({
    required BuildContext context,
    required OemHardeningProvider provider,
    required OemInstructionStep step,
    required bool isBatteryIgnored,
    required bool isKeepAliveEnabled,
  }) {
    final isBatteryStep = step.actionType == 'battery_opt';
    final isAutostartStep = step.actionType == 'autostart';
    final isKeepAliveStep = step.actionType == 'keep_alive';

    final isStepDone = (isBatteryStep && isBatteryIgnored) ||
        (isKeepAliveStep && isKeepAliveEnabled);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStepDone
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isStepDone
                      ? AppColors.success.withValues(alpha: 0.2)
                      : AppColors.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: isStepDone
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: AppColors.success)
                    : Text(
                        '${step.stepNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.adaptive(
                            context,
                            dark: AppColors.accent,
                            light: const Color(0xFFC26A00),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isStepDone)
                const Text(
                  'Enabled',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              step.description,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: isKeepAliveStep
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          step.actionLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: isKeepAliveEnabled,
                        activeColor: AppColors.accent,
                        onChanged: (val) => provider.toggleKeepAliveService(val),
                      ),
                    ],
                  )
                : OutlinedButton.icon(
                    onPressed: () {
                      if (isBatteryStep) {
                        provider.requestDisableBatteryOptimization();
                      } else if (isAutostartStep) {
                        provider.openAutostartSettings();
                      }
                    },
                    icon: Icon(
                      isBatteryStep
                          ? Icons.battery_alert_rounded
                          : Icons.open_in_new_rounded,
                      size: 15,
                    ),
                    label: Text(step.actionLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.adaptive(
                        context,
                        dark: AppColors.accent,
                        light: const Color(0xFFC26A00),
                      ),
                      side: BorderSide(color: AppColors.border(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getBrandProTips(OemBrand brand) {
    switch (brand) {
      case OemBrand.xiaomi:
        return '• In Recent Apps switcher, long-press Nestin and tap the Padlock icon to lock it in RAM.\n• Set Battery saver to "No restrictions" (Settings > Apps > Nestin > Battery saver).\n• Enable Autostart in Security app.';
      case OemBrand.samsung:
        return '• In Device Care > Battery > Background usage limits > Never sleeping apps, add Nestin.\n• Set App Info > Battery to "Unrestricted".\n• Turn OFF "Put unused apps to sleep" for Nestin.';
      case OemBrand.huawei:
        return '• In Battery > App launch, change Nestin from "Manage automatically" to "Manage manually".\n• Turn ON Auto-launch, Secondary launch, and Run in background.\n• Exclude Nestin in Battery optimization.';
      case OemBrand.oppo:
        return '• In Phone Manager > Startup manager, allow Nestin to run on startup.\n• In Battery > App battery management, set to "Don\'t optimize" and allow high background power.';
      case OemBrand.vivo:
        return '• In Settings > Battery > High background power consumption, switch Nestin to ON.\n• In iManager > App Manager > Autostart, enable Nestin.';
      default:
        return '• In Settings > Apps > Nestin > Battery, choose "Unrestricted".\n• Turn on the Nestin Foreground Keep-Alive Guard for guaranteed wake-up reliability.';
    }
  }
}
