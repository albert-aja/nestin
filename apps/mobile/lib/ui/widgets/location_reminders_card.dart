import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/location_reminder.dart';
import '../../providers/geofence_provider.dart';
import 'location_reminders_sheet.dart';

class LocationRemindersCard extends StatelessWidget {
  const LocationRemindersCard({super.key});

  static const Color _scoutBlue = Color(0xFF3B82F6);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<GeofenceProvider>(
      builder: (context, provider, _) {
        final pending = provider.pendingReminders;
        final previewItems = pending.take(3).toList();
        final armedCount = provider.armedCount;
        final perm = provider.permissionState;

        return InkWell(
          onTap: () => LocationRemindersSheet.show(context),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _scoutBlue.withValues(alpha: 0.38)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _scoutBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: _scoutBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.pick(
                                    'Location Reminders',
                                    'Pengingat Lokasi',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: armedCount > 0
                                      ? _scoutBlue.withValues(alpha: 0.18)
                                      : AppColors.trackSurface(context),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l10n.pick(
                                    '$armedCount Armed',
                                    '$armedCount Aktif',
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: armedCount > 0
                                        ? _scoutBlue
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.pick(
                              '🧭 ${provider.places.length} geofence zones • ${perm.label}',
                              '🧭 ${provider.places.length} zona lokasi • ${perm.label}',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: perm.isReadyForBackground
                                  ? _emerald
                                  : (perm.canUseForeground
                                      ? AppColors.adaptive(
                                          context,
                                          dark: _amber,
                                          light: const Color(0xFFB45309),
                                        )
                                      : AppColors.textSecondary(context)),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add Location Reminder',
                      onPressed: () =>
                          showLocationReminderEditorDialog(context),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: _scoutBlue,
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),

                if (previewItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border(context)),
                  const SizedBox(height: 10),
                  ...previewItems.map((item) {
                    final place = provider.findPlaceById(item.placeId);
                    final placeName = place?.name ?? 'Saved Place';
                    final dist = place != null
                        ? provider.distanceToPlaceMeters(place)
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => provider.toggleCompletion(item.id),
                            borderRadius: BorderRadius.circular(6),
                            child: Icon(
                              item.isCompleted
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: item.isCompleted
                                  ? _emerald
                                  : (item.isEnabled
                                      ? _scoutBlue
                                      : AppColors.textSecondary(context)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: item.isEnabled
                                        ? AppColors.textPrimary(context)
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                                Text(
                                  '${item.triggerType.emoji} ${item.triggerType.shortLabel} $placeName${dist != null ? ' • ${dist.round()} m' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await provider.simulateTrigger(item.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.pick(
                                        '🧭 Triggered: "${item.title}" (${item.triggerType.shortLabel} $placeName)',
                                        '🧭 Terpicu: "${item.title}" (${item.triggerType.shortLabel} $placeName)',
                                      ),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _scoutBlue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.pick('Test', 'Uji'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Text(
                      l10n.pick(
                        'No active place alerts. Tap to set reminders on arrival or departure.',
                        'Belum ada pengingat lokasi aktif. Ketuk untuk mengatur saat tiba atau pergi.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pending.length > previewItems.length
                          ? l10n.pick(
                              '+${pending.length - previewItems.length} more reminders',
                              '+${pending.length - previewItems.length} pengingat lagi',
                            )
                          : l10n.pick(
                              'Manage places & geofence rules',
                              'Kelola tempat & aturan lokasi',
                            ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: _scoutBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary(context),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
