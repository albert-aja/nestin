import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/oem_hardening_provider.dart';
import 'oem_hardening_sheet.dart';

class OemWarningBanner extends StatelessWidget {
  const OemWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OemHardeningProvider>(
      builder: (context, provider, _) {
        if (!provider.shouldShowWarningBanner) {
          return const SizedBox.shrink();
        }

        final status = provider.status;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE04A3A).withOpacity(0.18),
                const Color(0xFFF59E0B).withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE04A3A).withOpacity(0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE04A3A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFE04A3A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${status.brandDisplayName} Battery Alert',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Aggressive battery killer may silence alarms when phone sleeps.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.adaptive(
                          context,
                          dark: const Color(0xFFB0B4C3),
                          light: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => OemHardeningSheet.show(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE04A3A)
                      .withValues(alpha: AppColors.isDark(context) ? 0.22 : 0.16),
                  foregroundColor: AppColors.adaptive(
                    context,
                    dark: Colors.white,
                    light: const Color(0xFFB91C1C),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Protect',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textSecondary(context)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => provider.dismissWarningBanner(),
              ),
            ],
          ),
        );
      },
    );
  }
}

