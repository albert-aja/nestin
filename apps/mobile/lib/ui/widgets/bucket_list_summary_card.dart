import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/bucket_list_item.dart';
import '../../providers/bucket_list_provider.dart';
import '../../providers/geofence_provider.dart';
import '../screens/explore/bucket_list_screen.dart';

class BucketListSummaryCard extends StatelessWidget {
  const BucketListSummaryCard({super.key});

  static const Color _pippinEmerald = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    BucketListProvider? provider;
    try {
      provider = Provider.of<BucketListProvider>(context);
    } catch (_) {
      return const SizedBox.shrink();
    }

    GeofenceProvider? geo;
    try {
      geo = Provider.of<GeofenceProvider>(context);
    } catch (_) {}

    final l10n = context.l10n;
    final isId = l10n.isIndonesian;
    final total = provider.totalCount;
    final completed = provider.completedCount;
    final previewItems = provider.pendingItems.take(2).toList(growable: false);

    return InkWell(
      key: const Key('explore_bucket_list_card'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BucketListScreen()),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _pippinEmerald.withValues(alpha: 0.38),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _pippinEmerald.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/mascots/sprites/pippin/treasure_map.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.explore_rounded,
                      color: _pippinEmerald,
                      size: 22,
                    ),
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
                              l10n.tr('life_bucket_list_places'),
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
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _pippinEmerald.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.tr('done_2', {'completed': completed, 'total': total}),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.adaptive(
                                  context,
                                  dark: _pippinEmerald,
                                  light: const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.tr('dreams_ahead_promoted_to_echo', {'provider_pendingCount': provider.pendingCount, 'provider_promotedCount': provider.promotedCount}),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
            if (previewItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.border(context)),
              const SizedBox(height: 10),
              ...previewItems.map((item) {
                final livePlace = item.hasSavedPlaceLink && geo != null
                    ? geo.findPlaceById(item.savedPlaceId!)
                    : null;
                final placeText = item.resolvedLocationLabel(
                  livePlaceName: livePlace?.name,
                );
                final window = item.targetWindowLabel(isIndonesian: isId);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        item.category.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      if (window != null || placeText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          window ?? placeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
